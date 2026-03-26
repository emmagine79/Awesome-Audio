import Testing
import Foundation
@testable import AwesomeAudio

@Suite("DeEsser")
struct DeEsserTests {

    // MARK: - Protocol Conformance

    @Test func conformsToStreamingProcessor() {
        let deEsser = DeEsser(amount: 0.5)
        let _: any StreamingProcessor = deEsser
        #expect(deEsser.sampleRate == 48000)
        #expect(deEsser.latencySamples == 96)
    }

    // MARK: - Sibilant Attenuation

    @Test func sibilantFrequencyIsAttenuated() {
        // 7kHz sine at amount=1.0 should be attenuated by more than 3dB
        let deEsser = DeEsser(amount: 1.0)

        // Warm up to clear transient
        var warmup = AudioTestHelpers.sineWave(frequency: 7000, sampleRate: 48000, duration: 0.5)
        warmup.withUnsafeMutableBufferPointer { ptr in
            deEsser.process(ptr.baseAddress!, frameCount: ptr.count)
        }

        let inputSamples = AudioTestHelpers.sineWave(frequency: 7000, sampleRate: 48000, duration: 1.0)
        let inputRms = AudioTestHelpers.rms(inputSamples)

        var output = inputSamples
        output.withUnsafeMutableBufferPointer { ptr in
            deEsser.process(ptr.baseAddress!, frameCount: ptr.count)
        }

        // Skip the lookahead delay at the front
        let offset = deEsser.latencySamples
        let outputSlice = Array(output.dropFirst(offset))
        let outputRms = AudioTestHelpers.rms(outputSlice)

        let attenuationDb = AudioTestHelpers.linearToDb(inputRms) - AudioTestHelpers.linearToDb(outputRms)
        #expect(attenuationDb > 3.0, "Expected >3dB attenuation at 7kHz, got \(attenuationDb)dB")
    }

    // MARK: - Non-Sibilant Pass-Through

    @Test func lowFrequencyPassesThrough() {
        // 200Hz sine should pass within 1dB (non-sibilant content)
        let deEsser = DeEsser(amount: 1.0)

        // Warm up
        var warmup = AudioTestHelpers.sineWave(frequency: 200, sampleRate: 48000, duration: 0.5)
        warmup.withUnsafeMutableBufferPointer { ptr in
            deEsser.process(ptr.baseAddress!, frameCount: ptr.count)
        }

        let inputSamples = AudioTestHelpers.sineWave(frequency: 200, sampleRate: 48000, duration: 1.0)
        let inputRms = AudioTestHelpers.rms(inputSamples)

        var output = inputSamples
        output.withUnsafeMutableBufferPointer { ptr in
            deEsser.process(ptr.baseAddress!, frameCount: ptr.count)
        }

        // Skip the lookahead delay at the front
        let offset = deEsser.latencySamples
        let outputSlice = Array(output.dropFirst(offset))
        let outputRms = AudioTestHelpers.rms(outputSlice)

        let attenuationDb = abs(AudioTestHelpers.linearToDb(inputRms) - AudioTestHelpers.linearToDb(outputRms))
        #expect(attenuationDb < 1.0, "Expected <1dB change at 200Hz, got \(attenuationDb)dB")
    }

    // MARK: - Bypass at Amount 0

    @Test func amountZeroIsPassthrough() {
        // amount=0.0 should produce no gain reduction (after accounting for lookahead delay)
        let deEsser = DeEsser(amount: 0.0)

        let inputSamples = AudioTestHelpers.sineWave(frequency: 7000, sampleRate: 48000, duration: 1.0)
        let inputRms = AudioTestHelpers.rms(inputSamples)

        var output = inputSamples
        output.withUnsafeMutableBufferPointer { ptr in
            deEsser.process(ptr.baseAddress!, frameCount: ptr.count)
        }

        // The lookahead delays output by 96 samples — compare RMS excluding the tail
        let offset = deEsser.latencySamples
        let outputSlice = Array(output.dropFirst(offset))
        let outputRms = AudioTestHelpers.rms(outputSlice)

        let attenuationDb = abs(AudioTestHelpers.linearToDb(inputRms) - AudioTestHelpers.linearToDb(outputRms))
        #expect(attenuationDb < 0.5, "Expected <0.5dB change with amount=0.0, got \(attenuationDb)dB")
    }
}
