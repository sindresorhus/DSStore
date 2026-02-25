import Foundation

// TODO: Use `Span` when it's available in Swift.

/**
Main type for reading and writing macOS .DS_Store files.
*/
public struct DSStore: Sendable {
	// MARK: - Constants

	private static let fileAlignment: UInt32 = 0x00000001
	private static let buddyMagic: UInt32 = 0x42756431 // "Bud1"
	private static let dsdbTableOfContentsName = "DSDB"
	private static let pageSize: UInt32 = 0x1000
	private static let filenameSortLocale = Locale(identifier: "en_US_POSIX")
	private static let filenameSortOptions: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
	private static let maxBTreeTraversalDepth = 1024

	private final class DiagnosticHandlerStorage: @unchecked Sendable {
		private let lock = NSLock()
		private var handler: ((String) -> Void)?
		private static let threadDictionaryKey = "com.sindresorhus.dsstore.diagnostic-handler"

		private final class ThreadDiagnosticHandlerBox {
			let handler: ((String) -> Void)?

			init(handler: ((String) -> Void)?) {
				self.handler = handler
			}
		}

		func set(_ handler: ((String) -> Void)?) {
			lock.lock()

			defer {
				lock.unlock()
			}

			self.handler = handler
		}

		func get() -> ((String) -> Void)? {
			if let threadHandler = Thread.current.threadDictionary[Self.threadDictionaryKey] as? ThreadDiagnosticHandlerBox {
				return threadHandler.handler
			}

			lock.lock()

			defer {
				lock.unlock()
			}

			return handler
		}

		func pushThreadLocalHandler(_ handler: ((String) -> Void)?) -> Any? {
			let previousHandler = Thread.current.threadDictionary[Self.threadDictionaryKey]
			Thread.current.threadDictionary[Self.threadDictionaryKey] = ThreadDiagnosticHandlerBox(handler: handler)
			return previousHandler
		}

		func popThreadLocalHandler(previousHandler: Any?) {
			if let previousHandler {
				Thread.current.threadDictionary[Self.threadDictionaryKey] = previousHandler
				return
			}

			Thread.current.threadDictionary.removeObject(forKey: Self.threadDictionaryKey)
		}
	}

	private static let diagnosticHandlerStorage = DiagnosticHandlerStorage()

	/**
	Optional handler for non-fatal parsing diagnostics.
	*/
	public static var diagnosticHandler: ((String) -> Void)? {
		get {
			diagnosticHandlerStorage.get()
		}
		set {
			diagnosticHandlerStorage.set(newValue)
		}
	}

	// MARK: - Properties

	/**
	All records in the DS_Store file.
	*/
	public internal(set) var records = [Record]()

	private var allocator = BuddyAllocator()

	private struct RecordKey: Hashable {
		let filename: String
		let typeCode: UInt32
	}

	private static func emitDiagnostic(_ message: String) {
		diagnosticHandlerStorage.get()?(message)
	}

	// MARK: - Initialization

	/**
	Creates an empty DS_Store container.
	*/
	public init() {}

	/**
	Creates a DS_Store container with the given records.
	*/
	public init(records: [Record]) {
		self.records = records
	}

	// MARK: - Reading

	/**
	Read a DS_Store file from the given URL.
	*/
	public static func read(from url: URL) throws(Error) -> Self {
		let data: Data
		do {
			data = try Data(contentsOf: url, options: .mappedIfSafe)
		} catch let error as CocoaError where error.code == .fileReadNoSuchFile {
			throw Error.fileNotFound
		} catch {
			throw Error.readFailed(error.localizedDescription)
		}

		return try read(from: data)
	}

	/**
	Read a DS_Store file from the given path.
	*/
	public static func read(fromPath path: String) throws(Error) -> Self {
		let url = URL(fileURLWithPath: path)
		return try read(from: url)
	}

