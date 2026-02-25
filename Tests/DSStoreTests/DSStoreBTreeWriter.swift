import Foundation
import Testing
@testable import DSStore

private typealias FourCC = DSStore.FourCC

@Suite("DSStore B-tree Writer", .serialized)
struct DSStoreBTreeWriterTests {
	@Test("Writes multi-level B-tree nodes")
	func writesMultiLevelBTreeNodes() throws {
		var store = DSStore()
		let iconData = Data(repeating: 0x42, count: 16)

		for index in 0..<1500 {
			let filename = String(format: "File-%04d.txt", index)
			store.add(DSStore.Record(filename: filename, type: .iconLocation, value: .data(iconData)))
		}

		let data = try store.serialize()
		let parsed = try BTreeTestParser.parse(data)

		#expect(parsed.header.treeHeight >= 1)
		#expect(parsed.header.nodeCount >= 2)
		#expect(parsed.header.recordCount == 1500)
		#expect(parsed.header.pageSize == 0x1000)

		let records = try BTreeTestParser.readAllRecords(parsed: parsed)
		#expect(records.count == 1500)
	}

	@Test("Allocator free lists include padding gaps")
	func allocatorFreeListsIncludePaddingGaps() throws {
		var store = DSStore()
		for index in 0..<10 {
			let filename = "File-\(index).txt"
			store.add(DSStore.Record(filename: filename, type: .iconLocation, value: .data(Data(repeating: 0, count: 16))))
		}

		let data = try store.serialize()
		let parsed = try BTreeTestParser.parse(data)
		let freeListCount = parsed.allocator.freeLists.reduce(0) { $0 + $1.count }

		#expect(freeListCount > 0)
		for (power, offsets) in parsed.allocator.freeLists.enumerated() {
			let alignment = UInt32(1) << power
			for offset in offsets {
				#expect(offset.isMultiple(of: alignment))
			}
		}
	}

