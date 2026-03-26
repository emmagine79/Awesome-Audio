import Foundation
import Accelerate

/// Feed-forward compressor with soft knee and lookahead.
///
/// Signal flow per sample:
///   1. Input sample written into circular lookahead buffer.
///   2. Level detection on current input (in dB).
///   3. Gain curve applied (soft knee + integrated makeup).
///   4. Gain smoothed via attack/release envelope follower.
///   5. Delayed sample (from lookahead buffer) multiplied by smoothed gain.
///
/// The auto makeup gain is integrated into the gain curve so that signals below the
/// knee receive 0 dB total gain change (unity), while signals above threshold receive
/// gain reduction partially offset by the makeup amount.
final class Compressor: StreamingProcessor {

    // MARK: - StreamingProcessor

    let sampleRate: Double = 48000
    let latencySamples: Int = 144   // 3 ms at 48 kHz

    // MARK: - Parameters

    private let threshold: Float    // dBFS
    private let ratio: Float
    private let attackCoeff: Float
    private let releaseCoeff: Float
    private let makeupGainDb: Float // stored for gain curve use

    // Soft knee half-width in dB
    private let halfKneeDb: Float = 3.0   // total knee = 6 dB

    // MARK: - State

    /// Circular lookahead buffer (latencySamples elements).
    private var lookaheadBuffer: [Float]
    private var writeIndex: Int = 0

    /// Smoothed gain in dB (0 = no change, negative = attenuation).
    private var envelopeDb: Float = 0.0

    // MARK: - Init

    init(preset: CompressionPreset) {
        threshold = preset.threshold
        ratio     = preset.ratio

        // exp(-1 / (timeMs × 0.001 × 48000))
        attackCoeff  = exp(-1.0 / (preset.attackMs  * 0.001 * 48000))
        releaseCoeff = exp(-1.0 / (preset.releaseMs * 0.001 * 48000))

        // Auto makeup: -threshold × (1 - 1/ratio) / 2
        makeupGainDb = -preset.threshold * (1.0 - 1.0 / preset.ratio) / 2.0

        lookaheadBuffer = [Float](repeating: 0, count: 144)
    }

    // MARK: - StreamingProcessor

    func process(_ buffer: UnsafeMutablePointer<Float>, frameCount: Int) {
        for i in 0..<frameCount {
            let inputSample = buffer[i]

            // Write current sample into lookahead ring buffer
            lookaheadBuffer[writeIndex] = inputSample

            // Level detection (dBFS)
            let absInput = abs(inputSample)
            let inputDb  = 20.0 * log10(max(absInput, 1e-10))

            // Gain curve: returns total gain change in dB (0 below knee)
            let targetGainDb = gainCurve(inputDb: inputDb)

            // Envelope follower: attack when gain drops, release when gain rises
            if targetGainDb < envelopeDb {
                envelopeDb = attackCoeff  * envelopeDb + (1.0 - attackCoeff)  * targetGainDb
            } else {
                envelopeDb = releaseCoeff * envelopeDb + (1.0 - releaseCoeff) * targetGainDb
            }

            // Read the oldest sample from the lookahead delay line
            let readIndex = (writeIndex + 1) % latencySamples
            let delayedSample = lookaheadBuffer[readIndex]

            // Apply smoothed gain
            let gainLinear = pow(10.0, envelopeDb / 20.0)
            buffer[i] = delayedSample * gainLinear

            writeIndex = (writeIndex + 1) % latencySamples
        }
    }

    func reset() {
        lookaheadBuffer = [Float](repeating: 0, count: latencySamples)
        writeIndex = 0
        envelopeDb = 0.0
    }

    // MARK: - Gain curve

    /// Computes the total gain change in dB for the given input level.
    ///
    /// Returns 0 for signals below the soft knee. For compressed signals, returns
    /// (gain reduction + makeup gain). The makeup gain is included so that the
    /// curve is continuous and below-threshold signals pass at unity (0 dB).
    ///
    /// Soft-knee formula (Audio EQ Cookbook):
    ///   if 2(x − T) < −W  → 0
    ///   if 2|x − T| ≤ W   → (1/R − 1)(x − T + W/2)² / (2W)
    ///   if 2(x − T) > W   → (x − T)(1/R − 1)
    /// where T = threshold, W = knee width, R = ratio.
    /// Makeup is then added for the above-threshold portion and blended in knee.
    private func gainCurve(inputDb: Float) -> Float {
        let lowerKnee = threshold - halfKneeDb
        let upperKnee = threshold + halfKneeDb
        let kneeWidth = halfKneeDb * 2.0   // = 6 dB

        if inputDb <= lowerKnee {
            // Below knee: unity (no gain change)
            return 0.0
        } else if inputDb >= upperKnee {
            // Above knee: full compression + full makeup
            let reductionDb = (inputDb - threshold) * (1.0 - 1.0 / ratio)
            return -reductionDb + makeupGainDb
        } else {
            // Soft-knee region: blend [0 … 1] of full compression + makeup
            // alpha goes 0 → 1 as inputDb goes lowerKnee → upperKnee
            let alpha = (inputDb - lowerKnee) / kneeWidth       // 0..1
            // Quadratic soft-knee gain reduction (partial compression)
            let softReductionDb = (inputDb - lowerKnee) * (inputDb - lowerKnee) /
                                  (2.0 * kneeWidth) * (1.0 - 1.0 / ratio)
            // Blend makeup proportionally (0 at lower edge, makeupGainDb at upper edge)
            let blendedMakeup = alpha * makeupGainDb
            return -softReductionDb + blendedMakeup
        }
    }
}
