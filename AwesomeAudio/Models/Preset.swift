import Foundation

// MARK: - CompressionPreset

enum CompressionPreset: String, Codable, CaseIterable {
    case gentle
    case medium
    case heavy

    var threshold: Float {
        switch self {
        case .gentle: return -18.0
        case .medium: return -24.0
        case .heavy:  return -30.0
        }
    }

    var ratio: Float {
        switch self {
        case .gentle: return 2.0
        case .medium: return 3.5
        case .heavy:  return 6.0
        }
    }

    var attackMs: Float {
        switch self {
        case .gentle: return 20.0
        case .medium: return 10.0
        case .heavy:  return 5.0
        }
    }

    var releaseMs: Float {
        switch self {
        case .gentle: return 200.0
        case .medium: return 120.0
        case .heavy:  return 80.0
        }
    }
}

// MARK: - PresetSnapshot (Codable value type for serialization)

struct PresetSnapshot: Codable, Equatable {
    var name: String
    var targetLUFS: Float
    var truePeakLimitDBFS: Float
    var highPassFrequency: Float
    var compressionPreset: CompressionPreset
    var compressionThreshold: Float
    var compressionRatio: Float
    var compressionAttackMs: Float
    var compressionReleaseMs: Float
    var deEsserFrequency: Float
    var deEsserThreshold: Float
    var deEsserRatio: Float
    var noiseReductionEnabled: Bool
    var noiseReductionAttenLimitDB: Float
}

// MARK: - Preset (plain Swift class, usable without SwiftData)
// The SwiftData @Model wrapper lives in AwesomeAudio/AppLayer/PresetModel.swift
// and is only compiled into the Xcode app target.

final class Preset {
    var name: String
    var createdAt: Date
    var isBuiltIn: Bool

    // Loudness
    var targetLUFS: Float
    var truePeakLimitDBFS: Float

    // High-pass filter
    var highPassFrequency: Float

    // Compression
    var compressionPreset: CompressionPreset
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

    init(
        name: String,
        isBuiltIn: Bool = false,
        targetLUFS: Float = -16.0,
        truePeakLimitDBFS: Float = -1.0,
        highPassFrequency: Float = 80.0,
        compressionPreset: CompressionPreset = .medium,
        compressionThreshold: Float = -24.0,
        compressionRatio: Float = 3.5,
        compressionAttackMs: Float = 10.0,
        compressionReleaseMs: Float = 120.0,
        deEsserFrequency: Float = 7500.0,
        deEsserThreshold: Float = -30.0,
        deEsserRatio: Float = 4.0,
        noiseReductionEnabled: Bool = true,
        noiseReductionAttenLimitDB: Float = 40.0
    ) {
        self.name = name
        self.createdAt = Date()
        self.isBuiltIn = isBuiltIn
        self.targetLUFS = targetLUFS
        self.truePeakLimitDBFS = truePeakLimitDBFS
        self.highPassFrequency = highPassFrequency
        self.compressionPreset = compressionPreset
        self.compressionThreshold = compressionThreshold
        self.compressionRatio = compressionRatio
        self.compressionAttackMs = compressionAttackMs
        self.compressionReleaseMs = compressionReleaseMs
        self.deEsserFrequency = deEsserFrequency
        self.deEsserThreshold = deEsserThreshold
        self.deEsserRatio = deEsserRatio
        self.noiseReductionEnabled = noiseReductionEnabled
        self.noiseReductionAttenLimitDB = noiseReductionAttenLimitDB
    }

    /// Returns a Codable snapshot of the current preset values.
    func snapshot() -> PresetSnapshot {
        PresetSnapshot(
            name: name,
            targetLUFS: targetLUFS,
            truePeakLimitDBFS: truePeakLimitDBFS,
            highPassFrequency: highPassFrequency,
            compressionPreset: compressionPreset,
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

    // MARK: Built-in presets

    static let builtInPresets: [Preset] = [
        Preset(
            name: "Podcast",
            isBuiltIn: true,
            targetLUFS: -16.0,
            truePeakLimitDBFS: -1.0,
            highPassFrequency: 80.0,
            compressionPreset: .medium,
            compressionThreshold: -24.0,
            compressionRatio: 3.5,
            compressionAttackMs: 10.0,
            compressionReleaseMs: 120.0,
            deEsserFrequency: 7500.0,
            deEsserThreshold: -30.0,
            deEsserRatio: 4.0,
            noiseReductionEnabled: true,
            noiseReductionAttenLimitDB: 40.0
        ),
        Preset(
            name: "Voiceover",
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
            noiseReductionEnabled: true,
            noiseReductionAttenLimitDB: 30.0
        ),
        Preset(
            name: "Audiobook",
            isBuiltIn: true,
            targetLUFS: -18.0,
            truePeakLimitDBFS: -3.0,
            highPassFrequency: 90.0,
            compressionPreset: .gentle,
            compressionThreshold: -20.0,
            compressionRatio: 2.5,
            compressionAttackMs: 15.0,
            compressionReleaseMs: 150.0,
            deEsserFrequency: 7000.0,
            deEsserThreshold: -32.0,
            deEsserRatio: 3.5,
            noiseReductionEnabled: true,
            noiseReductionAttenLimitDB: 35.0
        )
    ]
}
