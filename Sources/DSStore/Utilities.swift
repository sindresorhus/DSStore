import Foundation

// MARK: - FourCC

extension DSStore {
	/**
	FourCC (Four Character Code) representation.
	*/
	public struct FourCC: Hashable, CustomStringConvertible, Codable, Sendable {
		/**
		Raw 32-bit FourCC value.
		*/
		public let rawValue: UInt32

		/**
		Creates a FourCC from a raw value.
		*/
		public init(_ rawValue: UInt32) {
			self.rawValue = rawValue
		}

		/**
		Creates a FourCC from a 4-character ASCII static string literal.
		*/
		public init(_ string: StaticString) {
			precondition(string.utf8CodeUnitCount == 4, "FourCC requires exactly 4 ASCII characters.")
			let buffer = UnsafeBufferPointer(start: string.utf8Start, count: Int(string.utf8CodeUnitCount))
			self.rawValue = UInt32(buffer[0]) << 24 | UInt32(buffer[1]) << 16 | UInt32(buffer[2]) << 8 | UInt32(buffer[3])
		}

		/**
		Creates a FourCC from a 4-character ASCII string.
		*/
		public init?(_ string: String) {
			guard string.count == 4, let data = string.data(using: .ascii), data.count == 4 else {
				return nil
			}

			let bytes = Array(data)
			self.rawValue = UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16 | UInt32(bytes[2]) << 8 | UInt32(bytes[3])
		}

		/**
		The four-character string representation.
		*/
		public var stringValue: String {
			let bytes: [UInt8] = [
				UInt8((rawValue >> 24) & 0xFF),
				UInt8((rawValue >> 16) & 0xFF),
				UInt8((rawValue >> 8) & 0xFF),
				UInt8(rawValue & 0xFF)
			]

			return String(bytes: bytes, encoding: .ascii) ?? "????"
		}

		/**
		Human-readable string representation.
		*/
		public var description: String {
			stringValue
		}

		/**
		Creates a FourCC from a static 4-character literal.
		*/
		public static func literal(_ string: StaticString) -> Self {
			Self(string)
		}
	}
}

// MARK: - Binary Reader

/**
Helper for reading big-endian binary data.
*/
final class BinaryReader {
	enum Error: Swift.Error, LocalizedError {
		case unexpectedEnd
		case invalidOffset
		case invalidSkip
		case invalidASCIIString
		case invalidUTF16String

		var errorDescription: String? {
			switch self {
			case .unexpectedEnd:
				"Unexpected end of data"
			case .invalidOffset:
				"Invalid seek offset"
			case .invalidSkip:
				"Invalid skip length"
			case .invalidASCIIString:
				"Invalid ASCII string"
			case .invalidUTF16String:
				"Invalid UTF-16 string"
			}
		}
	}

	private let data: Data
	private(set) var position = 0

	init(data: Data) {
		self.data = data
	}

	var count: Int {
		data.count
	}

	var remaining: Int {
		data.count - position
	}

	var isAtEnd: Bool {
		position >= data.count
	}

	func seek(to offset: Int) throws(Error) {
		guard offset >= 0, offset <= data.count else {
			throw Error.invalidOffset
		}
		position = offset
	}

	func skip(_ count: Int) throws(Error) {
		guard count >= 0 else {
			throw Error.invalidSkip
		}
		guard position + count <= data.count else {
			throw Error.unexpectedEnd
		}
		position += count
	}

	func readUInt8() throws(Error) -> UInt8 {
		guard position < data.count else {
			throw Error.unexpectedEnd
		}
		let value = data[data.startIndex + position]
		position += 1
		return value
	}

	func readUInt16() throws(Error) -> UInt16 {
		try readFixedWidthInteger(UInt16.self)
	}

	func readUInt32() throws(Error) -> UInt32 {
		try readFixedWidthInteger(UInt32.self)
	}

	func readUInt64() throws(Error) -> UInt64 {
		try readFixedWidthInteger(UInt64.self)
	}

	func readBytes(_ count: Int) throws(Error) -> Data {
		guard count >= 0 else {
			throw Error.invalidSkip
		}
		guard position + count <= data.count else {
			throw Error.unexpectedEnd
		}
		let result = data.subdata(in: (data.startIndex + position)..<(data.startIndex + position + count))
		position += count
		return result
	}

	func readFourCC() throws(Error) -> DSStore.FourCC {
		DSStore.FourCC(try readUInt32())
	}

	func readUTF16String(characterCount: Int) throws(Error) -> String {
		guard characterCount >= 0 else {
			throw Error.invalidUTF16String
		}
		let (byteCount, overflow) = characterCount.multipliedReportingOverflow(by: 2)
		guard !overflow else {
			throw Error.invalidUTF16String
		}
		let stringData = try readBytes(byteCount)
		guard let string = String(data: stringData, encoding: .utf16BigEndian) else {
			throw Error.invalidUTF16String
		}
		return string
	}

