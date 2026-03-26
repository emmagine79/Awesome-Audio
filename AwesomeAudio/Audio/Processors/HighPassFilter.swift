import Accelerate
import Foundation

/// 2nd-order Butterworth high-pass filter implemented as a biquad section.
///
/// Uses `vDSP.Biquad` from the Accelerate framework for SIMD-accelerated processing.
/// Cutoff frequency and Q are fixed at construction time; call `reset()` to clear
/// internal filter state without changing the cutoff.
final class HighPassFilter: StreamingProcessor {

    // MARK: - StreamingProcessor

    let sampleRate: Double = 48000
    let latencySamples: Int = 0

    // MARK: - Private state

    private let cutoffHz: Float
    private let q: Float
    private var biquad: vDSP.Biquad<Float>

    // MARK: - Init

    /// Creates a high-pass filter.
    /// - Parameters:
    ///   - cutoffHz: -3 dB cutoff frequency in Hz. Default: 80 Hz.
    ///   - q: Quality factor (resonance). Default: 1/√2 ≈ 0.7071 (Butterworth maximally-flat).
    init(cutoffHz: Float = 80, q: Float = 0.7071) {
        self.cutoffHz = cutoffHz
        self.q = q
        self.biquad = Self.makeBiquad(cutoffHz: cutoffHz, q: q, sampleRate: 48000)
    }

    // MARK: - StreamingProcessor conformance

    func process(_ buffer: UnsafeMutablePointer<Float>, frameCount: Int) {
        let input = Array(UnsafeBufferPointer(start: buffer, count: frameCount))
        let output = biquad.apply(input: input)
        buffer.update(from: output, count: frameCount)
    }

    func reset() {
        biquad = Self.makeBiquad(cutoffHz: cutoffHz, q: q, sampleRate: 48000)
    }

    // MARK: - Private helpers

    /// Compute normalised biquad coefficients for a 2nd-order Butterworth HPF.
    ///
    /// Standard Audio EQ Cookbook formulation (Robert Bristow-Johnson):
    /// ```
    /// w0    = 2π × f0 / Fs
    /// alpha = sin(w0) / (2×Q)
    /// b0    =  (1 + cos(w0)) / 2
    /// b1    = -(1 + cos(w0))
    /// b2    =  (1 + cos(w0)) / 2
    /// a0    =   1 + alpha
    /// a1    =  -2 × cos(w0)
    /// a2    =   1 - alpha
    /// ```
    /// All coefficients are divided by a0 before being passed to `vDSP.Biquad`.
    private static func makeBiquad(cutoffHz: Float, q: Float, sampleRate: Float) -> vDSP.Biquad<Float> {
        let w0    = 2.0 * Float.pi * cutoffHz / sampleRate
        let sinW0 = sin(w0)
        let cosW0 = cos(w0)
        let alpha = sinW0 / (2.0 * q)

        let b0 =  (1.0 + cosW0) / 2.0
        let b1 = -(1.0 + cosW0)
        let b2 =  (1.0 + cosW0) / 2.0
        let a0 =   1.0 + alpha
        let a1 =  -2.0 * cosW0
        let a2 =   1.0 - alpha

        // vDSP.Biquad expects [b0, b1, b2, a1, a2] normalised by a0
        let coefficients: [Double] = [
            Double(b0 / a0),
            Double(b1 / a0),
            Double(b2 / a0),
            Double(a1 / a0),
            Double(a2 / a0)
        ]

        // sections: 1 biquad section
        return vDSP.Biquad<Float>(coefficients: coefficients, channelCount: 1, sectionCount: 1, ofType: Float.self)!
    }
}
