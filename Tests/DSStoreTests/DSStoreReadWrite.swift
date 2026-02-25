import Foundation
import Testing
@testable import DSStore

@Suite("DSStore Read/Write")
struct DSStoreReadWriteTests {
	private func replaceUInt32(in data: inout Data, at offset: Int, with value: UInt32) {
		var bigEndianValue = value.bigEndian
		withUnsafeBytes(of: &bigEndianValue) { bytes in
			data.replaceSubrange(offset..<offset + 4, with: bytes)
		}
	}

	@Test("Create empty store")
	func createEmptyStore() {
		let store = DSStore()
		#expect(store.records.isEmpty)
		#expect(store.filenames.isEmpty)
	}

	@Test("Create store with records")
	func createStoreWithRecords() {
		let records = [
			DSStore.Record(filename: "a.txt", type: .iconLocation, value: .data(Data())),
			DSStore.Record(filename: "b.txt", type: .iconLocation, value: .data(Data()))
		]
		let store = DSStore(records: records)

		#expect(store.records.count == 2)
	}

	@Test("Write and read back")
	func writeAndReadBack() throws {
		try TestHelpers.withTempFile { url in
			let original = try TestHelpers.createSampleDSStore()
			try original.write(to: url)

			let loaded = try DSStore.read(from: url)

			#expect(loaded.records.count == original.records.count)
			#expect(loaded.filenames == original.filenames)
		}
	}

	@Test("Round-trip preserves icon positions")
	func roundTripIconPositions() throws {
		try TestHelpers.withTempFile { url in
			var original = DSStore()
			try original.setIconPosition(for: "App.app", x: 123, y: 456)
			try original.setIconPosition(for: "README", x: 789, y: 101)

			try original.write(to: url)
			let loaded = try DSStore.read(from: url)

			let appPos = loaded.iconPosition(for: "App.app")
			let readmePos = loaded.iconPosition(for: "README")

			#expect(appPos?.x == 123)
			#expect(appPos?.y == 456)
			#expect(readmePos?.x == 789)
			#expect(readmePos?.y == 101)
		}
	}

	@Test("Write to path string")
	func writeToPathString() throws {
		try TestHelpers.withTempFile { url in
			var store = DSStore()
			try store.setIconPosition(for: "test", x: 1, y: 2)

			try store.write(toPath: url.path)

			let loaded = try DSStore.read(fromPath: url.path)
			#expect(loaded.records.count == 1)
		}
	}

	@Test("Serialize to Data")
	func serializeToData() throws {
		var store = DSStore()
		try store.setIconPosition(for: "file.txt", x: 50, y: 100)

		let data = try store.serialize()

		#expect(!data.isEmpty)
		// Check magic number
		#expect(data[0] == 0x00)
		#expect(data[1] == 0x00)
		#expect(data[2] == 0x00)
		#expect(data[3] == 0x01)
		// Check Bud1 magic
		#expect(data[4] == 0x42) // B
		#expect(data[5] == 0x75) // u
		#expect(data[6] == 0x64) // d
		#expect(data[7] == 0x31) // 1
	}

