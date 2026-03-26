import Foundation

/// Triangular Probability Density Function (TPDF) ditherer.
///
/// Adds spectrally flat triangular noise at an amplitude of ±1 LSB of the target
/// bit depth before quantisation. The triangular distribution is formed by summing
/// two independent uniform random values, each in [−0.5, 0.5].
///
/// This is a utility — it does **not** conform to `StreamingProcessor`.
/// Typical use: insert between the last floating-point processor and the final
/// integer sample encoder when exporting to 16-bit or 24-bit PCM.
final class TPDFDitherer {

    // MARK: - Configuration

    /// Target bit depth (16 or 24 are typical values).
    let targetBitDepth: Int

    // MARK: - Private state

    /// Amplitude of one LSB at the target bit depth.
    ///
    /// For a signed integer PCM range of ±1.0 full scale:
    ///   LSB amplitude = 1 / 2^(bitDepth − 1)
    private let amplitude: Float

    // MARK: - Init

    /// - Parameter targetBitDepth: Bit depth of the destination format (e.g. 16 or 24).
    init(targetBitDepth: Int) {
        self.targetBitDepth = targetBitDepth
        self.amplitude = 1.0 / Float(1 << (targetBitDepth - 1))
    }

    // MARK: - Processing

    /// Adds TPDF dither noise to every sample in `buffer` in place.
    ///
    /// Each sample receives a noise value drawn from the triangular distribution:
    ///   noise = (r1 + r2) × amplitude,  where r1, r2 ∈ [−0.5, 0.5]
    ///
    /// - Parameters:
    ///   - buffer: Pointer to interleaved (mono) float samples, modified in place.
    ///   - frameCount: Number of samples to process.
    func apply(_ buffer: UnsafeMutablePointer<Float>, frameCount: Int) {
        for i in 0..<frameCount {
            let r1 = Float.random(in: -0.5...0.5)
            let r2 = Float.random(in: -0.5...0.5)
            buffer[i] += (r1 + r2) * amplitude
        }
    }
}
