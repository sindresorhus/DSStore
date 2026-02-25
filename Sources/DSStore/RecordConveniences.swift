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
	Background type for the directory, when the record is `background`.
	*/
	public var backgroundType: DSStore.BackgroundType? {
		guard
			type == .background,
			case .data(let data) = value,
			data.count >= 4
		else {
			return nil
		}

		let typeString = String(bytes: data.prefix(4), encoding: .ascii)
		switch typeString {
		case "DefB":
			return .default
		case "ClrB":
			guard
				data.count >= 10,
				let red = data.readUInt16BE(at: 4),
				let green = data.readUInt16BE(at: 6),
				let blue = data.readUInt16BE(at: 8)
			else {
				return nil
			}

			return .color(red: red, green: green, blue: blue)
		case "PctB":
			return .picture
		default:
			return nil
		}
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
	*/
	public var pathValue: String? {
		guard type == .trashPutBackLocation else {
			return nil
		}

		let path: String? = switch value {
		case .string(let string):
			string
		case .data(let data):
			String(data: data, encoding: .utf8)
		default:
			nil
		}

		guard let path else {
			return nil
		}

		return path.hasPrefix("/") ? path : "/\(path)"
	}
}
