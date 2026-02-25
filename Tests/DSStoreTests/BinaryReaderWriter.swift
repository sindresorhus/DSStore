import Foundation
import Testing
@testable import DSStore

private typealias FourCC = DSStore.FourCC

@Suite("BinaryReader")
struct BinaryReaderTests {
	@Test("Read UInt8")
	func readUInt8() throws {
		let data = Data([0x42, 0xFF, 0x00])
		let reader = BinaryReader(data: data)

		#expect(try reader.readUInt8() == 0x42)
		#expect(try reader.readUInt8() == 0xFF)
		#expect(try reader.readUInt8() == 0x00)
	}

	@Test("Read UInt16 big-endian")
	func readUInt16() throws {
		let data = Data([0x12, 0x34])
		let reader = BinaryReader(data: data)

		#expect(try reader.readUInt16() == 0x1234)
	}

	@Test("Read UInt32 big-endian")
	func readUInt32() throws {
		let data = Data([0x12, 0x34, 0x56, 0x78])
		let reader = BinaryReader(data: data)

		#expect(try reader.readUInt32() == 0x12345678)
	}

	@Test("Read UInt64 big-endian")
	func readUInt64() throws {
		let data = Data([0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00])
		let reader = BinaryReader(data: data)

		#expect(try reader.readUInt64() == 0x100000000)
	}

	@Test("Read bytes")
	func readBytes() throws {
		let data = Data([0x01, 0x02, 0x03, 0x04, 0x05])
		let reader = BinaryReader(data: data)

		let bytes = try reader.readBytes(3)
		#expect(bytes == Data([0x01, 0x02, 0x03]))
		#expect(reader.position == 3)
	}

	@Test("Seek to position")
	func seekToPosition() throws {
		let data = Data([0x01, 0x02, 0x03, 0x04])
		let reader = BinaryReader(data: data)

		try reader.seek(to: 2)
		#expect(try reader.readUInt8() == 0x03)
	}

	@Test("Seek past end throws")
	func seekPastEndThrows() {
		let reader = BinaryReader(data: Data([0x01]))

		#expect(throws: BinaryReader.Error.self) {
			try reader.seek(to: 2)
		}
	}

	@Test("Skip bytes")
	func skipBytes() throws {
		let data = Data([0x01, 0x02, 0x03, 0x04])
		let reader = BinaryReader(data: data)

		try reader.skip(2)
		#expect(try reader.readUInt8() == 0x03)
	}

	@Test("Skip past end throws")
	func skipPastEndThrows() {
		let reader = BinaryReader(data: Data([0x01]))

		#expect(throws: BinaryReader.Error.self) {
			try reader.skip(2)
		}
	}

	@Test("Read FourCC")
	func readFourCC() throws {
		let data = Data([0x42, 0x75, 0x64, 0x31]) // "Bud1"
		let reader = BinaryReader(data: data)

		let fourCC = try reader.readFourCC()
		#expect(fourCC.stringValue == "Bud1")
	}

	@Test("Read UTF-16 string")
	func readUTF16String() throws {
		// "Hi" in UTF-16 BE: H=0x0048, i=0x0069
		let data = Data([0x00, 0x48, 0x00, 0x69])
		let reader = BinaryReader(data: data)

		let string = try reader.readUTF16String(characterCount: 2)
		#expect(string == "Hi")
	}

	@Test("Read ASCII string")
	func readASCIIString() throws {
		let data = Data([0x44, 0x53, 0x44, 0x42]) // "DSDB"
		let reader = BinaryReader(data: data)

		let string = try reader.readASCIIString(byteCount: 4)
		#expect(string == "DSDB")
	}

	@Test("Remaining bytes")
	func remainingBytes() throws {
		let data = Data([0x01, 0x02, 0x03, 0x04])
		let reader = BinaryReader(data: data)

		#expect(reader.remaining == 4)
		_ = try reader.readUInt8()
		#expect(reader.remaining == 3)
	}

	@Test("Is at end")
	func isAtEnd() throws {
		let data = Data([0x01])
		let reader = BinaryReader(data: data)

		#expect(!reader.isAtEnd)
		_ = try reader.readUInt8()
		#expect(reader.isAtEnd)
	}

	@Test("Read past end throws")
	func readPastEndThrows() {
		let data = Data([0x01])
		let reader = BinaryReader(data: data)

		#expect(throws: BinaryReader.Error.self) {
			_ = try reader.readUInt32()
		}
	}
}