	/**
	Read a DS_Store file from data.
	*/
	public static func read(from data: Data) throws(Error) -> Self {
		let previousDiagnosticHandler = diagnosticHandlerStorage.pushThreadLocalHandler(diagnosticHandlerStorage.get())
		defer {
			diagnosticHandlerStorage.popThreadLocalHandler(previousHandler: previousDiagnosticHandler)
		}

		var store = Self()
		let reader = BinaryReader(data: data)

		do {
			// Read file header
			let alignment = try reader.readUInt32()
			guard alignment == fileAlignment else {
				throw Error.invalidHeader
			}

			let magic = try reader.readUInt32()
			guard magic == buddyMagic else {
				throw Error.invalidMagic
			}

			let rootBlockOffset = try reader.readUInt32()
			guard let rootBlockOffsetInt = Int(exactly: rootBlockOffset),
				  rootBlockOffsetInt <= Int.max - 4
			else {
				throw Error.corruptedFile("Invalid allocator offset")
			}
			guard rootBlockOffsetInt.isMultiple(of: 4) else {
				throw Error.corruptedFile("Allocator offset is misaligned")
			}
			let rootBlockSize = try reader.readUInt32()
			guard let rootBlockSizeInt = Int(exactly: rootBlockSize) else {
				throw Error.corruptedFile("Invalid allocator block size")
			}
			guard rootBlockSizeInt >= 32 else {
				throw Error.corruptedFile("Allocator block size is too small")
			}
			guard rootBlockSize.isPowerOfTwo else {
				throw Error.corruptedFile("Allocator block size must be a power of two")
			}
			guard rootBlockSizeInt <= reader.count else {
				throw Error.corruptedFile("Allocator block size exceeds file length")
			}
			guard rootBlockOffsetInt <= reader.count - rootBlockSizeInt else {
				throw Error.corruptedFile("Allocator block exceeds file length")
			}
			guard rootBlockOffsetInt <= reader.count - 4 else {
				throw Error.corruptedFile("Allocator offset exceeds file length")
			}
			let rootBlockOffsetCheck = try reader.readUInt32()

			guard rootBlockOffset == rootBlockOffsetCheck else {
				throw Error.offsetMismatch
			}

			// Skip 16 unknown bytes
			try reader.skip(16)

			// Read buddy allocator data
			try store.readAllocator(reader: reader, offset: rootBlockOffsetInt + 4)

			guard let allocatorAddress = store.allocator.blockAddresses.first else {
				throw Error.corruptedFile("Allocator block address is missing")
			}
			let allocatorSizeBits = allocatorAddress & 0x1F
			guard allocatorSizeBits >= 5 else {
				throw Error.invalidBlockAddress
			}
			let (allocatorOffset, allocatorSize) = BuddyAllocator.decodeAddress(allocatorAddress)
			guard allocatorOffset == rootBlockOffset else {
				throw Error.corruptedFile("Allocator block offset mismatch")
			}
			guard allocatorSize == rootBlockSize else {
				throw Error.corruptedFile("Allocator block size mismatch")
			}

			// The DSDB entry is the only root for the record tree.
			guard let dsdbBlockNumber = store.allocator.tableOfContents[dsdbTableOfContentsName] else {
				throw Error.invalidBTreeHeader
			}

			try store.readBTree(reader: reader, blockNumber: Int(dsdbBlockNumber))
		} catch let error as BinaryReader.Error {
			switch error {
			case .invalidUTF16String:
				throw Error.invalidUTF16String
			default:
				throw Error.corruptedFile(error.localizedDescription)
			}
		} catch let error as BuddyAllocator.Error {
			switch error {
			case .invalidBlockAddress:
				throw Error.invalidBlockAddress
			}
		} catch let error as Error {
			throw error
		} catch {
			throw Error.corruptedFile(error.localizedDescription)
		}

		return store
	}

	private mutating func readAllocator(reader: BinaryReader, offset: Int) throws {
		try reader.seek(to: offset)

		// Read block addresses count
		let blockCountRaw = try reader.readUInt32()
		guard let blockCount = Int(exactly: blockCountRaw) else {
			throw Error.corruptedFile("Invalid block count")
		}
		guard blockCount > 0 else {
			throw Error.corruptedFile("Invalid block count")
		}
		allocator.blockCount = blockCount

		let unknown = try reader.readUInt32()
		if unknown != 0 {
			Self.emitDiagnostic("Allocator header contains non-zero reserved value")
		}

		let addressCount = max(256, blockCount.roundedUp(toMultipleOf: 256))
		let (addressesByteCount, overflow) = addressCount.multipliedReportingOverflow(by: 4)
		guard !overflow, addressesByteCount <= reader.remaining else {
			throw Error.corruptedFile("Block addresses exceed remaining data")
		}
		allocator.blockAddresses = []
		allocator.blockAddresses.reserveCapacity(addressCount)
		for _ in 0..<addressCount {
			let address = try reader.readUInt32()
			allocator.blockAddresses.append(address)
		}
		if blockCount < addressCount {
			for index in blockCount..<addressCount where allocator.blockAddresses[index] != 0 {
				throw Error.corruptedFile("Block address exceeds block count")
			}
		}

		// Read table of contents
		let tableOfContentsCountRaw = try reader.readUInt32()
		guard let tableOfContentsCount = Int(exactly: tableOfContentsCountRaw) else {
			throw Error.corruptedFile("Invalid table of contents count")
		}
		guard tableOfContentsCount > 0 else {
			throw Error.corruptedFile("Missing table of contents")
		}
		guard tableOfContentsCount <= blockCount else {
			throw Error.corruptedFile("Table of contents count exceeds block count")
		}
		guard tableOfContentsCount <= reader.remaining / 5 else {
			throw Error.corruptedFile("Table of contents exceeds remaining data")
		}
		allocator.tableOfContents = [:]

		for _ in 0..<tableOfContentsCount {
			let nameLength = Int(try reader.readUInt8())
			guard nameLength > 0 else {
				throw Error.corruptedFile("Table of contents entry has empty name")
			}
			guard nameLength <= reader.remaining else {
				throw Error.corruptedFile("Table of contents name exceeds remaining data")
			}
			let name = try reader.readASCIIString(byteCount: nameLength)
			guard allocator.tableOfContents[name] == nil else {
				throw Error.corruptedFile("Duplicate table of contents entry")
			}
			let blockNumber = try reader.readUInt32()
			guard blockNumber < blockCountRaw else {
				throw Error.corruptedFile("Table of contents block number exceeds block count")
			}
			guard blockNumber != 0 else {
				throw Error.corruptedFile("Table of contents block number is invalid")
			}
			allocator.tableOfContents[name] = blockNumber
			if name != Self.dsdbTableOfContentsName {
				Self.emitDiagnostic("Unknown table of contents entry: \(name)")
			}
		}

		// Read free lists (32 lists, one for each power of 2)
		allocator.freeLists = []
		for sizePower in 0..<32 {
			let countRaw = try reader.readUInt32()
			guard let count = Int(exactly: countRaw) else {
				throw Error.corruptedFile("Invalid free list count")
			}

			let (freeListByteCount, freeListOverflow) = count.multipliedReportingOverflow(by: 4)
			guard
				!freeListOverflow,
				freeListByteCount <= reader.remaining
			else {
				throw Error.corruptedFile("Free list exceeds remaining data")
			}

			var freeList = [UInt32]()
			for _ in 0..<count {
				let offset = try reader.readUInt32()
				let alignment = UInt32(1) << UInt32(sizePower)
				if
					alignment > 0,
					!offset.isMultiple(of: alignment)
				{
					throw Error.corruptedFile("Free list offset is misaligned")
				}

				freeList.append(offset)
			}

			allocator.freeLists.append(freeList)
		}
	}

