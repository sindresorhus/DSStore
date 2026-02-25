import Foundation
import Testing
@testable import DSStore

@Suite("DSStore.Record")
struct DSStoreRecordTests {
	@Test("Create record with all components")
	func createRecord() {
		let record = DSStore.Record(
			filename: "test.txt",
			type: .iconLocation,
			value: .data(Data([0x00, 0x01]))
		)

		#expect(record.filename == "test.txt")
		#expect(record.type == .iconLocation)
		#expect(record.value == .data(Data([0x00, 0x01])))
	}

	@Test("Record for directory itself uses dot")
	func directoryRecord() {
		let record = DSStore.Record(
			filename: ".",
			type: .browserWindowSettings,
			value: .data(Data())
		)

		#expect(record.filename == ".")
	}

	@Test("Record with unicode filename")
	func unicodeFilename() {
		let filename = "文件名.txt"
		let record = DSStore.Record(
			filename: filename,
			type: .spotlightComment,
			value: .string("Comment")
		)

		#expect(record.filename == filename)
	}

	@Test("Record with emoji filename")
	func emojiFilename() {
		let filename = "📁 Documents"
		let record = DSStore.Record(
			filename: filename,
			type: .iconLocation,
			value: .data(Data())
		)

		#expect(record.filename == filename)
	}

	@Test("Record equality")
	func recordEquality() {
		let record1 = DSStore.Record(filename: "a.txt", type: .iconLocation, value: .uint32(1))
		let record2 = DSStore.Record(filename: "a.txt", type: .iconLocation, value: .uint32(1))
		let record3 = DSStore.Record(filename: "b.txt", type: .iconLocation, value: .uint32(1))

		#expect(record1 == record2)
		#expect(record1 != record3)
	}

	@Test("Record description")
	func recordDescription() {
		let record = DSStore.Record(
			filename: "test.txt",
			type: .spotlightComment,
			value: .string("Hello")
		)

		let description = record.description
		#expect(description.contains("test.txt"))
		#expect(description.contains("cmmt"))
		#expect(description.contains("Hello"))
	}

	@Test("Record convenience: isDirectoryRecord")
	func isDirectoryRecord() {
		let record = DSStore.Record(filename: ".", type: .iconLocation, value: .data(Data()))
		#expect(record.isDirectoryRecord)
	}

	@Test("Record convenience: iconPosition")
	func iconPosition() {
		var data = Data()
		var xValue = UInt32(10).bigEndian
		var yValue = UInt32(20).bigEndian
		data.append(contentsOf: withUnsafeBytes(of: &xValue) { $0 })
		data.append(contentsOf: withUnsafeBytes(of: &yValue) { $0 })

		let record = DSStore.Record(filename: "File.txt", type: .iconLocation, value: .data(data))

		#expect(record.iconPosition?.x == 10)
		#expect(record.iconPosition?.y == 20)
	}

	@Test("Record convenience: backgroundType")
	func backgroundType() {
		var data = Data("ClrB".utf8)
		var red = UInt16(1000).bigEndian
		var green = UInt16(2000).bigEndian
		var blue = UInt16(3000).bigEndian
		data.append(contentsOf: withUnsafeBytes(of: &red) { $0 })
		data.append(contentsOf: withUnsafeBytes(of: &green) { $0 })
		data.append(contentsOf: withUnsafeBytes(of: &blue) { $0 })
		data.append(contentsOf: [0x00, 0x00])

		let record = DSStore.Record(filename: ".", type: .background, value: .data(data))

		if case .color(let resultRed, let resultGreen, let resultBlue) = record.backgroundType {
			#expect(resultRed == 1000)
			#expect(resultGreen == 2000)
			#expect(resultBlue == 3000)
		} else {
			Issue.record("Expected color background type")
		}
	}

	@Test("Record convenience: windowBounds")
	func windowBounds() {
		var data = Data()
		var top = UInt16(10).bigEndian
		var left = UInt16(20).bigEndian
		var bottom = UInt16(110).bigEndian
		var right = UInt16(220).bigEndian
		data.append(contentsOf: withUnsafeBytes(of: &top) { $0 })
		data.append(contentsOf: withUnsafeBytes(of: &left) { $0 })
		data.append(contentsOf: withUnsafeBytes(of: &bottom) { $0 })
		data.append(contentsOf: withUnsafeBytes(of: &right) { $0 })

		let record = DSStore.Record(filename: ".", type: .finderWindowInfo, value: .data(data))
		#expect(record.windowBounds?.width == 200)
		#expect(record.windowBounds?.height == 100)
	}

	@Test("Record convenience: pathValue")
	func pathValue() {
		let stringRecord = DSStore.Record(filename: "File.txt", type: .trashPutBackLocation, value: .string("Users/test"))
		#expect(stringRecord.pathValue == "/Users/test")

		let dataRecord = DSStore.Record(filename: "File.txt", type: .trashPutBackLocation, value: .data(Data("var/tmp".utf8)))
		#expect(dataRecord.pathValue == "/var/tmp")
	}

	@Test("RecordType isSizeRecord")
	func isSizeRecord() {
		#expect(DSStore.RecordType.logicalSize.isSizeRecord)
		#expect(DSStore.RecordType.logicalSizeLegacy.isSizeRecord)
		#expect(DSStore.RecordType.physicalSize.isSizeRecord)
		#expect(DSStore.RecordType.physicalSizeLegacy.isSizeRecord)
		#expect(!DSStore.RecordType.viewStyle.isSizeRecord)
	}

	@Test("RecordType isLegacySizeRecord")
	func isLegacySizeRecord() {
		#expect(DSStore.RecordType.logicalSizeLegacy.isLegacySizeRecord)
		#expect(DSStore.RecordType.physicalSizeLegacy.isLegacySizeRecord)
		#expect(!DSStore.RecordType.logicalSize.isLegacySizeRecord)
		#expect(!DSStore.RecordType.physicalSize.isLegacySizeRecord)
	}

	@Test("ViewStyle displayName")
	func viewStyleDisplayName() {
		#expect(DSStore.ViewStyle.icon.displayName == "Icon view")
		#expect(DSStore.ViewStyle.list.displayName == "List view")
		#expect(DSStore.ViewStyle.column.displayName == "Column view")
		#expect(DSStore.ViewStyle.gallery.displayName == "Gallery view")
	}
}
