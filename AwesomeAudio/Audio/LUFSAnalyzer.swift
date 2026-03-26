import Foundation
import SPFKLoudnessC

/// Measures EBU R128 integrated loudness (LUFS) and true peak of streaming audio.
///
/// Feed audio chunks via `analyze(_:frameCount:)`, then call `finalize()` to
/// read integrated loudness and true peak. Call `reset()` to reuse the analyzer.
///
/// Configured for mono, 48000 Hz audio.
final class LUFSAnalyzer: AudioAnalyzer {

    // MARK: - Constants

    private static let sampleRate: UInt = 48000
    private static let channels: UInt32 = 1

    // MARK: - State

    private var state: UnsafeMutablePointer<ebur128_state>

    // MARK: - Init / Deinit

    init() {
        state = LUFSAnalyzer.makeState()
    }

    deinit {
        destroyState()
    }

    // MARK: - AudioAnalyzer

    func analyze(_ buffer: UnsafePointer<Float>, frameCount: Int) {
        ebur128_add_frames_float(state, buffer, frameCount)
    }

    func finalize() -> AnalysisResult {
        var integratedLoudness: Double = 0
        ebur128_loudness_global(state, &integratedLoudness)

        var truePeakLinear: Double = 0
        ebur128_true_peak(state, 0, &truePeakLinear)
        let truePeakDBTP = truePeakLinear > 0
            ? 20.0 * log10(truePeakLinear)
            : -Double.infinity

        return AnalysisResult(
            measuredLUFS: Float(integratedLoudness),
            measuredTruePeak: Float(truePeakDBTP)
        )
    }

    func reset() {
        destroyState()
        state = LUFSAnalyzer.makeState()
    }

    // MARK: - Private Helpers

    private static func makeState() -> UnsafeMutablePointer<ebur128_state> {
        let mode = Int32(EBUR128_MODE_I.rawValue | EBUR128_MODE_TRUE_PEAK.rawValue)
        guard let st = ebur128_init(channels, sampleRate, mode) else {
            fatalError("LUFSAnalyzer: ebur128_init failed — out of memory")
        }
        return st
    }

    private func destroyState() {
        var mutableState: UnsafeMutablePointer<ebur128_state>? = state
        ebur128_destroy(&mutableState)
    }
}