	@Test("Rejects filenames with null characters")
	func rejectsFilenamesWithNullCharacters() {
		var store = DSStore()
		store.add(DSStore.Record(filename: "bad\u{0}name", type: .spotlightComment, value: .string("Comment")))

		#expect(throws: DSStore.Error.self) {
			_ = try store.serialize()
		}
	}

	@Test("Invalid page size throws")
	func invalidPageSizeThrows() throws {
		var store = DSStore()
		try store.setIconPosition(for: "file.txt", x: 10, y: 20)

		var data = try store.serialize()
		let pageSizeOffset = 0x24 + 16
		replaceUInt32(in: &data, at: pageSizeOffset, with: 0x00000020)

		#expect(throws: DSStore.Error.self) {
			_ = try DSStore.read(from: data)
		}
	}

	@Test("Allocator offset must be aligned")
	func allocatorOffsetMustBeAligned() throws {
		var store = DSStore()
		try store.setIconPosition(for: "file.txt", x: 10, y: 20)

		var data = try store.serialize()
		replaceUInt32(in: &data, at: 0x08, with: 0x00001001)
		replaceUInt32(in: &data, at: 0x10, with: 0x00001001)

		#expect(throws: DSStore.Error.self) {
			_ = try DSStore.read(from: data)
		}
	}

	@Test("Allocator block size must be a power of two")
	func allocatorBlockSizeMustBePowerOfTwo() throws {
		var store = DSStore()
		try store.setIconPosition(for: "file.txt", x: 10, y: 20)

		var data = try store.serialize()
		replaceUInt32(in: &data, at: 0x0C, with: 0x00000600)

		#expect(throws: DSStore.Error.self) {
			_ = try DSStore.read(from: data)
		}
	}

	@Test("Allocator block size cannot be too small")
	func allocatorBlockSizeCannotBeTooSmall() throws {
		var store = DSStore()
		try store.setIconPosition(for: "file.txt", x: 10, y: 20)

		var data = try store.serialize()
		replaceUInt32(in: &data, at: 0x0C, with: 0x00000010)

		#expect(throws: DSStore.Error.self) {
			_ = try DSStore.read(from: data)
		}
	}

	@Test("Allocator block cannot exceed file length")
	func allocatorBlockCannotExceedFileLength() throws {
		var store = DSStore()
		try store.setIconPosition(for: "file.txt", x: 10, y: 20)

		var data = try store.serialize()
		replaceUInt32(in: &data, at: 0x0C, with: 0x00100000)

		#expect(throws: DSStore.Error.self) {
			_ = try DSStore.read(from: data)
		}
	}

	@Test("Read from Data")
	func readFromData() throws {
		var originalStore = DSStore()
		try originalStore.setIconPosition(for: "test.txt", x: 200, y: 300)

		let data = try originalStore.serialize()
		let loadedStore = try DSStore.read(from: data)

		let position = loadedStore.iconPosition(for: "test.txt")
		#expect(position?.x == 200)
		#expect(position?.y == 300)
	}

	@Test("Multiple write operations")
	func multipleWriteOperations() throws {
		try TestHelpers.withTempFile { url in
			// First write
			var store1 = DSStore()
			try store1.setIconPosition(for: "first.txt", x: 10, y: 20)
			try store1.write(to: url)

			// Overwrite
			var store2 = DSStore()
			try store2.setIconPosition(for: "second.txt", x: 30, y: 40)
			try store2.write(to: url)

			// Read back
			let loaded = try DSStore.read(from: url)
			#expect(loaded.iconPosition(for: "first.txt") == nil)
			#expect(loaded.iconPosition(for: "second.txt")?.x == 30)
		}
	}

	@Test("Read real DS_Store fixture with multi-level B-tree")
	func readRealFixture() throws {
		// The fixture from Trash has many records, requiring multi-level B-tree traversal.
		// This tests that position is correctly saved/restored when recursing into child nodes.
		let fixtureURL = try #require(Bundle.module.url(forResource: "fixture", withExtension: nil))
		let store = try DSStore.read(from: fixtureURL)

		// A Trash DS_Store typically has many files - if B-tree traversal were broken,
		// we'd either crash or get far fewer records
		#expect(store.records.count > 50, "Expected many records from multi-level B-tree")
		#expect(store.filenames.count > 20, "Expected many unique filenames")

		// Verify records have valid data (not corrupted by bad position tracking)
		for record in store.records {
			#expect(!record.filename.isEmpty, "Filename should not be empty")
			#expect(record.type.fourCC.rawValue != 0, "Type should not be null")
		}

		// Check that we have blob values
		let blobRecords = store.records.filter {
			if case .data = $0.value {
				return true
			}
			return false
		}
		#expect(!blobRecords.isEmpty, "Should have blob records")
	}
}
