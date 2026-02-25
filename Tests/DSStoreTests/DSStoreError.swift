import Foundation
import Testing
@testable import DSStore

@Suite("DSStore Error Handling")
struct DSStoreErrorTests {
	@Test("Read non-existent file throws error")
	func readNonExistentFile() {
		let url = URL(fileURLWithPath: "/nonexistent/path/.DS_Store")

		#expect(throws: DSStore.Error.self) {
			_ = try DSStore.read(from: url)
		}
	}

	@Test("Read empty file throws error")
	func readEmptyFile() throws {
		try TestHelpers.withTempFile { url in
			// File is empty
			#expect(throws: DSStore.Error.self) {
				_ = try DSStore.read(from: url)
			}
		}
	}

	@Test("Read invalid magic throws error")
	func readInvalidMagic() throws {
		try TestHelpers.withTempFile { url in
			// Write garbage data
			try Data([0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF]).write(to: url)

			#expect(throws: DSStore.Error.self) {
				_ = try DSStore.read(from: url)
			}
		}
	}

	@Test("Read truncated file throws error")
	func readTruncatedFile() throws {
		try TestHelpers.withTempFile { url in
			// Write partial header
			try Data([0x00, 0x00, 0x00, 0x01, 0x42, 0x75, 0x64, 0x31]).write(to: url)

			#expect(throws: DSStore.Error.self) {
				_ = try DSStore.read(from: url)
			}
		}
	}

	@Test("Error descriptions are meaningful")
	func errorDescriptions() throws {
		let errors: [DSStore.Error] = [
			.invalidMagic,
			.invalidHeader,
			.offsetMismatch,
			.invalidBlockAddress,
			.invalidBTreeHeader,
			.unknownDataType("test"),
			.invalidUTF16String,
			.fileNotFound,
			.readFailed("test reason"),
			.plistSerializationFailed("test reason"),
			.writeFailed("test reason"),
			.corruptedFile("test reason")
		]

		for error in errors {
			let description = error.errorDescription
			#expect(description != nil)
			#expect(!(try #require(description?.isEmpty)))
		}
	}

	@Test("Unknown data type error includes type name")
	func unknownDataTypeError() {
		let error = DSStore.Error.unknownDataType("xxxx")
		#expect(error.errorDescription?.contains("xxxx") == true)
	}

	@Test("Corrupted file error includes reason")
	func corruptedFileError() {
		let error = DSStore.Error.corruptedFile("missing block")
		#expect(error.errorDescription?.contains("missing block") == true)
	}
}
