// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Tymark",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "Tymark",
            targets: ["Tymark"]
        ),
        .executable(
            name: "TymarkSmokeCheck",
            targets: ["TymarkSmokeCheck"]
        ),
        .library(
            name: "TymarkParser",
            targets: ["TymarkParser"]
        ),
        .library(
            name: "TymarkEditor",
            targets: ["TymarkEditor"]
        ),
        .library(
            name: "TymarkTheme",
            targets: ["TymarkTheme"]
        ),
        .library(
            name: "TymarkWorkspace",
            targets: ["TymarkWorkspace"]
        ),
        .library(
            name: "TymarkSync",
            targets: ["TymarkSync"]
        ),
        .library(
            name: "TymarkExport",
            targets: ["TymarkExport"]
        ),
        .library(
            name: "TymarkHighlighter",
            targets: ["TymarkHighlighter"]
        ),
        .library(
            name: "TymarkAI",
            targets: ["TymarkAI"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-markdown.git", from: "0.3.0")
    ],
    targets: [
        // MARK: - Tymark App
        .executableTarget(
            name: "Tymark",
            dependencies: [
                "TymarkParser",
                "TymarkEditor",
                "TymarkTheme",
                "TymarkWorkspace",
                "TymarkSync",
                "TymarkExport",
                "TymarkHighlighter",
                "TymarkAI"
            ],
            path: "App/Tymark",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),

        // MARK: - Smoke Check
        .executableTarget(
            name: "TymarkSmokeCheck",
            dependencies: [
                "TymarkParser",
                "TymarkTheme"
            ],
            path: "App/TymarkSmokeCheck",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),

        // MARK: - TymarkParser
        .target(
            name: "TymarkParser",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown")
            ],
            path: "Packages/TymarkParser/Sources",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "TymarkParserTests",
            dependencies: ["TymarkParser"],
            path: "Packages/TymarkParser/Tests"
        ),

        // MARK: - TymarkEditor
        .target(
            name: "TymarkEditor",
            dependencies: [
                "TymarkParser",
                "TymarkTheme"
            ],
            path: "Packages/TymarkEditor/Sources",
            resources: [
                .process("../Resources")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "TymarkEditorTests",
            dependencies: ["TymarkEditor"],
            path: "Packages/TymarkEditor/Tests"
        ),

        // MARK: - TymarkTheme
        .target(
            name: "TymarkTheme",
            dependencies: [],
            path: "Packages/TymarkTheme/Sources",
            resources: [
                .process("../Resources/Themes")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "TymarkThemeTests",
            dependencies: ["TymarkTheme"],
            path: "Packages/TymarkTheme/Tests"
        ),

        // MARK: - TymarkWorkspace
        .target(
            name: "TymarkWorkspace",
            dependencies: [],
            path: "Packages/TymarkWorkspace/Sources",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "TymarkWorkspaceTests",
            dependencies: ["TymarkWorkspace"],
            path: "Packages/TymarkWorkspace/Tests"
        ),

        // MARK: - TymarkSync
        .target(
            name: "TymarkSync",
            dependencies: [
                "TymarkParser"
            ],
            path: "Packages/TymarkSync/Sources",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "TymarkSyncTests",
            dependencies: ["TymarkSync"],
            path: "Packages/TymarkSync/Tests"
        ),

        // MARK: - TymarkExport
        .target(
            name: "TymarkExport",
            dependencies: [
                "TymarkParser",
                "TymarkTheme"
            ],
            path: "Packages/TymarkExport/Sources",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "TymarkExportTests",
            dependencies: ["TymarkExport"],
            path: "Packages/TymarkExport/Tests"
        ),

        // MARK: - TymarkAI
        .target(
            name: "TymarkAI",
            dependencies: [],
            path: "Packages/TymarkAI/Sources",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "TymarkAITests",
            dependencies: ["TymarkAI"],
            path: "Packages/TymarkAI/Tests"
        ),

        // MARK: - TymarkHighlighter
        .target(
            name: "TymarkHighlighter",
            dependencies: [],
            path: "Packages/TymarkHighlighter/Sources",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "TymarkHighlighterTests",
            dependencies: ["TymarkHighlighter"],
            path: "Packages/TymarkHighlighter/Tests"
        )
    ]
)
