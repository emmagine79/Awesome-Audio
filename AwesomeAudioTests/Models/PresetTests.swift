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
        #expect(preset.noiseReductionStrength == 0.35)
        #expect(preset.deEssAmount == 0.5)
        #expect(preset.presenceAmount == 0.25)
        #expect(preset.airAmount == 0.15)
        #expect(preset.compressionPreset == .medium)
        #expect(preset.targetLUFS == -16)
        #expect(preset.truePeakCeiling == -2.0)
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

    @Test func attenuationLimitMappingIsConservative() {
        #expect(Preset.attenuationLimitDb(for: 0.0) == 6.0)
        #expect(Preset.attenuationLimitDb(for: 0.5) == 18.0)
        #expect(Preset.attenuationLimitDb(for: 1.0) == 30.0)
    }

    @Test func presetSnapshotRoundtrip() throws {
        let snapshot = PresetSnapshot(
            highPassCutoff: 80,
            noiseReductionStrength: 0.35,
            noiseReductionAttenLimitDB: 14.4,
            deEssAmount: 0.5,
            presenceAmount: 0.30,
            airAmount: 0.18,
            compressionPreset: .medium,
            targetLUFS: -16,
            truePeakCeiling: -2.0,
            outputBitDepth: 24
        )
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(PresetSnapshot.self, from: data)
        #expect(decoded == snapshot)
    }

    @Test func presetSnapshotFromModel() {
        let preset = Preset(name: "Test", noiseReductionStrength: 0.35)
        let snapshot = preset.snapshot()
        #expect(snapshot.highPassCutoff == 80)
        #expect(snapshot.noiseReductionStrength == 0.35)
        #expect(snapshot.noiseReductionAttenLimitDB == 14.4)
        #expect(snapshot.presenceAmount == 0.25)
        #expect(snapshot.airAmount == 0.15)
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

    @Test func builtInPresetNoiseReductionStrengthsAreSafer() {
        let presetsByName = Dictionary(uniqueKeysWithValues: Preset.builtInPresets.map { ($0.name, $0) })
        #expect(presetsByName["Podcast Standard"]?.noiseReductionStrength == 0.10)
        #expect(presetsByName["YouTube"]?.noiseReductionStrength == 0.10)
        #expect(presetsByName["Noisy Environment"]?.noiseReductionStrength == 0.35)
        #expect(presetsByName["Minimal"]?.noiseReductionStrength == 0.0)
    }

    @Test func builtInPresetsAdoptMasteringFriendlyToneDefaults() {
        let presetsByName = Dictionary(uniqueKeysWithValues: Preset.builtInPresets.map { ($0.name, $0) })
        #expect(presetsByName["Podcast Standard"]?.truePeakCeiling == -2.0)
        #expect(presetsByName["Podcast Standard"]?.presenceAmount == 0.30)
        #expect(presetsByName["Podcast Standard"]?.airAmount == 0.18)
        #expect(presetsByName["Minimal"]?.deEssAmount == 0.10)
    }
}