	private mutating func readBTree(reader: BinaryReader, blockNumber: Int) throws {
		let (offset, size) = try allocator.blockOffset(for: blockNumber)
		guard offset <= reader.count - size else {
			throw Error.corruptedFile("B-tree block exceeds file length")
		}
		guard size >= BTreeHeader.headerSize else {
			throw Error.invalidBTreeHeader
		}
		try reader.seek(to: offset)

		// Read B-tree header
		let rootNodeBlockNumber = try reader.readUInt32()
		guard rootNodeBlockNumber != 0 else {
			throw Error.invalidBTreeHeader
		}
		let treeHeight = try reader.readUInt32()
		let recordCount = try reader.readUInt32()
		let nodeCount = try reader.readUInt32()
		let pageSize = try reader.readUInt32()
		guard let nodeCountInt = Int(exactly: nodeCount), nodeCountInt > 0 else {
			throw Error.corruptedFile("Invalid B-tree node count")
		}
		guard treeHeight <= nodeCount else {
			throw Error.corruptedFile("B-tree height exceeds node count")
		}

		guard pageSize == Self.pageSize else {
			throw Error.invalidBTreeHeader
		}

		guard reader.position <= offset + size else {
			throw Error.corruptedFile("B-tree header exceeds block size")
		}

		// Walk the tree instead of trusting header counts so we can validate structure.
		var visitedNodes = Set<Int>()
		var totalRecordCount = 0
		var maxInternalDepth = 0
		var hasInternalNodes = false
		var previousLeafRecord: Record?
		let maxTraversalDepth = max(1, min(nodeCountInt, Self.maxBTreeTraversalDepth))
		try traverseNode(
			reader: reader,
			blockNumber: Int(rootNodeBlockNumber),
			depth: 0,
			maxDepth: maxTraversalDepth,
			visitedNodes: &visitedNodes,
			totalRecordCount: &totalRecordCount,
			maxInternalDepth: &maxInternalDepth,
			hasInternalNodes: &hasInternalNodes,
			previousLeafRecord: &previousLeafRecord
		)

		guard let totalRecordCountValue = UInt32(exactly: totalRecordCount) else {
			throw Error.corruptedFile("B-tree record count exceeds UInt32")
		}

		if nodeCount != UInt32(visitedNodes.count) {
			throw Error.corruptedFile("B-tree node count mismatch")
		}
		if recordCount != totalRecordCountValue {
			throw Error.corruptedFile("B-tree record count mismatch")
		}
		// Spec stores the count of internal node levels, not total depth.
		let internalLevels = hasInternalNodes ? UInt32(maxInternalDepth + 1) : 0
		if treeHeight != internalLevels {
			throw Error.corruptedFile("B-tree height mismatch")
		}

		var recordKeys = Set<RecordKey>()
		for record in records {
			let key = RecordKey(filename: record.filename, typeCode: record.type.fourCC.rawValue)
			guard recordKeys.insert(key).inserted else {
				throw Error.corruptedFile("Duplicate record key")
			}
		}
	}

