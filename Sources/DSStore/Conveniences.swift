import Foundation

extension DSStore {
	/**
	Finder view style values stored in the `vstl` record.
	*/
	public enum ViewStyle: String, CaseIterable, Sendable {
		case icon
		case list
		case column
		case gallery

		/**
		Creates a view style from a Finder view-style FourCC.
		*/
		public init?(fourCC: FourCC) {
			switch fourCC {
			case .iconView:
				self = .icon
			case .listView:
				self = .list
			case .columnView:
				self = .column
			case .galleryView:
				self = .gallery
			default:
				return nil
			}
		}

		/**
		Finder FourCC for this view style.
		*/
		public var fourCC: FourCC {
			switch self {
			case .icon:
				.iconView
			case .list:
				.listView
			case .column:
				.columnView
			case .gallery:
				.galleryView
			}
		}

		/**
		User-facing display name.
		*/
		public var displayName: String {
			switch self {
			case .icon:
				"Icon view"
			case .list:
				"List view"
			case .column:
				"Column view"
			case .gallery:
				"Gallery view"
			}
		}
	}

	/**
	Finder sort styles stored in the `vSrn` record.
	*/
	public enum ViewSort: String, CaseIterable, Sendable {
		case none // swiftlint:disable:this discouraged_none_name
		case name
		case kind
		case dateModified
		case dateCreated
		case size
		case label

		/**
		Creates a sort style from a Finder sort FourCC.
		*/
		public init?(fourCC: FourCC) {
			switch fourCC {
			case FourCC.literal("none"):
				self = .none
			case FourCC.literal("name"):
				self = .name
			case FourCC.literal("kind"):
				self = .kind
			case FourCC.literal("modd"):
				self = .dateModified
			case FourCC.literal("crea"):
				self = .dateCreated
			case FourCC.literal("size"):
				self = .size
			case FourCC.literal("labl"):
				self = .label
			default:
				return nil
			}
		}

		/**
		User-facing display name.
		*/
		public var displayName: String {
			switch self {
			case .none:
				"None"
			case .name:
				"Name"
			case .kind:
				"Kind"
			case .dateModified:
				"Date Modified"
			case .dateCreated:
				"Date Created"
			case .size:
				"Size"
			case .label:
				"Label"
			}
		}

		/**
		Finder FourCC for this sort style.
		*/
		public var fourCC: FourCC {
			switch self {
			case .none:
				FourCC.literal("none")
			case .name:
				FourCC.literal("name")
			case .kind:
				FourCC.literal("kind")
			case .dateModified:
				FourCC.literal("modd")
			case .dateCreated:
				FourCC.literal("crea")
			case .size:
				FourCC.literal("size")
			case .label:
				FourCC.literal("labl")
			}
		}
	}

	/**
	Window bounds stored in the `fwi0` record.
	*/
	public struct WindowBounds: Hashable, Sendable {
		/**
		Top edge of the window frame.
		*/
		public var top: Int

		/**
		Left edge of the window frame.
		*/
		public var left: Int

		/**
		Bottom edge of the window frame.
		*/
		public var bottom: Int

		/**
		Right edge of the window frame.
		*/
		public var right: Int

		/**
		Optional Finder view style code associated with the bounds.
		*/
		public var viewStyle: FourCC?

		/**
		Computed window width.
		*/
		public var width: Int {
			right - left
		}

		/**
		Computed window height.
		*/
		public var height: Int {
			bottom - top
		}

		/**
		Creates window bounds.
		*/
		public init(top: Int, left: Int, bottom: Int, right: Int, viewStyle: FourCC? = nil) {
			self.top = top
			self.left = left
			self.bottom = bottom
			self.right = right
			self.viewStyle = viewStyle
		}
	}

	/**
	Finder window settings stored in the `bwsp` record.
	*/
	// swiftlint:disable discouraged_optional_boolean
	public struct WindowSettings: Hashable, Sendable {
		/**
		Window frame stored in `WindowBounds`, using the AppKit string format.
		*/
		public struct WindowFrame: Hashable, Sendable {
			private static let posixLocale = Locale(identifier: "en_US_POSIX")
			private static let numberCharacters = CharacterSet(charactersIn: "{}, ")

			/**
			Window origin X.
			*/
			public var originX: Double

