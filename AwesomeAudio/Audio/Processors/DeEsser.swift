import Accelerate
import Foundation

/// Split-band dynamic EQ de-esser with lookahead.
///
/// Architecture:
/// - A bandpass biquad at 6500 Hz (Q = 2) extracts the sidechain detection signal.
/// - An envelope follower (attack 0.5 ms, release 20 ms) tracks energy in that band.
/// - When the envelope exceeds a threshold, the sibilant band is attenuated by up to
///   `−6 dB × amount`.
/// - A 96-sample (2 ms) lookahead buffer delays the main signal so gain reduction
///   is applied precisely at the onset of sibilance, not after it.
///
/// Latency: 96 samples.
final class DeEsser: StreamingProcessor {

    // MARK: - StreamingProcessor

    let sampleRate: Double = 48000
    let latencySamples: Int = 96

    // MARK: - Constants

    private static let lookaheadLength = 96
    private static let sidechainFrequency: Double = 6500
    private static let sidechainQ: Double = 2.0
    private static let attackMs: Double = 0.5
    private static let releaseMs: Double = 20.0
    private static let maxReductionDb: Float = 1.5

    // MARK: - Configuration

    /// Reduction depth. 0.0 = no processing, 1.0 = full −6 dB max reduction.
    private let amount: Float

    // MARK: - DSP State

    private var sidechainBiquad: vDSP.Biquad<Float>
    private let sidechainCoefficients: [Double]
    private var envelope: Float = 0
    private let attackCoeff: Float
    private let releaseCoeff: Float

    /// Threshold above which gain reduction begins (linear amplitude).
    private let threshold: Float

    /// Maximum gain reduction in linear amplitude.
    private let maxReductionLinear: Float

    /// FIFO lookahead delay for the main signal (96 samples).
    private var lookaheadBuffer: [Float]
    private var lookaheadWriteIndex: Int = 0

    // MARK: - Init

    init(amount: Float) {
        self.amount = max(0, min(1, amount))

        // Biquad bandpass coefficients for 6500 Hz, Q=2, at 48 kHz
        // Using standard bandpass (0 dB peak) formulation:
        //   w0 = 2π·f/fs,  α = sin(w0)/(2·Q)
        //   b0 =  α,  b1 = 0,  b2 = −α
        //   a0 = 1 + α,  a1 = −2·cos(w0),  a2 = 1 − α
        // vDSP.Biquad expects [b0/a0, b1/a0, b2/a0, a1/a0, a2/a0]
        let w0 = 2.0 * Double.pi * DeEsser.sidechainFrequency / 48000.0
        let alpha = sin(w0) / (2.0 * DeEsser.sidechainQ)
        let cosw0 = cos(w0)
        let a0 = 1.0 + alpha
        let b0 =  alpha / a0
        let b1 =  0.0
        let b2 = -alpha / a0
        let a1 = (-2.0 * cosw0) / a0
        let a2 = (1.0 - alpha) / a0

        sidechainCoefficients = [b0, b1, b2, a1, a2]
        sidechainBiquad = vDSP.Biquad<Float>(
            coefficients: sidechainCoefficients,
            channelCount: 1,
            sectionCount: 1,
            ofType: Float.self
        )!

        // Envelope follower time constants
        let sr = 48000.0
        attackCoeff  = Float(exp(-1.0 / (DeEsser.attackMs  * 0.001 * sr)))
        releaseCoeff = Float(exp(-1.0 / (DeEsser.releaseMs * 0.001 * sr)))

        // Threshold: roughly −15 dBFS. This keeps the de-esser from biting into
        // general brightness on otherwise clean spoken-word material.
        threshold = 0.24

        // Maximum linear gain reduction (e.g. −6 dB = 0.5 linear)
        let maxDb = DeEsser.maxReductionDb * self.amount
        maxReductionLinear = pow(10.0, -maxDb / 20.0)

        // Lookahead FIFO initialised to silence
        lookaheadBuffer = [Float](repeating: 0, count: DeEsser.lookaheadLength)
        lookaheadWriteIndex = 0
    }

    // MARK: - Processing

    func process(_ buffer: UnsafeMutablePointer<Float>, frameCount: Int) {
        for i in 0..<frameCount {
            let inputSample = buffer[i]

            // --- Sidechain: filter sample through bandpass biquad ---
            let sidechainSample = sidechainBiquad.apply(input: [inputSample])[0]

            // --- Envelope follower (half-wave rectified peak follower) ---
            let absLevel = abs(sidechainSample)
            if absLevel > envelope {
                envelope = attackCoeff  * envelope + (1.0 - attackCoeff)  * absLevel
            } else {
                envelope = releaseCoeff * envelope + (1.0 - releaseCoeff) * absLevel
            }

            // --- Compute gain reduction ---
            let gainReduction: Float
            if amount == 0 || envelope <= threshold {
                gainReduction = 1.0
            } else {
                // Smooth gain reduction proportional to how far above threshold
                let excess = (envelope - threshold) / threshold  // 0…∞
                let depth = min(excess, 1.0)                     // clamp to [0, 1]
                gainReduction = 1.0 - depth * (1.0 - maxReductionLinear)
            }

            // --- Lookahead delay ---
            // Read the oldest sample from the FIFO (this is what we output)
            let delayedSample = lookaheadBuffer[lookaheadWriteIndex]

            // Write the current input into the FIFO
            lookaheadBuffer[lookaheadWriteIndex] = inputSample
            lookaheadWriteIndex = (lookaheadWriteIndex + 1) % DeEsser.lookaheadLength

            // --- Apply gain reduction to the delayed (lookahead-compensated) sample ---
            buffer[i] = delayedSample * gainReduction
        }
    }

    func reset() {
        sidechainBiquad = vDSP.Biquad<Float>(
            coefficients: sidechainCoefficients,
            channelCount: 1,
            sectionCount: 1,
            ofType: Float.self
        ) ?? sidechainBiquad
        envelope = 0
        lookaheadBuffer = [Float](repeating: 0, count: DeEsser.lookaheadLength)
        lookaheadWriteIndex = 0
    }
}
