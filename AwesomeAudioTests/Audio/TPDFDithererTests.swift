import Testing
import Foundation
@testable import AwesomeAudio

@Suite("TPDFDitherer")
struct TPDFDithererTests {

    // MARK: - Test 1: 16-bit dither modifies most samples of a quiet signal

    @Test func sixteenBitDitherModifiesSamples() {
        let ditherer = TPDFDitherer(targetBitDepth: 16)

        // Quiet signal near DC (well below noise floor of 16-bit = -96 dBFS ≈ 1.5e-5 linear)
        // Use a constant near-zero value so any dither change is detectable
        let frameCount = 4800
        let original = [Float](repeating: 1.0e-7, count: frameCount)
        var buffer = original

        buffer.withUnsafeMutableBufferPointer { ptr in
            ditherer.apply(ptr.baseAddress!, frameCount: frameCount)
        }

        // Count samples that differ from original
        var changedCount = 0
        for i in 0..<frameCount {
            if buffer[i] != original[i] { changedCount += 1 }
        }

        // At least 90% of samples should be modified by the dither noise
        let ratio = Float(changedCount) / Float(frameCount)
        #expect(ratio > 0.9, "16-bit dither must modify >90% of samples, changed \(ratio * 100)%")
    }

    // MARK: - Test 2: 24-bit dither changes RMS by < 0.01 dB

    @Test func twentyFourBitDitherRmsImpactIsNegligible() {
        let ditherer = TPDFDitherer(targetBitDepth: 24)

        // -20 dBFS sine — well above 24-bit noise floor; dither should be inaudible
        let amplitude: Float = pow(10.0, -20.0 / 20.0)
        var signal = AudioTestHelpers.sineWave(frequency: 1000, sampleRate: 48000, duration: 1.0, amplitude: amplitude)
        let inputRms = AudioTestHelpers.rms(signal)

        signal.withUnsafeMutableBufferPointer { ptr in
            ditherer.apply(ptr.baseAddress!, frameCount: ptr.count)
        }

        let outputRms = AudioTestHelpers.rms(signal)
        let diffDb = abs(AudioTestHelpers.linearToDb(outputRms) - AudioTestHelpers.linearToDb(inputRms))
        #expect(diffDb < 0.01, "24-bit dither must change RMS < 0.01 dB, got \(diffDb) dB")
    }
}
