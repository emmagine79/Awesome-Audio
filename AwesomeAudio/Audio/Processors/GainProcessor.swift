import Accelerate
import Foundation

/// Applies a static gain computed from LUFS analysis to normalize loudness.
///
/// Conforms to `AnalysisDerivedProcessor`. After `configure(from:)` is called,
/// every `process(_:frameCount:)` call multiplies all samples by a fixed linear
/// gain derived from the formula:
///
///     gainDb = targetLUFS − measuredLUFS + overshootLU
///
/// `reset()` returns the processor to unity gain (0 dB).
final class GainProcessor: AnalysisDerivedProcessor {

    // MARK: - StreamingProcessor

    let sampleRate: Double = 48000
    let latencySamples: Int = 0

    // MARK: - Private State

    private var gainLinear: Float = 1.0

    // MARK: - Configuration

    /// Configures gain using default podcast targets: −16 LUFS with 0.3 LU overshoot.
    func configure(from result: AnalysisResult) {
        configure(from: result, targetLUFS: -16.0, overshootLU: 0.3)
    }

    /// Configures gain with explicit target and overshoot values.
    ///
    /// - Parameters:
    ///   - result: Analysis result containing the measured integrated LUFS.
    ///   - targetLUFS: Desired output loudness in LUFS (e.g. −16).
    ///   - overshootLU: Additional gain in LU applied on top of the target (e.g. 0.3).
    func configure(from result: AnalysisResult, targetLUFS: Float, overshootLU: Float) {
        let gainDb = targetLUFS - result.measuredLUFS + overshootLU
        gainLinear = pow(10.0, gainDb / 20.0)
    }

    // MARK: - Processing

    func process(_ buffer: UnsafeMutablePointer<Float>, frameCount: Int) {
        var scalar = gainLinear
        vDSP_vsmul(buffer, 1, &scalar, buffer, 1, vDSP_Length(frameCount))
    }

    func reset() {
        gainLinear = 1.0
    }
}