	@Test("Rejects records larger than a page")
	func rejectsOversizedRecord() {
		var store = DSStore()
		let oversizedData = Data(repeating: 0, count: 0x2000)
		store.add(DSStore.Record(filename: "TooBig", type: .iconLocation, value: .data(oversizedData)))

		#expect(throws: DSStore.Error.self) {
			_ = try store.serialize()
		}
	}

	@Test("Builds tree when records fill most of a page")
	func buildsTreeWithLargeRecords() throws {
		var store = DSStore()
		let largeData = Data(repeating: 0x4F, count: 4000)

		for index in 0..<3 {
			let filename = "Large-\(index).bin"
			store.add(DSStore.Record(filename: filename, type: .iconLocation, value: .data(largeData)))
		}

		let data = try store.serialize()
		let parsed = try BTreeTestParser.parse(data)
		let records = try BTreeTestParser.readAllRecords(parsed: parsed)

		#expect(parsed.header.recordCount == 3)
		#expect(records.count == 3)
	}

	@Test("Node blocks are power-of-two sized and at most a page")
	func nodeBlocksUsePowerOfTwoSizes() throws {
		var store = DSStore()
		let data = Data(repeating: 0x1F, count: 120)

		for index in 0..<40 {
			let filename = "Item-\(index)"
			store.add(DSStore.Record(filename: filename, type: .iconLocation, value: .data(data)))
		}

		let fileData = try store.serialize()
		let parsed = try BTreeTestParser.parse(fileData)
		let nodeBlocks = try BTreeTestParser.readAllNodeBlocks(parsed: parsed)

		for blockNumber in nodeBlocks {
			let size = try BTreeTestParser.blockSize(allocator: parsed.allocator, blockNumber: blockNumber)
			#expect(size >= 32)
			#expect(size <= 0x1000)
			#expect((size & (size - 1)) == 0)
		}
	}

	@Test("Node blocks use minimal power-of-two size")
	func nodeBlocksUseMinimalSize() throws {
		var store = DSStore()
		let data = Data(repeating: 0x2A, count: 180)

		for index in 0..<60 {
			let filename = "Node-\(index)"
			store.add(DSStore.Record(filename: filename, type: .iconLocation, value: .data(data)))
		}

		let fileData = try store.serialize()
		let parsed = try BTreeTestParser.parse(fileData)
		let nodeBlocks = try BTreeTestParser.readAllNodeBlocks(parsed: parsed)

		for blockNumber in nodeBlocks {
			let usedSize = try BTreeTestParser.nodeUsedSize(parsed: parsed, blockNumber: blockNumber)
			let expectedSize = Int(usedSize.powerOfTwoSize() ?? 0)
			let actualSize = try BTreeTestParser.blockSize(allocator: parsed.allocator, blockNumber: blockNumber)
			#expect(actualSize == expectedSize)
		}
	}

	@Test("Rejects node blocks larger than a page")
	func rejectsNodeBlocksLargerThanPage() throws {
		var store = DSStore()
		for index in 0..<300 {
			let filename = "Item-\(index)"
			store.add(DSStore.Record(filename: filename, type: .iconLocation, value: .data(Data(repeating: 0x1, count: 16))))
		}

		var fileData = try store.serialize()
		let parsed = try BTreeTestParser.parse(fileData)
		let addressesOffset = try BTreeTestParser.blockAddressesOffset(in: fileData)
		let rootBlock = Int(parsed.header.rootBlockNumber)
		let addressOffset = addressesOffset + rootBlock * 4

		let originalAddress = readUInt32(from: fileData, offset: addressOffset)
		let oversizedAddress = (originalAddress & ~UInt32(0x1F)) | 13
		writeUInt32(oversizedAddress, to: &fileData, offset: addressOffset)

		#expect(throws: DSStore.Error.self) {
			_ = try DSStore.read(from: fileData)
		}
	}

	@Test("Rejects misaligned block addresses")
	func rejectsMisalignedBlockAddresses() throws {
		var store = DSStore()
		try store.setIconPosition(for: "File.txt", x: 10, y: 20)

		var fileData = try store.serialize()
		let parsed = try BTreeTestParser.parse(fileData)
		let addressesOffset = try BTreeTestParser.blockAddressesOffset(in: fileData)
		let rootBlock = Int(parsed.header.rootBlockNumber)
		let addressOffset = addressesOffset + rootBlock * 4

		let originalAddress = readUInt32(from: fileData, offset: addressOffset)
		let sizePower = originalAddress & 0x1F
		let offset = originalAddress & ~UInt32(0x1F)
		let misalignedOffset = offset + 0x100
		let misalignedAddress = misalignedOffset | sizePower
		writeUInt32(misalignedAddress, to: &fileData, offset: addressOffset)

		#expect(throws: DSStore.Error.self) {
			_ = try DSStore.read(from: fileData)
		}
	}

	@Test("Rejects allocator block address mismatch")
	func rejectsAllocatorBlockAddressMismatch() throws {
		var store = DSStore()
		try store.setIconPosition(for: "File.txt", x: 10, y: 20)

		var fileData = try store.serialize()
		let addressesOffset = try BTreeTestParser.blockAddressesOffset(in: fileData)

		let allocatorAddress = readUInt32(from: fileData, offset: addressesOffset)
		let sizePower = allocatorAddress & 0x1F
		let offset = allocatorAddress & ~UInt32(0x1F)
		let newOffset = offset + 0x1000
		let newAddress = newOffset | sizePower
		writeUInt32(newAddress, to: &fileData, offset: addressesOffset)

		#expect(throws: DSStore.Error.self) {
			_ = try DSStore.read(from: fileData)
		}
	}

	@Test("Rejects table of contents block number beyond block count")
	func rejectsTableOfContentsBlockNumberBeyondBlockCount() throws {
		var store = DSStore()
		try store.setIconPosition(for: "File.txt", x: 10, y: 20)

		var fileData = try store.serialize()
		let blockCountOffset = try tableOfContentsCountOffset(in: fileData) - 8
		let blockCount = readUInt32(from: fileData, offset: blockCountOffset)
		let blockNumberOffset = try tableOfContentsBlockNumberOffset(in: fileData)

		writeUInt32(blockCount, to: &fileData, offset: blockNumberOffset)

		#expect(throws: DSStore.Error.self) {
			_ = try DSStore.read(from: fileData)
		}
	}

	@Test("Rejects table of contents count beyond block count")
	func rejectsTableOfContentsCountBeyondBlockCount() throws {
		var store = DSStore()
		try store.setIconPosition(for: "File.txt", x: 10, y: 20)

		var fileData = try store.serialize()
		let blockCountOffset = try allocatorOffset(in: fileData)
		let blockCount = readUInt32(from: fileData, offset: blockCountOffset)
		let tableOfContentsCountOffset = try tableOfContentsCountOffset(in: fileData)

		writeUInt32(blockCount + 1, to: &fileData, offset: tableOfContentsCountOffset)

		#expect(throws: DSStore.Error.self) {
			_ = try DSStore.read(from: fileData)
		}
	}

	@Test("Diagnostics handler reports unknown table of contents entries")
	func diagnosticsHandlerReportsUnknownTableOfContentsEntries() throws {
		var store = DSStore()
		try store.setIconPosition(for: "File.txt", x: 10, y: 20)

		var fileData = try store.serialize()
		let tableOfContentsCountOffset = try tableOfContentsCountOffset(in: fileData)
		let originalCount = readUInt32(from: fileData, offset: tableOfContentsCountOffset)
		let extraEntryOffset = try tableOfContentsEndOffset(in: fileData)
		let entryBytes: [UInt8] = [4, 0x41, 0x42, 0x43, 0x44, 0x00, 0x00, 0x00, 0x01]
		fileData.insert(contentsOf: entryBytes, at: extraEntryOffset)
		writeUInt32(originalCount + 1, to: &fileData, offset: tableOfContentsCountOffset)

		var diagnostics = [String]()
		DSStore.diagnosticHandler = { diagnostics.append($0) }
		defer { DSStore.diagnosticHandler = nil }

		_ = try DSStore.read(from: fileData)
		#expect(diagnostics.contains { $0.contains("ABCD") })
	}

	@Test("Rejects root node block number beyond block count")
	func rejectsRootNodeBlockNumberBeyondBlockCount() throws {
		var store = DSStore()
		try store.setIconPosition(for: "File.txt", x: 10, y: 20)

		var fileData = try store.serialize()
		let blockCountOffset = try allocatorOffset(in: fileData)
		let blockCount = readUInt32(from: fileData, offset: blockCountOffset)
		let rootBlockNumberOffset = 0x24

		writeUInt32(blockCount, to: &fileData, offset: rootBlockNumberOffset)

		#expect(throws: DSStore.Error.self) {
			_ = try DSStore.read(from: fileData)
		}
	}

	@Test("Detects duplicate node references")
	func detectsDuplicateNodeReferences() throws {
		var store = DSStore()
		for index in 0..<1600 {
			let filename = String(format: "File-%04d", index)
			store.add(DSStore.Record(filename: filename, type: .iconLocation, value: .data(Data(repeating: 0x4, count: 32))))
		}

		var fileData = try store.serialize()
		let parsed = try BTreeTestParser.parse(fileData)
		let rootBlock = Int(parsed.header.rootBlockNumber)
		let rootOffset = try BTreeTestParser.blockOffset(allocator: parsed.allocator, blockNumber: rootBlock)

		let rightmostChild = readUInt32(from: fileData, offset: rootOffset)
		#expect(rightmostChild != 0)
		let firstChild = readUInt32(from: fileData, offset: rootOffset + 8)

		writeUInt32(firstChild, to: &fileData, offset: rootOffset)

		#expect(throws: DSStore.Error.self) {
			_ = try DSStore.read(from: fileData)
		}
	}

	@Test("Rejects zero child pointers in internal nodes")
	func rejectsZeroChildPointers() throws {
		var store = DSStore()
		for index in 0..<1600 {
			let filename = String(format: "File-%04d", index)
			store.add(DSStore.Record(filename: filename, type: .iconLocation, value: .data(Data(repeating: 0x7, count: 24))))
		}

		var fileData = try store.serialize()
		let parsed = try BTreeTestParser.parse(fileData)
		let rootBlock = Int(parsed.header.rootBlockNumber)
		let rootOffset = try BTreeTestParser.blockOffset(allocator: parsed.allocator, blockNumber: rootBlock)

		let rightmostChild = readUInt32(from: fileData, offset: rootOffset)
		#expect(rightmostChild != 0)

		writeUInt32(0, to: &fileData, offset: rootOffset + 8)

		#expect(throws: DSStore.Error.self) {
			_ = try DSStore.read(from: fileData)
		}
	}

	@Test("Diagnostics handler reports out-of-order leaf records")
	func diagnosticsHandlerReportsOutOfOrderLeafRecords() throws {
		var store = DSStore()
		store.add(DSStore.Record(filename: "A", type: .iconLocation, value: .data(Data(repeating: 0x1, count: 16))))
		store.add(DSStore.Record(filename: "B", type: .iconLocation, value: .data(Data(repeating: 0x1, count: 16))))

		var fileData = try store.serialize()
		let parsed = try BTreeTestParser.parse(fileData)
		let rootBlock = Int(parsed.header.rootBlockNumber)
		let rootOffset = try BTreeTestParser.blockOffset(allocator: parsed.allocator, blockNumber: rootBlock)

		let reader = BinaryReader(data: fileData)
		try reader.seek(to: rootOffset)
		let rightmostChild = try reader.readUInt32()
		#expect(rightmostChild == 0)
		let recordCountRaw = try reader.readUInt32()
		guard let recordCount = Int(exactly: recordCountRaw) else {
			throw DSStore.Error.corruptedFile("Invalid record")
		}
		#expect(recordCount == 2)

		let firstRecordRange = try recordRange(reader: reader)
		let secondRecordRange = try recordRange(reader: reader)

		swapRanges(in: &fileData, firstRange: firstRecordRange, secondRange: secondRecordRange)

		var diagnostics = [String]()
		DSStore.diagnosticHandler = { diagnostics.append($0) }
		defer { DSStore.diagnosticHandler = nil }

		_ = try DSStore.read(from: fileData)
		#expect(!diagnostics.isEmpty)
	}


	@Test("Rejects mismatched header counts")
	func rejectsMismatchedHeaderCounts() throws {
		var store = DSStore()
		for index in 0..<50 {
			let filename = "Header-\(index)"
			store.add(DSStore.Record(filename: filename, type: .iconLocation, value: .data(Data(repeating: 0x5, count: 20))))
		}

		var fileData = try store.serialize()
		let primaryHeaderOffset = 0x24

		writeUInt32(1, to: &fileData, offset: primaryHeaderOffset + 8)
		writeUInt32(1, to: &fileData, offset: primaryHeaderOffset + 12)

		#expect(throws: DSStore.Error.self) {
			_ = try DSStore.read(from: fileData)
		}
	}

	@Test("Rejects empty table of contents")
	func rejectsEmptyTableOfContents() throws {
		var store = DSStore()
		try store.setIconPosition(for: "Sample", x: 10, y: 20)

		var fileData = try store.serialize()
		let tableOfContentsCountOffset = try tableOfContentsCountOffset(in: fileData)
		writeUInt32(0, to: &fileData, offset: tableOfContentsCountOffset)

		#expect(throws: DSStore.Error.self) {
			_ = try DSStore.read(from: fileData)
		}
	}

	@Test("Parser diagnostics are stable for equivalent filenames")
	func parserDiagnosticsForEquivalentFilenames() throws {
		var store = DSStore()
		store.add(DSStore.Record(filename: "a.txt", type: .spotlightComment, value: .string("lower")))
		store.add(DSStore.Record(filename: "A.txt", type: .spotlightComment, value: .string("upper")))
		store.add(DSStore.Record(filename: "b.txt", type: .spotlightComment, value: .string("lower")))

		let data = try store.serialize()

		var diagnostics = [String]()
		DSStore.diagnosticHandler = { message in
			diagnostics.append(message)
		}
		defer {
			DSStore.diagnosticHandler = nil
		}

		_ = try DSStore.read(from: data)

		#expect(diagnostics.isEmpty)
	}

	@Test("Rejects empty table of contents entry name")
	func rejectsEmptyTableOfContentsEntryName() throws {
		var store = DSStore()
		try store.setIconPosition(for: "Sample", x: 10, y: 20)

		var fileData = try store.serialize()
		let nameLengthOffset = try tableOfContentsEntryNameLengthOffset(in: fileData)
		fileData[nameLengthOffset] = 0

		#expect(throws: DSStore.Error.self) {
			_ = try DSStore.read(from: fileData)
		}
	}

	@Test("Rejects impossible tree height")
	func rejectsImpossibleTreeHeight() throws {
		var store = DSStore()
		try store.setIconPosition(for: "Sample", x: 10, y: 20)

		var fileData = try store.serialize()
		let primaryHeaderOffset = 0x24
		let nodeCount = readUInt32(from: fileData, offset: primaryHeaderOffset + 12)
		writeUInt32(nodeCount + 1, to: &fileData, offset: primaryHeaderOffset + 4)

		#expect(throws: DSStore.Error.self) {
			_ = try DSStore.read(from: fileData)
		}
	}
}