			/**
			Window origin Y.
			*/
			public var originY: Double

			/**
			Window width.
			*/
			public var width: Double

			/**
			Window height.
			*/
			public var height: Double

			/**
			Creates a window frame value.
			*/
			public init(originX: Double, originY: Double, width: Double, height: Double) {
				self.originX = originX
				self.originY = originY
				self.width = width
				self.height = height
			}

			/**
			Parses the AppKit-style frame string.
			*/
			public init?(string: String) {
				let numbers = Self.parseNumbers(from: string)
				guard numbers.count == 4 else {
					return nil
				}
				self.originX = numbers[0]
				self.originY = numbers[1]
				self.width = numbers[2]
				self.height = numbers[3]
			}

			/**
			AppKit-style frame string representation.
			*/
			public var stringValue: String {
				"{{\(Self.format(originX)), \(Self.format(originY))}, {\(Self.format(width)), \(Self.format(height))}}"
			}

			private static func parseNumbers(from string: String) -> [Double] {
				let scanner = Scanner(string: string)
				scanner.charactersToBeSkipped = numberCharacters
				scanner.locale = posixLocale

				var numbers = [Double]()
				while !scanner.isAtEnd {
					if let number = scanner.scanDouble() {
						numbers.append(number)
					} else {
						scanner.currentIndex = scanner.string.index(after: scanner.currentIndex)
					}
				}
				return numbers
			}

			private static func format(_ value: Double) -> String {
				String(format: "%.15g", locale: posixLocale, value)
			}
		}

		/**
		AppKit `WindowBounds` string.
		*/
		public var windowBounds: String?

		/**
		Sidebar width.
		*/
		public var sidebarWidth: Double?

		/**
		Whether Finder shows the sidebar.
		*/
		public var showSidebar: Bool?

		/**
		Whether Finder shows the toolbar.
		*/
		public var showToolbar: Bool?

		/**
		Whether Finder shows the status bar.
		*/
		public var showStatusBar: Bool?

		/**
		Whether Finder shows the path bar.
		*/
		public var showPathBar: Bool?

		/**
		View style string stored by Finder.
		*/
		public var viewStyle: String?

		/**
		Target URL string.
		*/
		public var targetURL: String?

		/**
		Target path components.
		*/
		public var targetPath: [String] = []

		/**
		Creates window settings.
		*/
		public init(
			windowBounds: String? = nil,
			sidebarWidth: Double? = nil,
			showSidebar: Bool? = nil,
			showToolbar: Bool? = nil,
			showStatusBar: Bool? = nil,
			showPathBar: Bool? = nil,
			viewStyle: String? = nil,
			targetURL: String? = nil,
			targetPath: [String] = []
		) {
			self.windowBounds = windowBounds
			self.sidebarWidth = sidebarWidth
			self.showSidebar = showSidebar
			self.showToolbar = showToolbar
			self.showStatusBar = showStatusBar
			self.showPathBar = showPathBar
			self.viewStyle = viewStyle
			self.targetURL = targetURL
			self.targetPath = targetPath
		}

		/**
		Creates window settings from plist-backed values.
		*/
		public init?(plistValue: PlistValue) {
			guard case .dictionary(let dictionary) = plistValue else {
				return nil
			}

			self.windowBounds = dictionary["WindowBounds"]?.stringValue
			self.sidebarWidth = dictionary["SidebarWidth"]?.doubleValue
			self.showSidebar = dictionary["ShowSidebar"]?.booleanValue
			self.showToolbar = dictionary["ShowToolbar"]?.booleanValue
			self.showStatusBar = dictionary["ShowStatusBar"]?.booleanValue
			self.showPathBar = dictionary["ShowPathbar"]?.booleanValue
			self.viewStyle = dictionary["ViewStyle"]?.stringValue
			self.targetURL = dictionary["TargetURL"]?.stringValue
			self.targetPath = dictionary["TargetPath"]?.stringArrayValue ?? []
		}

