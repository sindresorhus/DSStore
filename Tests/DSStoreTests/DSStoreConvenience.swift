import Foundation
import Testing
@testable import DSStore

private typealias FourCC = DSStore.FourCC
private typealias PlistValue = DSStore.PlistValue

@Suite("DSStore Convenience Methods")
struct DSStoreConvenienceTests {
	@Test("Set and get icon position")
	func setGetIconPosition() throws {
		var store = DSStore()

		try store.setIconPosition(for: "App.app", x: 140, y: 180)

		let position = store.iconPosition(for: "App.app")
		#expect(position?.x == 140)
		#expect(position?.y == 180)
	}

	@Test("Icon position returns nil for missing file")
	func iconPositionMissing() {
		let store = DSStore()
		#expect(store.iconPosition(for: "nonexistent.txt") == nil)
	}

	@Test("Update icon position")
	func updateIconPosition() throws {
		var store = DSStore()

		try store.setIconPosition(for: "file.txt", x: 100, y: 200)
		try store.setIconPosition(for: "file.txt", x: 300, y: 400)

		let position = store.iconPosition(for: "file.txt")
		#expect(position?.x == 300)
		#expect(position?.y == 400)

		// Should only have one Iloc record
		let ilocRecords = store.records.filter { $0.type == .iconLocation }
		#expect(ilocRecords.count == 1)
	}

	@Test("Reject invalid icon positions")
	func rejectInvalidIconPosition() throws {
		var store = DSStore()

		#expect(throws: DSStore.Error.self) {
			try store.setIconPosition(for: "file.txt", x: -1, y: 200)
		}
		#expect(store.record(for: "file.txt", type: .iconLocation) == nil)