private enum BTreeTestParser {
	struct ParsedAllocator {
		let blockAddresses: [UInt32]
		let tableOfContents: [String: UInt32]
		let freeLists: [[UInt32]]
	}

	struct ParsedHeader {
		let rootBlockNumber: UInt32
		let treeHeight: UInt32
		let recordCount: UInt32
		let nodeCount: UInt32
		let pageSize: UInt32
	}

	struct ParsedFile {
		let data: Data
		let allocator: ParsedAllocator
		let header: ParsedHeader
	}

	static func parse(_ data: Data) throws -> ParsedFile {
		let reader = BinaryReader(data: data)

		let alignment = try reader.readUInt32()
		#expect(alignment == 1)

		let magic = try reader.readUInt32()
		#expect(magic == 0x42756431)

		let rootBlockOffset = try reader.readUInt32()
		_ = try reader.readUInt32()
		let rootBlockOffsetCheck = try reader.readUInt32()
		#expect(rootBlockOffset == rootBlockOffsetCheck)

		try reader.skip(16)

		let allocator = try readAllocator(reader: reader, offset: Int(rootBlockOffset) + 4)
		guard let primaryBlock = allocator.tableOfContents["DSDB"] else {
			throw DSStore.Error.invalidBTreeHeader
		}

		let header = try readHeader(reader: reader, allocator: allocator, blockNumber: Int(primaryBlock))

		return ParsedFile(data: data, allocator: allocator, header: header)
	}