		/**
		Plist representation for the `bwsp` record.
		*/
		public var plistValue: PlistValue {
			var dictionary = [String: PlistValue]()

			if let windowBounds {
				dictionary["WindowBounds"] = .string(windowBounds)
			}
			if let sidebarWidth {
				dictionary["SidebarWidth"] = .double(sidebarWidth)
			}
			if let showSidebar {
				dictionary["ShowSidebar"] = .bool(showSidebar)
			}
			if let showToolbar {
				dictionary["ShowToolbar"] = .bool(showToolbar)
			}
			if let showStatusBar {
				dictionary["ShowStatusBar"] = .bool(showStatusBar)
			}
			if let showPathBar {
				dictionary["ShowPathbar"] = .bool(showPathBar)
			}
			if let viewStyle {
				dictionary["ViewStyle"] = .string(viewStyle)
			}
			if let targetURL {
				dictionary["TargetURL"] = .string(targetURL)
			}
			if !targetPath.isEmpty {
				dictionary["TargetPath"] = .array(targetPath.map { .string($0) })
			}

			return .dictionary(dictionary)
		}

		/**
		Typed window frame helper for `windowBounds`.
		*/
		public var windowBoundsValue: WindowFrame? {
			get {
				guard let windowBounds else {
					return nil
				}

				return WindowFrame(string: windowBounds)
			}
			set {
				windowBounds = newValue?.stringValue
			}
		}
	}
	// swiftlint:enable discouraged_optional_boolean

	/**
	Icon view settings stored in the `icvp` record.
	*/
	// swiftlint:disable discouraged_optional_boolean
	public struct IconViewSettings: Hashable, Sendable {
		/**
		Whether Finder shows icon previews.
		*/
		public var showIconPreview: Bool?

		/**
		Whether Finder shows item info text.
		*/
		public var showItemInfo: Bool?

		/**
		Whether labels are placed below icons.
		*/
		public var labelOnBottom: Bool?

		/**
		Horizontal scroll position.
		*/
		public var scrollPositionX: Double?

		/**
		Vertical scroll position.
		*/
		public var scrollPositionY: Double?

		/**
		Horizontal grid offset.
		*/
		public var gridOffsetX: Double?

		/**
		Vertical grid offset.
		*/
		public var gridOffsetY: Double?

		/**
		Icon label text size.
		*/
		public var textSize: Int?

		/**
		Icon size.
		*/
		public var iconSize: Int?

		/**
		Grid spacing.
		*/
		public var gridSpacing: Double?

		/**
		Finder icon view options schema version.
		*/
		public var viewOptionsVersion: Int?

		/**
		Arrangement key (for example, `name`).
		*/
		public var arrangeBy: String?

		/**
		Background mode identifier.
		*/
		public var backgroundType: Int?

		/**
		Background color red channel.
		*/
		public var backgroundColorRed: Double?

		/**
		Background color green channel.
		*/
		public var backgroundColorGreen: Double?

		/**
		Background color blue channel.
		*/
		public var backgroundColorBlue: Double?

		/**
		Creates icon view settings.
		*/
		public init(
			showIconPreview: Bool? = nil,
			showItemInfo: Bool? = nil,
			labelOnBottom: Bool? = nil,
			scrollPositionX: Double? = nil,
			scrollPositionY: Double? = nil,
			gridOffsetX: Double? = nil,
			gridOffsetY: Double? = nil,
			textSize: Int? = nil,
			iconSize: Int? = nil,
			gridSpacing: Double? = nil,
			viewOptionsVersion: Int? = nil,
			arrangeBy: String? = nil,
			backgroundType: Int? = nil,
			backgroundColorRed: Double? = nil,
			backgroundColorGreen: Double? = nil,
			backgroundColorBlue: Double? = nil
		) {
			self.showIconPreview = showIconPreview
			self.showItemInfo = showItemInfo
			self.labelOnBottom = labelOnBottom
			self.scrollPositionX = scrollPositionX
			self.scrollPositionY = scrollPositionY
			self.gridOffsetX = gridOffsetX
			self.gridOffsetY = gridOffsetY
			self.textSize = textSize
			self.iconSize = iconSize
			self.gridSpacing = gridSpacing
			self.viewOptionsVersion = viewOptionsVersion
			self.arrangeBy = arrangeBy
			self.backgroundType = backgroundType
			self.backgroundColorRed = backgroundColorRed
			self.backgroundColorGreen = backgroundColorGreen
			self.backgroundColorBlue = backgroundColorBlue
		}

