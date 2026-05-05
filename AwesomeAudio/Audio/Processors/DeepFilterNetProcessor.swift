import Foundation

/// DeepFilterNet noise reduction processor.
///
/// In Xcode builds with the bridging header and static library linked,
/// define the DEEPFILTERNET_AVAILABLE Swift flag to enable the real engine.
/// In SPM builds, this falls back to a passthrough stub.

#if DEEPFILTERNET_AVAILABLE

final class DeepFilterNetProcessor: StreamingProcessor {
    let sampleRate: Double = 48000
    private(set) var latencySamples: Int = 0
    let processingFrameLength: Int

    private var state: OpaquePointer?
    private let frameLength: Int
    private var frameInputBuffer: [Float]
    private var frameOutputBuffer: [Float]
    private var outputAccumulator: [Float] = []
    private var isBypassed = false

    init(modelPath: String, attenuationLimitDb: Float = 18) throws {
        // Validate path before calling df_create — the Rust code panics (abort)
        // on invalid paths rather than returning null
        guard !modelPath.isEmpty,
              FileManager.default.fileExists(atPath: modelPath) else {
            throw ProcessingError.engineInitFailed
        }

        guard let st = modelPath.withCString({ path in
            df_create(path, attenuationLimitDb)
        }) else {
            throw ProcessingError.engineInitFailed
        }

        self.state = st
        self.frameLength = Int(df_get_frame_length(st))
        self.processingFrameLength = self.frameLength
        self.latencySamples = Int(df_get_delay_samples(st))
        self.frameInputBuffer = [Float](repeating: 0, count: frameLength)
        self.frameOutputBuffer = [Float](repeating: 0, count: frameLength)
    }

    deinit {
        if let st = state {
            df_free(st)
        }
    }

    func setStrength(_ strength: Float) {
        isBypassed = strength <= 0.0001
        guard let st = state else { return }
        let attenDb = Preset.attenuationLimitDb(for: strength)
        df_set_atten_lim(st, attenDb)
    }

    func process(_ buffer: UnsafeMutablePointer<Float>, frameCount: Int) {
        guard let st = state, !isBypassed, frameCount > 0 else { return }

        var framesWritten = 0
        if !outputAccumulator.isEmpty {
            let available = min(outputAccumulator.count, frameCount)
            for i in 0..<available {
                buffer[i] = outputAccumulator[i]
            }
            outputAccumulator.removeFirst(available)
            framesWritten = available
        }

        while framesWritten < frameCount {
            let framesThisPass = min(frameLength, frameCount - framesWritten)
            frameInputBuffer.withUnsafeMutableBufferPointer { ptr in
                guard let base = ptr.baseAddress else { return }
                for i in 0..<frameLength {
                    base[i] = 0
                }
                base.update(from: buffer + framesWritten, count: framesThisPass)
            }

            frameOutputBuffer.withUnsafeMutableBufferPointer { outPtr in
                frameInputBuffer.withUnsafeMutableBufferPointer { inPtr in
                    _ = df_process_frame(st, inPtr.baseAddress, outPtr.baseAddress)
                }
            }

            frameOutputBuffer.withUnsafeBufferPointer { ptr in
                guard let base = ptr.baseAddress else { return }
                (buffer + framesWritten).update(from: base, count: framesThisPass)
            }

            if framesThisPass < frameLength {
                outputAccumulator.append(contentsOf: frameOutputBuffer[framesThisPass..<frameLength])
            }
            framesWritten += framesThisPass
        }
    }

    func reset() {
        frameInputBuffer = [Float](repeating: 0, count: frameLength)
        frameOutputBuffer = [Float](repeating: 0, count: frameLength)
        outputAccumulator.removeAll()
    }
}

#else

/// Stub noise reducer — passthrough when DeepFilterNet is not available.
final class DeepFilterNetProcessor: StreamingProcessor {
    let sampleRate: Double = 48000
    let latencySamples: Int = 0
    let processingFrameLength: Int = 0

    init(modelPath: String, attenuationLimitDb: Float = 18) throws {
        // No-op in stub builds
    }

    func setStrength(_ strength: Float) {}

    func process(_ buffer: UnsafeMutablePointer<Float>, frameCount: Int) {
        // Passthrough
    }

    func reset() {}
}

#endif
