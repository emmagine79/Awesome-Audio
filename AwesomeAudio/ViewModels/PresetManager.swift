import Foundation
import Observation

// MARK: - PresetManager

@Observable
final class PresetManager {

    // MARK: - State

    private var presets: [Preset] = []

    // MARK: - Init

    init() {
        seedBuiltIns()
    }

    // MARK: - Public API

    func allPresets() -> [Preset] {
        presets
    }

    /// Creates a new user preset copied from `source` with the given name.
    @discardableResult
    func createPreset(from source: Preset, name: String) -> Preset {
        let copy = Preset(
            name: name,
            isBuiltIn: false,
            highPassCutoff: source.highPassCutoff,
            noiseReductionStrength: source.noiseReductionStrength,
            deEssAmount: source.deEssAmount,
            compressionPreset: source.compressionPreset,
            targetLUFS: source.targetLUFS,
            truePeakCeiling: source.truePeakCeiling,
            outputBitDepth: source.outputBitDepth
        )
        presets.append(copy)
        return copy
    }

    /// Deletes a user-created preset. Built-in presets are protected and silently ignored.
    func deletePreset(_ preset: Preset) {
        guard !preset.isBuiltIn else { return }
        presets.removeAll { $0.id == preset.id }
    }

    // MARK: - Private

    private func seedBuiltIns() {
        presets = Preset.builtInPresets
    }
}
