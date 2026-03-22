// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AppleCalendarOpenClawSkill",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(
            name: "apple-calendar-cli",
            targets: ["AppleCalendarCLI"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "AppleCalendarCLI",
            path: "Sources/AppleCalendarCLI"
        ),
    ]
)
