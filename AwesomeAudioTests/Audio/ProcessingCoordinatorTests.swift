import Testing
import Foundation
@testable import AwesomeAudio

@Suite("ProcessingCoordinator")
struct ProcessingCoordinatorTests {

    @Test func twentyFourBitProcessProducesCenteredUnclippedOutput() async throws {
        let coordinator = ProcessingCoordinator()
        let input = AudioTestHelpers.sineWave(
            frequency: 997,
            sampleRate: 48_000,
            duration: 2.0,
            amplitude: 0.5
        )
        let audioInfo = AudioTestHelpers.makeAudioFileInfo(samples: input)
        let preset = PresetSnapshot(
            highPassCutoff: 60,
            noiseReductionStrength: 0.0,
            noiseReductionAttenLimitDB: 0.0,
            deEssAmount: 0.0,
            compressionPreset: .gentle,
            targetLUFS: -16.0,
            truePeakCeiling: -1.0,
            outputBitDepth: 24
        )

        let result = try await coordinator.process(
            audioInfo: audioInfo,
            preset: preset,
            progress: { _ in }
        )
        defer { try? FileManager.default.removeItem(at: result.tempOutputURL) }

        let decoded = try AudioTestHelpers.readMonoFloatSamples(from: result.tempOutputURL)
        let mean = AudioTestHelpers.mean(decoded)
        let clipped = AudioTestHelpers.clippedSampleFraction(decoded)

        #expect(abs(mean) < 0.001, "Processed output should not introduce measurable DC offset, got \(mean)")
        #expect(clipped == 0, "Processed 24-bit output should not clip any samples, got \(clipped * 100)% clipped")
    }
}