		/**
		Creates icon view settings from plist-backed values.
		*/
		public init?(plistValue: PlistValue) {
			guard case .dictionary(let dictionary) = plistValue else {
				return nil
			}

			self.showIconPreview = dictionary["showIconPreview"]?.booleanValue
			self.showItemInfo = dictionary["showItemInfo"]?.booleanValue
			self.labelOnBottom = dictionary["labelOnBottom"]?.booleanValue
			self.scrollPositionX = dictionary["scrollPositionX"]?.doubleValue
			self.scrollPositionY = dictionary["scrollPositionY"]?.doubleValue
			self.gridOffsetX = dictionary["gridOffsetX"]?.doubleValue
			self.gridOffsetY = dictionary["gridOffsetY"]?.doubleValue
			self.textSize = dictionary["textSize"]?.intValue
			self.iconSize = dictionary["iconSize"]?.intValue
			self.gridSpacing = dictionary["gridSpacing"]?.doubleValue
			self.viewOptionsVersion = dictionary["viewOptionsVersion"]?.intValue
			self.arrangeBy = dictionary["arrangeBy"]?.stringValue
			self.backgroundType = dictionary["backgroundType"]?.intValue
			self.backgroundColorRed = dictionary["backgroundColorRed"]?.doubleValue
			self.backgroundColorGreen = dictionary["backgroundColorGreen"]?.doubleValue
			self.backgroundColorBlue = dictionary["backgroundColorBlue"]?.doubleValue
		}

		/**
		Plist representation for the `icvp` record.
		*/
		public var plistValue: PlistValue {
			var dictionary = [String: PlistValue]()

			if let showIconPreview {
				dictionary["showIconPreview"] = .bool(showIconPreview)
			}

			if let showItemInfo {
				dictionary["showItemInfo"] = .bool(showItemInfo)
			}

			if let labelOnBottom {
				dictionary["labelOnBottom"] = .bool(labelOnBottom)
			}

			if let scrollPositionX {
				dictionary["scrollPositionX"] = .double(scrollPositionX)
			}

			if let scrollPositionY {
				dictionary["scrollPositionY"] = .double(scrollPositionY)
			}

			if let gridOffsetX {
				dictionary["gridOffsetX"] = .double(gridOffsetX)
			}

			if let gridOffsetY {
				dictionary["gridOffsetY"] = .double(gridOffsetY)
			}

			if let textSize {
				dictionary["textSize"] = .int(textSize)
			}

			if let iconSize {
				dictionary["iconSize"] = .int(iconSize)
			}

			if let gridSpacing {
				dictionary["gridSpacing"] = .double(gridSpacing)
			}

			if let viewOptionsVersion {
				dictionary["viewOptionsVersion"] = .int(viewOptionsVersion)
			}

			if let arrangeBy {
				dictionary["arrangeBy"] = .string(arrangeBy)
			}

			if let backgroundType {
				dictionary["backgroundType"] = .int(backgroundType)
			}

			if let backgroundColorRed {
				dictionary["backgroundColorRed"] = .double(backgroundColorRed)
			}

			if let backgroundColorGreen {
				dictionary["backgroundColorGreen"] = .double(backgroundColorGreen)
			}

			if let backgroundColorBlue {
				dictionary["backgroundColorBlue"] = .double(backgroundColorBlue)
			}

			return .dictionary(dictionary)
		}
	}
	// swiftlint:enable discouraged_optional_boolean

	/**
	List view settings stored in the `lsvp` record.
	*/
	// swiftlint:disable discouraged_optional_boolean
	public struct ListViewSettings: Hashable, Sendable {
		/**
		Whether Finder shows icon previews.
		*/
		public var showIconPreview: Bool?

		/**
		Whether dates are shown in relative format.
		*/
		public var useRelativeDates: Bool?

		/**
		Whether Finder calculates all item sizes.
		*/
		public var calculateAllSizes: Bool?

		/**
		Horizontal scroll position.
		*/
		public var scrollPositionX: Double?

		/**
		Vertical scroll position.
		*/
		public var scrollPositionY: Double?

		/**
		List text size.
		*/
		public var textSize: Int?

		/**
		List icon size.
		*/
		public var iconSize: Int?

