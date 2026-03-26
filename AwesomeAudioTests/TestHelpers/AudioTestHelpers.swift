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

    static func speechLikeFixture(sampleRate: Float = 48_000, duration: Float = 2.0) -> [Float] {
        let sampleCount = Int(sampleRate * duration)
        var samples = [Float](repeating: 0, count: sampleCount)

        let lowFundamental: Float = 180
        let midHarmonic: Float = 540
        let presenceHarmonic: Float = 2_700
        let sibilance: Float = 6_800

        for i in 0..<sampleCount {
            let time = Float(i) / sampleRate

            let phraseEnvelope = 0.45 + 0.35 * max(0, sin(2.0 * .pi * 1.7 * time))
            let syllablePulse = 0.55 + 0.45 * max(0, sin(2.0 * .pi * 4.8 * time))
            let envelope = phraseEnvelope * syllablePulse

            let base =
                0.34 * sin(2.0 * .pi * lowFundamental * time) +
                0.16 * sin(2.0 * .pi * midHarmonic * time) +
                0.08 * sin(2.0 * .pi * presenceHarmonic * time)

            let sibilanceGate = pow(max(0, sin(2.0 * .pi * 7.0 * time)), 6)
            let brightBurst = 0.18 * sibilanceGate * sin(2.0 * .pi * sibilance * time)

            samples[i] = envelope * (base + brightBurst)
        }

        return samples
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

    static func spectralBandEnergy(
        _ samples: [Float],
        sampleRate: Float = 48_000,
        lowHz: Float,
        highHz: Float,
        probeStepHz: Float = 250
    ) -> Float {
        guard !samples.isEmpty, highHz >= lowHz else { return 0 }

        var total: Float = 0
        var frequency = max(lowHz, probeStepHz)
        while frequency <= highHz {
            total += toneEnergy(samples, sampleRate: sampleRate, frequency: frequency)
            frequency += probeStepHz
        }
        return total
    }

    static func bandEnergyRatio(
        _ samples: [Float],
        sampleRate: Float = 48_000,
        numerator: ClosedRange<Float>,
        denominator: ClosedRange<Float>
    ) -> Float {
        let numeratorEnergy = spectralBandEnergy(
            samples,
            sampleRate: sampleRate,
            lowHz: numerator.lowerBound,
            highHz: numerator.upperBound
        )
        let denominatorEnergy = spectralBandEnergy(
            samples,
            sampleRate: sampleRate,
            lowHz: denominator.lowerBound,
            highHz: denominator.upperBound
        )

        guard denominatorEnergy > 0 else { return 0 }
        return numeratorEnergy / denominatorEnergy
    }

    static func analyze(_ samples: [Float]) -> AnalysisResult {
        let analyzer = LUFSAnalyzer()
        samples.withUnsafeBufferPointer { ptr in
            guard let base = ptr.baseAddress else { return }
            analyzer.analyze(base, frameCount: ptr.count)
        }
        return analyzer.finalize()
    }

    static func audioMetadata(for url: URL) throws -> (sampleRate: Double, channelCount: Int, bitDepth: Int) {
        let file = try AVAudioFile(forReading: url)
        return (
            sampleRate: file.processingFormat.sampleRate,
            channelCount: Int(file.processingFormat.channelCount),
            bitDepth: Int(file.fileFormat.streamDescription.pointee.mBitsPerChannel)
        )
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

    private static func toneEnergy(_ samples: [Float], sampleRate: Float, frequency: Float) -> Float {
        let angleScale = 2.0 * Float.pi * frequency / sampleRate
        var cosineProjection: Float = 0
        var sineProjection: Float = 0

        for i in samples.indices {
            let phase = angleScale * Float(i)
            let sample = samples[i]
            cosineProjection += sample * cos(phase)
            sineProjection += sample * sin(phase)
        }

        let normalized = 2.0 / Float(samples.count)
        return (cosineProjection * cosineProjection + sineProjection * sineProjection) * normalized * normalized
    }
}
