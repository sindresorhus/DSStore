import Foundation
import Testing
@testable import DSStore

private typealias FourCC = DSStore.FourCC

@Suite("FourCC")
struct FourCCTests {
	@Test("Create from string")
	func createFromString() {
		let fourCC = FourCC.literal("Iloc")
		#expect(fourCC.stringValue == "Iloc")
		#expect(fourCC.rawValue == 0x496C6F63)
	}

	@Test("Create from UInt32")
	func createFromUInt32() {
		let fourCC = FourCC(0x42756431) // "Bud1"
		#expect(fourCC.stringValue == "Bud1")
	}

	@Test("Round-trip conversion")
	func roundTripConversion() {
		let original = "BKGD"
		let fourCC = FourCC(original)
		#expect(fourCC?.stringValue == original)
	}

	@Test("Create from string variable")
	func createFromStringVariable() {
		let original = "Iloc"
		let fourCC = FourCC(original)
		#expect(fourCC?.stringValue == "Iloc")
		#expect(fourCC?.rawValue == 0x496C6F63)
	}

	@Test("Invalid string returns nil")
	func invalidStringReturnsNil() {
		let tooShort = "ABC"
		let tooLong = "ABCDE"
		let nonASCII = "ÅBCD"

		#expect(FourCC(tooShort) == nil)
		#expect(FourCC(tooLong) == nil)
		#expect(FourCC(nonASCII) == nil)
	}

	@Test("Equality")
	func equality() {
		let first = FourCC.literal("test")
		let second = FourCC.literal("test")
		let third = FourCC.literal("diff")

		#expect(first == second)
		#expect(first != third)
	}

	@Test("Hashable conformance")
	func hashable() {
		let fourCC1 = FourCC.literal("Iloc")
		let fourCC2 = FourCC.literal("Iloc")

		var set = Set<FourCC>()
		set.insert(fourCC1)
		set.insert(fourCC2)

		#expect(set.count == 1)
	}

	@Test("Common type constants")
	func commonTypeConstants() {
		#expect(DSStore.RecordType.iconLocation.fourCC.stringValue == "Iloc")
		#expect(DSStore.RecordType.background.fourCC.stringValue == "BKGD")
		#expect(DSStore.RecordType.finderWindowInfo.fourCC.stringValue == "fwi0")
		#expect(DSStore.RecordType.viewStyle.fourCC.stringValue == "vstl")
		#expect(DSStore.RecordType.iconViewOptions.fourCC.stringValue == "icvo")
		#expect(DSStore.RecordType.listViewProperties.fourCC.stringValue == "lsvp")
		#expect(DSStore.RecordType.browserWindowSettings.fourCC.stringValue == "bwsp")
		#expect(DSStore.RecordType.spotlightComment.fourCC.stringValue == "cmmt")
	}

	@Test("Description matches string value")
	func descriptionMatchesStringValue() {
		let fourCC = FourCC.literal("test")
		#expect(fourCC.description == "test")
		#expect(String(describing: fourCC) == "test")
	}

	@Test("Binary representation is big-endian")
	func binaryRepresentationIsBigEndian() {
		let fourCC = FourCC.literal("ABCD")
		// A=0x41, B=0x42, C=0x43, D=0x44
		#expect(fourCC.rawValue == 0x41424344)
	}
}
