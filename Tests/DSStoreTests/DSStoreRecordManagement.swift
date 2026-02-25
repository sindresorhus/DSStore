import Foundation
import Testing
@testable import DSStore

@Suite("DSStore Record Management")
struct DSStoreRecordManagementTests {
	@Test("Add record")
	func addRecord() {
		var store = DSStore()
		let record = DSStore.Record(filename: "test.txt", type: .spotlightComment, value: .string("Comment"))

		store.add(record)

		#expect(store.records.count == 1)
		#expect(store.records.first == record)
	}

	@Test("Add record replaces existing with same filename and type")
	func addRecordReplacesExisting() {
		var store = DSStore()

		store.add(DSStore.Record(filename: "test.txt", type: .spotlightComment, value: .string("First")))
		store.add(DSStore.Record(filename: "test.txt", type: .spotlightComment, value: .string("Second")))

		#expect(store.records.count == 1)
		if case .string(let comment) = store.records.first?.value {
			#expect(comment == "Second")
		} else {
			Issue.record("Expected ustr value")
		}
	}

	@Test("Add multiple records for same file with different types")
	func addMultipleRecordTypes() {
		var store = DSStore()

		store.add(DSStore.Record(filename: "test.txt", type: .spotlightComment, value: .string("Comment")))
		store.add(DSStore.Record(filename: "test.txt", type: .iconLocation, value: .data(Data())))

		#expect(store.records.count == 2)
	}

	@Test("Get records for filename")
	func getRecordsForFilename() {
		var store = DSStore()
		store.add(DSStore.Record(filename: "a.txt", type: .spotlightComment, value: .string("A")))
		store.add(DSStore.Record(filename: "a.txt", type: .iconLocation, value: .data(Data())))
		store.add(DSStore.Record(filename: "b.txt", type: .spotlightComment, value: .string("B")))

		let aRecords = store.records(for: "a.txt")
		let bRecords = store.records(for: "b.txt")
		let cRecords = store.records(for: "c.txt")

		#expect(aRecords.count == 2)
		#expect(bRecords.count == 1)
		#expect(cRecords.isEmpty)
	}

	@Test("Get specific record by filename and type")
	func getSpecificRecord() {
		var store = DSStore()
		store.add(DSStore.Record(filename: "test.txt", type: .spotlightComment, value: .string("Comment")))
		store.add(DSStore.Record(filename: "test.txt", type: .iconLocation, value: .data(Data())))

		let commentRecord = store.record(for: "test.txt", type: .spotlightComment)
		let iconRecord = store.record(for: "test.txt", type: .iconLocation)
		let missingRecord = store.record(for: "test.txt", type: .browserWindowSettings)

		#expect(commentRecord != nil)
		#expect(iconRecord != nil)
		#expect(missingRecord == nil)
	}

	@Test("Remove records for filename")
	func removeRecordsForFilename() {
		var store = DSStore()
		store.add(DSStore.Record(filename: "a.txt", type: .spotlightComment, value: .string("A")))
		store.add(DSStore.Record(filename: "a.txt", type: .iconLocation, value: .data(Data())))
		store.add(DSStore.Record(filename: "b.txt", type: .spotlightComment, value: .string("B")))

		store.removeRecords(for: "a.txt")

		#expect(store.records.count == 1)
		#expect(store.records.first?.filename == "b.txt")
	}

	@Test("Remove specific record")
	func removeSpecificRecord() {
		var store = DSStore()
		store.add(DSStore.Record(filename: "test.txt", type: .spotlightComment, value: .string("Comment")))
		store.add(DSStore.Record(filename: "test.txt", type: .iconLocation, value: .data(Data())))

		store.remove(filename: "test.txt", type: .spotlightComment)

		#expect(store.records.count == 1)
		#expect(store.records.first?.type == .iconLocation)
	}

	@Test("Get all filenames")
	func getAllFilenames() {
		var store = DSStore()
		store.add(DSStore.Record(filename: "a.txt", type: .spotlightComment, value: .string("A")))
		store.add(DSStore.Record(filename: "a.txt", type: .iconLocation, value: .data(Data())))
		store.add(DSStore.Record(filename: "b.txt", type: .spotlightComment, value: .string("B")))
		store.add(DSStore.Record(filename: ".", type: .browserWindowSettings, value: .data(Data())))

		let filenames = store.filenames

		#expect(filenames.count == 3)
		#expect(filenames.contains("a.txt"))
		#expect(filenames.contains("b.txt"))
		#expect(filenames.contains("."))
	}
}