	func readASCIIString(byteCount: Int) throws(Error) -> String {
		let stringData = try readBytes(byteCount)
		guard let string = String(data: stringData, encoding: .ascii) else {
			throw Error.invalidASCIIString
		}
		return string
	}

	private func readFixedWidthInteger<T: FixedWidthInteger>(_ type: T.Type) throws(Error) -> T {
		let byteCount = MemoryLayout<T>.size
		guard position + byteCount <= data.count else {
			throw Error.unexpectedEnd
		}
		let value = data.withUnsafeBytes { bytes in
			bytes.loadUnaligned(fromByteOffset: position, as: T.self).bigEndian
		}
		position += byteCount
		return value
	}
}

// MARK: - Binary Writer

/**
Helper for writing big-endian binary data.
*/
final class BinaryWriter {
	enum Error: Swift.Error, LocalizedError {
		case invalidASCIIString

		var errorDescription: String? {
			switch self {
			case .invalidASCIIString:
				"Invalid ASCII string"
			}
		}
	}

	private(set) var data = Data()

	var count: Int {
		data.count
	}

	func writeUInt8(_ value: UInt8) {
		data.append(value)
	}

	func writeUInt16(_ value: UInt16) {
		writeFixedWidthInteger(value)
	}

	func writeUInt32(_ value: UInt32) {
		writeFixedWidthInteger(value)
	}

	func writeUInt64(_ value: UInt64) {
		writeFixedWidthInteger(value)
	}

	func writeBytes(_ bytes: Data) {
		data.append(bytes)
	}

	func writeBytes(_ bytes: [UInt8]) {
		data.append(contentsOf: bytes)
	}

	func writeFourCC(_ fourCC: DSStore.FourCC) {
		writeUInt32(fourCC.rawValue)
	}

	func writeUTF16String(_ string: String) {
		let utf16 = Array(string.utf16)
		for unit in utf16 {
			writeUInt16(unit)
		}
	}

	func writeASCIIString(_ string: String) throws(Error) {
		guard let data = string.data(using: .ascii) else {
			throw Error.invalidASCIIString
		}
		writeBytes(data)
	}

	func writePadding(toAlignment alignment: Int) {
		guard alignment > 0 else {
			return
		}
		let remainder = data.count % alignment
		if remainder != 0 {
			let paddingSize = alignment - remainder
			data.append(contentsOf: [UInt8](repeating: 0, count: paddingSize))
		}
	}

	func writeZeros(_ count: Int) {
		guard count > 0 else {
			return
		}
		data.append(contentsOf: [UInt8](repeating: 0, count: count))
	}

	func writePadding(toOffset offset: Int) {
		guard offset > data.count else {
			return
		}
		writeZeros(offset - data.count)
	}

	private func writeFixedWidthInteger(_ value: some FixedWidthInteger) {
		var bigEndian = value.bigEndian
		data.append(contentsOf: withUnsafeBytes(of: &bigEndian) { $0 })
	}
}

// MARK: - Data Utilities

extension Data {
	private static let binaryPropertyListPrefix = Data([0x62, 0x70, 0x6C, 0x69, 0x73, 0x74]) // "bplist"
	private static let xmlPropertyListPrefix = Data([0x3C, 0x3F, 0x78, 0x6D, 0x6C]) // "<?xml"

	var isBinaryPropertyList: Bool {
		starts(with: Self.binaryPropertyListPrefix)
	}

	var isXMLPropertyList: Bool {
		starts(with: Self.xmlPropertyListPrefix)
	}

	var isPropertyListData: Bool {
		isBinaryPropertyList || isXMLPropertyList
	}

	func readUInt16BE(at offset: Int) -> UInt16? {
		guard offset >= 0, offset + 2 <= count else {
			return nil
		}
		return withUnsafeBytes { bytes in
			bytes.loadUnaligned(fromByteOffset: offset, as: UInt16.self).bigEndian
		}
	}

	func readUInt32BE(at offset: Int) -> UInt32? {
		guard offset >= 0, offset + 4 <= count else {
			return nil
		}
		return withUnsafeBytes { bytes in
			bytes.loadUnaligned(fromByteOffset: offset, as: UInt32.self).bigEndian
		}
	}
}

// MARK: - Date Utilities

extension Date {
	private static let macEpochOffsetSeconds: Double = 2_082_844_800
	private static let macTimeUnitsPerSecond: Double = 65_536

	init(macEpochTimeUnits: UInt64) {
		let seconds = Double(macEpochTimeUnits) / Self.macTimeUnitsPerSecond
		let unixSeconds = seconds - Self.macEpochOffsetSeconds
		self = Date(timeIntervalSince1970: unixSeconds)
	}

	var macEpochTimeUnits: UInt64? {
		let unixSeconds = timeIntervalSince1970
		let macSeconds = unixSeconds + Self.macEpochOffsetSeconds
		let scaledSeconds = macSeconds * Self.macTimeUnitsPerSecond
		guard macSeconds >= 0, macSeconds.isFinite, scaledSeconds.isFinite, scaledSeconds <= Double(UInt64.max) else {
			return nil
		}
		return UInt64(scaledSeconds.rounded(.towardZero))
	}
}