	private mutating func traverseNode(
		reader: BinaryReader,
		blockNumber: Int,
		depth: Int,
		maxDepth: Int,
		visitedNodes: inout Set<Int>,
		totalRecordCount: inout Int,
		maxInternalDepth: inout Int,
		hasInternalNodes: inout Bool,
		previousLeafRecord: inout Record?
	) throws {
		guard depth <= maxDepth else {
			throw Error.corruptedFile("B-tree depth exceeds supported limit")
		}

		guard visitedNodes.insert(blockNumber).inserted else {
			throw Error.corruptedFile("B-tree contains duplicate node reference")
		}
		let (offset, size) = try allocator.blockOffset(for: blockNumber)
		guard offset <= reader.count - size else {
			throw Error.corruptedFile("Node exceeds file length")
		}
		guard size <= Int(Self.pageSize) else {
			throw Error.invalidBTreeHeader
		}
		guard offset <= Int.max - size else {
			throw Error.corruptedFile("Node size exceeds supported range")
		}
		let nodeEnd = offset + size
		try reader.seek(to: offset)

		// Read node header
		let rightmostChild = try reader.readUInt32() // P - rightmost child pointer (0 if leaf)
		let recordCountRaw = try reader.readUInt32()
		guard let recordCount = Int(exactly: recordCountRaw) else {
			throw Error.corruptedFile("Invalid record count")
		}
		guard reader.position <= nodeEnd else {
			throw Error.corruptedFile("Node header exceeds block size")
		}

		if rightmostChild == 0 {
			let remainingInNode = nodeEnd - reader.position
			let minimumRecordSize = 12
			if recordCount > 0, recordCount > remainingInNode / minimumRecordSize {
				throw Error.corruptedFile("Leaf node record count exceeds block size")
			}
			// Leaf node - read records directly
			for _ in 0..<recordCount {
				let record = try readRecord(reader: reader)
				guard reader.position <= nodeEnd else {
					throw Error.corruptedFile("Leaf node record exceeds block size")
				}
				if let previousLeafRecord,
				   Self.compareRecords(previousLeafRecord, record) == .orderedDescending
				{
					Self.emitDiagnostic("Leaf node record order is invalid for \(previousLeafRecord.filename)")
				}
				records.append(record)
				totalRecordCount += 1
				previousLeafRecord = record
			}
		} else {
			hasInternalNodes = true
			maxInternalDepth = max(maxInternalDepth, depth)
			guard recordCount > 0 else {
				throw Error.corruptedFile("Internal node has no records")
			}
			let remainingInNode = nodeEnd - reader.position
			let minimumRecordSize = 16
			if recordCount > remainingInNode / minimumRecordSize {
				throw Error.corruptedFile("Internal node record count exceeds block size")
			}

			// Internal node - alternate between child pointers and records
			for _ in 0..<recordCount {
				let childBlockNumber = try reader.readUInt32()
				guard childBlockNumber != 0 else {
					throw Error.corruptedFile("Internal node contains zero child pointer")
				}

				// Save position before recursing
				let savedPosition = reader.position

				try traverseNode(
					reader: reader,
					blockNumber: Int(childBlockNumber),
					depth: depth + 1,
					maxDepth: maxDepth,
					visitedNodes: &visitedNodes,
					totalRecordCount: &totalRecordCount,
					maxInternalDepth: &maxInternalDepth,
					hasInternalNodes: &hasInternalNodes,
					previousLeafRecord: &previousLeafRecord
				)

				// Restore position after recursive call to continue reading this node
				try reader.seek(to: savedPosition)

				let record = try readRecord(reader: reader)
				guard reader.position <= nodeEnd else {
					throw Error.corruptedFile("Internal node record exceeds block size")
				}
				if let previousLeafRecord,
				   Self.compareRecords(previousLeafRecord, record) == .orderedDescending
				{
					Self.emitDiagnostic("Internal node record order is invalid for \(previousLeafRecord.filename)")
				}
				records.append(record)
				totalRecordCount += 1
				previousLeafRecord = record
			}

			// Visit rightmost child
			try traverseNode(
				reader: reader,
				blockNumber: Int(rightmostChild),
				depth: depth + 1,
				maxDepth: maxDepth,
				visitedNodes: &visitedNodes,
				totalRecordCount: &totalRecordCount,
				maxInternalDepth: &maxInternalDepth,
				hasInternalNodes: &hasInternalNodes,
				previousLeafRecord: &previousLeafRecord
			)
		}
	}

	private func readRecord(reader: BinaryReader) throws -> Record {
		// Read filename
		let filenameLength = try reader.readUInt32()
		guard let filenameLength = Int(exactly: filenameLength) else {
			throw Error.corruptedFile("Invalid filename length")
		}
		guard filenameLength <= reader.remaining / 2 else {
			throw Error.corruptedFile("Filename exceeds remaining data")
		}
		let filename = try reader.readUTF16String(characterCount: filenameLength)

		// Read structure type (FourCC)
		let structureType = try reader.readFourCC()
		guard structureType.rawValue != 0 else {
			throw Error.corruptedFile("Invalid record type")
		}
		let recordType = RecordType(fourCC: structureType)

		// Read data type (FourCC)
		let dataType = try reader.readFourCC()

		// Read value based on data type
		let value = try readValue(reader: reader, dataType: dataType)

		return Record(filename: filename, type: recordType, value: value)
	}

	private static func compareFilenames(_ left: String, _ right: String) -> ComparisonResult {
		left.compare(
			right,
			options: filenameSortOptions,
			range: nil,
			locale: Self.filenameSortLocale
		)
	}

	private func readValue(reader: BinaryReader, dataType: FourCC) throws -> Value {
		switch dataType {
		case .null:
			return .null
		case .bool:
			let byte = try reader.readUInt8()
			guard byte <= 1 else {
				throw Error.corruptedFile("Invalid bool value")
			}
			return .boolean(byte != 0)
		case .long:
			let value = try reader.readUInt32()
			return .uint32(value)
		case .shor:
			// Stored as 4 bytes, but only lower 2 are significant
			let rawValue = try reader.readUInt32()
			guard let value = UInt16(exactly: rawValue) else {
				throw Error.corruptedFile("Invalid shor value")
			}
			return .uint16(value)
		case .comp:
			let value = try reader.readUInt64()
			return .uint64(value)
		case .dutc:
			// Mac epoch timestamp: (1/65536)-second intervals since 1904-01-01
			let rawValue = try reader.readUInt64()
			return .timestamp(Date(macEpochTimeUnits: rawValue))
		case .type:
			let fourCC = try reader.readFourCC()
			return .fourCC(fourCC)
		case .ustr:
			let length = try reader.readUInt32()
			guard let length = Int(exactly: length) else {
				throw Error.corruptedFile("Invalid string length")
			}
			guard length <= reader.remaining / 2 else {
				throw Error.corruptedFile("String exceeds remaining data")
			}
			let string = try reader.readUTF16String(characterCount: length)
			return .string(string)
		case .blob:
			let data = try readLengthPrefixedData(reader: reader, label: "Blob")

			// Check if blob is a plist and parse it
			if data.isPropertyListData {
				if let object = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
				   let plistValue = PlistValue(object)
				{
					return .propertyList(plistValue)
				}
			}

			return .data(data)
		case .book:
			return .bookmark(try readLengthPrefixedData(reader: reader, label: "Bookmark"))
		default:
			throw Error.unknownDataType(dataType.stringValue)
		}
	}

