import Foundation

extension DSStore {
	/**
	A known record type in a DS_Store file.
	*/
	public enum RecordType: Hashable, Sendable, CustomStringConvertible {
		/**
		Background of the Finder window (12-byte blob).

		Raw type: `BKGD`.
		*/
		case background

		/**
		Icon view options flag (bool).

		Raw type: `ICVO`.
		*/
		case iconViewOptionsFlag

		/**
		File icon location (16-byte blob with x, y coordinates).

		Raw type: `Iloc`.
		*/
		case iconLocation

		/**
		List view options flag (bool).

		Raw type: `LSVO`.
		*/
		case listViewOptionsFlag

		/**
		Browser window settings (binary plist).

		Raw type: `bwsp`.
		*/
		case browserWindowSettings

		/**
		Text clipping.

		Raw type: `clip`.
		*/
		case textClipping

		/**
		Spotlight comments (ustr).

		Raw type: `cmmt`.
		*/
		case spotlightComment

		/**
		Desktop icon location (32-byte blob).

		Raw type: `dilc`.
		*/
		case desktopIconLocation

		/**
		Subdirectory is disclosed/open in list view (bool).

		Raw type: `dscl`.
		*/
		case subdirectoryDisclosed

		/**
		File extension information (ustr).

		Raw type: `extn`.
		*/
		case extensionHidden

		/**
		Finder window information (16-byte blob with rect and view type).

		Raw type: `fwi0`.
		*/
		case finderWindowInfo

		/**
		Finder window sidebar width in pixels (long).

		Raw type: `fwsw`.
		*/
		case finderWindowSidebarWidth

		/**
		Finder window vertical height (shor).

		Raw type: `fwvh`.
		*/
		case finderWindowVerticalHeight

		/**
		Gallery view properties (binary plist).

		Raw type: `glvp`.
		*/
		case galleryViewProperties

		/**
		Group (ustr).

		Raw type: `GRP0`.
		*/
		case group

		/**
		Icon view grid offset (8-byte blob).

		Raw type: `icgo`.
		*/
		case iconViewGridOffset

		/**
		Icon view scroll position (8-byte blob).

		Raw type: `icsp`.
		*/
		case iconViewScrollPosition

		/**
		Icon view options (18-26 byte blob).

		Raw type: `icvo`.
		*/
		case iconViewOptions

		/**
		Icon view properties (binary plist).

		Raw type: `icvp`.
		*/
		case iconViewProperties

		/**
		Icon view text label size in points (shor).

		Raw type: `icvt`.
		*/
		case iconViewTextSize

		/**
		Info (40-48 byte blob).

		Raw type: `info`.
		*/
		case info

		/**
		Logical size of directory contents in bytes (comp).

		Raw type: `lg1S`.
		*/
		case logicalSize

		/**
		Logical size of directory contents in bytes (comp, legacy format).

		Raw type: `logS`.
		*/
		case logicalSizeLegacy

		/**
		List view scroll position (8-byte blob).

		Raw type: `lssp`.
		*/
		case listViewScrollPosition

		/**
		List view options (76-byte blob).

		Raw type: `lsvo`.
		*/
		case listViewOptions

		/**
		List view columns (binary plist).

		Raw type: `lsvC`.
		*/
		case listViewColumns

		/**
		List view properties (binary plist).

		Raw type: `lsvp`.
		*/
		case listViewProperties

		/**
		List view properties variant (binary plist).

		Raw type: `lsvP`.
		*/
		case listViewPropertiesAlternate

		/**
		List view text size in points (shor).

		Raw type: `lsvt`.
		*/
		case listViewTextSize

		/**
		Modification date (dutc).

		Raw type: `modD`.
		*/
		case modificationDate

		/**
		Modification date variant (dutc).

		Raw type: `moDD`.
		*/
		case modificationDateAlternate

		/**
		Physical size in bytes (comp).

		Raw type: `phyS`.
		*/
		case physicalSize

		/**
		Physical size in bytes (comp).

		Raw type: `ph1S`.
		*/
		case physicalSizeLegacy

		/**
		Background picture alias (variable blob).

		Raw type: `pict`.
		*/
		case backgroundPicture

		/**
		Trash put back location (blob).

		Raw type: `ptbL`.
		*/
		case trashPutBackLocation

		/**
		Trash put back name (ustr).

		Raw type: `ptbN`.
		*/
		case trashPutBackName

		/**
		View sort (long).

		Raw type: `vSrn`.
		*/
		case viewSortVersion

		/**
		View style (FourCC).

		Raw type: `vstl`.
		*/
		case viewStyle

		/**
		Custom record type not covered by known cases.

		Raw type: user-supplied FourCC.
		*/
		case custom(FourCC)

