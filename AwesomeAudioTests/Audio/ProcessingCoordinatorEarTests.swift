import Testing
import Foundation
@testable import AwesomeAudio

@Suite("ProcessingCoordinatorEarTests")
struct ProcessingCoordinatorEarTests {

    @Test func finalLoudnessDoesNotOvershootTarget() async throws {
        let coordinator = ProcessingCoordinator()
        let input = AudioTestHelpers.speechLikeFixture(duration: 2.5)
        let audioInfo = AudioTestHelpers.makeAudioFileInfo(samples: input)
        let preset = PresetSnapshot(
            highPassCutoff: 80,
            noiseReductionStrength: 0.0,
            noiseReductionAttenLimitDB: 0.0,
            deEssAmount: 0.2,
            compressionPreset: .medium,
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

        #expect(
            result.afterLUFS <= preset.targetLUFS + 0.1,
            "Final output should stay near the requested target LUFS without overshoot, got \(result.afterLUFS) LUFS for target \(preset.targetLUFS)"
        )
    }

    @Test func processingRetainsEnoughHighBandEnergy() async throws {
        let coordinator = ProcessingCoordinator()
        let midBand = AudioTestHelpers.sineWave(
            frequency: 440,
            sampleRate: 48_000,
            duration: 2.5,
            amplitude: 0.14
        )
        let sibilance = AudioTestHelpers.sineWave(
            frequency: 6_800,
            sampleRate: 48_000,
            duration: 2.5,
            amplitude: 0.24
        )
        let input = zip(midBand, sibilance).map(+)
        let audioInfo = AudioTestHelpers.makeAudioFileInfo(samples: input)
        let preset = PresetSnapshot(
            highPassCutoff: 80,
            noiseReductionStrength: 1.0,
            noiseReductionAttenLimitDB: 30.0,
            deEssAmount: 1.0,
            compressionPreset: .medium,
            targetLUFS: -16.0,
            truePeakCeiling: -1.0,
            outputBitDepth: 24
        )

        let beforeRatio = AudioTestHelpers.toneEnergyRatio(
            input,
            numeratorFrequency: 6_800,
            denominatorFrequency: 440
        )

        let result = try await coordinator.process(
            audioInfo: audioInfo,
            preset: preset,
            progress: { _ in }
        )
        defer { try? FileManager.default.removeItem(at: result.tempOutputURL) }

        let decoded = try AudioTestHelpers.readMonoFloatSamples(from: result.tempOutputURL)
        let afterRatio = AudioTestHelpers.toneEnergyRatio(
            decoded,
            numeratorFrequency: 6_800,
            denominatorFrequency: 440
        )

        #expect(
            afterRatio >= beforeRatio * 0.45,
            "Processing should retain most of the upper-band detail. Before ratio \(beforeRatio), after ratio \(afterRatio)"
        )
    }
}