	static func readAllRecords(parsed: ParsedFile) throws -> [DSStore.Record] {
		let reader = BinaryReader(data: parsed.data)
		return try traverseNode(reader: reader, allocator: parsed.allocator, blockNumber: Int(parsed.header.rootBlockNumber))
	}

	static func readAllNodeBlocks(parsed: ParsedFile) throws -> [Int] {
		let reader = BinaryReader(data: parsed.data)
		var visited = Set<Int>()
		try collectNodeBlocks(reader: reader, allocator: parsed.allocator, blockNumber: Int(parsed.header.rootBlockNumber), visited: &visited)
		return Array(visited)
	}

	static func nodeUsedSize(parsed: ParsedFile, blockNumber: Int) throws -> Int {
		let reader = BinaryReader(data: parsed.data)
		let offset = try blockOffset(allocator: parsed.allocator, blockNumber: blockNumber)
		try reader.seek(to: offset)

		let rightmostChild = try reader.readUInt32()
		let recordCountRaw = try reader.readUInt32()
		guard let recordCount = Int(exactly: recordCountRaw) else {
			throw DSStore.Error.corruptedFile("Invalid record")
		}

		if rightmostChild == 0 {
			for _ in 0..<recordCount {
				_ = try readRecord(reader: reader)
			}
		} else {
			for _ in 0..<recordCount {
				_ = try reader.readUInt32()
				_ = try readRecord(reader: reader)
			}
		}

		return reader.position - offset
	}

