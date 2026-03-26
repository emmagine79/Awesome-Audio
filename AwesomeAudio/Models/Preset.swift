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
    var compressionPreset: CompressionPreset
    var targetLUFS: Float
    var truePeakCeiling: Float
    var outputBitDepth: Int
}

// MARK: - Preset (plain Swift class, usable without SwiftData)

final class Preset {
    var id: UUID
    var name: String
    var isBuiltIn: Bool
    var createdAt: Date

    // Processing parameters
    var highPassCutoff: Float          // 60-120 Hz
    var noiseReductionStrength: Float  // 0.0-1.0
    var deEssAmount: Float             // 0.0-1.0
    var compressionPreset: CompressionPreset
    var targetLUFS: Float              // -16 or -14
    var truePeakCeiling: Float         // default -1.0 dBTP
    var outputBitDepth: Int            // 16 or 24

    init(
        name: String,
        isBuiltIn: Bool = false,
        highPassCutoff: Float = 80,
        noiseReductionStrength: Float = 0.7,
        deEssAmount: Float = 0.5,
        compressionPreset: CompressionPreset = .medium,
        targetLUFS: Float = -16,
        truePeakCeiling: Float = -1.0,
        outputBitDepth: Int = 24
    ) {
        self.id = UUID()
        self.name = name
        self.isBuiltIn = isBuiltIn
        self.createdAt = Date()
        self.highPassCutoff = highPassCutoff
        self.noiseReductionStrength = noiseReductionStrength
        self.deEssAmount = deEssAmount
        self.compressionPreset = compressionPreset
        self.targetLUFS = targetLUFS
        self.truePeakCeiling = truePeakCeiling
        self.outputBitDepth = outputBitDepth
    }

    func snapshot() -> PresetSnapshot {
        PresetSnapshot(
            highPassCutoff: highPassCutoff,
            noiseReductionStrength: noiseReductionStrength,
            noiseReductionAttenLimitDB: noiseReductionStrength * 100.0,
            deEssAmount: deEssAmount,
            compressionPreset: compressionPreset,
            targetLUFS: targetLUFS,
            truePeakCeiling: truePeakCeiling,
            outputBitDepth: outputBitDepth
        )
    }

    // MARK: Built-in presets

    static let builtInPresets: [Preset] = [
        Preset(name: "Podcast Standard", isBuiltIn: true,
               highPassCutoff: 80, noiseReductionStrength: 0.7, deEssAmount: 0.5,
               compressionPreset: .medium, targetLUFS: -16, outputBitDepth: 24),
        Preset(name: "YouTube", isBuiltIn: true,
               highPassCutoff: 80, noiseReductionStrength: 0.7, deEssAmount: 0.5,
               compressionPreset: .medium, targetLUFS: -14, outputBitDepth: 24),
        Preset(name: "Noisy Environment", isBuiltIn: true,
               highPassCutoff: 100, noiseReductionStrength: 0.9, deEssAmount: 0.4,
               compressionPreset: .heavy, targetLUFS: -16, outputBitDepth: 24),
        Preset(name: "Minimal", isBuiltIn: true,
               highPassCutoff: 60, noiseReductionStrength: 0.3, deEssAmount: 0.3,
               compressionPreset: .gentle, targetLUFS: -16, outputBitDepth: 24),
    ]
}
