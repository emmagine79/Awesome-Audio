import Foundation
import Accelerate

enum AudioTestHelpers {
    static func sineWave(frequency: Float, sampleRate: Float = 48000, duration: Float = 1.0, amplitude: Float = 1.0) -> [Float] {
        let sampleCount = Int(sampleRate * duration)
        var samples = [Float](repeating: 0, count: sampleCount)
        let angularFrequency = 2.0 * Float.pi * frequency / sampleRate
        for i in 0..<sampleCount {
            samples[i] = amplitude * sin(angularFrequency * Float(i))
        }
        return samples
    }

    static func whiteNoise(sampleRate: Float = 48000, duration: Float = 1.0, amplitude: Float = 0.1) -> [Float] {
        let sampleCount = Int(sampleRate * duration)
        return (0..<sampleCount).map { _ in Float.random(in: -amplitude...amplitude) }
    }

    static func silence(sampleRate: Float = 48000, duration: Float = 1.0) -> [Float] {
        [Float](repeating: 0, count: Int(sampleRate * duration))
    }

    static func rms(_ samples: [Float]) -> Float {
        var result: Float = 0
        vDSP_rmsqv(samples, 1, &result, vDSP_Length(samples.count))
        return result
    }

    static func peakAbsolute(_ samples: [Float]) -> Float {
        var result: Float = 0
        vDSP_maxmgv(samples, 1, &result, vDSP_Length(samples.count))
        return result
    }

    static func linearToDb(_ linear: Float) -> Float {
        20 * log10(max(linear, 1e-10))
    }
}
