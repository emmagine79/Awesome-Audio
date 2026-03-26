import Testing
import Foundation
@testable import AwesomeAudio

@Suite("Compressor Tests")
struct CompressorTests {

    // MARK: - Test 1: Basic properties

    @Test func sampleRateAndLatency() {
        let compressor = Compressor(preset: .medium)
        #expect(compressor.sampleRate == 48000)
        #expect(compressor.latencySamples == 144)
    }

    // MARK: - Test 2: 0 dBFS sine → output peak < input peak

    @Test func loudSignalIsAttenuated() {
        let compressor = Compressor(preset: .medium)

        // 0 dBFS sine wave (amplitude = 1.0)
        var samples = AudioTestHelpers.sineWave(frequency: 1000, sampleRate: 48000, duration: 1.0, amplitude: 1.0)
        let inputPeak = AudioTestHelpers.peakAbsolute(samples)

        samples.withUnsafeMutableBufferPointer { ptr in
            compressor.process(ptr.baseAddress!, frameCount: ptr.count)
        }

        let outputPeak = AudioTestHelpers.peakAbsolute(samples)
        #expect(outputPeak < inputPeak, "Compressor must attenuate a 0 dBFS signal")
    }

    // MARK: - Test 3: -40 dBFS sine → passes within 1 dB

    @Test func quietSignalPassesUntouched() {
        let compressor = Compressor(preset: .medium)

        // medium threshold = -24 dBFS; -40 dBFS is well below threshold
        let amplitude: Float = pow(10, -40.0 / 20.0)   // ≈ 0.01
        var samples = AudioTestHelpers.sineWave(frequency: 1000, sampleRate: 48000, duration: 1.0, amplitude: amplitude)
        let inputRMS = AudioTestHelpers.rms(samples)

        samples.withUnsafeMutableBufferPointer { ptr in
            compressor.process(ptr.baseAddress!, frameCount: ptr.count)
        }

        let outputRMS = AudioTestHelpers.rms(samples)
        let diffDb = abs(AudioTestHelpers.linearToDb(outputRMS) - AudioTestHelpers.linearToDb(inputRMS))
        #expect(diffDb <= 1.0, "Quiet signal below threshold must pass within 1 dB (diff: \(diffDb) dB)")
    }

    // MARK: - Test 4: reset clears state so quiet signal after loud passes cleanly

    @Test func resetClearsState() {
        let compressor = Compressor(preset: .medium)

        // Drive the compressor hard with a 0 dBFS signal
        var loud = AudioTestHelpers.sineWave(frequency: 1000, sampleRate: 48000, duration: 0.5, amplitude: 1.0)
        loud.withUnsafeMutableBufferPointer { ptr in
            compressor.process(ptr.baseAddress!, frameCount: ptr.count)
        }

        // Reset, then send a quiet signal (-40 dBFS)
        compressor.reset()

        let amplitude: Float = pow(10, -40.0 / 20.0)
        var quiet = AudioTestHelpers.sineWave(frequency: 1000, sampleRate: 48000, duration: 1.0, amplitude: amplitude)
        let inputRMS = AudioTestHelpers.rms(quiet)

        quiet.withUnsafeMutableBufferPointer { ptr in
            compressor.process(ptr.baseAddress!, frameCount: ptr.count)
        }

        let outputRMS = AudioTestHelpers.rms(quiet)
        let diffDb = abs(AudioTestHelpers.linearToDb(outputRMS) - AudioTestHelpers.linearToDb(inputRMS))
        #expect(diffDb <= 1.0, "After reset, quiet signal must pass cleanly (diff: \(diffDb) dB)")
    }
}
