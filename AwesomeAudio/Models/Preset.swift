import Foundation

// MARK: - CompressionPreset

enum CompressionPreset: String, Codable, CaseIterable {
    case gentle
    case medium
    case heavy

    var threshold: Float {
        switch self {
        case .gentle: return -20
        case .medium: return -24
        case .heavy: return -30
        }
    }

    var ratio: Float {
        switch self {
        case .gentle: return 2
        case .medium: return 3
        case .heavy: return 4
        }
    }

    var attackMs: Float {
        switch self {
        case .gentle: return 20
        case .medium: return 10
        case .heavy: return 5
        }
    }

    var releaseMs: Float {
        switch self {
        case .gentle: return 200
        case .medium: return 100
        case .heavy: return 50
        }
    }
}

// MARK: - PresetSnapshot (Codable, for serialization in ProcessingRecord)

struct PresetSnapshot: Codable, Equatable {
    var highPassCutoff: Float
    var noiseReductionStrength: Float       // UI value 0.0-1.0
    var noiseReductionAttenLimitDB: Float   // engine-native value, for reproducibility
    var deEssAmount: Float                  // 0.0-1.0
    var presenceAmount: Float               // 0.0-1.0
    var airAmount: Float                    // 0.0-1.0
    var compressionPreset: CompressionPreset
    var targetLUFS: Float
    var truePeakCeiling: Float
    var outputBitDepth: Int

    init(
        highPassCutoff: Float,
        noiseReductionStrength: Float,
        noiseReductionAttenLimitDB: Float,
        deEssAmount: Float,
        presenceAmount: Float = 0.25,
        airAmount: Float = 0.15,
        compressionPreset: CompressionPreset,
        targetLUFS: Float,
        truePeakCeiling: Float,
        outputBitDepth: Int
    ) {
        self.highPassCutoff = highPassCutoff
        self.noiseReductionStrength = noiseReductionStrength
        self.noiseReductionAttenLimitDB = noiseReductionAttenLimitDB
        self.deEssAmount = deEssAmount
        self.presenceAmount = presenceAmount
        self.airAmount = airAmount
        self.compressionPreset = compressionPreset
        self.targetLUFS = targetLUFS
        self.truePeakCeiling = truePeakCeiling
        self.outputBitDepth = outputBitDepth
    }
}

// MARK: - Preset (plain Swift class, usable without SwiftData)

final class Preset {
    static func attenuationLimitDb(for strength: Float) -> Float {
        let clamped = max(0, min(1, strength))
        return 6.0 + clamped * 24.0
    }

    var id: UUID
    var name: String
    var isBuiltIn: Bool
    var createdAt: Date

    // Processing parameters
    var highPassCutoff: Float          // 60-120 Hz
    var noiseReductionStrength: Float  // 0.0-1.0
    var deEssAmount: Float             // 0.0-1.0
    var presenceAmount: Float          // 0.0-1.0
    var airAmount: Float               // 0.0-1.0
    var compressionPreset: CompressionPreset
    var targetLUFS: Float              // -16 or -14
    var truePeakCeiling: Float         // default -2.0 dBTP
    var outputBitDepth: Int            // 16 or 24

    init(
        name: String,
        isBuiltIn: Bool = false,
        highPassCutoff: Float = 80,
        noiseReductionStrength: Float = 0.35,
        deEssAmount: Float = 0.5,
        presenceAmount: Float = 0.25,
        airAmount: Float = 0.15,
        compressionPreset: CompressionPreset = .medium,
        targetLUFS: Float = -16,
        truePeakCeiling: Float = -2.0,
        outputBitDepth: Int = 24
    ) {
        self.id = UUID()
        self.name = name
        self.isBuiltIn = isBuiltIn
        self.createdAt = Date()
        self.highPassCutoff = highPassCutoff
        self.noiseReductionStrength = noiseReductionStrength
        self.deEssAmount = deEssAmount
        self.presenceAmount = presenceAmount
        self.airAmount = airAmount
        self.compressionPreset = compressionPreset
        self.targetLUFS = targetLUFS
        self.truePeakCeiling = truePeakCeiling
        self.outputBitDepth = outputBitDepth
    }

    func snapshot() -> PresetSnapshot {
        PresetSnapshot(
            highPassCutoff: highPassCutoff,
            noiseReductionStrength: noiseReductionStrength,
            noiseReductionAttenLimitDB: Self.attenuationLimitDb(for: noiseReductionStrength),
            deEssAmount: deEssAmount,
            presenceAmount: presenceAmount,
            airAmount: airAmount,
            compressionPreset: compressionPreset,
            targetLUFS: targetLUFS,
            truePeakCeiling: truePeakCeiling,
            outputBitDepth: outputBitDepth
        )
    }

    // MARK: Built-in presets

    static let builtInPresets: [Preset] = [
        Preset(name: "Podcast Standard", isBuiltIn: true,
               highPassCutoff: 80, noiseReductionStrength: 0.10, deEssAmount: 0.20,
               presenceAmount: 0.30, airAmount: 0.18,
               compressionPreset: .medium, targetLUFS: -16, truePeakCeiling: -2.0, outputBitDepth: 24),
        Preset(name: "YouTube", isBuiltIn: true,
               highPassCutoff: 80, noiseReductionStrength: 0.10, deEssAmount: 0.20,
               presenceAmount: 0.35, airAmount: 0.22,
               compressionPreset: .medium, targetLUFS: -14, truePeakCeiling: -2.0, outputBitDepth: 24),
        Preset(name: "Noisy Environment", isBuiltIn: true,
               highPassCutoff: 100, noiseReductionStrength: 0.35, deEssAmount: 0.25,
               presenceAmount: 0.18, airAmount: 0.10,
               compressionPreset: .heavy, targetLUFS: -16, truePeakCeiling: -2.0, outputBitDepth: 24),
        Preset(name: "Minimal", isBuiltIn: true,
               highPassCutoff: 60, noiseReductionStrength: 0.0, deEssAmount: 0.10,
               presenceAmount: 0.20, airAmount: 0.12,
               compressionPreset: .gentle, targetLUFS: -16, truePeakCeiling: -2.0, outputBitDepth: 24),
    ]
}
