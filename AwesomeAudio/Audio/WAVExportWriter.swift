import AVFoundation
import Foundation

final class WAVExportWriter {
    private let file: AVAudioFile
    private let processingFormat: AVAudioFormat

    init(url: URL, sampleRate: Double = 48_000, bitDepth: Int) throws {
        guard bitDepth == 16 || bitDepth == 24 else {
            throw ProcessingError.processingFailed(
                stage: "WAVExportWriter init",
                underlying: NSError(domain: "AwesomeAudio", code: -10, userInfo: [
                    NSLocalizedDescriptionKey: "Unsupported WAV bit depth \(bitDepth)"
                ])
            )
        }

        guard let processingFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw ProcessingError.engineInitFailed
        }

        let fileSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: bitDepth,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]

        self.processingFormat = processingFormat
        self.file = try AVAudioFile(
            forWriting: url,
            settings: fileSettings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
    }

    func append(samples: UnsafePointer<Float>, frameCount: Int) throws {
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: processingFormat,
            frameCapacity: AVAudioFrameCount(frameCount)
        ) else {
            throw ProcessingError.processingFailed(
                stage: "WAVExportWriter append",
                underlying: NSError(domain: "AwesomeAudio", code: -11)
            )
        }

        buffer.frameLength = AVAudioFrameCount(frameCount)
        if let channel = buffer.floatChannelData?[0] {
            channel.update(from: samples, count: frameCount)
        }

        try file.write(from: buffer)
    }
}
