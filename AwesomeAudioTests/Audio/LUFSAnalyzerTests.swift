import Testing
import Foundation
@testable import AwesomeAudio

@Suite("LUFSAnalyzer")
struct LUFSAnalyzerTests {

    // MARK: - Reasonable Result

    @Test func lufsAnalyzerProducesReasonableResult() {
        // 1 kHz sine at amplitude 0.5 for 2 seconds at 48000 Hz
        let samples = AudioTestHelpers.sineWave(
            frequency: 1000,
            sampleRate: 48000,
            duration: 2.0,
            amplitude: 0.5
        )

        let analyzer = LUFSAnalyzer()
        samples.withUnsafeBufferPointer { ptr in
            analyzer.analyze(ptr.baseAddress!, frameCount: ptr.count)
        }
        let result = analyzer.finalize()

        // EBU R128 integrated loudness must be negative and within a sane range
        #expect(result.measuredLUFS < 0,
                "Integrated LUFS should be negative, got \(result.measuredLUFS)")
        #expect(result.measuredLUFS > -30,
                "LUFS for a 0.5-amplitude sine should be louder than -30, got \(result.measuredLUFS)")
        #expect(result.measuredLUFS < 0,
                "LUFS must be below 0 LUFS for a sub-unity signal, got \(result.measuredLUFS)")

        // True peak of a 0.5-amplitude sine should be around -6 dBTP
        #expect(result.measuredTruePeak < 0,
                "True peak should be negative dBTP for a 0.5-amplitude sine, got \(result.measuredTruePeak)")
        #expect(result.measuredTruePeak > -20,
                "True peak should be above -20 dBTP for a 0.5-amplitude sine, got \(result.measuredTruePeak)")
    }

    // MARK: - Reset Allows Reuse

    @Test func lufsAnalyzerResetAllowsReuse() {
        let analyzer = LUFSAnalyzer()

        // Loud signal: amplitude 0.9 for 3 seconds
        let loudSamples = AudioTestHelpers.sineWave(
            frequency: 1000,
            sampleRate: 48000,
            duration: 3.0,
            amplitude: 0.9
        )
        loudSamples.withUnsafeBufferPointer { ptr in
            analyzer.analyze(ptr.baseAddress!, frameCount: ptr.count)
        }
        let loudResult = analyzer.finalize()

        analyzer.reset()

        // Quiet signal: amplitude 0.05 for 3 seconds
        let quietSamples = AudioTestHelpers.sineWave(
            frequency: 1000,
            sampleRate: 48000,
            duration: 3.0,
            amplitude: 0.05
        )
        quietSamples.withUnsafeBufferPointer { ptr in
            analyzer.analyze(ptr.baseAddress!, frameCount: ptr.count)
        }
        let quietResult = analyzer.finalize()

        #expect(quietResult.measuredLUFS < loudResult.measuredLUFS,
                "Quiet signal (\(quietResult.measuredLUFS) LUFS) should measure lower than loud signal (\(loudResult.measuredLUFS) LUFS)")
    }
}