		/**
		Creates a known record type from a FourCC code.
		Unknown codes map to `.custom`.
		*/
		public init(fourCC: FourCC) {
			self = switch fourCC {
			case FourCC.literal("BKGD"):
				.background
			case FourCC.literal("ICVO"):
				.iconViewOptionsFlag
			case FourCC.literal("Iloc"):
				.iconLocation
			case FourCC.literal("LSVO"):
				.listViewOptionsFlag
			case FourCC.literal("bwsp"):
				.browserWindowSettings
			case FourCC.literal("clip"):
				.textClipping
			case FourCC.literal("cmmt"):
				.spotlightComment
			case FourCC.literal("dilc"):
				.desktopIconLocation
			case FourCC.literal("dscl"):
				.subdirectoryDisclosed
			case FourCC.literal("extn"):
				.extensionHidden
			case FourCC.literal("fwi0"):
				.finderWindowInfo
			case FourCC.literal("fwsw"):
				.finderWindowSidebarWidth
			case FourCC.literal("fwvh"):
				.finderWindowVerticalHeight
			case FourCC.literal("glvp"):
				.galleryViewProperties
			case FourCC.literal("GRP0"):
				.group
			case FourCC.literal("icgo"):
				.iconViewGridOffset
			case FourCC.literal("icsp"):
				.iconViewScrollPosition
			case FourCC.literal("icvo"):
				.iconViewOptions
			case FourCC.literal("icvp"):
				.iconViewProperties
			case FourCC.literal("icvt"):
				.iconViewTextSize
			case FourCC.literal("info"):
				.info
			case FourCC.literal("lg1S"):
				.logicalSize
			case FourCC.literal("logS"):
				.logicalSizeLegacy
			case FourCC.literal("lssp"):
				.listViewScrollPosition
			case FourCC.literal("lsvo"):
				.listViewOptions
			case FourCC.literal("lsvC"):
				.listViewColumns
			case FourCC.literal("lsvp"):
				.listViewProperties
			case FourCC.literal("lsvP"):
				.listViewPropertiesAlternate
			case FourCC.literal("lsvt"):
				.listViewTextSize
			case FourCC.literal("modD"):
				.modificationDate
			case FourCC.literal("moDD"):
				.modificationDateAlternate
			case FourCC.literal("ph1S"):
				.physicalSizeLegacy
			case FourCC.literal("phyS"):
				.physicalSize
			case FourCC.literal("pict"):
				.backgroundPicture
			case FourCC.literal("ptbL"):
				.trashPutBackLocation
			case FourCC.literal("ptbN"):
				.trashPutBackName
			case FourCC.literal("vSrn"):
				.viewSortVersion
			case FourCC.literal("vstl"):
				.viewStyle
			default:
				.custom(fourCC)
			}
		}

		/**
		Underlying FourCC value for this record type.
		*/
		public var fourCC: FourCC {
			switch self {
			case .background:
				FourCC.literal("BKGD")
			case .iconViewOptionsFlag:
				FourCC.literal("ICVO")
			case .iconLocation:
				FourCC.literal("Iloc")
			case .listViewOptionsFlag:
				FourCC.literal("LSVO")
			case .browserWindowSettings:
				FourCC.literal("bwsp")
			case .textClipping:
				FourCC.literal("clip")
			case .spotlightComment:
				FourCC.literal("cmmt")
			case .desktopIconLocation:
				FourCC.literal("dilc")
			case .subdirectoryDisclosed:
				FourCC.literal("dscl")
			case .extensionHidden:
				FourCC.literal("extn")
			case .finderWindowInfo:
				FourCC.literal("fwi0")
			case .finderWindowSidebarWidth:
				FourCC.literal("fwsw")
			case .finderWindowVerticalHeight:
				FourCC.literal("fwvh")
			case .galleryViewProperties:
				FourCC.literal("glvp")
			case .group:
				FourCC.literal("GRP0")
			case .iconViewGridOffset:
				FourCC.literal("icgo")
			case .iconViewScrollPosition:
				FourCC.literal("icsp")
			case .iconViewOptions:
				FourCC.literal("icvo")
			case .iconViewProperties:
				FourCC.literal("icvp")
			case .iconViewTextSize:
				FourCC.literal("icvt")
			case .info:
				FourCC.literal("info")
			case .logicalSize:
				FourCC.literal("lg1S")
			case .logicalSizeLegacy:
				FourCC.literal("logS")
			case .listViewScrollPosition:
				FourCC.literal("lssp")
			case .listViewOptions:
				FourCC.literal("lsvo")
			case .listViewColumns:
				FourCC.literal("lsvC")
			case .listViewProperties:
				FourCC.literal("lsvp")
			case .listViewPropertiesAlternate:
				FourCC.literal("lsvP")
			case .listViewTextSize:
				FourCC.literal("lsvt")
			case .modificationDate:
				FourCC.literal("modD")
			case .modificationDateAlternate:
				FourCC.literal("moDD")
			case .physicalSize:
				FourCC.literal("phyS")
			case .physicalSizeLegacy:
				FourCC.literal("ph1S")
			case .backgroundPicture:
				FourCC.literal("pict")
			case .trashPutBackLocation:
				FourCC.literal("ptbL")
			case .trashPutBackName:
				FourCC.literal("ptbN")
			case .viewSortVersion:
				FourCC.literal("vSrn")
			case .viewStyle:
				FourCC.literal("vstl")
			case .custom(let fourCC):
				fourCC
			}
		}

