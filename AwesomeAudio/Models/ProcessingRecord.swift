import Foundation

// MARK: - ProcessingRecord (plain Swift class, usable without SwiftData)
// The SwiftData @Model wrapper lives in AwesomeAudio/AppLayer/ProcessingRecordModel.swift
// and is only compiled into the Xcode app target.

final class ProcessingRecord {
    let id: UUID
    let createdAt: Date

    // Source file info
    let sourceURL: URL
    let outputURL: URL
    let sourceFilename: String
    let outputFilename: String

    // Before/after loudness measurements
    let beforeLUFS: Float
    let beforeTruePeak: Float
    let afterLUFS: Float
    let afterTruePeak: Float

    // Processing duration
    let processingDurationSeconds: Double

    // Serialized preset used for this run
    private let presetSnapshotData: Data?

    init(
        sourceURL: URL,
        outputURL: URL,
        beforeLUFS: Float,
        beforeTruePeak: Float,
        afterLUFS: Float,
        afterTruePeak: Float,
        processingDurationSeconds: Double,
        presetSnapshot: PresetSnapshot? = nil
    ) {
        self.id = UUID()
        self.createdAt = Date()
        self.sourceURL = sourceURL
        self.outputURL = outputURL
        self.sourceFilename = sourceURL.lastPathComponent
        self.outputFilename = outputURL.lastPathComponent
        self.beforeLUFS = beforeLUFS
        self.beforeTruePeak = beforeTruePeak
        self.afterLUFS = afterLUFS
        self.afterTruePeak = afterTruePeak
        self.processingDurationSeconds = processingDurationSeconds
        self.presetSnapshotData = presetSnapshot.flatMap { try? JSONEncoder().encode($0) }
    }

    /// Decodes the stored preset snapshot, if present.
    var presetSnapshot: PresetSnapshot? {
        guard let data = presetSnapshotData else { return nil }
        return try? JSONDecoder().decode(PresetSnapshot.self, from: data)
    }
}
