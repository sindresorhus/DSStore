import Foundation
import Testing
@testable import DSStore

private typealias FourCC = DSStore.FourCC
private typealias PlistValue = DSStore.PlistValue

@Suite("DSStore Integration")
struct DSStoreIntegrationTests {
	@Test("Complete DMG layout workflow")
	func completeDMGLayoutWorkflow() throws {
		try TestHelpers.withTempFile { url in
			// Create a typical DMG layout
			var store = DSStore()

			// Position the app and Applications alias
			try store.setIconPosition(for: "MyApp.app", x: 140, y: 180)
			try store.setIconPosition(for: "Applications", x: 480, y: 180)

			// Configure the window
			try store.setWindowBounds(top: 100, left: 100, bottom: 400, right: 620)
			store.setViewStyle(.iconView)

			// Set a white background
			store.setBackground(.color(red: 65_535, green: 65_535, blue: 65_535))

			// Write it out
			try store.write(to: url)

			// Read it back and verify
			let loaded = try DSStore.read(from: url)

			#expect(loaded.iconPosition(for: "MyApp.app")?.x == 140)
			#expect(loaded.iconPosition(for: "MyApp.app")?.y == 180)
			#expect(loaded.iconPosition(for: "Applications")?.x == 480)
			#expect(loaded.iconPosition(for: "Applications")?.y == 180)

			#expect(loaded.record(for: ".", type: .finderWindowInfo) != nil)
			#expect(loaded.record(for: ".", type: .viewStyle) != nil)
			#expect(loaded.record(for: ".", type: .background) != nil)
		}
	}

	@Test("Modify existing store")
	func modifyExistingStore() throws {
		try TestHelpers.withTempFile { url in
			// Create initial store
			var store1 = DSStore()
			try store1.setIconPosition(for: "old.txt", x: 100, y: 100)
			try store1.setIconPosition(for: "keep.txt", x: 200, y: 200)
			try store1.write(to: url)

			// Load, modify, and save
			var store2 = try DSStore.read(from: url)
			store2.removeRecords(for: "old.txt")
			try store2.setIconPosition(for: "new.txt", x: 300, y: 300)
			try store2.write(to: url)

			// Verify modifications
			let store3 = try DSStore.read(from: url)
			#expect(store3.iconPosition(for: "old.txt") == nil)
			#expect(store3.iconPosition(for: "keep.txt")?.x == 200)
			#expect(store3.iconPosition(for: "new.txt")?.x == 300)
		}
	}

	@Test("Large number of records")
	func largeNumberOfRecords() throws {
		try TestHelpers.withTempFile { url in
			var store = DSStore()

			// Add many files
			for index in 0..<100 {
				try store.setIconPosition(for: "file_\(index).txt", x: index * 10, y: index * 10)
			}

			try store.write(to: url)

			let loaded = try DSStore.read(from: url)
			#expect(loaded.filenames.count == 100)

			// Verify a few random positions
			#expect(loaded.iconPosition(for: "file_0.txt")?.x == 0)
			#expect(loaded.iconPosition(for: "file_50.txt")?.x == 500)
			#expect(loaded.iconPosition(for: "file_99.txt")?.x == 990)
		}
	}

	@Test("Unicode filenames")
	func unicodeFilenames() throws {
		try TestHelpers.withTempFile { url in
			var store = DSStore()

			let filenames = [
				"日本語.txt",
				"한국어.txt",
				"العربية.txt",
				"🎉 Party.txt",
				"Ñoño.txt",
				"Ελληνικά.txt"
			]

			for (index, filename) in filenames.enumerated() {
				try store.setIconPosition(for: filename, x: index * 100, y: 100)
			}

			try store.write(to: url)

			let loaded = try DSStore.read(from: url)

			for (index, filename) in filenames.enumerated() {
				let position = loaded.iconPosition(for: filename)
				#expect(position?.x == index * 100, "Position mismatch for \(filename)")
			}
		}
	}

	@Test("Mixed record types for same file")
	func mixedRecordTypes() throws {
		try TestHelpers.withTempFile { url in
			var store = DSStore()

			// Add multiple record types for the same file
			try store.setIconPosition(for: "document.pdf", x: 100, y: 200)
			store.add(DSStore.Record(
				filename: "document.pdf",
				type: .spotlightComment,
				value: .string("Important document")
			))

			try store.write(to: url)

			let loaded = try DSStore.read(from: url)
			let records = loaded.records(for: "document.pdf")

			#expect(records.count == 2)
			#expect(records.contains { $0.type == .iconLocation })
			#expect(records.contains { $0.type == .spotlightComment })
		}
	}

	@Test("Store description")
	func storeDescription() throws {
		var store = DSStore()
		try store.setIconPosition(for: "test.txt", x: 100, y: 200)
		store.setViewStyle(.iconView)

		let description = store.description

		#expect(description.contains("DSStore"))
		#expect(description.contains("2 records"))
		#expect(description.contains("test.txt"))
	}