	private func readLengthPrefixedData(reader: BinaryReader, label: String) throws -> Data {
		let lengthRaw = try reader.readUInt32()
		guard let length = Int(exactly: lengthRaw) else {
			throw Error.corruptedFile("Invalid \(label.lowercased()) length")
		}
		guard length <= reader.remaining else {
			throw Error.corruptedFile("\(label) exceeds remaining data")
		}
		return try reader.readBytes(length)
	}

	// MARK: - Writing

	/**
	Write the DS_Store to a file at the given URL.
	*/
	public func write(to url: URL) throws(Error) {
		let data = try serialize()
		do {
			try data.write(to: url)
		} catch {
			throw Error.writeFailed(error.localizedDescription)
		}
	}

	/**
	Write the DS_Store to the given file path.
	*/
	public func write(toPath path: String) throws(Error) {
		let url = URL(fileURLWithPath: path)
		try write(to: url)
	}

	/**
	Serialize the DS_Store to Data.
	*/
	public func serialize() throws(Error) -> Data {
		do {
			return try serializeData()
		} catch let error as BinaryWriter.Error {
			throw Error.writeFailed(error.localizedDescription)
		} catch let error as Error {
			throw error
		} catch {
			throw Error.writeFailed(error.localizedDescription)
		}
	}

	/**
	Reference type keeps parent/child edits in sync during bulk-loading.
	*/
	private final class BTreeNode {
		let blockID: UInt32
		let isLeaf: Bool
		var records: [Data]
		var children: [BTreeNode]

		init(blockID: UInt32, isLeaf: Bool, records: [Data], children: [BTreeNode]) {
			self.blockID = blockID
			self.isLeaf = isLeaf
			self.records = records
			self.children = children
		}
	}

	private struct AllocatedBlock {
		let blockID: UInt32
		let offset: UInt32
		let sizePower: UInt32
	}

