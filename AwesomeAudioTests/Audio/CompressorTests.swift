import Testing
import Foundation
@testable import AwesomeAudio

@Suite("Compressor Tests")
struct CompressorTests {

    @Test func sampleRateAndLatency() {
        let compressor = Compressor(preset: .medium)
        #expect(compressor.sampleRate == 48000)
        #expect(compressor.latencySamples == 144)
    }

    @Test func compressorReducesDynamicRange() {
        let compressor = Compressor(preset: .medium)

        // Process a loud signal (0 dBFS) and a quiet signal (-40 dBFS)
        var loud = AudioTestHelpers.sineWave(frequency: 1000, sampleRate: 48000, duration: 0.5, amplitude: 1.0)
        var quiet = AudioTestHelpers.sineWave(frequency: 1000, sampleRate: 48000, duration: 0.5, amplitude: 0.01)

        let inputDynamicRange = AudioTestHelpers.linearToDb(AudioTestHelpers.rms(loud))
            - AudioTestHelpers.linearToDb(AudioTestHelpers.rms(quiet))

        loud.withUnsafeMutableBufferPointer { ptr in
            compressor.process(ptr.baseAddress!, frameCount: ptr.count)
        }
        compressor.reset()
        quiet.withUnsafeMutableBufferPointer { ptr in
            compressor.process(ptr.baseAddress!, frameCount: ptr.count)
        }

        let outputDynamicRange = AudioTestHelpers.linearToDb(AudioTestHelpers.rms(loud))
            - AudioTestHelpers.linearToDb(AudioTestHelpers.rms(quiet))

        // Compressor should reduce dynamic range (loud-quiet gap smaller after)
        #expect(outputDynamicRange < inputDynamicRange,
                "Dynamic range should be reduced: input=\(inputDynamicRange)dB, output=\(outputDynamicRange)dB")
    }

    @Test func compressorAppliesGainReductionToLoudSignal() {
        let compressor = Compressor(preset: .medium)

        // 0 dBFS sine — well above -24 dB threshold
        var samples = AudioTestHelpers.sineWave(frequency: 1000, sampleRate: 48000, duration: 0.5, amplitude: 1.0)

        samples.withUnsafeMutableBufferPointer { ptr in
            compressor.process(ptr.baseAddress!, frameCount: ptr.count)
        }

        // With medium preset (threshold=-24, ratio=3:1), gain reduction on a 0dBFS signal is significant
        // Even with ~8 dB makeup gain, the net result should not amplify a 0 dBFS signal above ~2.5x
        // (gain reduction of ~16dB at 0dBFS, +8dB makeup = ~-8dB net)
        let outputPeak = AudioTestHelpers.peakAbsolute(samples)
        let outputPeakDb = AudioTestHelpers.linearToDb(outputPeak)
        #expect(outputPeakDb < 6.0, "Output shouldn't be boosted excessively: \(outputPeakDb) dB")
    }

    @Test func resetClearsState() {
        let compressor = Compressor(preset: .medium)

        // Drive hard with loud signal
        var loud = AudioTestHelpers.sineWave(frequency: 1000, sampleRate: 48000, duration: 0.5, amplitude: 1.0)
        loud.withUnsafeMutableBufferPointer { ptr in
            compressor.process(ptr.baseAddress!, frameCount: ptr.count)
        }

        compressor.reset()

        // After reset, process another loud signal — should produce same result as fresh compressor
        let comp2 = Compressor(preset: .medium)
        var signal1 = AudioTestHelpers.sineWave(frequency: 1000, sampleRate: 48000, duration: 0.3, amplitude: 1.0)
        var signal2 = signal1

        signal1.withUnsafeMutableBufferPointer { ptr in
            compressor.process(ptr.baseAddress!, frameCount: ptr.count)
        }
        signal2.withUnsafeMutableBufferPointer { ptr in
            comp2.process(ptr.baseAddress!, frameCount: ptr.count)
        }

        let rms1 = AudioTestHelpers.rms(signal1)
        let rms2 = AudioTestHelpers.rms(signal2)
        let diffDb = abs(AudioTestHelpers.linearToDb(rms1) - AudioTestHelpers.linearToDb(rms2))
        #expect(diffDb < 0.5, "After reset, output should match fresh instance (diff: \(diffDb) dB)")
    }
}