	static func blockAddressesOffset(in data: Data) throws -> Int {
		let reader = BinaryReader(data: data)
		_ = try reader.readUInt32()
		_ = try reader.readUInt32()
		let rootBlockOffset = try reader.readUInt32()
		_ = try reader.readUInt32()
		_ = try reader.readUInt32()
		try reader.skip(16)
		return Int(rootBlockOffset) + 12
	}

	private static func readAllocator(reader: BinaryReader, offset: Int) throws -> ParsedAllocator {
		try reader.seek(to: offset)

		let blockCountRaw = try reader.readUInt32()
		guard let blockCount = Int(exactly: blockCountRaw), blockCount > 0 else {
			throw DSStore.Error.corruptedFile("Invalid block count")
		}

		try reader.skip(4)

		var blockAddresses = [UInt32]()
		let addressCount = max(256, blockCount.roundedUp(toMultipleOf: 256))
		blockAddresses.reserveCapacity(addressCount)
		for _ in 0..<addressCount {
			blockAddresses.append(try reader.readUInt32())
		}

		let tableOfContentsCountRaw = try reader.readUInt32()
		guard let tableOfContentsCount = Int(exactly: tableOfContentsCountRaw) else {
			throw DSStore.Error.corruptedFile("Invalid table of contents count")
		}

		var tableOfContents = [String: UInt32]()
		for _ in 0..<tableOfContentsCount {
			let nameLength = Int(try reader.readUInt8())
			let name = try reader.readASCIIString(byteCount: nameLength)
			let blockNumber = try reader.readUInt32()
			tableOfContents[name] = blockNumber
		}

		var freeLists = [[UInt32]]()
		for _ in 0..<32 {
			let countRaw = try reader.readUInt32()
			guard let count = Int(exactly: countRaw) else {
				throw DSStore.Error.corruptedFile("Invalid free list count")
			}
			var list = [UInt32]()
			for _ in 0..<count {
				list.append(try reader.readUInt32())
			}
			freeLists.append(list)
		}

		return ParsedAllocator(blockAddresses: blockAddresses, tableOfContents: tableOfContents, freeLists: freeLists)
	}