@Suite("BinaryWriter")
struct BinaryWriterTests {
	@Test("Write UInt8")
	func writeUInt8() {
		let writer = BinaryWriter()
		writer.writeUInt8(0x42)

		#expect(writer.data == Data([0x42]))
	}

	@Test("Write UInt16 big-endian")
	func writeUInt16() {
		let writer = BinaryWriter()
		writer.writeUInt16(0x1234)

		#expect(writer.data == Data([0x12, 0x34]))
	}

	@Test("Write UInt32 big-endian")
	func writeUInt32() {
		let writer = BinaryWriter()
		writer.writeUInt32(0x12345678)

		#expect(writer.data == Data([0x12, 0x34, 0x56, 0x78]))
	}

	@Test("Write UInt64 big-endian")
	func writeUInt64() {
		let writer = BinaryWriter()
		writer.writeUInt64(0x100000000)

		#expect(writer.data == Data([0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00]))
	}

	@Test("Write bytes from Data")
	func writeBytesFromData() {
		let writer = BinaryWriter()
		writer.writeBytes(Data([0x01, 0x02, 0x03]))

		#expect(writer.data == Data([0x01, 0x02, 0x03]))
	}

	@Test("Write bytes from array")
	func writeBytesFromArray() {
		let writer = BinaryWriter()
		writer.writeBytes([0x01, 0x02, 0x03])

		#expect(writer.data == Data([0x01, 0x02, 0x03]))
	}

	@Test("Write FourCC")
	func writeFourCC() {
		let writer = BinaryWriter()
		writer.writeFourCC(FourCC.literal("Bud1"))

		#expect(writer.data == Data([0x42, 0x75, 0x64, 0x31]))
	}

	@Test("Write UTF-16 string")
	func writeUTF16String() {
		let writer = BinaryWriter()
		writer.writeUTF16String("Hi")

		#expect(writer.data == Data([0x00, 0x48, 0x00, 0x69]))
	}

	@Test("Write ASCII string")
	func writeASCIIString() throws {
		let writer = BinaryWriter()
		try writer.writeASCIIString("DSDB")

		#expect(writer.data == Data([0x44, 0x53, 0x44, 0x42]))
	}

	@Test("Write ASCII string rejects non-ASCII")
	func writeASCIIStringRejectsNonASCII() throws {
		let writer = BinaryWriter()
		let nonASCII = String(try #require(UnicodeScalar(0x80)))

		#expect(throws: BinaryWriter.Error.self) {
			try writer.writeASCIIString(nonASCII)
		}
	}

	@Test("Write zeros")
	func writeZeros() {
		let writer = BinaryWriter()
		writer.writeZeros(4)

		#expect(writer.data == Data([0x00, 0x00, 0x00, 0x00]))
	}

	@Test("Write padding to alignment")
	func writePaddingToAlignment() {
		let writer = BinaryWriter()
		writer.writeUInt8(0x01)
		writer.writePadding(toAlignment: 4)

		#expect(writer.data.count == 4)
		#expect(writer.data == Data([0x01, 0x00, 0x00, 0x00]))
	}

	@Test("Count property")
	func countProperty() {
		let writer = BinaryWriter()
		#expect(writer.data.isEmpty)

		writer.writeUInt32(0)
		#expect(writer.count == 4)
	}
}