	private func serializeData() throws -> Data {
		var recordKeys = Set<RecordKey>()
		for record in records {
			let key = RecordKey(filename: record.filename, typeCode: record.type.fourCC.rawValue)
			if !recordKeys.insert(key).inserted {
				throw Error.writeFailed("Duplicate record key")
			}
		}

		// Finder expects a deterministic sort order for record keys.
		let sortedRecords = records.sorted { r1, r2 in
			Self.compareRecords(r1, r2) == .orderedAscending
		}

		// Pre-encode records so we can size pages without re-serializing.
		let encodedRecords = try sortedRecords.map { try encodeRecord($0) }
		let btreeInfo = try buildBTreeNodes(encodedRecords)

		// Keep the root metadata block in the canonical location to match existing tools.
		let rootMetadataBlockOffset: UInt32 = 0x20
		let rootMetadataBlockSizePower: UInt32 = 5
		let rootMetadataBlockSize = UInt32(1) << rootMetadataBlockSizePower

		var allocatedBlocks = [AllocatedBlock]()
		allocatedBlocks.append(AllocatedBlock(blockID: 1, offset: rootMetadataBlockOffset, sizePower: rootMetadataBlockSizePower))

		// Finder stores nodes in smaller power-of-two blocks even though page size is 4 KiB.
		let nodeData = try btreeInfo.nodes.map { node -> (node: BTreeNode, data: Data, sizePower: UInt32, blockSize: UInt32) in
			let data = try buildNodeData(node)
			guard let sizePower = data.count.powerOfTwoSizePower() else {
				throw Error.writeFailed("Allocation size exceeds supported range")
			}
			guard let blockSize = data.count.powerOfTwoSize() else {
				throw Error.writeFailed("Allocation size exceeds supported range")
			}
			return (node: node, data: data, sizePower: sizePower, blockSize: blockSize)
		}

		var nodeOffsets = [UInt32: UInt32]()
		// Pack node blocks sequentially so allocator free lists stay stable.
		var cursor = rootMetadataBlockOffset + rootMetadataBlockSize
		for entry in nodeData {
			let offset = cursor.roundedUp(toMultipleOf: entry.blockSize)
			nodeOffsets[entry.node.blockID] = offset
			allocatedBlocks.append(AllocatedBlock(blockID: entry.node.blockID, offset: offset, sizePower: entry.sizePower))
			cursor = offset + entry.blockSize
		}

		// Choose the smallest allocator block that can hold the metadata.
		var allocatorSizePower: UInt32 = 12
		var allocatorOffset: UInt32 = 0
		var allocatorData = Data()
		var allocatorBlockSize: UInt32 = 0

		while true {
			allocatorBlockSize = UInt32(1) << allocatorSizePower
			// Keep allocator block aligned so its address encoding matches the block table.
			allocatorOffset = cursor.roundedUp(toMultipleOf: allocatorBlockSize)
			var blocks = allocatedBlocks
			blocks.append(AllocatedBlock(blockID: 0, offset: allocatorOffset, sizePower: allocatorSizePower))

			let freeLists = try buildFreeLists(allocatedBlocks: blocks, fileEnd: allocatorOffset + allocatorBlockSize)
			allocatorData = try buildAllocatorData(
				allocatedBlocks: blocks,
				freeLists: freeLists,
				blockCount: blocks.map(\.blockID).max().map { $0 + 1 } ?? 1
			)

			if allocatorData.count <= Int(allocatorBlockSize) {
				break
			}

			allocatorSizePower += 1
			if allocatorSizePower > 31 {
				throw Error.writeFailed("Allocator block exceeds supported range")
			}
		}

		// Build the final file
		let writer = BinaryWriter()

		// File alignment prefix
		writer.writeUInt32(Self.fileAlignment)

		// Buddy allocator header
		writer.writeUInt32(Self.buddyMagic)

		writer.writeUInt32(allocatorOffset)
		writer.writeUInt32(UInt32(1) << allocatorSizePower)
		writer.writeUInt32(allocatorOffset) // Duplicate for validation

		// 16 unknown bytes (zeros)
		writer.writeZeros(16)

		// Write B-tree root metadata block at offset 0x24
		writer.writePadding(toOffset: Int(rootMetadataBlockOffset) + 4)
		writer.writeUInt32(btreeInfo.rootBlockID)
		// Header stores internal node levels (0 when the root is a leaf).
		writer.writeUInt32(btreeInfo.treeHeight)
		writer.writeUInt32(btreeInfo.recordCount)
		writer.writeUInt32(UInt32(btreeInfo.nodes.count))
		writer.writeUInt32(Self.pageSize)
		writer.writeZeros(Int(rootMetadataBlockSize) - BTreeHeader.headerSize)

		for entry in nodeData {
			guard let nodeOffset = nodeOffsets[entry.node.blockID] else {
				throw Error.writeFailed("Missing node offset")
			}
			writer.writePadding(toOffset: Int(nodeOffset) + 4)
			writer.writeBytes(entry.data)
			if entry.data.count < Int(entry.blockSize) {
				writer.writeZeros(Int(entry.blockSize) - entry.data.count)
			}
		}

		writer.writePadding(toOffset: Int(allocatorOffset) + 4)
		writer.writeBytes(allocatorData)
		if allocatorData.count < Int(allocatorBlockSize) {
			// Keep file length aligned to allocator block size to match block metadata.
			writer.writeZeros(Int(allocatorBlockSize) - allocatorData.count)
		}

		return writer.data
	}

	private static func compareRecords(_ lhs: Record, _ rhs: Record) -> ComparisonResult {
		let filenameComparison = compareFilenames(lhs.filename, rhs.filename)
		if filenameComparison != .orderedSame {
			return filenameComparison
		}

		if lhs.type.fourCC.rawValue == rhs.type.fourCC.rawValue {
			return .orderedSame
		}

		return lhs.type.fourCC.rawValue < rhs.type.fourCC.rawValue ? .orderedAscending : .orderedDescending
	}

	private func encodeRecord(_ record: Record) throws -> Data {
		let writer = BinaryWriter()

		guard !record.filename.unicodeScalars.contains(where: { $0.value == 0 }) else {
			throw Error.writeFailed("Filename contains a null character")
		}
		let utf16Count = record.filename.utf16.count
		guard let utf16Count = UInt32(exactly: utf16Count) else {
			throw Error.writeFailed("Filename is too long")
		}
		writer.writeUInt32(utf16Count)
		writer.writeUTF16String(record.filename)
		writer.writeFourCC(record.type.fourCC)
		try writeValue(writer: writer, value: record.value)

		return writer.data
	}