	static func blockSize(allocator: ParsedAllocator, blockNumber: Int) throws -> Int {
		guard blockNumber >= 0, blockNumber < allocator.blockAddresses.count else {
			throw DSStore.Error.invalidBlockAddress
		}
		let address = allocator.blockAddresses[blockNumber]
		guard address != 0 else {
			throw DSStore.Error.invalidBlockAddress
		}
		let sizeBits = address & 0x1F
		guard sizeBits >= 5 else {
			throw DSStore.Error.invalidBlockAddress
		}
		return Int(UInt32(1) << sizeBits)
	}

	static func blockOffset(allocator: ParsedAllocator, blockNumber: Int) throws -> Int {
		guard blockNumber >= 0, blockNumber < allocator.blockAddresses.count else {
			throw DSStore.Error.invalidBlockAddress
		}
		let address = allocator.blockAddresses[blockNumber]
		guard address != 0 else {
			throw DSStore.Error.invalidBlockAddress
		}
		let sizeBits = address & 0x1F
		guard sizeBits >= 5 else {
			throw DSStore.Error.invalidBlockAddress
		}
		return Int(address & ~UInt32(0x1F)) + 4
	}

	private static func readHeader(reader: BinaryReader, allocator: ParsedAllocator, blockNumber: Int) throws -> ParsedHeader {
		let offset = try blockOffset(allocator: allocator, blockNumber: blockNumber)
		try reader.seek(to: offset)
		let rootBlockNumber = try reader.readUInt32()
		let treeHeight = try reader.readUInt32()
		let recordCount = try reader.readUInt32()
		let nodeCount = try reader.readUInt32()
		let pageSize = try reader.readUInt32()

		return ParsedHeader(
			rootBlockNumber: rootBlockNumber,
			treeHeight: treeHeight,
			recordCount: recordCount,
			nodeCount: nodeCount,
			pageSize: pageSize
		)
	}

