import Testing
import Foundation
@testable import AwesomeAudio

@Suite("ToneShaperTests")
struct ToneShaperTests {

    @Test func presenceAndAirLiftIncreaseUpperBandEnergy() {
        let input = AudioTestHelpers.speechLikeFixture(duration: 2.0)
        let beforeRatio = AudioTestHelpers.bandEnergyRatio(
            input,
            numerator: 2_000...10_000,
            denominator: 80...2_000
        )

        let shaper = ToneShaper(presenceAmount: 0.5, airAmount: 0.5)
        var processed = input
        processed.withUnsafeMutableBufferPointer { ptr in
            guard let base = ptr.baseAddress else { return }
            shaper.process(base, frameCount: ptr.count)
        }

        let afterRatio = AudioTestHelpers.bandEnergyRatio(
            processed,
            numerator: 2_000...10_000,
            denominator: 80...2_000
        )

        #expect(afterRatio > beforeRatio, "Tone shaping should increase upper-band energy. Before \(beforeRatio), after \(afterRatio)")
    }

    @Test func silenceRemainsSilent() {
        let shaper = ToneShaper(presenceAmount: 0.6, airAmount: 0.6)
        var processed = AudioTestHelpers.silence(duration: 1.0)

        processed.withUnsafeMutableBufferPointer { ptr in
            guard let base = ptr.baseAddress else { return }
            shaper.process(base, frameCount: ptr.count)
        }

        #expect(AudioTestHelpers.peakAbsolute(processed) == 0)
    }

    @Test func toneShapingPreservesCenteredSignal() {
        let shaper = ToneShaper(presenceAmount: 0.35, airAmount: 0.35)
        var processed = AudioTestHelpers.sineWave(
            frequency: 997,
            sampleRate: 48_000,
            duration: 1.0,
            amplitude: 0.4
        )

        processed.withUnsafeMutableBufferPointer { ptr in
            guard let base = ptr.baseAddress else { return }
            shaper.process(base, frameCount: ptr.count)
        }

        #expect(abs(AudioTestHelpers.mean(processed)) < 0.001)
        #expect(AudioTestHelpers.clippedSampleFraction(processed) == 0)
    }
}