// MARK: - Numeric Utilities

extension UInt32 {
	func roundedUp(toMultipleOf alignment: UInt32) -> UInt32 {
		guard alignment > 0 else {
			return self
		}
		let (sum, overflow) = addingReportingOverflow(alignment - 1)
		if overflow {
			return self
		}
		return (sum / alignment) * alignment
	}

	var isPowerOfTwo: Bool {
		self != 0 && (self & (self - 1)) == 0
	}
}

extension Int {
	/**
	Rounds the value up to the next multiple of the given alignment.
	*/
	func roundedUp(toMultipleOf alignment: Int) -> Int {
		guard alignment > 0 else {
			return self
		}
		let remainder = self % alignment
		if remainder == 0 {
			return self
		}
		return self + (alignment - remainder)
	}

	var isPowerOfTwo: Bool {
		self > 0 && (self & (self - 1)) == 0
	}

	/**
	Returns the power-of-two exponent for this byte count, clamped to at least 2^minimumPower.
	*/
	func powerOfTwoSizePower(minimumPower: UInt32 = 5) -> UInt32? {
		guard self > 0, let value = UInt32(exactly: self) else {
			return nil
		}
		let minimumSize = UInt32(1) << minimumPower
		let adjusted = Swift.max(value, minimumSize)
		let power = UInt32(UInt32.bitWidth - (adjusted - 1).leadingZeroBitCount)
		guard power <= 31 else {
			return nil
		}
		return Swift.max(power, minimumPower)
	}

	/**
	Returns the power-of-two block size for this byte count, clamped to at least 2^minimumPower.
	*/
	func powerOfTwoSize(minimumPower: UInt32 = 5) -> UInt32? {
		guard let power = powerOfTwoSizePower(minimumPower: minimumPower) else {
			return nil
		}
		return UInt32(1) << power
	}
}

// MARK: - Buddy Allocator

/**
Manages block allocation in the DS_Store file.
*/
struct BuddyAllocator {
	enum Error: Swift.Error, LocalizedError {
		case invalidBlockAddress

		var errorDescription: String? {
			switch self {
			case .invalidBlockAddress:
				"Invalid block address"
			}
		}
	}

	/**
	Block addresses indexed by block number.
	*/
	var blockAddresses: [UInt32]

	/**
	Declared number of blocks in the allocator table.
	*/
	var blockCount: Int?

	/**
	Table of contents mapping names to block numbers.
	*/
	var tableOfContents: [String: UInt32]

	/**
	Free lists for each power of 2 (from 2^0 to 2^31).
	*/
	var freeLists: [[UInt32]]

	init() {
		self.blockAddresses = []
		self.blockCount = nil
		self.tableOfContents = [:]
		self.freeLists = Array(repeating: [], count: 32)
	}

	/**
	Decode a block address to get offset and size.
	*/
	static func decodeAddress(_ address: UInt32) -> (offset: UInt32, size: UInt32) {
		let sizeBits = address & 0x1F
		let offset = address & ~UInt32(0x1F)
		let size = UInt32(1) << sizeBits
		return (offset, size)
	}

	/**
	Encode offset and size into a block address.
	*/
	static func encodeAddress(offset: UInt32, sizePower: UInt32) -> UInt32 {
		offset | sizePower
	}

	/**
	Get the actual file offset for a block number.
	*/
	func blockOffset(for blockNumber: Int) throws(Error) -> (offset: Int, size: Int) {
		if let blockCount, blockNumber >= blockCount {
			throw Error.invalidBlockAddress
		}
		guard blockNumber >= 0, blockNumber < blockAddresses.count else {
			throw Error.invalidBlockAddress
		}
		let address = blockAddresses[blockNumber]
		guard address != 0 else {
			throw Error.invalidBlockAddress
		}
		let sizeBits = address & 0x1F
		guard sizeBits >= 5 else {
			throw Error.invalidBlockAddress
		}
		let (offset, size) = Self.decodeAddress(address)
		guard let offsetInt = Int(exactly: offset),
			  let sizeInt = Int(exactly: size)
		else {
			throw Error.invalidBlockAddress
		}
		guard offsetInt.isMultiple(of: sizeInt) else {
			throw Error.invalidBlockAddress
		}
		guard offsetInt <= Int.max - 4 else {
			throw Error.invalidBlockAddress
		}
		// Add 4 for the file alignment prefix
		return (offsetInt + 4, sizeInt)
	}
}

// MARK: - B-Tree

/**
B-tree header information.
*/
struct BTreeHeader {
	let rootBlockNumber: UInt32
	/**
	Number of internal node levels (0 when the root is a leaf).
	*/
	let treeHeight: UInt32
	let recordCount: UInt32
	let nodeCount: UInt32
	let pageSize: UInt32 // Always 0x1000

	static let headerSize = 20
}
