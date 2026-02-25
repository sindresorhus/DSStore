import Foundation

extension DSStore {
	/**
	A single record stored in a DS_Store file.
	*/
	public struct Record: Hashable, Identifiable, CustomStringConvertible, Sendable {
		/**
		The filename this record applies to ("." for the directory itself).
		*/
		public let filename: String

		/**
		The structure type/property name.
		*/
		public let type: RecordType

		/**
		The value associated with this record.
		*/
		public let value: Value

		/**
		Creates a DS_Store record.
		*/
		public init(filename: String, type: RecordType, value: Value) {
			self.filename = filename
			self.type = type
			self.value = value
		}

		/**
		Stable record identifier derived from filename and record type.
		*/
		public var id: String {
			"\(filename)-\(type.fourCC.stringValue)"
		}

		/**
		Human-readable record description.
		*/
		public var description: String {
			"DSStore.Record(filename: \"\(filename)\", type: \(type.fourCC), value: \(value))"
		}
	}
}
