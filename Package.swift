// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Field75Mapper",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "Field75Core",
            targets: ["Field75Core"]
        ),
        .executable(
            name: "field75ctl",
            targets: ["field75ctl"]
        ),
        .executable(
            name: "Field75Mapper",
            targets: ["Field75MapperApp"]
        )
    ],
    targets: [
        .target(
            name: "Field75Core",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreFoundation")
            ]
        ),
        .executableTarget(
            name: "field75ctl",
            dependencies: ["Field75Core"]
        ),
        .executableTarget(
            name: "Field75MapperApp",
            dependencies: ["Field75Core"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices")
            ]
        ),
        .testTarget(
            name: "Field75CoreTests",
            dependencies: ["Field75Core"]
        )
    ]
)
