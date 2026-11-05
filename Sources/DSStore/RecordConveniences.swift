import Foundation

extension DSStore.Record {
	/**
	Whether the record represents the directory itself (".").
	*/
	public var isDirectoryRecord: Bool {
		filename == "."
	}

	/**
	Icon position for the record if it is an icon location record.
	*/
	public var iconPosition: (x: Int, y: Int)? {
		guard
			type == .iconLocation, case .data(let data) = value,
			let xPosition = data.readUInt32BE(at: 0),
			let yPosition = data.readUInt32BE(at: 4)
		else {
			return nil
		}

		return (Int(xPosition), Int(yPosition))
	}

	/**
	Finder window bounds when the record is `finderWindowInfo`.
	*/
	public var windowBounds: DSStore.WindowBounds? {
		guard
			type == .finderWindowInfo, case .data(let data) = value,
			let top = data.readUInt16BE(at: 0),
			let left = data.readUInt16BE(at: 2),
			let bottom = data.readUInt16BE(at: 4),
			let right = data.readUInt16BE(at: 6)
		else {
			return nil
		}

		let viewStyle: DSStore.FourCC? = if let viewStyleRaw = data.readUInt32BE(at: 8) {
			DSStore.FourCC(viewStyleRaw)
		} else {
			nil
		}

		return DSStore.WindowBounds(
			top: Int(top),
			left: Int(left),
			bottom: Int(bottom),
			right: Int(right),
			viewStyle: viewStyle
		)
	}

	/**
	Path value when the record stores a file path.

	Deprecated: use `DSStore.putBackURL(for:storeURL:)`. This value is only the directory, and the original filename is in a separate `ptbN` record.

	For a Put Back location (`ptbL`), the path is relative to the root of the volume that holds the `.DS_Store` file. macOS stores it without a leading slash on the boot volume (for example, `Users/sindresorhus/Downloads/`), and with a leading slash on other volumes (for example, `/x/y/` for `/Volumes/External/x/y/`). This adds a leading slash if there is none, so the result is an absolute path only for a `.DS_Store` file on the boot volume. For other volumes, prepend the volume path.
	*/
	@available(*, deprecated, renamed: "DSStore.putBackURL(for:storeURL:)")
	public var pathValue: String? {
		guard let putBackDirectoryPath else {
			return nil
		}

		return putBackDirectoryPath.hasPrefix("/") ? putBackDirectoryPath : "/\(putBackDirectoryPath)"
	}

	/**
	Directory a trashed item came from, from the Put Back location (`ptbL`) record.

	Relative to the volume root, exactly as macOS stores it: no leading slash on the boot volume, one on other volumes.
	*/
	var putBackDirectoryPath: String? {
		guard type == .trashPutBackLocation else {
			return nil
		}

		return switch value {
		case .string(let string):
			string
		case .data(let data):
			String(data: data, encoding: .utf8)
		default:
			nil
		}
	}

	/**
	Name a trashed item had before it went to the Trash, from the Put Back name (`ptbN`) record.

	It differs from the name in the Trash when Finder renamed the item to prevent a collision.
	*/
	var putBackName: String? {
		guard
			type == .trashPutBackName,
			case .string(let name) = value
		else {
			return nil
		}

		return name
	}
}
