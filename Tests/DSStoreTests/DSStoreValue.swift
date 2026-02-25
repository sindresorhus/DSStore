import Foundation
import Testing
@testable import DSStore

private typealias FourCC = DSStore.FourCC
private typealias PlistValue = DSStore.PlistValue

@Suite("DSStore.Value")
struct DSStoreValueTests {
	@Test("Bool value")
	func boolValue() {
		let trueValue = DSStore.Value.boolean(true)
		let falseValue = DSStore.Value.boolean(false)

		#expect(trueValue == .boolean(true))
		#expect(falseValue == .boolean(false))
		#expect(trueValue != falseValue)
	}

	@Test("Long value")
	func longValue() {
		let value = DSStore.Value.uint32(12_345)
		let expectedValue = DSStore.Value.uint32(12_345)
		#expect(value == expectedValue)

		if case .uint32(let number) = value {
			#expect(number == 12_345)
		} else {
			Issue.record("Expected long value")
		}
	}

	@Test("Short value")
	func shortValue() {
		let value = DSStore.Value.uint16(256)
		#expect(value == .uint16(256))
	}

	@Test("Comp (64-bit) value")
	func compValue() {
		let largeNumber: UInt64 = 9_876_543_210
		let value = DSStore.Value.uint64(largeNumber)

		if case .uint64(let number) = value {
			#expect(number == largeNumber)
		} else {
			Issue.record("Expected comp value")
		}
	}

	@Test("Date value")
	func dateValue() {
		let date = Date(timeIntervalSince1970: 1_000_000)
		let value = DSStore.Value.timestamp(date)

		if case .timestamp(let storedDate) = value {
			#expect(abs(storedDate.timeIntervalSince1970 - date.timeIntervalSince1970) < 1)
		} else {
			Issue.record("Expected dutc value")
		}
	}

	@Test("Type (FourCC) value")
	func typeValue() {
		let fourCC = FourCC.literal("icnv")
		let value = DSStore.Value.fourCC(fourCC)

		if case .fourCC(let storedFourCC) = value {
			#expect(storedFourCC == fourCC)
		} else {
			Issue.record("Expected type value")
		}
	}

	@Test("Unicode string value")
	func ustrValue() {
		let string = "Hello, 世界! 🌍"
		let value = DSStore.Value.string(string)

		if case .string(let storedString) = value {
			#expect(storedString == string)
		} else {
			Issue.record("Expected ustr value")
		}
	}

	@Test("Blob value")
	func blobValue() {
		let data = Data([0x00, 0x01, 0x02, 0xFF, 0xFE])
		let value = DSStore.Value.data(data)

		if case .data(let storedData) = value {
			#expect(storedData == data)
		} else {
			Issue.record("Expected blob value")
		}
	}

	@Test("Book value")
	func bookValue() {
		let data = Data([0x10, 0x20, 0x30])
		let value = DSStore.Value.bookmark(data)

		if case .bookmark(let storedData) = value {
			#expect(storedData == data)
		} else {
			Issue.record("Expected book value")
		}
	}

	@Test("Null value")
	func nullValue() {
		let value = DSStore.Value.null
		#expect(value == .null)
	}

	@Test("Description formatting")
	func descriptionFormatting() {
		#expect(DSStore.Value.boolean(true).description == "boolean(true)")
		#expect(DSStore.Value.uint32(42).description == "uint32(42)")
		#expect(DSStore.Value.uint16(16).description == "uint16(16)")
		#expect(DSStore.Value.string("test").description == "string(\"test\")")
		#expect(DSStore.Value.data(Data([1, 2, 3])).description == "data(3 bytes)")
		#expect(DSStore.Value.bookmark(Data([1])).description == "bookmark(1 bytes)")
		#expect(DSStore.Value.null.description == "null")
	}