	private static func collectNodeBlocks(reader: BinaryReader, allocator: ParsedAllocator, blockNumber: Int, visited: inout Set<Int>) throws {
		guard visited.insert(blockNumber).inserted else {
			return
		}
		let offset = try blockOffset(allocator: allocator, blockNumber: blockNumber)
		try reader.seek(to: offset)

		let rightmostChild = try reader.readUInt32()
		let recordCountRaw = try reader.readUInt32()
		guard let recordCount = Int(exactly: recordCountRaw) else {
			throw DSStore.Error.corruptedFile("Invalid record")
		}

		if rightmostChild == 0 {
			for _ in 0..<recordCount {
				_ = try readRecord(reader: reader)
			}
		} else {
			for _ in 0..<recordCount {
				let childBlock = try reader.readUInt32()
				let savedPosition = reader.position
				try collectNodeBlocks(reader: reader, allocator: allocator, blockNumber: Int(childBlock), visited: &visited)
				try reader.seek(to: savedPosition)
				_ = try readRecord(reader: reader)
			}
			try collectNodeBlocks(reader: reader, allocator: allocator, blockNumber: Int(rightmostChild), visited: &visited)
		}
	}

	private static func traverseNode(reader: BinaryReader, allocator: ParsedAllocator, blockNumber: Int) throws -> [DSStore.Record] {
		let offset = try blockOffset(allocator: allocator, blockNumber: blockNumber)
		try reader.seek(to: offset)

		let rightmostChild = try reader.readUInt32()
		let recordCountRaw = try reader.readUInt32()
		guard let recordCount = Int(exactly: recordCountRaw) else {
			throw DSStore.Error.corruptedFile("Invalid record")
		}

		var records = [DSStore.Record]()
		if rightmostChild == 0 {
			for _ in 0..<recordCount {
				records.append(try readRecord(reader: reader))
			}
		} else {
			for _ in 0..<recordCount {
				let childBlock = try reader.readUInt32()
				let savedPosition = reader.position
				records.append(contentsOf: try traverseNode(reader: reader, allocator: allocator, blockNumber: Int(childBlock)))
				try reader.seek(to: savedPosition)
				records.append(try readRecord(reader: reader))
			}
			records.append(contentsOf: try traverseNode(reader: reader, allocator: allocator, blockNumber: Int(rightmostChild)))
		}

		return records
	}

	private static func readRecord(reader: BinaryReader) throws -> DSStore.Record {
		let filenameLength = try reader.readUInt32()
		guard let filenameLength = Int(exactly: filenameLength) else {
			throw DSStore.Error.corruptedFile("Invalid record")
		}
		let filename = try reader.readUTF16String(characterCount: filenameLength)
		let type = DSStore.RecordType(fourCC: try reader.readFourCC())
		let dataType = try reader.readFourCC()
		let value = try readValue(reader: reader, dataType: dataType)
		return DSStore.Record(filename: filename, type: type, value: value)
	}

	private static func readValue(reader: BinaryReader, dataType: FourCC) throws -> DSStore.Value {
		switch dataType.stringValue {
		case "bool":
			return .boolean(try reader.readUInt8() != 0)
		case "long":
			return .uint32(try reader.readUInt32())
		case "shor":
			let rawValue = try reader.readUInt32()
			guard rawValue <= UInt32(UInt16.max) else {
				throw DSStore.Error.corruptedFile("Invalid record")
			}
			return .uint16(UInt16(rawValue))
		case "comp":
			return .uint64(try reader.readUInt64())
		case "dutc":
			let rawValue = try reader.readUInt64()
			return .timestamp(Date(macEpochTimeUnits: rawValue))
		case "type":
			return .fourCC(try reader.readFourCC())
		case "ustr":
			let length = try reader.readUInt32()
			guard let length = Int(exactly: length) else {
				throw DSStore.Error.corruptedFile("Invalid record")
			}
			return .string(try reader.readUTF16String(characterCount: length))
		case "blob":
			let length = try reader.readUInt32()
			guard let length = Int(exactly: length) else {
				throw DSStore.Error.corruptedFile("Invalid record")
			}
			return .data(try reader.readBytes(length))
		case "book":
			let length = try reader.readUInt32()
			guard let length = Int(exactly: length) else {
				throw DSStore.Error.corruptedFile("Invalid record")
			}
			return .bookmark(try reader.readBytes(length))
		default:
			throw DSStore.Error.unknownDataType(dataType.stringValue)
		}
	}
}

