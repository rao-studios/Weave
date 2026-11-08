// swift-tools-version: 6.2
// Weave: spawns AIIs on demand and weaves their Threads into one federated search.
//
//   WeaveKit   the Granite services (Fabric, Host, Search, Port, Explorer), the fabric's homes,
//              ports and launch specs over AII's contract, the loopback HTTP clients for Thread
//              and Sewn, and Weave's own HTTP port (Hummingbird) — everything but the window
//   Weave      the macOS app (Sources/WeaveApp): the shell and settings services, the pages,
//              the design, and WeaveAppRoot, the façade AppKit calls
//
// OUT:  the `Weave` executable (Scripts/build/make-app.sh assembles build/Weave.app) and the
//       `WeaveKit` library.
// PIN:  Every dependency is taken by URL, on main, and Package.resolved pins the commit, as Ambient,
//       Veil and Craft take them. AII comes with `traits: []`: its `Server` trait (Frigate/MLX,
//       Hummingbird for the servers, Supabase …) is the servers' business, and Swift prunes what the
//       trait gates (tools 6.2). Weave runs the installed ~/.rao/aii/bin/AIIServer; it never builds one.
// PIN:  Support/Info.plist is linked into the executable (-sectcreate), so a bare `swift build` knows
//       its bundle id and version as the .app does. Package.swift and the plist agree on the OS floor.
// PIN:  Reducers hold @Relay (a @MainActor wrapper) and are built off the main actor: every target
//       that defines services stays in Swift 5 language mode.

import PackageDescription

let v5: [SwiftSetting] = [.swiftLanguageMode(.v5)]

let embeddedInfoPlist: [LinkerSetting] = [
    .unsafeFlags([
        "-Xlinker", "-sectcreate",
        "-Xlinker", "__TEXT",
        "-Xlinker", "__info_plist",
        "-Xlinker", "\(Context.packageDirectory)/Support/Info.plist",
    ]),
]

let package = Package(
    name: "Weave",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "WeaveKit", targets: ["WeaveKit"]),
        .executable(name: "Weave", targets: ["Weave"]),
    ],
    dependencies: [
        .package(url: "https://github.com/riteshpakala/Granite.git", branch: "main"),
        .package(url: "https://github.com/rao-studios/AII.git", branch: "main", traits: []),
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
        // Already in the graph through AII and Hummingbird; named so the port's logger can be quieted.
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),
        // Also already in the graph: the forwarder passes bodies through as bytes (NIOCore,
        // NIOFoundationCompat) and answers with the AII's own status and content type (HTTPTypes).
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
        .package(url: "https://github.com/apple/swift-http-types.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "WeaveKit",
            dependencies: [
                .product(name: "AII", package: "AII"),
                .product(name: "Granite", package: "Granite"),
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOFoundationCompat", package: "swift-nio"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
            ],
            swiftSettings: v5
        ),
        .executableTarget(
            name: "Weave",
            dependencies: [
                "WeaveKit",
                .product(name: "AII", package: "AII"),
                .product(name: "Granite", package: "Granite"),
                .product(name: "GraniteUI", package: "Granite"),
            ],
            path: "Sources/WeaveApp",
            resources: [.copy("Resources/AppIcon.png")],
            swiftSettings: v5,
            linkerSettings: embeddedInfoPlist
        ),
        // Fixtures and URLProtocol stubs: test doubles, in no product.
        .target(
            name: "WeaveKitTestSupport",
            dependencies: ["WeaveKit", .product(name: "AII", package: "AII")],
            path: "Tests/WeaveKitTestSupport",
            swiftSettings: v5
        ),
        .testTarget(
            name: "WeaveKitTests",
            dependencies: [
                "WeaveKit", "WeaveKitTestSupport",
                .product(name: "AII", package: "AII"),
                .product(name: "Granite", package: "Granite"),
                .product(name: "Hummingbird", package: "hummingbird"),
            ],
            swiftSettings: v5
        ),
        .testTarget(
            name: "WeaveAppTests",
            dependencies: ["Weave", "WeaveKit", .product(name: "Granite", package: "Granite")],
            swiftSettings: v5
        ),
    ]
)