		/**
		Finder list view options schema version.
		*/
		public var viewOptionsVersion: Int?

		/**
		Sort column identifier.
		*/
		public var sortColumn: String?

		/**
		Column configuration payload.
		*/
		public var columns: PlistValue?

		/**
		Creates list view settings.
		*/
		public init(
			showIconPreview: Bool? = nil,
			useRelativeDates: Bool? = nil,
			calculateAllSizes: Bool? = nil,
			scrollPositionX: Double? = nil,
			scrollPositionY: Double? = nil,
			textSize: Int? = nil,
			iconSize: Int? = nil,
			viewOptionsVersion: Int? = nil,
			sortColumn: String? = nil,
			columns: PlistValue? = nil
		) {
			self.showIconPreview = showIconPreview
			self.useRelativeDates = useRelativeDates
			self.calculateAllSizes = calculateAllSizes
			self.scrollPositionX = scrollPositionX
			self.scrollPositionY = scrollPositionY
			self.textSize = textSize
			self.iconSize = iconSize
			self.viewOptionsVersion = viewOptionsVersion
			self.sortColumn = sortColumn
			self.columns = columns
		}

		/**
		Creates list view settings from plist-backed values.
		*/
		public init?(plistValue: PlistValue) {
			guard case .dictionary(let dictionary) = plistValue else {
				return nil
			}

			self.showIconPreview = dictionary["showIconPreview"]?.booleanValue
			self.useRelativeDates = dictionary["useRelativeDates"]?.booleanValue
			self.calculateAllSizes = dictionary["calculateAllSizes"]?.booleanValue
			self.scrollPositionX = dictionary["scrollPositionX"]?.doubleValue
			self.scrollPositionY = dictionary["scrollPositionY"]?.doubleValue
			self.textSize = dictionary["textSize"]?.intValue
			self.iconSize = dictionary["iconSize"]?.intValue
			self.viewOptionsVersion = dictionary["viewOptionsVersion"]?.intValue
			self.sortColumn = dictionary["sortColumn"]?.stringValue
			self.columns = dictionary["columns"]
		}

		/**
		Plist representation for the `lsvp` or `lsvP` record.
		*/
		public var plistValue: PlistValue {
			var dictionary = [String: PlistValue]()

			if let showIconPreview {
				dictionary["showIconPreview"] = .bool(showIconPreview)
			}

			if let useRelativeDates {
				dictionary["useRelativeDates"] = .bool(useRelativeDates)
			}

			if let calculateAllSizes {
				dictionary["calculateAllSizes"] = .bool(calculateAllSizes)
			}

			if let scrollPositionX {
				dictionary["scrollPositionX"] = .double(scrollPositionX)
			}

			if let scrollPositionY {
				dictionary["scrollPositionY"] = .double(scrollPositionY)
			}

			if let textSize {
				dictionary["textSize"] = .int(textSize)
			}

			if let iconSize {
				dictionary["iconSize"] = .int(iconSize)
			}

			if let viewOptionsVersion {
				dictionary["viewOptionsVersion"] = .int(viewOptionsVersion)
			}

			if let sortColumn {
				dictionary["sortColumn"] = .string(sortColumn)
			}

			if let columns {
				dictionary["columns"] = columns
			}

			return .dictionary(dictionary)
		}
	}

	// swiftlint:enable discouraged_optional_boolean

	/**
	A single icon placement with absolute coordinates.
	*/
	public struct IconPlacement: Hashable, Sendable {
		/**
		Filename for the icon placement.
		*/
		public let filename: String

		/**
		Horizontal icon position.
		*/
		public let x: Int

		/**
		Vertical icon position.
		*/
		public let y: Int

		/**
		Creates an icon placement.
		*/
		public init(filename: String, x: Int, y: Int) {
			self.filename = filename
			self.x = x
			self.y = y
		}
	}
}

extension DSStore {
	// MARK: - Convenience Methods

	/**
	Get all unique filenames in the store.
	*/
	public var filenames: Set<String> {
		Set(records.map(\.filename))
	}

	/**
	Get all records for a specific filename.
	*/
	public func records(for filename: String) -> [Record] {
		records.filter { $0.filename == filename }
	}

