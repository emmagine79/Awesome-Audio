import Accelerate
import Foundation

/// Gentle tonal shaping for mastering-oriented spoken-word material.
///
/// Adds a modest presence lift around 3.2 kHz and an air shelf around 9.5 kHz.
/// Both stages are optional and stream-safe.
final class ToneShaper: StreamingProcessor {
    let sampleRate: Double = 48_000
    let latencySamples: Int = 0

    private let hasPresenceStage: Bool
    private let hasAirStage: Bool
    private let presenceCoefficients: [Double]
    private let airCoefficients: [Double]
    private var presenceBiquad: vDSP.Biquad<Float>
    private var airBiquad: vDSP.Biquad<Float>

    init(presenceAmount: Float, airAmount: Float) {
        let clampedPresence = max(0, min(1, presenceAmount))
        let clampedAir = max(0, min(1, airAmount))

        hasPresenceStage = clampedPresence > 0.001
        hasAirStage = clampedAir > 0.001

        let presenceGainDb = 4.0 * clampedPresence
        let airGainDb = 5.0 * clampedAir

        presenceCoefficients = Self.makePeakingEQ(
            centerHz: 3_200,
            q: 0.9,
            gainDb: presenceGainDb
        )
        airCoefficients = Self.makeHighShelf(
            cutoffHz: 9_500,
            slope: 0.7,
            gainDb: airGainDb
        )

        presenceBiquad = vDSP.Biquad<Float>(
            coefficients: presenceCoefficients,
            channelCount: 1,
            sectionCount: 1,
            ofType: Float.self
        )!

        airBiquad = vDSP.Biquad<Float>(
            coefficients: airCoefficients,
            channelCount: 1,
            sectionCount: 1,
            ofType: Float.self
        )!
    }

    func process(_ buffer: UnsafeMutablePointer<Float>, frameCount: Int) {
        guard hasPresenceStage || hasAirStage else { return }

        var working = Array(UnsafeBufferPointer(start: buffer, count: frameCount))
        if hasPresenceStage {
            working = presenceBiquad.apply(input: working)
        }
        if hasAirStage {
            working = airBiquad.apply(input: working)
        }

        working.withUnsafeBufferPointer { ptr in
            guard let base = ptr.baseAddress else { return }
            buffer.update(from: base, count: frameCount)
        }
    }

    func reset() {
        presenceBiquad = vDSP.Biquad<Float>(
            coefficients: presenceCoefficients,
            channelCount: 1,
            sectionCount: 1,
            ofType: Float.self
        ) ?? presenceBiquad

        airBiquad = vDSP.Biquad<Float>(
            coefficients: airCoefficients,
            channelCount: 1,
            sectionCount: 1,
            ofType: Float.self
        ) ?? airBiquad
    }

    private static func makePeakingEQ(centerHz: Double, q: Double, gainDb: Float) -> [Double] {
        let gain = pow(10.0, Double(gainDb) / 40.0)
        let omega = 2.0 * Double.pi * centerHz / 48_000.0
        let alpha = sin(omega) / (2.0 * q)
        let cosOmega = cos(omega)

        let b0 = 1.0 + alpha * gain
        let b1 = -2.0 * cosOmega
        let b2 = 1.0 - alpha * gain
        let a0 = 1.0 + alpha / gain
        let a1 = -2.0 * cosOmega
        let a2 = 1.0 - alpha / gain

        return [b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0]
    }

    private static func makeHighShelf(cutoffHz: Double, slope: Double, gainDb: Float) -> [Double] {
        let gain = pow(10.0, Double(gainDb) / 40.0)
        let omega = 2.0 * Double.pi * cutoffHz / 48_000.0
        let cosOmega = cos(omega)
        let sinOmega = sin(omega)
        let beta = sqrt(gain) / slope
        let alpha = sinOmega / 2.0 * sqrt((gain + 1.0 / gain) * (1.0 / slope - 1.0) + 2.0)

        let b0 = gain * ((gain + 1.0) + (gain - 1.0) * cosOmega + 2.0 * sqrt(gain) * alpha)
        let b1 = -2.0 * gain * ((gain - 1.0) + (gain + 1.0) * cosOmega)
        let b2 = gain * ((gain + 1.0) + (gain - 1.0) * cosOmega - 2.0 * sqrt(gain) * alpha)
        let a0 = (gain + 1.0) - (gain - 1.0) * cosOmega + 2.0 * beta * alpha
        let a1 = 2.0 * ((gain - 1.0) - (gain + 1.0) * cosOmega)
        let a2 = (gain + 1.0) - (gain - 1.0) * cosOmega - 2.0 * beta * alpha

        return [b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0]
    }
}