		try store.setIconPosition(for: "file.txt", x: 100, y: 200)
		#expect(throws: DSStore.Error.self) {
			try store.setIconPosition(for: "file.txt", x: Int.max, y: 200)
		}
		let position = store.iconPosition(for: "file.txt")
		#expect(position?.x == 100)
		#expect(position?.y == 200)
	}

	@Test("Set default background")
	func setDefaultBackground() {
		var store = DSStore()

		store.setBackground(.default)

		let record = store.record(for: ".", type: .background)
		#expect(record != nil)

		if case .data(let data) = record?.value {
			#expect(data.count == 12)
			// Check "DefB" magic
			#expect(data[0] == 0x44) // D
			#expect(data[1] == 0x65) // e
			#expect(data[2] == 0x66) // f
			#expect(data[3] == 0x42) // B
		} else {
			Issue.record("Expected blob value")
		}
	}

	@Test("Set color background")
	func setColorBackground() {
		var store = DSStore()

		store.setBackground(.color(red: 65_535, green: 32_768, blue: 0))

		let record = store.record(for: ".", type: .background)
		#expect(record != nil)

		if case .data(let data) = record?.value {
			// Check "ClrB" magic
			#expect(data[0] == 0x43) // C
			#expect(data[1] == 0x6C) // l
			#expect(data[2] == 0x72) // r
			#expect(data[3] == 0x42) // B
		} else {
			Issue.record("Expected blob value")
		}
	}

	@Test("Set picture background")
	func setPictureBackground() {
		var store = DSStore()

		store.setBackground(.picture)

		let record = store.record(for: ".", type: .background)
		#expect(record != nil)

		if case .data(let data) = record?.value {
			// Check "PctB" magic
			#expect(data[0] == 0x50) // P
			#expect(data[1] == 0x63) // c
			#expect(data[2] == 0x74) // t
			#expect(data[3] == 0x42) // B
		} else {
			Issue.record("Expected blob value")
		}
	}

	@Test("Set window bounds")
	func setWindowBounds() throws {
		var store = DSStore()

		try store.setWindowBounds(top: 100, left: 200, bottom: 500, right: 800)

		let record = store.record(for: ".", type: .finderWindowInfo)
		#expect(record != nil)

		if case .data(let data) = record?.value {
			#expect(data.count == 16)
		} else {
			Issue.record("Expected blob value")
		}
	}

	@Test("Reject invalid window bounds")
	func rejectInvalidWindowBounds() throws {
		var store = DSStore()

		#expect(throws: DSStore.Error.self) {
			try store.setWindowBounds(top: -10, left: 0, bottom: 100, right: 200)
		}
		#expect(store.record(for: ".", type: .finderWindowInfo) == nil)

		try store.setWindowBounds(top: 10, left: 0, bottom: 100, right: 200)
		#expect(throws: DSStore.Error.self) {
			try store.setWindowBounds(top: Int.max, left: 0, bottom: 100, right: 200)
		}

		let bounds = store.windowBounds()
		#expect(bounds?.top == 10)
		#expect(bounds?.left == 0)
		#expect(bounds?.bottom == 100)
		#expect(bounds?.right == 200)
		#expect(bounds?.viewStyle == .iconView)
	}

	@Test("Set window bounds with custom view style")
	func setWindowBoundsWithViewStyle() throws {
		var store = DSStore()

		try store.setWindowBounds(top: 0, left: 0, bottom: 400, right: 600, viewStyle: .columnView)

		let record = store.record(for: ".", type: .finderWindowInfo)
		#expect(record != nil)

		if case .data(let data) = record?.value {
			#expect(data.count == 16)
			// View style is at bytes 8-11: "clmv"
			#expect(data[8] == 0x63) // c
			#expect(data[9] == 0x6C) // l
			#expect(data[10] == 0x6D) // m
			#expect(data[11] == 0x76) // v
		} else {
			Issue.record("Expected blob value")
		}
	}

	@Test("Set view style")
	func setViewStyle() {
		var store = DSStore()

		store.setViewStyle(.iconView)

		let record = store.record(for: ".", type: .viewStyle)
		#expect(record != nil)

		if case .fourCC(let fourCC) = record?.value {
			#expect(fourCC == .iconView)
		} else {
			Issue.record("Expected type value")
		}
	}

	@Test("Set various view styles")
	func setVariousViewStyles() {
		let styles: [FourCC] = [.iconView, .columnView, .listView, .galleryView]

		for style in styles {
			var store = DSStore()
			store.setViewStyle(style)

			if case .fourCC(let fourCC) = store.record(for: ".", type: .viewStyle)?.value {
				#expect(fourCC == style)
			} else {
				Issue.record("Expected type value for style: \(style.stringValue)")
			}
		}
	}

	@Test("Comment helpers")
	func commentHelpers() {
		var store = DSStore()

		store.setComment("Hello", for: "Notes.txt")
		#expect(store.comment(for: "Notes.txt") == "Hello")

		store.removeComment(for: "Notes.txt")
		#expect(store.comment(for: "Notes.txt") == nil)
	}

	@Test("View style helper")
	func viewStyleHelper() {
		var store = DSStore()
		store.setViewStyle(.columnView)
		#expect(store.viewStyle() == .columnView)
	}

	@Test("View style value helper")
	func viewStyleValueHelper() {
		var store = DSStore()
		store.setViewStyle(.column)
		#expect(store.viewStyleValue() == .column)
	}

	@Test("View sort helper")
	func viewSortHelper() {
		var store = DSStore()
		store.setViewSort(.dateModified)
		#expect(store.viewSortValue() == .dateModified)
	}

	@Test("Background reader")
	func backgroundReader() {
		var store = DSStore()
		store.setBackground(.color(red: 1000, green: 2000, blue: 3000))

		if case .color(let red, let green, let blue) = store.background() {
			#expect(red == 1000)
			#expect(green == 2000)
			#expect(blue == 3000)
		} else {
			Issue.record("Expected color background")
		}
	}

	@Test("Background picture alias helpers")
	func backgroundPictureAliasHelpers() throws {
		var store = DSStore()
		let aliasData = Data([0x01, 0x02, 0x03, 0x04])

		try store.setBackgroundPicture(aliasData: aliasData)

		if case .picture = store.background() {
			// Expected
		} else {
			Issue.record("Expected picture background")
		}
		#expect(store.backgroundPictureAliasData() == aliasData)
	}

	@Test("Window bounds reader")
	func windowBoundsReader() throws {
		var store = DSStore()
		try store.setWindowBounds(top: 10, left: 20, bottom: 210, right: 420, viewStyle: .listView)

		let bounds = store.windowBounds()
		#expect(bounds?.top == 10)
		#expect(bounds?.left == 20)
		#expect(bounds?.bottom == 210)
		#expect(bounds?.right == 420)
		#expect(bounds?.viewStyle == .listView)
	}

	@Test("Window settings window bounds value")
	func windowSettingsWindowBoundsValue() {
		var settings = DSStore.WindowSettings(windowBounds: "{{10, 20}, {300, 400}}")
		let frame = settings.windowBoundsValue
		#expect(frame?.originX == 10)
		#expect(frame?.originY == 20)
		#expect(frame?.width == 300)
		#expect(frame?.height == 400)

		settings.windowBoundsValue = DSStore.WindowSettings.WindowFrame(originX: 5, originY: 6, width: 7, height: 8)
		#expect(settings.windowBounds == "{{5, 6}, {7, 8}}")
	}

	@Test("Window bounds setter")
	func windowBoundsSetter() throws {
		var store = DSStore()
		let bounds = DSStore.WindowBounds(top: 5, left: 15, bottom: 205, right: 405, viewStyle: .galleryView)

		try store.setWindowBounds(bounds)

		let record = store.record(for: ".", type: .finderWindowInfo)
		#expect(record != nil)
	}

	@Test("Window settings helpers")
	func windowSettingsHelpers() {
		var store = DSStore()
		let settings = DSStore.WindowSettings(
			windowBounds: "{{100, 200}, {800, 600}}",
			sidebarWidth: 182,
			showSidebar: true,
			showToolbar: true,
			showStatusBar: false,
			showPathBar: true,
			viewStyle: "Nlsv"
		)

		store.setWindowSettings(settings)

		let loadedSettings = store.windowSettings()
		#expect(loadedSettings?.windowBounds == settings.windowBounds)
		#expect(loadedSettings?.sidebarWidth == settings.sidebarWidth)
		#expect(loadedSettings?.showSidebar == settings.showSidebar)
		#expect(loadedSettings?.showToolbar == settings.showToolbar)
		#expect(loadedSettings?.showStatusBar == settings.showStatusBar)
		#expect(loadedSettings?.showPathBar == settings.showPathBar)
		#expect(loadedSettings?.viewStyle == settings.viewStyle)
	}

	@Test("Icon view settings helpers")
	func iconViewSettingsHelpers() {
		var store = DSStore()
		let settings = DSStore.IconViewSettings(
			showIconPreview: true,
			showItemInfo: false,
			labelOnBottom: true,
			scrollPositionX: 10,
			scrollPositionY: 20,
			gridOffsetX: 5,
			gridOffsetY: 6,
			textSize: 12,
			iconSize: 64,
			gridSpacing: 56,
			viewOptionsVersion: 1,
			arrangeBy: "name"
		)

		store.setIconViewSettings(settings)

		let loadedSettings = store.iconViewSettings()
		#expect(loadedSettings?.showIconPreview == settings.showIconPreview)
		#expect(loadedSettings?.gridOffsetX == settings.gridOffsetX)
		#expect(loadedSettings?.iconSize == settings.iconSize)
		#expect(loadedSettings?.arrangeBy == settings.arrangeBy)
	}

	@Test("List view settings helpers")
	func listViewSettingsHelpers() {
		var store = DSStore()
		let settings = DSStore.ListViewSettings(
			showIconPreview: true,
			useRelativeDates: true,
			calculateAllSizes: false,
			scrollPositionX: 1,
			scrollPositionY: 2,
			textSize: 11,
			iconSize: 32,
			viewOptionsVersion: 1,
			sortColumn: "name",
			columns: .array([.string("name"), .string("dateModified")])
		)

		store.setListViewSettings(settings)

		let loadedSettings = store.listViewSettings()
		#expect(loadedSettings?.sortColumn == settings.sortColumn)
		#expect(loadedSettings?.textSize == settings.textSize)
		#expect(loadedSettings?.columns == settings.columns)
	}

	@Test("Batch icon positions")
	func batchIconPositions() throws {
		var store = DSStore()
		let placements: [DSStore.IconPlacement] = [
			.init(filename: "App.app", x: 100, y: 120),
			.init(filename: "Applications", x: 420, y: 120)
		]

		try store.setIconPositions(placements)

		#expect(store.iconPosition(for: "App.app")?.x == 100)
		#expect(store.iconPosition(for: "Applications")?.x == 420)
	}
}
