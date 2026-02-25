import Foundation

extension DSStore {
	/**
	A type-safe representation of property list values.
	*/
	public indirect enum PlistValue: Hashable, Sendable, CustomStringConvertible {
		case string(String)
		case int(Int)
		case double(Double)
		case bool(Bool)
		case data(Data)
		case date(Date)
		case array([Self])
		case dictionary([String: Self])

		/**
		Human-readable summary of the plist value.
		*/
		public var description: String {
			switch self {
			case .string(let value):
				"\"\(value)\""
			case .int(let value):
				"\(value)"
			case .double(let value):
				"\(value)"
			case .bool(let value):
				value ? "true" : "false"
			case .data(let value):
				"<\(value.count) bytes>"
			case .date(let value):
				"\(value)"
			case .array(let value):
				"[\(value.count) items]"
			case .dictionary(let value):
				"{\(value.count) keys}"
			}
		}

		/**
		Creates a PlistValue from a Foundation property list object.
		Returns nil if the object cannot be represented as a PlistValue.
		*/
		public init?(_ object: Any) {
			switch object {
			case let string as String:
				self = .string(string)
			case let number as NSNumber:
				// Check if it's a boolean (CFBoolean)
				if CFGetTypeID(number) == CFBooleanGetTypeID() {
					self = .bool(number.boolValue)
				} else {
					switch CFNumberGetType(number) {
					case .floatType,
						.float32Type,
						.float64Type,
						.doubleType,
						.cgFloatType:
						self = .double(number.doubleValue)
					default:
						guard let intValue = Self.intFromNSNumber(number) else {
							return nil
						}
						self = .int(intValue)
					}
				}
			case let data as Data:
				self = .data(data)
			case let date as Date:
				self = .date(date)
			case let array as [Any]:
				var result = [Self]()
				for item in array {
					guard let plistValue = Self(item) else {
						return nil
					}
					result.append(plistValue)
				}
				self = .array(result)
			case let dictionary as [String: Any]:
				var result = [String: Self]()
				for (key, value) in dictionary {
					guard let plistValue = Self(value) else {
						return nil
					}
					result[key] = plistValue
				}
				self = .dictionary(result)
			default:
				return nil
			}
		}

		private static func intFromNSNumber(_ number: NSNumber) -> Int? {
			let value = number.stringValue
			guard let intValue = Int(value) else {
				return nil
			}

			return intValue
		}

		/**
		Converts the PlistValue back to a Foundation property list object.
		*/
		public var asFoundationObject: Any {
			switch self {
			case .string(let value):
				value
			case .int(let value):
				value
			case .double(let value):
				value
			case .bool(let value):
				value
			case .data(let value):
				value
			case .date(let value):
				value
			case .array(let value):
				value.map(\.asFoundationObject)
			case .dictionary(let value):
				value.mapValues(\.asFoundationObject)
			}
		}

		/**
		Serializes the PlistValue to binary property list data.
		*/
		public func serialized() throws(DSStore.Error) -> Data {
			do {
				return try PropertyListSerialization.data(fromPropertyList: asFoundationObject, format: .binary, options: 0)
			} catch {
				throw DSStore.Error.plistSerializationFailed(error.localizedDescription)
			}
		}
	}
}

/**
Value types that can be stored in a DS_Store record.

Each case documents the original on-disk type code.
*/
extension DSStore {
	/**
	Typed value payload for a DS_Store record.
	*/
	public enum Value: Hashable, CustomStringConvertible, Sendable {
		/**
		On-disk type: `bool`.
		*/
		case boolean(Bool)

		/**
		On-disk type: `long`.
		*/
		case uint32(UInt32)

		/**
		On-disk type: `shor` (stored in a 32-bit slot).
		*/
		case uint16(UInt16)

		/**
		On-disk type: `comp`.
		*/
		case uint64(UInt64)

		/**
		On-disk type: `dutc`.
		*/
		case timestamp(Date)

		/**
		On-disk type: `type`.
		*/
		case fourCC(FourCC)

		/**
		On-disk type: `ustr`.
		*/
		case string(String)

		/**
		On-disk type: `blob`.
		*/
		case data(Data)

		/**
		On-disk type: `book`.
		*/
		case bookmark(Data)

		/**
		On-disk type: `null`.
		*/
		case null

		/**
		On-disk type: `blob` (property list payload).
		*/
		case propertyList(PlistValue)

		/**
		Human-readable summary of the value.
		*/
		public var description: String {
			switch self {
			case .boolean(let value):
				"boolean(\(value))"
			case .uint32(let value):
				"uint32(\(value))"
			case .uint16(let value):
				"uint16(\(value))"
			case .uint64(let value):
				"uint64(\(value))"
			case .timestamp(let date):
				"timestamp(\(date))"
			case .fourCC(let fourCC):
				"fourCC(\(fourCC))"
			case .string(let string):
				"string(\"\(string)\")"
			case .data(let data):
				"data(\(data.count) bytes)"
			case .bookmark(let data):
				"bookmark(\(data.count) bytes)"
			case .null:
				"null"
			case .propertyList(let value):
				"propertyList(\(value))"
			}
		}
	}
}