	private func buildBTreeNodes(_ recordData: [Data]) throws -> (nodes: [BTreeNode], rootBlockID: UInt32, treeHeight: UInt32, recordCount: UInt32) {
		let pageSize = Int(Self.pageSize)

		/**
		Use on-disk layout sizes so splits match how Finder stores nodes.
		*/
		func nodeSize(records: [Data], isLeaf: Bool) -> Int {
			let perRecordOverhead = isLeaf ? 0 : 4
			let recordsSize = records.reduce(0) { $0 + $1.count + perRecordOverhead }
			return 8 + recordsSize
		}

		/**
		Choose a separator that keeps both halves within the page size budget.
		*/
		func splitIndex(for records: [Data], isLeaf: Bool) throws -> Int {
			let perRecordOverhead = isLeaf ? 0 : 4
			let recordSizes = records.map { $0.count + perRecordOverhead }
			var prefix = [Int](repeating: 0, count: recordSizes.count + 1)
			for (index, size) in recordSizes.enumerated() {
				prefix[index + 1] = prefix[index] + size
			}
			let totalSize = prefix.last ?? 0

			func findIndex(allowEmpty: Bool) -> Int? {
				var bestIndex: Int?
				var bestBalance = Int.max

				for index in 0..<records.count {
					if !allowEmpty, index == 0 || index == records.count - 1 {
						continue
					}
					let leftSize = 8 + prefix[index]
					let rightSize = 8 + (totalSize - prefix[index + 1])
					guard leftSize <= pageSize, rightSize <= pageSize else {
						continue
					}
					let balance = abs(leftSize - rightSize)
					if balance < bestBalance {
						bestBalance = balance
						bestIndex = index
					}
				}
				return bestIndex
			}

			if let index = findIndex(allowEmpty: false) {
				return index
			}
			if let index = findIndex(allowEmpty: true) {
				return index
			}
			throw Error.writeFailed("Unable to split B-tree node")
		}

		var nextBlockID: UInt32 = 2
		func allocateBlockID() -> UInt32 {
			let blockIdentifier = nextBlockID
			nextBlockID += 1
			return blockIdentifier
		}

		var root = BTreeNode(blockID: allocateBlockID(), isLeaf: true, records: [], children: [])

		func splitNode(_ node: BTreeNode) throws -> (promoted: Data, rightNode: BTreeNode) {
			let index = try splitIndex(for: node.records, isLeaf: node.isLeaf)
			let promoted = node.records[index]
			let leftRecords = Array(node.records[..<index])
			let rightRecords = Array(node.records[(index + 1)...])

			if node.isLeaf {
				node.records = leftRecords
				let rightNode = BTreeNode(blockID: allocateBlockID(), isLeaf: true, records: rightRecords, children: [])
				return (promoted, rightNode)
			}

			let leftChildrenCount = leftRecords.count + 1
			guard node.children.count >= leftChildrenCount else {
				throw Error.writeFailed("Invalid internal node structure")
			}
			let rightChildren = Array(node.children[leftChildrenCount...])
			node.children = Array(node.children[..<leftChildrenCount])
			node.records = leftRecords

			let rightNode = BTreeNode(blockID: allocateBlockID(), isLeaf: false, records: rightRecords, children: rightChildren)
			return (promoted, rightNode)
		}

		/**
		Records are already sorted, so we always append down the rightmost path.
		*/
		func insertRecord(_ record: Data, into node: BTreeNode) throws -> (promoted: Data, rightNode: BTreeNode)? {
			if node.isLeaf {
				node.records.append(record)
			} else {
				guard let rightmostChild = node.children.last else {
					throw Error.writeFailed("Missing child pointer")
				}
				if let split = try insertRecord(record, into: rightmostChild) {
					node.records.append(split.promoted)
					node.children.append(split.rightNode)
				}
			}

			if nodeSize(records: node.records, isLeaf: node.isLeaf) <= pageSize {
				return nil
			}
			return try splitNode(node)
		}

		for record in recordData {
			if record.count + 8 > pageSize {
				throw Error.writeFailed("Record exceeds B-tree page size")
			}
			if let split = try insertRecord(record, into: root) {
				root = BTreeNode(blockID: allocateBlockID(), isLeaf: false, records: [split.promoted], children: [root, split.rightNode])
			}
		}

		var nodes = [BTreeNode]()
		var maxInternalDepth = 0
		var hasInternalNodes = false

		func collectNodes(from node: BTreeNode, depth: Int) {
			nodes.append(node)
			if !node.isLeaf {
				hasInternalNodes = true
				maxInternalDepth = max(maxInternalDepth, depth)
			}
			for child in node.children {
				collectNodes(from: child, depth: depth + 1)
			}
		}

		collectNodes(from: root, depth: 0)

		guard let recordCount = UInt32(exactly: recordData.count) else {
			throw Error.writeFailed("Record count exceeds UInt32")
		}

		let internalLevels = hasInternalNodes ? UInt32(maxInternalDepth + 1) : 0
		return (nodes: nodes, rootBlockID: root.blockID, treeHeight: internalLevels, recordCount: recordCount)
	}

	private func buildNodeData(_ node: BTreeNode) throws -> Data {
		let writer = BinaryWriter()
		if node.isLeaf {
			guard let recordCount = UInt32(exactly: node.records.count) else {
				throw Error.writeFailed("Record count exceeds UInt32")
			}
			writer.writeUInt32(0)
			writer.writeUInt32(recordCount)
			for record in node.records {
				writer.writeBytes(record)
			}
		} else {
			guard node.children.count == node.records.count + 1 else {
				throw Error.writeFailed("Invalid internal node structure")
			}
			guard let rightmostChild = node.children.last else {
				throw Error.writeFailed("Missing rightmost child")
			}
			guard let recordCount = UInt32(exactly: node.records.count) else {
				throw Error.writeFailed("Record count exceeds UInt32")
			}
			writer.writeUInt32(rightmostChild.blockID)
			writer.writeUInt32(recordCount)
			for index in 0..<node.records.count {
				writer.writeUInt32(node.children[index].blockID)
				writer.writeBytes(node.records[index])
			}
		}
		guard writer.count <= Int(Self.pageSize) else {
			throw Error.writeFailed("Node exceeds page size")
		}
		return writer.data
	}