	@Test("Equality for all types")
	func equalityForAllTypes() {
		// Same values should be equal
		let booleanValue = DSStore.Value.boolean(true)
		let matchingBooleanValue = DSStore.Value.boolean(true)
		let uint32Value = DSStore.Value.uint32(100)
		let matchingUInt32Value = DSStore.Value.uint32(100)
		let stringValue = DSStore.Value.string("test")
		let matchingStringValue = DSStore.Value.string("test")
		let dataValue = DSStore.Value.data(Data([1, 2]))
		let matchingDataValue = DSStore.Value.data(Data([1, 2]))
		let bookmarkValue = DSStore.Value.bookmark(Data([1, 2]))
		let matchingBookmarkValue = DSStore.Value.bookmark(Data([1, 2]))
		let nullValue = DSStore.Value.null
		let matchingNullValue = DSStore.Value.null

		#expect(booleanValue == matchingBooleanValue)
		#expect(uint32Value == matchingUInt32Value)
		#expect(stringValue == matchingStringValue)
		#expect(dataValue == matchingDataValue)
		#expect(bookmarkValue == matchingBookmarkValue)
		#expect(nullValue == matchingNullValue)

		// Different values should not be equal
		#expect(DSStore.Value.boolean(true) != DSStore.Value.boolean(false))
		#expect(DSStore.Value.uint32(100) != DSStore.Value.uint32(200))
		#expect(DSStore.Value.string("a") != DSStore.Value.string("b"))
		#expect(DSStore.Value.bookmark(Data([1])) != DSStore.Value.bookmark(Data([2])))

		// Different types should not be equal
		#expect(DSStore.Value.uint32(1) != DSStore.Value.uint16(1))
	}

	@Test("Plist value")
	func plistValue() {
		let plist = PlistValue.dictionary([
			"name": .string("Test"),
			"count": .int(42),
			"enabled": .bool(true),
			"items": .array([.string("a"), .string("b")])
		])
		let value = DSStore.Value.propertyList(plist)

		if case .propertyList(let storedPlist) = value {
			#expect(storedPlist == plist)
		} else {
			Issue.record("Expected plist value")
		}
	}

	@Test("Plist from Foundation object")
	func plistFromFoundation() {
		let dictionary: [String: Any] = [
			"string": "hello",
			"number": 42,
			"bool": true,
			"nested": ["a", "b", "c"]
		]

		guard let plist = PlistValue(dictionary) else {
			Issue.record("Failed to create PlistValue from dictionary")
			return
		}

		if case .dictionary(let dictionaryValue) = plist {
			#expect(dictionaryValue["string"] == .string("hello"))
			#expect(dictionaryValue["number"] == .int(42))
			#expect(dictionaryValue["bool"] == .bool(true))
			#expect(dictionaryValue["nested"] == .array([.string("a"), .string("b"), .string("c")]))
		} else {
			Issue.record("Expected dictionary plist")
		}
	}

	@Test("Plist from Foundation object accepts supported integer range")
	func plistFromFoundationAcceptsInRangeInteger() {
		let dictionary: [String: Any] = [
			"maxInt": NSNumber(value: Int.max)
		]

		guard let plist = PlistValue(dictionary) else {
			Issue.record("Failed to create PlistValue from dictionary")
			return
		}

		#expect(plist == .dictionary(["maxInt": .int(Int.max)]))
	}

	@Test("Plist from Foundation object rejects oversized integers")
	func plistFromFoundationRejectsOversizedInteger() {
		let dictionary: [String: Any] = [
			"oversized": NSNumber(value: UInt64.max)
		]

		#expect(PlistValue(dictionary) == nil)
	}

	@Test("Plist serialization round-trip")
	func plistSerializationRoundTrip() throws {
		let plist = PlistValue.dictionary([
			"ShowToolbar": .bool(true),
			"WindowBounds": .string("{{100, 200}, {800, 600}}")
		])

		let data = try plist.serialized()
		#expect(data.starts(with: [0x62, 0x70, 0x6C, 0x69, 0x73, 0x74])) // "bplist"

		// Parse it back
		let object = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
		guard let roundTripped = PlistValue(object) else {
			Issue.record("Failed to parse serialized plist")
			return
		}

		#expect(roundTripped == plist)
	}
}