	@Test("Round-trip all value types")
	func roundTripAllValueTypes() throws {
		try TestHelpers.withTempFile { url in
			var store = DSStore()

			// bool
			store.add(DSStore.Record(filename: "bool.txt", type: .custom(FourCC.literal("tst1")), value: .boolean(true)))

			// long
			store.add(DSStore.Record(filename: "long.txt", type: .custom(FourCC.literal("tst2")), value: .uint32(123_456)))

			// shor
			store.add(DSStore.Record(filename: "shor.txt", type: .custom(FourCC.literal("tst3")), value: .uint16(1234)))

			// comp (UInt64)
			store.add(DSStore.Record(filename: "comp.txt", type: .custom(FourCC.literal("tst4")), value: .uint64(9_876_543_210)))

			// type (FourCC)
			store.add(DSStore.Record(filename: "type.txt", type: .custom(FourCC.literal("tst5")), value: .fourCC(.iconView)))

			// ustr (string)
			store.add(DSStore.Record(filename: "ustr.txt", type: .custom(FourCC.literal("tst6")), value: .string("Hello World")))

			// blob
			store.add(DSStore.Record(filename: "blob.txt", type: .custom(FourCC.literal("tst7")), value: .data(Data([0x01, 0x02, 0x03]))))

			// book
			store.add(DSStore.Record(filename: "book.txt", type: .custom(FourCC.literal("tst8")), value: .bookmark(Data([0xAA, 0xBB]))))

			// null
			store.add(DSStore.Record(filename: "null.txt", type: .custom(FourCC.literal("tst9")), value: .null))

			try store.write(to: url)
			let loaded = try DSStore.read(from: url)

			// Verify bool
			if case .boolean(let value) = loaded.record(for: "bool.txt", type: .custom(FourCC.literal("tst1")))?.value {
				#expect(value == true)
			} else {
				Issue.record("Expected bool value")
			}

			// Verify long
			if case .uint32(let value) = loaded.record(for: "long.txt", type: .custom(FourCC.literal("tst2")))?.value {
				#expect(value == 123_456)
			} else {
				Issue.record("Expected long value")
			}

			// Verify shor
			if case .uint16(let value) = loaded.record(for: "shor.txt", type: .custom(FourCC.literal("tst3")))?.value {
				#expect(value == 1234)
			} else {
				Issue.record("Expected shor value")
			}

			// Verify comp
			if case .uint64(let value) = loaded.record(for: "comp.txt", type: .custom(FourCC.literal("tst4")))?.value {
				#expect(value == 9_876_543_210)
			} else {
				Issue.record("Expected comp value")
			}

			// Verify type
			if case .fourCC(let value) = loaded.record(for: "type.txt", type: .custom(FourCC.literal("tst5")))?.value {
				#expect(value == .iconView)
			} else {
				Issue.record("Expected type value")
			}

			// Verify ustr
			if case .string(let value) = loaded.record(for: "ustr.txt", type: .custom(FourCC.literal("tst6")))?.value {
				#expect(value == "Hello World")
			} else {
				Issue.record("Expected ustr value")
			}

			// Verify blob
			if case .data(let value) = loaded.record(for: "blob.txt", type: .custom(FourCC.literal("tst7")))?.value {
				#expect(value == Data([0x01, 0x02, 0x03]))
			} else {
				Issue.record("Expected blob value")
			}

			// Verify book
			if case .bookmark(let value) = loaded.record(for: "book.txt", type: .custom(FourCC.literal("tst8")))?.value {
				#expect(value == Data([0xAA, 0xBB]))
			} else {
				Issue.record("Expected book value")
			}

			// Verify null
			let nullValue = loaded.record(for: "null.txt", type: .custom(FourCC.literal("tst9")))?.value
			#expect(nullValue == .null)
		}
	}

	@Test("Round-trip date value")
	func roundTripDateValue() throws {
		try TestHelpers.withTempFile { url in
			var store = DSStore()
			let originalDate = Date(timeIntervalSince1970: 1_700_000_000)

			store.add(DSStore.Record(filename: "date.txt", type: .custom(FourCC.literal("dutc")), value: .timestamp(originalDate)))

			try store.write(to: url)
			let loaded = try DSStore.read(from: url)

			if case .timestamp(let loadedDate) = loaded.record(for: "date.txt", type: .custom(FourCC.literal("dutc")))?.value {
				// Allow small precision loss due to Mac timestamp format
				#expect(abs(loadedDate.timeIntervalSince1970 - originalDate.timeIntervalSince1970) < 0.001)
			} else {
				Issue.record("Expected dutc value")
			}
		}
	}

	@Test("Round-trip plist value")
	func roundTripPlistValue() throws {
		try TestHelpers.withTempFile { url in
			var store = DSStore()

			let plist = PlistValue.dictionary([
				"ShowToolbar": .bool(true),
				"ShowSidebar": .bool(false),
				"WindowBounds": .string("{{100, 200}, {800, 600}}"),
				"IconSize": .int(72)
			])

			store.add(DSStore.Record(filename: ".", type: .browserWindowSettings, value: .propertyList(plist)))

			try store.write(to: url)
			let loaded = try DSStore.read(from: url)

			if case .propertyList(let loadedPlist) = loaded.record(for: ".", type: .browserWindowSettings)?.value {
				#expect(loadedPlist == plist)
			} else {
				Issue.record("Expected plist value")
			}
		}
	}

	@Test("Invalid plist blob stays blob")
	func invalidPlistBlobStaysBlob() throws {
		try TestHelpers.withTempFile { url in
			var store = DSStore()
			let invalidPlist = Data("<?xml".utf8)

			store.add(DSStore.Record(filename: "bad.plist", type: .custom(FourCC.literal("tstp")), value: .data(invalidPlist)))

			try store.write(to: url)
			let loaded = try DSStore.read(from: url)

			if case .data(let value) = loaded.record(for: "bad.plist", type: .custom(FourCC.literal("tstp")))?.value {
				#expect(value == invalidPlist)
			} else {
				Issue.record("Expected blob value")
			}
		}
	}
}
