import Testing
import Foundation
@testable import AwesomeAudio

@Suite("TruePeakLimiter")
struct TruePeakLimiterTests {

    // MARK: - Test 1: Protocol conformance

    @Test func conformsToStreamingProcessor() {
        let limiter = TruePeakLimiter(ceilingDbTP: -1.0)
        #expect(limiter.sampleRate == 48000)
        #expect(limiter.latencySamples == 240)
    }

    // MARK: - Test 2: 0 dBFS sine → output true peak ≤ -0.9 dBTP

    @Test func zeroDbusSineIsClamped() {
        let limiter = TruePeakLimiter(ceilingDbTP: -1.0)

        // Warm up lookahead / gain-smoothing with 1s of signal
        var warmup = AudioTestHelpers.sineWave(frequency: 1000, sampleRate: 48000, duration: 1.0, amplitude: 1.0)
        warmup.withUnsafeMutableBufferPointer { ptr in
            limiter.process(ptr.baseAddress!, frameCount: ptr.count)
        }

        // Measure: 0 dBFS sine, output peak must be ≤ -0.9 dBTP
        var signal = AudioTestHelpers.sineWave(frequency: 997, sampleRate: 48000, duration: 1.0, amplitude: 1.0)
        signal.withUnsafeMutableBufferPointer { ptr in
            limiter.process(ptr.baseAddress!, frameCount: ptr.count)
        }

        let peakLinear = AudioTestHelpers.peakAbsolute(signal)
        let peakDb = AudioTestHelpers.linearToDb(peakLinear)
        #expect(peakDb <= -0.9, "0 dBFS sine must be limited to ≤ -0.9 dBTP, got \(peakDb) dB")
    }

    // MARK: - Test 3: -20 dBFS sine passes within 0.1 dB

    @Test func quietSignalPassesUntouched() {
        let limiter = TruePeakLimiter(ceilingDbTP: -1.0)
        let amplitude: Float = pow(10.0, -20.0 / 20.0)  // -20 dBFS ≈ 0.1

        // Warm up
        var warmup = AudioTestHelpers.sineWave(frequency: 1000, sampleRate: 48000, duration: 0.5, amplitude: amplitude)
        warmup.withUnsafeMutableBufferPointer { ptr in
            limiter.process(ptr.baseAddress!, frameCount: ptr.count)
        }

        var signal = AudioTestHelpers.sineWave(frequency: 1000, sampleRate: 48000, duration: 1.0, amplitude: amplitude)
        let inputRms = AudioTestHelpers.rms(signal)

        signal.withUnsafeMutableBufferPointer { ptr in
            limiter.process(ptr.baseAddress!, frameCount: ptr.count)
        }

        let outputRms = AudioTestHelpers.rms(signal)
        let diffDb = abs(AudioTestHelpers.linearToDb(outputRms) - AudioTestHelpers.linearToDb(inputRms))
        #expect(diffDb < 0.1, "-20 dBFS sine must pass within 0.1 dB, got diff \(diffDb) dB")
    }

    // MARK: - Test 4: reset clears state

    @Test func resetClearsState() {
        let limiter = TruePeakLimiter(ceilingDbTP: -1.0)

        // Drive limiter hard with 0 dBFS signal
        var loud = AudioTestHelpers.sineWave(frequency: 1000, sampleRate: 48000, duration: 0.5, amplitude: 1.0)
        loud.withUnsafeMutableBufferPointer { ptr in
            limiter.process(ptr.baseAddress!, frameCount: ptr.count)
        }

        // Reset, then pass a quiet signal; it should come through cleanly
        limiter.reset()

        let amplitude: Float = pow(10.0, -20.0 / 20.0)
        var signal = AudioTestHelpers.sineWave(frequency: 1000, sampleRate: 48000, duration: 0.5, amplitude: amplitude)
        let inputRms = AudioTestHelpers.rms(signal)

        signal.withUnsafeMutableBufferPointer { ptr in
            limiter.process(ptr.baseAddress!, frameCount: ptr.count)
        }

        let outputRms = AudioTestHelpers.rms(signal)
        let diffDb = abs(AudioTestHelpers.linearToDb(outputRms) - AudioTestHelpers.linearToDb(inputRms))
        #expect(diffDb < 0.5, "After reset, quiet signal must pass cleanly, got diff \(diffDb) dB")
    }
}
