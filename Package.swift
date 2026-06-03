// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AwesomeAudio",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "AwesomeAudio",
            targets: ["AwesomeAudio"]
        ),
        .executable(
            name: "AwesomeAudioApp",
            targets: ["AwesomeAudioExecutable"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/ryanfrancesconi/spfk-loudness", from: "0.0.4"),
        .package(url: "https://github.com/dmrschmidt/DSWaveformImage", from: "14.0.0"),
        .package(url: "https://github.com/apple/swift-testing", from: "6.2.0")
    ],
    targets: [
        .target(
            name: "AwesomeAudio",
            dependencies: [
                .product(name: "SPFKLoudness", package: "spfk-loudness"),
                .product(name: "DSWaveformImage", package: "DSWaveformImage")
            ],
            path: "AwesomeAudio",
            exclude: ["AwesomeAudioApp.swift"],
            resources: [
                .process("Resources/Assets.xcassets"),
                .copy("Resources/DeepFilterNet3_onnx.tar.gz")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "AwesomeAudioTests",
            dependencies: [
                "AwesomeAudio",
                .product(name: "Testing", package: "swift-testing")
            ],
            path: "AwesomeAudioTests"
        ),
        .executableTarget(
            name: "AwesomeAudioExecutable",
            dependencies: ["AwesomeAudio"],
            path: "AwesomeAudioExecutable"
        )
    ]
)
