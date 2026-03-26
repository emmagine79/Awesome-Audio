import Testing
import Foundation
@testable import AwesomeAudio

@Suite("Preset Tests")
struct PresetTests {

    // MARK: - Preset creation with default values

    @Test func presetCreationDefaults() {
        let preset = Preset(name: "Test")
        #expect(preset.name == "Test")
        #expect(preset.isBuiltIn == false)
        #expect(preset.targetLUFS == -16.0)
        #expect(preset.truePeakLimitDBFS == -1.0)
        #expect(preset.highPassFrequency == 80.0)
        #expect(preset.compressionPreset == .medium)
        #expect(preset.compressionThreshold == -24.0)
        #expect(preset.compressionRatio == 3.5)
        #expect(preset.compressionAttackMs == 10.0)
        #expect(preset.compressionReleaseMs == 120.0)
        #expect(preset.deEsserFrequency == 7500.0)
        #expect(preset.deEsserThreshold == -30.0)
        #expect(preset.deEsserRatio == 4.0)
        #expect(preset.noiseReductionEnabled == true)
        #expect(preset.noiseReductionAttenLimitDB == 40.0)
    }

    @Test func presetCreationCustomValues() {
        let preset = Preset(
            name: "Custom",
            isBuiltIn: true,
            targetLUFS: -23.0,
            truePeakLimitDBFS: -3.0,
            highPassFrequency: 100.0,
            compressionPreset: .gentle,
            compressionThreshold: -18.0,
            compressionRatio: 2.0,
            compressionAttackMs: 20.0,
            compressionReleaseMs: 200.0,
            deEsserFrequency: 8000.0,
            deEsserThreshold: -28.0,
            deEsserRatio: 3.0,
            noiseReductionEnabled: false,
            noiseReductionAttenLimitDB: 30.0
        )
        #expect(preset.name == "Custom")
        #expect(preset.isBuiltIn == true)
        #expect(preset.targetLUFS == -23.0)
        #expect(preset.compressionPreset == .gentle)
        #expect(preset.noiseReductionEnabled == false)
    }

    // MARK: - CompressionPreset computed properties

    @Test func compressionPresetGentle() {
        let preset = CompressionPreset.gentle
        #expect(preset.threshold == -18.0)
        #expect(preset.ratio == 2.0)
        #expect(preset.attackMs == 20.0)
        #expect(preset.releaseMs == 200.0)
    }

    @Test func compressionPresetMedium() {
        let preset = CompressionPreset.medium
        #expect(preset.threshold == -24.0)
        #expect(preset.ratio == 3.5)
        #expect(preset.attackMs == 10.0)
        #expect(preset.releaseMs == 120.0)
    }

    @Test func compressionPresetHeavy() {
        let preset = CompressionPreset.heavy
        #expect(preset.threshold == -30.0)
        #expect(preset.ratio == 6.0)
        #expect(preset.attackMs == 5.0)
        #expect(preset.releaseMs == 80.0)
    }

    // MARK: - PresetSnapshot JSON encode/decode roundtrip

    @Test func presetSnapshotRoundtrip() throws {
        let original = PresetSnapshot(
            name: "Roundtrip Test",
            targetLUFS: -16.0,
            truePeakLimitDBFS: -1.0,
            highPassFrequency: 80.0,
            compressionPreset: .heavy,
            compressionThreshold: -30.0,
            compressionRatio: 6.0,
            compressionAttackMs: 5.0,
            compressionReleaseMs: 80.0,
            deEsserFrequency: 7500.0,
            deEsserThreshold: -30.0,
            deEsserRatio: 4.0,
            noiseReductionEnabled: true,
            noiseReductionAttenLimitDB: 40.0
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PresetSnapshot.self, from: data)

        #expect(decoded.name == original.name)
        #expect(decoded.targetLUFS == original.targetLUFS)
        #expect(decoded.truePeakLimitDBFS == original.truePeakLimitDBFS)
        #expect(decoded.highPassFrequency == original.highPassFrequency)
        #expect(decoded.compressionPreset == original.compressionPreset)
        #expect(decoded.compressionThreshold == original.compressionThreshold)
        #expect(decoded.compressionRatio == original.compressionRatio)
        #expect(decoded.compressionAttackMs == original.compressionAttackMs)
        #expect(decoded.compressionReleaseMs == original.compressionReleaseMs)
        #expect(decoded.deEsserFrequency == original.deEsserFrequency)
        #expect(decoded.deEsserThreshold == original.deEsserThreshold)
        #expect(decoded.deEsserRatio == original.deEsserRatio)
        #expect(decoded.noiseReductionEnabled == original.noiseReductionEnabled)
        #expect(decoded.noiseReductionAttenLimitDB == original.noiseReductionAttenLimitDB)
    }

    @Test func presetSnapshotFromModel() throws {
        let preset = Preset(
            name: "Snapshot Source",
            targetLUFS: -18.0,
            compressionPreset: .heavy
        )
        let snapshot = preset.snapshot()

        #expect(snapshot.name == "Snapshot Source")
        #expect(snapshot.targetLUFS == -18.0)
        #expect(snapshot.compressionPreset == .heavy)

        // Verify JSON roundtrip of snapshot produced from model
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(PresetSnapshot.self, from: data)
        #expect(decoded.name == snapshot.name)
        #expect(decoded.compressionPreset == snapshot.compressionPreset)
    }

    // MARK: - Built-in presets

    @Test func builtInPresetsExist() {
        let presets = Preset.builtInPresets
        #expect(presets.count == 3)
        #expect(presets.allSatisfy { $0.isBuiltIn })
    }

    @Test func builtInPresetNames() {
        let names = Preset.builtInPresets.map { $0.name }
        #expect(names.contains("Podcast"))
        #expect(names.contains("Voiceover"))
        #expect(names.contains("Audiobook"))
    }
}
