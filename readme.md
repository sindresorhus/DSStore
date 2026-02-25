# DSStore

> Parse and write macOS [`.DS_Store`](https://en.wikipedia.org/wiki/.DS_Store) files

A Swift library for reading, modifying, and creating `.DS_Store` files — the hidden files macOS uses to store Finder metadata like icon positions, view settings, and folder backgrounds.

Zero dependencies. Fully documented. Works great for building DMG installers with custom layouts.

## Highlights

- **Read & Write:** Parse existing files or create new ones from scratch.
- **Strongly typed:** Type-safe records with `DSStore.Record` and `DSStore.Value`.
- **Zero dependencies:** Pure Swift with no external dependencies.
- **Well documented:** Comprehensive API documentation and code comments.
- **Sendable:** Thread-safe types ready for Swift concurrency.

## Install

Add the following to `Package.swift`:

```swift
.package(url: "https://github.com/sindresorhus/DSStore", from: "0.1.0")
```

[Or add the package in Xcode.](https://developer.apple.com/documentation/xcode/adding_package_dependencies_to_your_app)

## Usage

### Reading a `.DS_Store` file

```swift
import DSStore

let store = try DSStore.read(from: url)

// Get all filenames referenced in the store
print(store.filenames)

// Get all records for a specific file
let records = store.records(for: "README.md")

// Get a specific record
if let position = store.iconPosition(for: "Application.app") {
	print("Icon at: \(position.x), \(position.y)")
}
```

### Creating a `.DS_Store` file

Perfect for DMG installers with custom icon layouts:

```swift
import DSStore

var store = DSStore()

// Set icon positions
try store.setIconPosition(for: "Application.app", x: 140, y: 180)
try store.setIconPosition(for: "Applications", x: 480, y: 180)

// Configure the Finder window
try store.setWindowBounds(top: 100, left: 100, bottom: 400, right: 620)
store.setViewStyle(.iconView)

// Set a background color (RGB values 0-65535)
store.setBackground(.color(red: 65535, green: 65535, blue: 65535))

// Write to disk
try store.write(to: url)
```

### Working with records directly

```swift
import DSStore

var store = DSStore()

// Add a Spotlight comment
store.add(DSStore.Record(
	filename: "Important.txt",
	type: .spotlightComment,
	value: .string("Don't delete this file!")
))

// Add a custom blob record
store.add(DSStore.Record(
	filename: ".",
	type: .custom(.literal("icvp")),
	value: .data(plistData)
))

// Remove records
store.removeRecords(for: "OldFile.txt")
```

## API

See the source for now.

<!-- [See the API docs.](https://swiftpackageindex.com/sindresorhus/DSStore/documentation/dsstore) -->

## FAQ

#### What is a `.DS_Store` file?

`.DS_Store` (Desktop Services Store) is a hidden file created by macOS Finder in every folder it opens. It stores custom attributes like icon positions, view settings, and folder backgrounds.

#### Why would I need to parse or create these files?

The most common use case is creating DMG installers with custom layouts — positioning the app icon and Applications folder alias in specific locations with a nice background image.

#### Is the file format documented by Apple?

No, it's a proprietary format. This library is based on reverse-engineering work by Mark Mentovai, Wim Lewis, and others.

#### Does this work on Linux?

The parsing and writing work anywhere Swift runs, but `.DS_Store` files are only used by macOS Finder.

#### Can I use this to clean up `.DS_Store` files?

Yes! You can read a file, inspect its contents, remove entries, and write it back. Or just delete the file entirely — Finder will recreate it.