	/**
	Get a specific record by filename and type.
	*/
	public func record(for filename: String, type: RecordType) -> Record? {
		records.first { $0.filename == filename && $0.type == type }
	}

	/**
	Add a record to the store.
	If a record with the same filename and type exists, it is replaced.
	*/
	public mutating func add(_ record: Record) {
		// Remove existing record with same filename and type.
		records.removeAll { $0.filename == record.filename && $0.type == record.type }
		records.append(record)
	}

	/**
	Remove all records for a filename.
	*/
	public mutating func removeRecords(for filename: String) {
		records.removeAll { $0.filename == filename }
	}

	/**
	Remove a specific record.
	*/
	public mutating func remove(filename: String, type: RecordType) {
		records.removeAll { $0.filename == filename && $0.type == type }
	}

	// MARK: - Record Helpers

	/**
	Returns the Spotlight comment for a filename.
	*/
	public func comment(for filename: String) -> String? {
		guard case .string(let comment) = record(for: filename, type: .spotlightComment)?.value else {
			return nil
		}

		return comment
	}

	/**
	Sets the Spotlight comment for a filename.
	*/
	public mutating func setComment(_ comment: String, for filename: String) {
		add(Record(filename: filename, type: .spotlightComment, value: .string(comment)))
	}

	/**
	Removes the Spotlight comment for a filename.
	*/
	public mutating func removeComment(for filename: String) {
		remove(filename: filename, type: .spotlightComment)
	}

	/**
	Returns the raw Finder view style FourCC for the folder.
	*/
	public func viewStyle() -> FourCC? {
		guard case .fourCC(let style) = record(for: ".", type: .viewStyle)?.value else {
			return nil
		}

		return style
	}

	/**
	Returns the typed Finder view style for the folder.
	*/
	public func viewStyleValue() -> ViewStyle? {
		guard let style = viewStyle() else {
			return nil
		}

		return ViewStyle(fourCC: style)
	}

	/**
	Returns the raw Finder sort style FourCC for the folder.
	*/
	public func viewSort() -> FourCC? {
		guard case .fourCC(let sort) = record(for: ".", type: .viewSortVersion)?.value else {
			return nil
		}

		return sort
	}

	/**
	Returns the typed Finder sort style for the folder.
	*/
	public func viewSortValue() -> ViewSort? {
		guard let sort = viewSort() else {
			return nil
		}

		return ViewSort(fourCC: sort)
	}

	// MARK: - Icon Location Helpers

	/**
	Set icon position for a file.
	*/
	public mutating func setIconPosition(for filename: String, x: Int, y: Int) throws(Error) {
		guard
			let xBigEndianValue = UInt32(exactly: x)?.bigEndian,
			let yBigEndianValue = UInt32(exactly: y)?.bigEndian
		else {
			throw Error.writeFailed("Icon position values are outside the supported range for \(filename)")
		}

		var blobData = Data()
		var xBigEndian = xBigEndianValue
		var yBigEndian = yBigEndianValue
		blobData.append(contentsOf: withUnsafeBytes(of: &xBigEndian) { $0 })
		blobData.append(contentsOf: withUnsafeBytes(of: &yBigEndian) { $0 })

		// Padding: 6 bytes of 0xFF, 2 bytes of 0x00.
		blobData.append(contentsOf: [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00])

		let record = Record(filename: filename, type: .iconLocation, value: .data(blobData))
		add(record)
	}

	/**
	Returns the icon position for a file.
	*/
	public func iconPosition(for filename: String) -> (x: Int, y: Int)? {
		record(for: filename, type: .iconLocation)?.iconPosition
	}

	// MARK: - Background Helpers

	/**
	Background type for a folder.
	*/
	public enum BackgroundType: Hashable, Sendable {
		case `default`
		case color(red: UInt16, green: UInt16, blue: UInt16)
		case picture
	}

