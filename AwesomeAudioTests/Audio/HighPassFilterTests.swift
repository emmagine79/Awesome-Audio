import Testing
import Foundation
@testable import AwesomeAudio

@Suite("HighPassFilter")
struct HighPassFilterTests {

    // MARK: - Properties

    @Test func sampleRateIs48000() {
        let hpf = HighPassFilter()
        #expect(hpf.sampleRate == 48000)
    }

    @Test func latencySamplesIsZero() {
        let hpf = HighPassFilter()
        #expect(hpf.latencySamples == 0)
    }

    // MARK: - Frequency Response

    @Test func lowFrequencyIsAttenuated() {
        // 40 Hz sine through 80 Hz HPF should be attenuated by more than 6 dB
        let hpf = HighPassFilter(cutoffHz: 80)
        var input = AudioTestHelpers.sineWave(frequency: 40, sampleRate: 48000, duration: 1.0)
        let inputRms = AudioTestHelpers.rms(input)

        input.withUnsafeMutableBufferPointer { ptr in
            hpf.process(ptr.baseAddress!, frameCount: ptr.count)
        }

        let outputRms = AudioTestHelpers.rms(input)
        let attenuationDb = AudioTestHelpers.linearToDb(inputRms) - AudioTestHelpers.linearToDb(outputRms)
        #expect(attenuationDb > 6.0, "Expected >6dB attenuation at 40Hz, got \(attenuationDb)dB")
    }

    @Test func highFrequencyPasses() {
        // 1000 Hz sine through 80 Hz HPF should pass within 0.5 dB
        let hpf = HighPassFilter(cutoffHz: 80)

        // Warm up filter with identical signal to avoid transient effects
        var warmup = AudioTestHelpers.sineWave(frequency: 1000, sampleRate: 48000, duration: 0.1)
        warmup.withUnsafeMutableBufferPointer { ptr in
            hpf.process(ptr.baseAddress!, frameCount: ptr.count)
        }

        var input = AudioTestHelpers.sineWave(frequency: 1000, sampleRate: 48000, duration: 1.0)
        let inputRms = AudioTestHelpers.rms(input)

        input.withUnsafeMutableBufferPointer { ptr in
            hpf.process(ptr.baseAddress!, frameCount: ptr.count)
        }

        let outputRms = AudioTestHelpers.rms(input)
        let attenuationDb = abs(AudioTestHelpers.linearToDb(outputRms) - AudioTestHelpers.linearToDb(inputRms))
        #expect(attenuationDb < 0.5, "Expected <0.5dB loss at 1000Hz, got \(attenuationDb)dB")
    }

    // MARK: - Reset

    @Test func resetRestoresFilterState() {
        // Process some signal to build up filter state
        let hpf = HighPassFilter(cutoffHz: 80)
        var noise = AudioTestHelpers.sineWave(frequency: 40, sampleRate: 48000, duration: 0.5)
        noise.withUnsafeMutableBufferPointer { ptr in
            hpf.process(ptr.baseAddress!, frameCount: ptr.count)
        }

        // Reset and process a reference signal
        hpf.reset()
        var afterReset = AudioTestHelpers.sineWave(frequency: 1000, sampleRate: 48000, duration: 0.1)
        afterReset.withUnsafeMutableBufferPointer { ptr in
            hpf.process(ptr.baseAddress!, frameCount: ptr.count)
        }

        // Fresh instance should produce identical output for the same input
        let freshHpf = HighPassFilter(cutoffHz: 80)
        var freshInput = AudioTestHelpers.sineWave(frequency: 1000, sampleRate: 48000, duration: 0.1)
        freshInput.withUnsafeMutableBufferPointer { ptr in
            freshHpf.process(ptr.baseAddress!, frameCount: ptr.count)
        }

        // Compare RMS of outputs — should be within 0.01 dB
        let resetRms = AudioTestHelpers.rms(afterReset)
        let freshRms = AudioTestHelpers.rms(freshInput)
        let diffDb = abs(AudioTestHelpers.linearToDb(resetRms) - AudioTestHelpers.linearToDb(freshRms))
        #expect(diffDb < 0.01, "After reset, output should match fresh instance within 0.01dB, got \(diffDb)dB")
    }
}