	private func writeValue(writer: BinaryWriter, value: Value) throws {
		switch value {
		case .boolean(let booleanValue):
			writer.writeFourCC(.bool)
			writer.writeUInt8(booleanValue ? 1 : 0)
		case .uint32(let uint32Value):
			writer.writeFourCC(.long)
			writer.writeUInt32(uint32Value)
		case .uint16(let uint16Value):
			writer.writeFourCC(.shor)
			writer.writeUInt32(UInt32(uint16Value))
		case .uint64(let uint64Value):
			writer.writeFourCC(.comp)
			writer.writeUInt64(uint64Value)
		case .timestamp(let date):
			writer.writeFourCC(.dutc)
			guard let rawValue = date.macEpochTimeUnits else {
				throw Error.writeFailed("Date is outside supported range")
			}
			writer.writeUInt64(rawValue)
		case .fourCC(let fourCC):
			writer.writeFourCC(.type)
			writer.writeFourCC(fourCC)

		case .string(let string):
			writer.writeFourCC(.ustr)
			guard let utf16Count = UInt32(exactly: string.utf16.count) else {
				throw Error.writeFailed("String is too long")
			}
			writer.writeUInt32(utf16Count)
			writer.writeUTF16String(string)
		case .data(let data):
			writer.writeFourCC(.blob)
			guard let dataCount = UInt32(exactly: data.count) else {
				throw Error.writeFailed("Blob is too large")
			}
			writer.writeUInt32(dataCount)
			writer.writeBytes(data)
		case .bookmark(let data):
			writer.writeFourCC(.book)
			guard let dataCount = UInt32(exactly: data.count) else {
				throw Error.writeFailed("Bookmark is too large")
			}
			writer.writeUInt32(dataCount)
			writer.writeBytes(data)
		case .null:
			writer.writeFourCC(.null)
		case .propertyList(let plistValue):
			writer.writeFourCC(.blob)
			let data = try plistValue.serialized()
			guard let dataCount = UInt32(exactly: data.count) else {
				throw Error.writeFailed("Plist is too large")
			}
			writer.writeUInt32(dataCount)
			writer.writeBytes(data)
		}
	}

	private func buildAllocatorData(allocatedBlocks: [AllocatedBlock], freeLists: [[UInt32]], blockCount: UInt32) throws -> Data {
		let writer = BinaryWriter()

		writer.writeUInt32(blockCount) // Number of blocks
		writer.writeUInt32(0) // Unknown (always 0)

		guard let blockCountInt = Int(exactly: blockCount) else {
			throw Error.writeFailed("Block count exceeds Int")
		}
		let addressCount = max(256, blockCountInt.roundedUp(toMultipleOf: 256))
		var blockAddresses = [UInt32](repeating: 0, count: addressCount)
		for block in allocatedBlocks {
			guard let blockIndex = Int(exactly: block.blockID), blockIndex < addressCount else {
				throw Error.writeFailed("Block count exceeds allocator limit")
			}
			blockAddresses[blockIndex] = BuddyAllocator.encodeAddress(offset: block.offset, sizePower: block.sizePower)
		}
		for address in blockAddresses {
			writer.writeUInt32(address)
		}

		// Table of contents
		writer.writeUInt32(1) // One TOC entry
		writer.writeUInt8(4) // "DSDB" length
		try writer.writeASCIIString("DSDB")
		writer.writeUInt32(1) // Block number 1 (B-tree master)

		// Free lists (32 lists)
		for list in freeLists {
			writer.writeUInt32(UInt32(list.count))
			for offset in list {
				writer.writeUInt32(offset)
			}
		}

		return writer.data
	}

	private func buildFreeLists(allocatedBlocks: [AllocatedBlock], fileEnd: UInt32) throws -> [[UInt32]] {
		struct Range {
			let offset: UInt32
			let size: UInt32
		}

		var allocated: [Range] = [
			Range(offset: 0, size: 0x20) // Keep allocator from reusing the file header space.
		]

		for block in allocatedBlocks {
			let size = UInt32(1) << block.sizePower
			allocated.append(Range(offset: block.offset, size: size))
		}

		allocated.sort { $0.offset < $1.offset }
		for index in 1..<allocated.count {
			let previous = allocated[index - 1]
			let current = allocated[index]
			if previous.offset + previous.size > current.offset {
				throw Error.writeFailed("Allocated blocks overlap")
			}
		}

		var freeRanges = [Range]()
		var cursor: UInt32 = 0
		for range in allocated {
			if cursor < range.offset {
				freeRanges.append(Range(offset: cursor, size: range.offset - cursor))
			}
			cursor = range.offset + range.size
		}
		if cursor < fileEnd {
			freeRanges.append(Range(offset: cursor, size: fileEnd - cursor))
		}

		var freeLists = Array(repeating: [UInt32](), count: 32)
		for range in freeRanges {
			var offset = range.offset
			var remaining = range.size
			while remaining > 0 {
				// Split into power-of-two blocks to match buddy allocator semantics.
				let maxPower = Int(31 - remaining.leadingZeroBitCount)
				var power = maxPower
				while power >= 5 {
					let size = UInt32(1) << power
					if
						offset.isMultiple(of: size),
						size <= remaining
					{
						freeLists[power].append(offset)
						offset += size
						remaining -= size
						break
					}
					power -= 1
				}
				if power < 5 {
					throw Error.writeFailed("Unable to align free blocks")
				}
			}
		}

		return freeLists
	}
}

// MARK: - CustomStringConvertible

extension DSStore: CustomStringConvertible {
	/**
	Debug description listing all records.
	*/
	public var description: String {
		var result = "DSStore with \(records.count) \(records.count == 1 ? "record" : "records"):\n"
		for record in records {
			result += "  \(record)\n"
		}
		return result
	}
}