		/**
		User-facing display name.
		*/
		public var displayName: String {
			switch self {
			case .background:
				"Background"
			case .iconViewOptionsFlag:
				"Icon View Options Flag"
			case .iconLocation:
				"Icon Location"
			case .listViewOptionsFlag:
				"List View Options Flag"
			case .browserWindowSettings:
				"Browser Window Settings"
			case .textClipping:
				"Text Clipping"
			case .spotlightComment:
				"Spotlight Comment"
			case .desktopIconLocation:
				"Desktop Icon Location"
			case .subdirectoryDisclosed:
				"Subdirectory Disclosed"
			case .extensionHidden:
				"Extension Hidden"
			case .finderWindowInfo:
				"Finder Window Info"
			case .finderWindowSidebarWidth:
				"Finder Window Sidebar Width"
			case .finderWindowVerticalHeight:
				"Finder Window Vertical Height"
			case .galleryViewProperties:
				"Gallery View Properties"
			case .group:
				"Group"
			case .iconViewGridOffset:
				"Icon View Grid Offset"
			case .iconViewScrollPosition:
				"Icon View Scroll Position"
			case .iconViewOptions:
				"Icon View Options"
			case .iconViewProperties:
				"Icon View Properties"
			case .iconViewTextSize:
				"Icon View Text Size"
			case .info:
				"Info"
			case .logicalSize:
				"Logical Size"
			case .logicalSizeLegacy:
				"Logical Size (Legacy)"
			case .listViewScrollPosition:
				"List View Scroll Position"
			case .listViewOptions:
				"List View Options"
			case .listViewColumns:
				"List View Columns"
			case .listViewProperties:
				"List View Properties"
			case .listViewPropertiesAlternate:
				"List View Properties (Alternate)"
			case .listViewTextSize:
				"List View Text Size"
			case .modificationDate:
				"Modification Date"
			case .modificationDateAlternate:
				"Modification Date (Alternate)"
			case .physicalSize:
				"Physical Size"
			case .physicalSizeLegacy:
				"Physical Size (Legacy)"
			case .backgroundPicture:
				"Background Picture"
			case .trashPutBackLocation:
				"Trash Put Back Location"
			case .trashPutBackName:
				"Trash Put Back Name"
			case .viewSortVersion:
				"View Sort Version"
			case .viewStyle:
				"View Style"
			case .custom(let fourCC):
				fourCC.stringValue
			}
		}

		/**
		Whether this record type encodes a file size.
		*/
		public var isSizeRecord: Bool {
			switch self {
			case .logicalSize, .logicalSizeLegacy, .physicalSize, .physicalSizeLegacy:
				true
			default:
				false
			}
		}

		/**
		Whether this size record type is the legacy variant.
		*/
		public var isLegacySizeRecord: Bool {
			switch self {
			case .logicalSizeLegacy, .physicalSizeLegacy:
				true
			default:
				false
			}
		}

		/**
		String representation of the record type code.
		*/
		public var description: String {
			fourCC.stringValue
		}

		/**
		Compares record types by their underlying FourCC.
		*/
		public static func == (lhs: Self, rhs: Self) -> Bool {
			lhs.fourCC.rawValue == rhs.fourCC.rawValue
		}

		/**
		Hashes the underlying FourCC.
		*/
		public func hash(into hasher: inout Hasher) {
			hasher.combine(fourCC.rawValue)
		}
	}
}

// MARK: - Value Type Codes

extension DSStore.FourCC {
	/**
	Null value (no data payload).
	*/
	public static let null = Self(0)

	/**
	Boolean value.
	*/
	public static let bool = literal("bool")

	/**
	32-bit unsigned integer.
	*/
	public static let long = literal("long")

	/**
	16-bit unsigned integer stored in a 32-bit slot.
	*/
	public static let shor = literal("shor")

	/**
	64-bit unsigned integer.
	*/
	public static let comp = literal("comp")

	/**
	Date/time value.
	*/
	public static let dutc = literal("dutc")

	/**
	FourCC value.
	*/
	public static let type = literal("type")

	/**
	UTF-16 string.
	*/
	public static let ustr = literal("ustr")

	/**
	Binary blob.
	*/
	public static let blob = literal("blob")

	/**
	Bookmark data.
	*/
	public static let book = literal("book")
}

// MARK: - View Style Codes

extension DSStore.FourCC {
	/**
	Icon view.
	*/
	public static let iconView = literal("icnv")

	/**
	Column view.
	*/
	public static let columnView = literal("clmv")

	/**
	List view.
	*/
	public static let listView = literal("Nlsv")

	/**
	Gallery view.
	*/
	public static let galleryView = literal("Flwv")
}
