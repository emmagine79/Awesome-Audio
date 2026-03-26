import Testing
import Foundation
@testable import AwesomeAudio

@Suite("GainProcessor")
struct GainProcessorTests {

    // MARK: - Protocol Conformance

    @Test func conformsToAnalysisDerivedProcessor() {
        let processor = GainProcessor()
        let _: any AnalysisDerivedProcessor = processor
        #expect(processor.sampleRate == 48000)
        #expect(processor.latencySamples == 0)
    }

    // MARK: - Gain Calculation

    @Test func gainCalculationFromLUFSMeasurement() {
        // measuredLUFS=-23, target=-16, overshoot=0.3 → gainDb = -16 - (-23) + 0.3 = +7.3dB
        let processor = GainProcessor()
        let result = AnalysisResult(measuredLUFS: -23.0, measuredTruePeak: -1.0)
        processor.configure(from: result, targetLUFS: -16.0, overshootLU: 0.3)

        // Verify by measuring output RMS vs input RMS
        let inputSamples = AudioTestHelpers.sineWave(frequency: 1000, sampleRate: 48000, duration: 1.0, amplitude: 0.5)
        let inputRms = AudioTestHelpers.rms(inputSamples)

        var output = inputSamples
        output.withUnsafeMutableBufferPointer { ptr in
            processor.process(ptr.baseAddress!, frameCount: ptr.count)
        }

        let outputRms = AudioTestHelpers.rms(output)
        let actualGainDb = AudioTestHelpers.linearToDb(outputRms) - AudioTestHelpers.linearToDb(inputRms)
        let expectedGainDb: Float = 7.3

        #expect(abs(actualGainDb - expectedGainDb) < 0.1,
                "Expected gain of +\(expectedGainDb)dB, got \(actualGainDb)dB")
    }

    // MARK: - Zero Gain Passthrough

    @Test func zeroGainIsPassthrough() {
        // When measured and target LUFS match, output should equal input
        let processor = GainProcessor()
        let result = AnalysisResult(measuredLUFS: -16.0, measuredTruePeak: -1.0)
        processor.configure(from: result, targetLUFS: -16.0, overshootLU: 0.0)

        let inputSamples = AudioTestHelpers.sineWave(frequency: 1000, sampleRate: 48000, duration: 1.0, amplitude: 0.5)
        var output = inputSamples

        output.withUnsafeMutableBufferPointer { ptr in
            processor.process(ptr.baseAddress!, frameCount: ptr.count)
        }

        // Each sample should be identical
        for (i, (original, processed)) in zip(inputSamples, output).enumerated() {
            #expect(abs(original - processed) < 1e-6,
                    "Sample \(i): expected \(original), got \(processed)")
            if abs(original - processed) >= 1e-6 { break }
        }
    }

    // MARK: - Default configure(from:) Uses targetLUFS=-16 and overshootLU=0.3

    @Test func defaultConfigureUsesExpectedDefaults() {
        let processor = GainProcessor()
        // measuredLUFS=-23 → gainDb = -16 - (-23) + 0.3 = +7.3dB
        let result = AnalysisResult(measuredLUFS: -23.0, measuredTruePeak: -1.0)
        processor.configure(from: result)

        let inputSamples = AudioTestHelpers.sineWave(frequency: 1000, sampleRate: 48000, duration: 1.0, amplitude: 0.5)
        let inputRms = AudioTestHelpers.rms(inputSamples)

        var output = inputSamples
        output.withUnsafeMutableBufferPointer { ptr in
            processor.process(ptr.baseAddress!, frameCount: ptr.count)
        }

        let outputRms = AudioTestHelpers.rms(output)
        let actualGainDb = AudioTestHelpers.linearToDb(outputRms) - AudioTestHelpers.linearToDb(inputRms)
        #expect(abs(actualGainDb - 7.3) < 0.1,
                "Default configure should yield +7.3dB, got \(actualGainDb)dB")
    }

    // MARK: - Reset

    @Test func resetRestoresUnityGain() {
        let processor = GainProcessor()
        let result = AnalysisResult(measuredLUFS: -30.0, measuredTruePeak: -1.0)
        processor.configure(from: result)
        processor.reset()

        let inputSamples = AudioTestHelpers.sineWave(frequency: 1000, sampleRate: 48000, duration: 1.0, amplitude: 0.5)
        var output = inputSamples

        output.withUnsafeMutableBufferPointer { ptr in
            processor.process(ptr.baseAddress!, frameCount: ptr.count)
        }

        let inputRms = AudioTestHelpers.rms(inputSamples)
        let outputRms = AudioTestHelpers.rms(output)
        let gainDb = abs(AudioTestHelpers.linearToDb(outputRms) - AudioTestHelpers.linearToDb(inputRms))
        #expect(gainDb < 0.01, "After reset, gain should be 0dB (unity), got \(gainDb)dB")
    }
}