	/**
	Set background type for the folder.
	*/
	public mutating func setBackground(_ type: BackgroundType) {
		var blobData = Data()

		switch type {
		case .default:
			blobData.append(contentsOf: Array("DefB".utf8))
			blobData.append(contentsOf: [UInt8](repeating: 0, count: 8))
		case .color(let red, let green, let blue):
			blobData.append(contentsOf: Array("ClrB".utf8))
			var redBigEndian = red.bigEndian
			var greenBigEndian = green.bigEndian
			var blueBigEndian = blue.bigEndian
			blobData.append(contentsOf: withUnsafeBytes(of: &redBigEndian) { $0 })
			blobData.append(contentsOf: withUnsafeBytes(of: &greenBigEndian) { $0 })
			blobData.append(contentsOf: withUnsafeBytes(of: &blueBigEndian) { $0 })
			blobData.append(contentsOf: [0x00, 0x00])
		case .picture:
			blobData.append(contentsOf: Array("PctB".utf8))

			// Length of pict record would go here.
			blobData.append(contentsOf: [UInt8](repeating: 0, count: 8))
		}

		let record = Record(filename: ".", type: .background, value: .data(blobData))
		add(record)
	}

	// MARK: - Window Settings Helpers

	/**
	Set Finder window bounds.
	*/
	public mutating func setWindowBounds(top: Int, left: Int, bottom: Int, right: Int, viewStyle: FourCC = .iconView) throws(Error) {
		guard
			let topBigEndianValue = UInt16(exactly: top)?.bigEndian,
			let leftBigEndianValue = UInt16(exactly: left)?.bigEndian,
			let bottomBigEndianValue = UInt16(exactly: bottom)?.bigEndian,
			let rightBigEndianValue = UInt16(exactly: right)?.bigEndian
		else {
			throw Error.writeFailed("Window bounds values are outside the supported range")
		}

		var blobData = Data()

		// Window rect: top, left, bottom, right (each 2 bytes).
		var topBigEndian = topBigEndianValue
		var leftBigEndian = leftBigEndianValue
		var bottomBigEndian = bottomBigEndianValue
		var rightBigEndian = rightBigEndianValue

		blobData.append(contentsOf: withUnsafeBytes(of: &topBigEndian) { $0 })
		blobData.append(contentsOf: withUnsafeBytes(of: &leftBigEndian) { $0 })
		blobData.append(contentsOf: withUnsafeBytes(of: &bottomBigEndian) { $0 })
		blobData.append(contentsOf: withUnsafeBytes(of: &rightBigEndian) { $0 })

		// View style (4 bytes).
		var viewStyleRaw = viewStyle.rawValue.bigEndian
		blobData.append(contentsOf: withUnsafeBytes(of: &viewStyleRaw) { $0 })

		// Unknown 4 bytes.
		blobData.append(contentsOf: [0x00, 0x00, 0x00, 0x00])

		let record = Record(filename: ".", type: .finderWindowInfo, value: .data(blobData))
		add(record)
	}

	/**
	Set view style for the folder.
	*/
	public mutating func setViewStyle(_ style: FourCC) {
		let record = Record(filename: ".", type: .viewStyle, value: .fourCC(style))
		add(record)
	}

	/**
	Sets the folder view style from a typed value.
	*/
	public mutating func setViewStyle(_ style: ViewStyle) {
		setViewStyle(style.fourCC)
	}

	/**
	Sets the folder sort style.
	*/
	public mutating func setViewSort(_ sort: ViewSort) {
		let record = Record(filename: ".", type: .viewSortVersion, value: .fourCC(sort.fourCC))
		add(record)
	}

	/**
	Read the background settings for the folder.
	*/
	public func background() -> BackgroundType? {
		record(for: ".", type: .background)?.backgroundType
	}

	/**
	Read the background picture alias data if present.
	*/
	public func backgroundPictureAliasData() -> Data? {
		guard
			let record = record(for: ".", type: .backgroundPicture),
			case .data(let data) = record.value
		else {
			return nil
		}

		return data
	}

	/**
	Set a background picture using Finder alias data.
	The caller is responsible for providing valid alias data for the image file.
	*/
	public mutating func setBackgroundPicture(aliasData: Data) throws(Error) {
		guard let aliasLength = UInt32(exactly: aliasData.count) else {
			throw Error.writeFailed("Alias data is too large")
		}

		var blobData = Data()
		blobData.append(contentsOf: Array("PctB".utf8))
		var aliasLengthBigEndian = aliasLength.bigEndian
		blobData.append(contentsOf: withUnsafeBytes(of: &aliasLengthBigEndian) { $0 })
		blobData.append(contentsOf: [UInt8](repeating: 0, count: 4))

		add(Record(filename: ".", type: .background, value: .data(blobData)))
		add(Record(filename: ".", type: .backgroundPicture, value: .data(aliasData)))
	}