private func tableOfContentsCountOffset(in data: Data) throws -> Int {
	let addressesOffset = try BTreeTestParser.blockAddressesOffset(in: data)
	let allocatorOffset = addressesOffset - 8
	let blockCount = Int(readUInt32(from: data, offset: allocatorOffset))
	let addressCount = max(256, blockCount.roundedUp(toMultipleOf: 256))
	return allocatorOffset + 8 + addressCount * 4
}

private func tableOfContentsEntryNameLengthOffset(in data: Data) throws -> Int {
	try tableOfContentsCountOffset(in: data) + 4
}

private func tableOfContentsBlockNumberOffset(in data: Data) throws -> Int {
	try tableOfContentsCountOffset(in: data) + 9
}

private func tableOfContentsEndOffset(in data: Data) throws -> Int {
	let countOffset = try tableOfContentsCountOffset(in: data)
	let startOffset = countOffset + 4
	let tableOfContentsCount = Int(readUInt32(from: data, offset: countOffset))
	var cursor = startOffset
	for _ in 0..<tableOfContentsCount {
		let nameLength = Int(data[cursor])
		cursor += 1 + nameLength + 4
	}
	return cursor
}


private func allocatorOffset(in data: Data) throws -> Int {
	let addressesOffset = try BTreeTestParser.blockAddressesOffset(in: data)
	return addressesOffset - 8
}

private func readUInt32(from data: Data, offset: Int) -> UInt32 {
	let value = data.subdata(in: offset..<(offset + 4))
	return value.withUnsafeBytes { bytes in
		bytes.loadUnaligned(as: UInt32.self).bigEndian
	}
}

private func writeUInt32(_ value: UInt32, to data: inout Data, offset: Int) {
	var bigEndian = value.bigEndian
	let bytes = withUnsafeBytes(of: &bigEndian) { Data($0) }
	data.replaceSubrange(offset..<(offset + 4), with: bytes)
}

private func recordRange(reader: BinaryReader) throws -> Range<Int> {
	let start = reader.position
	let filenameLength = try reader.readUInt32()
	guard let filenameLengthInt = Int(exactly: filenameLength) else {
		throw DSStore.Error.corruptedFile("Invalid record")
	}
	_ = try reader.readUTF16String(characterCount: filenameLengthInt)
	_ = try reader.readFourCC()
	let dataType = try reader.readFourCC()
	try skipValue(reader: reader, dataType: dataType)
	return start..<reader.position
}

private func skipValue(reader: BinaryReader, dataType: FourCC) throws {
	switch dataType.stringValue {
	case "null":
		break
	case "bool":
		_ = try reader.readUInt8()
	case "long":
		_ = try reader.readUInt32()
	case "shor":
		_ = try reader.readUInt32()
	case "comp":
		_ = try reader.readUInt64()
	case "dutc":
		_ = try reader.readUInt64()
	case "type":
		_ = try reader.readFourCC()
	case "ustr":
		let length = try reader.readUInt32()
		guard let lengthInt = Int(exactly: length) else {
			throw DSStore.Error.corruptedFile("Invalid record")
		}
		_ = try reader.readUTF16String(characterCount: lengthInt)
	case "blob", "book":
		let length = try reader.readUInt32()
		guard let lengthInt = Int(exactly: length) else {
			throw DSStore.Error.corruptedFile("Invalid record")
		}
		_ = try reader.readBytes(lengthInt)
	default:
		throw DSStore.Error.corruptedFile("Invalid record")
	}
}

private func swapRanges(in data: inout Data, firstRange: Range<Int>, secondRange: Range<Int>) {
	guard firstRange.count == secondRange.count else {
		return
	}
	let firstBytes = data.subdata(in: firstRange)
	let secondBytes = data.subdata(in: secondRange)
	data.replaceSubrange(firstRange, with: secondBytes)
	data.replaceSubrange(secondRange, with: firstBytes)
}
