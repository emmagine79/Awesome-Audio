import Testing
import Foundation
@testable import AwesomeAudio

@Suite("WAVExportWriter")
struct WAVExportWriterTests {

    @Test func twentyFourBitRoundTripPreservesCenteredUnclippedSignal() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")
        defer { try? FileManager.default.removeItem(at: url) }

        let input = AudioTestHelpers.sineWave(
            frequency: 997,
            sampleRate: 48_000,
            duration: 2.0,
            amplitude: 0.5
        )

        do {
            let writer = try WAVExportWriter(url: url, bitDepth: 24)
            try input.withUnsafeBufferPointer { ptr in
                guard let base = ptr.baseAddress else { return }
                try writer.append(samples: base, frameCount: ptr.count)
            }
        }

        let decoded = try AudioTestHelpers.readMonoFloatSamples(from: url)
        let mean = AudioTestHelpers.mean(decoded)
        let clipped = AudioTestHelpers.clippedSampleFraction(decoded)
        let peakDb = AudioTestHelpers.linearToDb(AudioTestHelpers.peakAbsolute(decoded))

        #expect(abs(mean) < 0.001, "24-bit export should not introduce measurable DC offset, got \(mean)")
        #expect(clipped == 0, "24-bit export should not clip any samples, got \(clipped * 100)% clipped")
        #expect(peakDb < -0.5, "24-bit export should keep a 0.5-amplitude sine safely below full scale, got \(peakDb) dBFS")
    }

    @Test func sixteenBitRoundTripPreservesCenteredUnclippedSignal() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")
        defer { try? FileManager.default.removeItem(at: url) }

        let input = AudioTestHelpers.sineWave(
            frequency: 997,
            sampleRate: 48_000,
            duration: 2.0,
            amplitude: 0.5
        )

        do {
            let writer = try WAVExportWriter(url: url, bitDepth: 16)
            try input.withUnsafeBufferPointer { ptr in
                guard let base = ptr.baseAddress else { return }
                try writer.append(samples: base, frameCount: ptr.count)
            }
        }

        let decoded = try AudioTestHelpers.readMonoFloatSamples(from: url)
        let mean = AudioTestHelpers.mean(decoded)
        let clipped = AudioTestHelpers.clippedSampleFraction(decoded)

        #expect(abs(mean) < 0.001, "16-bit export should not introduce measurable DC offset, got \(mean)")
        #expect(clipped == 0, "16-bit export should not clip any samples, got \(clipped * 100)% clipped")
    }
}
