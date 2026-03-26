import Foundation

struct AnalysisResult {
    let measuredLUFS: Float
    let measuredTruePeak: Float
}

struct ProcessingProgress: Sendable {
    let stageName: String
    let fractionComplete: Double
    let passNumber: Int
}

enum ProcessingError: LocalizedError {
    case unsupportedFormat(String)
    case fileTooShort
    case insufficientDiskSpace(needed: UInt64, available: UInt64)
    case outputNotWritable(URL)
    case engineInitFailed
    case processingFailed(stage: String, underlying: Error)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let ext):
            return "This file format isn't supported (\(ext)). Use WAV, MP3, M4A, or AIFF."
        case .fileTooShort:
            return "This file is too short to process (minimum 1 second)."
        case .insufficientDiskSpace(let needed, let available):
            let neededGB = String(format: "%.1f", Double(needed) / 1_073_741_824)
            let availGB = String(format: "%.1f", Double(available) / 1_073_741_824)
            return "Not enough disk space. Need \(neededGB) GB, only \(availGB) GB available."
        case .outputNotWritable(let url):
            return "Can't write to \(url.lastPathComponent). Choose a different folder."
        case .engineInitFailed:
            return "Audio processing engine failed to initialize. Try restarting the app."
        case .processingFailed(let stage, _):
            return "Processing failed at \(stage). Original file is unchanged."
        case .cancelled:
            return "Processing was cancelled."
        }
    }
}
