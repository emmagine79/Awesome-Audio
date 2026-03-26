// This file is compiled only by the Xcode app target, NOT the SPM library.
// It wraps ProcessingRecord as a SwiftData @Model for persistence.
import Foundation
import SwiftData

@Model
final class ProcessingRecordModel {
    var id: UUID
    var createdAt: Date

    // Source file info
    var sourceURLBookmark: Data?
    var outputURLBookmark: Data?
    var sourceFilename: String
    var outputFilename: String

    // Before/after loudness measurements
    var beforeLUFS: Float
    var beforeTruePeak: Float
    var afterLUFS: Float
    var afterTruePeak: Float

    // Processing duration
    var processingDurationSeconds: Double

    // Serialized preset snapshot
    var presetSnapshotData: Data?

    init(
        sourceFilename: String,
        outputFilename: String,
        beforeLUFS: Float,
        beforeTruePeak: Float,
        afterLUFS: Float,
        afterTruePeak: Float,
        processingDurationSeconds: Double,
        presetSnapshot: PresetSnapshot? = nil
    ) {
        self.id = UUID()
        self.createdAt = Date()
        self.sourceFilename = sourceFilename
        self.outputFilename = outputFilename
        self.beforeLUFS = beforeLUFS
        self.beforeTruePeak = beforeTruePeak
        self.afterLUFS = afterLUFS
        self.afterTruePeak = afterTruePeak
        self.processingDurationSeconds = processingDurationSeconds
        if let snapshot = presetSnapshot {
            self.presetSnapshotData = try? JSONEncoder().encode(snapshot)
        }
    }

    var presetSnapshot: PresetSnapshot? {
        guard let data = presetSnapshotData else { return nil }
        return try? JSONDecoder().decode(PresetSnapshot.self, from: data)
    }
}
