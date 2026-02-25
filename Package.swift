// swift-tools-version:6.2
import PackageDescription

let package = Package(
	name: "DSStore",
	platforms: [
		.macOS(.v13),
		.iOS(.v16),
		.tvOS(.v16),
		.watchOS(.v11),
		.visionOS(.v2)
	],
	products: [
		.library(
			name: "DSStore",
			targets: [
				"DSStore"
			]
		)
	],
	targets: [
		.target(
			name: "DSStore"
		),
		.testTarget(
			name: "DSStoreTests",
			dependencies: [
				"DSStore"
			],
			resources: [
				.copy("fixture")
			]
		)
	]
)
