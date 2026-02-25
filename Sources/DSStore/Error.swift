import Foundation

extension DSStore {
	/**
	Errors thrown while reading or writing DS_Store data.
	*/
	public enum Error: Swift.Error, LocalizedError, Sendable {
		case invalidMagic
		case invalidHeader
		case offsetMismatch
		case invalidBlockAddress
		case invalidBTreeHeader
		case unknownDataType(String)
		case invalidUTF16String
		case fileNotFound
		case readFailed(String)
		case plistSerializationFailed(String)
		case writeFailed(String)
		case corruptedFile(String)

		/**
		Localized error description.
		*/
		public var errorDescription: String? {
			switch self {
			case .invalidMagic:
				"Invalid file magic number"
			case .invalidHeader:
				"Invalid file header"
			case .offsetMismatch:
				"Root block offset mismatch"
			case .invalidBlockAddress:
				"Invalid block address"
			case .invalidBTreeHeader:
				"Invalid B-tree header"
			case .unknownDataType(let type):
				"Unknown data type: \(type)"
			case .invalidUTF16String:
				"Invalid UTF-16 string encoding"
			case .fileNotFound:
				"File not found"
			case .readFailed(let reason):
				"Read failed: \(reason)"
			case .plistSerializationFailed(let reason):
				"Property list serialization failed: \(reason)"
			case .writeFailed(let reason):
				"Write failed: \(reason)"
			case .corruptedFile(let reason):
				"Corrupted file: \(reason)"
			}
		}
	}
}
