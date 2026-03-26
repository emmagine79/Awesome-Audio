import Foundation
import Accelerate
import AVFoundation
@testable import AwesomeAudio

enum AudioTestHelpers {
    static func sineWave(frequency: Float, sampleRate: Float = 48000, duration: Float = 1.0, amplitude: Float = 1.0) -> [Float] {
        let sampleCount = Int(sampleRate * duration)
        var samples = [Float](repeating: 0, count: sampleCount)
        let angularFrequency = 2.0 * Float.pi * frequency / sampleRate
        for i in 0..<sampleCount {
            samples[i] = amplitude * sin(angularFrequency * Float(i))
        }
        return samples
    }

    static func whiteNoise(sampleRate: Float = 48000, duration: Float = 1.0, amplitude: Float = 0.1) -> [Float] {
        let sampleCount = Int(sampleRate * duration)
        return (0..<sampleCount).map { _ in Float.random(in: -amplitude...amplitude) }
    }

    static func silence(sampleRate: Float = 48000, duration: Float = 1.0) -> [Float] {
        [Float](repeating: 0, count: Int(sampleRate * duration))
    }

    static func rms(_ samples: [Float]) -> Float {
        var result: Float = 0
        vDSP_rmsqv(samples, 1, &result, vDSP_Length(samples.count))
        return result
    }

    static func peakAbsolute(_ samples: [Float]) -> Float {
        var result: Float = 0
        vDSP_maxmgv(samples, 1, &result, vDSP_Length(samples.count))
        return result
    }

    static func mean(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        return samples.reduce(0, +) / Float(samples.count)
    }

    static func clippedSampleFraction(_ samples: [Float], threshold: Float = 0.999_999) -> Float {
        guard !samples.isEmpty else { return 0 }
        let clipped = samples.filter { abs($0) >= threshold }.count
        return Float(clipped) / Float(samples.count)
    }

    static func linearToDb(_ linear: Float) -> Float {
        20 * log10(max(linear, 1e-10))
    }

    static func writeFloatWav(samples: [Float], url: URL, sampleRate: Double = 48_000) throws {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw NSError(domain: "AudioTestHelpers", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Could not create Float32 WAV format"
            ])
        }

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(samples.count)
        ) else {
            throw NSError(domain: "AudioTestHelpers", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Could not create Float32 WAV buffer"
            ])
        }

        buffer.frameLength = AVAudioFrameCount(samples.count)
        if let channel = buffer.floatChannelData?[0] {
            channel.initialize(from: samples, count: samples.count)
        }

        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
    }

    static func readMonoFloatSamples(from url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw NSError(domain: "AudioTestHelpers", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Could not create read buffer"
            ])
        }

        try file.read(into: buffer)

        guard let samples = buffer.floatChannelData?[0] else {
            throw NSError(domain: "AudioTestHelpers", code: 4, userInfo: [
                NSLocalizedDescriptionKey: "Expected Float32 channel data"
            ])
        }

        return Array(UnsafeBufferPointer(start: samples, count: Int(buffer.frameLength)))
    }

    static func makeAudioFileInfo(
        samples: [Float],
        sourceURL: URL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test.wav")
    ) -> AudioFileInfo {
        AudioFileInfo(
            samples: samples,
            sampleRate: 48_000,
            channelCount: 1,
            frameCount: samples.count,
            originalSampleRate: 48_000,
            originalChannelCount: 1,
            originalBitDepth: 32,
            duration: Double(samples.count) / 48_000.0,
            fileSizeBytes: UInt64(samples.count * MemoryLayout<Float>.size),
            sourceURL: sourceURL
        )
    }
}
