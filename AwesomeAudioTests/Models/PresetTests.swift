import Testing
import Foundation
@testable import AwesomeAudio

@Suite("Preset Tests")
struct PresetTests {

    @Test func presetDefaultValues() {
        let preset = Preset(name: "Test")
        #expect(preset.name == "Test")
        #expect(preset.isBuiltIn == false)
        #expect(preset.highPassCutoff == 80)
        #expect(preset.noiseReductionStrength == 0.7)
        #expect(preset.deEssAmount == 0.5)
        #expect(preset.compressionPreset == .medium)
        #expect(preset.targetLUFS == -16)
        #expect(preset.truePeakCeiling == -1.0)
        #expect(preset.outputBitDepth == 24)
    }

    @Test func compressionPresetGentle() {
        let p = CompressionPreset.gentle
        #expect(p.threshold == -20)
        #expect(p.ratio == 2)
        #expect(p.attackMs == 20)
        #expect(p.releaseMs == 200)
    }

    @Test func compressionPresetMedium() {
        let p = CompressionPreset.medium
        #expect(p.threshold == -24)
        #expect(p.ratio == 3)
        #expect(p.attackMs == 10)
        #expect(p.releaseMs == 100)
    }

    @Test func compressionPresetHeavy() {
        let p = CompressionPreset.heavy
        #expect(p.threshold == -30)
        #expect(p.ratio == 4)
        #expect(p.attackMs == 5)
        #expect(p.releaseMs == 50)
    }

    @Test func presetSnapshotRoundtrip() throws {
        let snapshot = PresetSnapshot(
            highPassCutoff: 80,
            noiseReductionStrength: 0.7,
            noiseReductionAttenLimitDB: 70,
            deEssAmount: 0.5,
            compressionPreset: .medium,
            targetLUFS: -16,
            truePeakCeiling: -1.0,
            outputBitDepth: 24
        )
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(PresetSnapshot.self, from: data)
        #expect(decoded == snapshot)
    }

    @Test func presetSnapshotFromModel() {
        let preset = Preset(name: "Test", noiseReductionStrength: 0.7)
        let snapshot = preset.snapshot()
        #expect(snapshot.highPassCutoff == 80)
        #expect(snapshot.noiseReductionStrength == 0.7)
        #expect(snapshot.noiseReductionAttenLimitDB == 70)  // 0.7 * 100
        #expect(snapshot.compressionPreset == .medium)
    }

    @Test func builtInPresetsExist() {
        let presets = Preset.builtInPresets
        #expect(presets.count == 4)
        #expect(presets.allSatisfy { $0.isBuiltIn })
    }

    @Test func builtInPresetNames() {
        let names = Preset.builtInPresets.map(\.name)
        #expect(names.contains("Podcast Standard"))
        #expect(names.contains("YouTube"))
        #expect(names.contains("Noisy Environment"))
        #expect(names.contains("Minimal"))
    }
}
