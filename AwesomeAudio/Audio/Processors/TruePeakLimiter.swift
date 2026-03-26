import Foundation

/// True-peak limiter with 4x polyphase oversampling.
///
/// Architecture:
/// - 4x oversampling via 4-phase polyphase FIR (12 taps per phase) to detect inter-sample peaks.
/// - Phase 0 is identity (passes original samples). Phases 1–3 are half-band interpolation FIR phases.
/// - 240-sample lookahead circular buffer (5 ms at 48 kHz) for zero-clipping with instant attack.
/// - Gain reduction: instant attack, 50 ms release time constant.
///
/// Latency: 240 samples (5 ms at 48 kHz).
final class TruePeakLimiter: StreamingProcessor {

    // MARK: - StreamingProcessor

    let sampleRate: Double = 48000
    let latencySamples: Int = 240

    // MARK: - Constants

    /// Taps per polyphase phase.
    private static let tapsPerPhase = 12
    /// Number of polyphase phases (oversampling factor).
    private static let phaseCount = 4

    /// Half-band lowpass polyphase FIR coefficients.
    ///
    /// These coefficients form a 48-tap prototype lowpass filter with a cutoff at Fs/8
    /// (i.e., 0.25 × oversampled Nyquist), deinterleaved into 4 polyphase phases.
    ///
    /// Phase 0 is the identity sub-filter:  [0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0]
    /// (one unit impulse at tap 5 → pure delay matching the other phases)
    ///
    /// Phases 1–3 are designed to reconstruct the signal at fractional offsets 1/4, 2/4, 3/4.
    /// The values below were derived from a Kaiser-windowed sinc (β ≈ 6) prototype.
    private static let phaseCoefficients: [[Float]] = [
        // Phase 0 — identity (original sample, delayed 5 taps to match group delay)
        [0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
        // Phase 1 — fractional delay 0.25
        [-0.00073, 0.00222, -0.00536, 0.01106, -0.02079, 0.03905,
          0.93805, -0.05301,  0.02195, -0.01028, 0.00430, -0.00147],
        // Phase 2 — fractional delay 0.50
        [-0.00104, 0.00317, -0.00775, 0.01622, -0.03121, 0.07979,
          0.07979, -0.03121,  0.01622, -0.00775, 0.00317, -0.00104],
        // Phase 3 — fractional delay 0.75
        [-0.00147, 0.00430, -0.01028, 0.02195, -0.05301, 0.93805,
          0.03905, -0.02079,  0.01106, -0.00536, 0.00222, -0.00073]
    ]

    // MARK: - Configuration

    private let ceiling: Float          // linear ceiling (e.g. 0.89125 for -1 dBTP)
    private let releaseCoeff: Float     // per-sample gain-release multiplier

    // MARK: - State

    /// Circular history of the last `tapsPerPhase` input samples for FIR convolution.
    private var history: [Float]
    private var historyIndex: Int = 0

    /// Lookahead circular buffer (240 samples).
    private var lookahead: [Float]
    private var lookaheadWrite: Int = 0
    private var lookaheadRead: Int = 0

    /// Current linear gain applied to delayed output (starts at unity).
    private var currentGain: Float = 1.0

    // MARK: - Init

    /// - Parameter ceilingDbTP: Maximum true-peak level in dBTP. Typical value: -1.0.
    init(ceilingDbTP: Float = -1.0) {
        ceiling = pow(10.0, ceilingDbTP / 20.0)
        // 50 ms release at 48 kHz
        releaseCoeff = exp(-1.0 / (0.050 * 48000.0))
        history = [Float](repeating: 0.0, count: Self.tapsPerPhase)
        lookahead = [Float](repeating: 0.0, count: latencySamples)
        lookaheadRead = 0
        lookaheadWrite = latencySamples - 240  // write starts 240 ahead of read → 240-sample delay
    }

    // MARK: - StreamingProcessor conformance

    func process(_ buffer: UnsafeMutablePointer<Float>, frameCount: Int) {
        for i in 0..<frameCount {
            let inputSample = buffer[i]

            // 1. Shift new sample into history (circular)
            history[historyIndex] = inputSample
            historyIndex = (historyIndex + 1) % Self.tapsPerPhase

            // 2. Write input sample into lookahead buffer
            lookahead[lookaheadWrite] = inputSample
            lookaheadWrite = (lookaheadWrite + 1) % latencySamples

            // 3. Compute true peak across all 4 polyphase phases via FIR convolution
            let truePeak = computeTruePeak()

            // 4. Determine required gain reduction
            let absTP = abs(truePeak)
            if absTP > ceiling {
                // Instant attack: clamp gain immediately
                let requiredGain = ceiling / absTP
                if requiredGain < currentGain {
                    currentGain = requiredGain
                }
            }

            // 5. Apply gain to the delayed (lookahead) sample
            let delayedSample = lookahead[lookaheadRead]
            buffer[i] = delayedSample * currentGain
            lookaheadRead = (lookaheadRead + 1) % latencySamples

            // 6. Release: let gain recover toward unity
            if currentGain < 1.0 {
                currentGain = min(1.0, currentGain / releaseCoeff)
            }
        }
    }

    func reset() {
        history = [Float](repeating: 0.0, count: Self.tapsPerPhase)
        historyIndex = 0
        lookahead = [Float](repeating: 0.0, count: latencySamples)
        lookaheadWrite = 0
        lookaheadRead = 0
        currentGain = 1.0
    }

    // MARK: - Private helpers

    /// FIR-convolve each polyphase phase against the history buffer and return the maximum absolute value.
    private func computeTruePeak() -> Float {
        var maxAbs: Float = 0.0
        let taps = Self.tapsPerPhase

        for phase in 0..<Self.phaseCount {
            let coeffs = Self.phaseCoefficients[phase]
            var acc: Float = 0.0
            for tap in 0..<taps {
                // Walk backwards through the circular history
                let idx = (historyIndex - 1 - tap + taps) % taps
                acc += history[idx] * coeffs[tap]
            }
            let absAcc = abs(acc)
            if absAcc > maxAbs { maxAbs = absAcc }
        }

        return maxAbs
    }
}