	/**
	Read the Finder window bounds for the folder.
	*/
	public func windowBounds() -> WindowBounds? {
		record(for: ".", type: .finderWindowInfo)?.windowBounds
	}

	/**
	Set the Finder window bounds using a value object.
	*/
	public mutating func setWindowBounds(_ bounds: WindowBounds) throws(Error) {
		try setWindowBounds(
			top: bounds.top,
			left: bounds.left,
			bottom: bounds.bottom,
			right: bounds.right,
			viewStyle: bounds.viewStyle ?? .iconView
		)
	}

	/**
	Read browser window settings from the `bwsp` record, if present.
	*/
	public func windowSettings() -> WindowSettings? {
		guard
			let record = record(for: ".", type: .browserWindowSettings),
			case .propertyList(let plistValue) = record.value
		else {
			return nil
		}
		return WindowSettings(plistValue: plistValue)
	}

	/**
	Write browser window settings to the `bwsp` record.
	*/
	public mutating func setWindowSettings(_ settings: WindowSettings) {
		add(Record(filename: ".", type: .browserWindowSettings, value: .propertyList(settings.plistValue)))
	}

	/**
	Read icon view settings from the `icvp` record, if present.
	*/
	public func iconViewSettings() -> IconViewSettings? {
		guard
			let record = record(for: ".", type: .iconViewProperties),
			case .propertyList(let plistValue) = record.value
		else {
			return nil
		}

		return IconViewSettings(plistValue: plistValue)
	}

	/**
	Write icon view settings to the `icvp` record.
	*/
	public mutating func setIconViewSettings(_ settings: IconViewSettings) {
		add(Record(filename: ".", type: .iconViewProperties, value: .propertyList(settings.plistValue)))
	}

	/**
	Read list view settings from the specified list view record, if present.
	*/
	public func listViewSettings(recordType: RecordType = .listViewProperties) -> ListViewSettings? {
		guard
			recordType == .listViewProperties || recordType == .listViewPropertiesAlternate,
			let record = record(for: ".", type: recordType),
			case .propertyList(let plistValue) = record.value
		else {
			return nil
		}
		return ListViewSettings(plistValue: plistValue)
	}

	/**
	Write list view settings to the specified list view record.
	*/
	public mutating func setListViewSettings(_ settings: ListViewSettings, recordType: RecordType = .listViewProperties) {
		guard
			recordType == .listViewProperties || recordType == .listViewPropertiesAlternate
		else {
			return
		}

		add(Record(filename: ".", type: recordType, value: .propertyList(settings.plistValue)))
	}

	/**
	Batch update icon positions.
	*/
	public mutating func setIconPositions(_ placements: [IconPlacement]) throws(Error) {
		for placement in placements {
			try setIconPosition(for: placement.filename, x: placement.x, y: placement.y)
		}
	}

	/**
	Batch update icon positions from a filename map.
	*/
	public mutating func setIconPositions(_ positions: [String: (x: Int, y: Int)]) throws(Error) {
		for (filename, position) in positions {
			try setIconPosition(for: filename, x: position.x, y: position.y)
		}
	}
}

extension DSStore.PlistValue {
	fileprivate var stringValue: String? {
		guard case .string(let value) = self else {
			return nil
		}

		return value
	}

	// swiftlint:disable discouraged_optional_boolean
	fileprivate var booleanValue: Bool? {
		guard case .bool(let value) = self else {
			return nil
		}

		return value
	}
	// swiftlint:enable discouraged_optional_boolean

	fileprivate var intValue: Int? {
		switch self {
		case .int(let value):
			value
		case .double(let value):
			Int(exactly: value)
		default:
			nil
		}
	}

	fileprivate var doubleValue: Double? {
		switch self {
		case .double(let value):
			value
		case .int(let value):
			Double(value)
		default:
			nil
		}
	}

	fileprivate var stringArrayValue: [String] {
		guard case .array(let values) = self else {
			return []
		}

		var result = [String]()
		for value in values {
			guard case .string(let string) = value else {
				return []
			}
			result.append(string)
		}

		return result
	}
}
