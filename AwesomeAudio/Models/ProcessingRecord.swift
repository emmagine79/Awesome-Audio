import Foundation

final class ProcessingRecord {
    var id: UUID
    var timestamp: Date
    var inputFileName: String
    var inputFileBookmark: Data?
    var outputFileName: String?
    var outputFileBookmark: Data?
    var presetName: String
    private var presetSnapshotData: Data

    var beforeLUFS: Float
    var afterLUFS: Float
    var beforeTruePeak: Float
    var afterTruePeak: Float
    var processingDurationSeconds: Double

    init(
        inputFileName: String,
        presetName: String,
        presetSnapshot: PresetSnapshot,
        beforeLUFS: Float,
        afterLUFS: Float,
        beforeTruePeak: Float,
        afterTruePeak: Float,
        processingDurationSeconds: Double
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.inputFileName = inputFileName
        self.presetName = presetName
        self.presetSnapshotData = (try? JSONEncoder().encode(presetSnapshot)) ?? Data()
        self.beforeLUFS = beforeLUFS
        self.afterLUFS = afterLUFS
        self.beforeTruePeak = beforeTruePeak
        self.afterTruePeak = afterTruePeak
        self.processingDurationSeconds = processingDurationSeconds
    }

    var presetSnapshot: PresetSnapshot? {
        try? JSONDecoder().decode(PresetSnapshot.self, from: presetSnapshotData)
    }
}
