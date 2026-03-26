// This file is compiled only by the Xcode app target, NOT the SPM library.
// It wraps the plain Preset class as a SwiftData @Model for persistence.
import Foundation
import SwiftData

@Model
final class PresetModel {
    var name: String
    var createdAt: Date
    var isBuiltIn: Bool

    // Loudness
    var targetLUFS: Float
    var truePeakLimitDBFS: Float

    // High-pass filter
    var highPassFrequency: Float

    // Compression
    var compressionPresetRaw: String  // CompressionPreset.rawValue
    var compressionThreshold: Float
    var compressionRatio: Float
    var compressionAttackMs: Float
    var compressionReleaseMs: Float

    // De-esser
    var deEsserFrequency: Float
    var deEsserThreshold: Float
    var deEsserRatio: Float

    // Noise reduction
    var noiseReductionEnabled: Bool
    var noiseReductionAttenLimitDB: Float

    init(from preset: Preset) {
        self.name = preset.name
        self.createdAt = preset.createdAt
        self.isBuiltIn = preset.isBuiltIn
        self.targetLUFS = preset.targetLUFS
        self.truePeakLimitDBFS = preset.truePeakLimitDBFS
        self.highPassFrequency = preset.highPassFrequency
        self.compressionPresetRaw = preset.compressionPreset.rawValue
        self.compressionThreshold = preset.compressionThreshold
        self.compressionRatio = preset.compressionRatio
        self.compressionAttackMs = preset.compressionAttackMs
        self.compressionReleaseMs = preset.compressionReleaseMs
        self.deEsserFrequency = preset.deEsserFrequency
        self.deEsserThreshold = preset.deEsserThreshold
        self.deEsserRatio = preset.deEsserRatio
        self.noiseReductionEnabled = preset.noiseReductionEnabled
        self.noiseReductionAttenLimitDB = preset.noiseReductionAttenLimitDB
    }

    func toPreset() -> Preset {
        Preset(
            name: name,
            isBuiltIn: isBuiltIn,
            targetLUFS: targetLUFS,
            truePeakLimitDBFS: truePeakLimitDBFS,
            highPassFrequency: highPassFrequency,
            compressionPreset: CompressionPreset(rawValue: compressionPresetRaw) ?? .medium,
            compressionThreshold: compressionThreshold,
            compressionRatio: compressionRatio,
            compressionAttackMs: compressionAttackMs,
            compressionReleaseMs: compressionReleaseMs,
            deEsserFrequency: deEsserFrequency,
            deEsserThreshold: deEsserThreshold,
            deEsserRatio: deEsserRatio,
            noiseReductionEnabled: noiseReductionEnabled,
            noiseReductionAttenLimitDB: noiseReductionAttenLimitDB
        )
    }
}
