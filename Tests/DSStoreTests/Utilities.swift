import Foundation
import DSStore

enum TestHelpers {
	static func createTempFile() -> URL {
		let url = FileManager.default.temporaryDirectory
			.appendingPathComponent(UUID().uuidString)
		FileManager.default.createFile(atPath: url.path, contents: nil)
		return url
	}

	static func createTempDirectory() -> URL {
		let url = FileManager.default.temporaryDirectory
			.appendingPathComponent(UUID().uuidString, isDirectory: true)
		try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
		return url
	}

	static func cleanup(_ url: URL) {
		try? FileManager.default.removeItem(at: url)
	}

	@discardableResult
	static func withTempFile<T>(_ test: (URL) throws -> T) throws -> T {
		let url = createTempFile()
		defer { cleanup(url) }
		return try test(url)
	}

	@discardableResult
	static func withTempDirectory<T>(_ test: (URL) throws -> T) throws -> T {
		let url = createTempDirectory()
		defer { cleanup(url) }
		return try test(url)
	}

	/**
	Creates a minimal valid DS_Store file for testing.
	*/
	static func createMinimalDSStoreData() throws -> Data {
		var store = DSStore()
		try store.setIconPosition(for: "Test.txt", x: 100, y: 200)
		return try store.serialize()
	}

	/**
	Creates a sample DS_Store with multiple records.
	*/
	static func createSampleDSStore() throws -> DSStore {
		var store = DSStore()
		try store.setIconPosition(for: "Application.app", x: 140, y: 180)
		try store.setIconPosition(for: "Applications", x: 480, y: 180)
		try store.setIconPosition(for: "README.md", x: 300, y: 180)
		try store.setWindowBounds(top: 100, left: 100, bottom: 400, right: 620)
		store.setViewStyle(.iconView)
		store.setBackground(.color(red: 65_535, green: 65_535, blue: 65_535))
		return store
	}
}
