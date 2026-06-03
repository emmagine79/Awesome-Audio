import Foundation
import Testing
@testable import AwesomeAudio

@Suite("Preset Manager Tests")
struct PresetManagerTests {

    @Test func createdPresetPreservesFullToneSnapshotAndPersists() throws {
        let url = try temporaryURL()
        let manager = PresetManager(storageURL: url)
        let source = Preset(
            name: "Voice Lift",
            highPassCutoff: 95,
            noiseReductionStrength: 0.42,
            deEssAmount: 0.21,
            presenceAmount: 0.73,
            airAmount: 0.61,
            compressionPreset: .heavy,
            targetLUFS: -14,
            truePeakCeiling: -1.5,
            outputBitDepth: 16
        )

        let created = manager.createPreset(from: source, name: "Voice Lift")
        let reloaded = PresetManager(storageURL: url).allPresets().first { $0.id == created.id }

        #expect(reloaded?.presenceAmount == 0.73)
        #expect(reloaded?.airAmount == 0.61)
        #expect(reloaded?.truePeakCeiling == -1.5)
        #expect(reloaded?.outputBitDepth == 16)
    }

    @Test func editingBuiltInPresetCreatesCustomVariant() throws {
        let manager = PresetManager(storageURL: try temporaryURL())
        let builtIn = try #require(manager.allPresets().first { $0.isBuiltIn })
        let edited = Preset(name: "Podcast Standard Edited", noiseReductionStrength: 0.55)

        let saved = manager.savePreset(target: builtIn, from: edited, name: "Podcast Standard Edited")

        #expect(saved.isBuiltIn == false)
        #expect(saved.name == "Podcast Standard Edited")
        #expect(manager.allPresets().contains { $0.id == builtIn.id && $0.isBuiltIn })
        #expect(manager.allPresets().contains { $0.id == saved.id && !$0.isBuiltIn })
    }

    @Test func duplicatePresetCreatesUniqueCopyName() throws {
        let manager = PresetManager(storageURL: try temporaryURL())
        let preset = Preset(name: "Narration")
        _ = manager.createPreset(from: preset, name: "Narration")

        let duplicate = manager.duplicatePreset(preset)

        #expect(duplicate.name == "Narration Copy")
        #expect(duplicate.id != preset.id)
        #expect(manager.allPresets().contains { $0.id == duplicate.id })
    }

    @Test func exportAndImportPresetRoundTripsUserPreset() throws {
        let exportURL = try temporaryURL(fileName: "presets.awesomepresets")
        let sourceManager = PresetManager(storageURL: try temporaryURL(fileName: "source.json"))
        let preset = sourceManager.createPreset(from: Preset(name: "Export Me", airAmount: 0.44), name: "Export Me")
        try sourceManager.exportPreset(preset, to: exportURL)

        let importManager = PresetManager(storageURL: try temporaryURL(fileName: "import.json"))
        let imported = try importManager.importPresets(from: exportURL)

        #expect(imported.count == 1)
        #expect(imported.first?.name == "Export Me")
        #expect(imported.first?.airAmount == 0.44)
        #expect(importManager.allPresets().contains { $0.name == "Export Me" })
    }

    private func temporaryURL(fileName: String = UUID().uuidString + ".json") throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AwesomeAudioPresetTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(fileName)
    }
}
