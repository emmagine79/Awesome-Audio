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

    private var state: OpaquePointer?
    private let frameLength: Int
    private var inputAccumulator: [Float] = []
    private var outputAccumulator: [Float] = []
    private var frameOutputBuffer: [Float]

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
        self.latencySamples = Int(df_get_delay_samples(st))
        self.frameOutputBuffer = [Float](repeating: 0, count: frameLength)
    }

    deinit {
        if let st = state {
            df_free(st)
        }
    }

    func setStrength(_ strength: Float) {
        guard let st = state else { return }
        let attenDb = Preset.attenuationLimitDb(for: strength)
        df_set_atten_lim(st, attenDb)
    }

    func process(_ buffer: UnsafeMutablePointer<Float>, frameCount: Int) {
        guard let st = state else { return }

        inputAccumulator.append(contentsOf: UnsafeBufferPointer(start: buffer, count: frameCount))

        while inputAccumulator.count >= frameLength {
            var frameInput = Array(inputAccumulator.prefix(frameLength))
            inputAccumulator.removeFirst(frameLength)

            frameOutputBuffer = [Float](repeating: 0, count: frameLength)
            frameInput.withUnsafeMutableBufferPointer { inPtr in
                frameOutputBuffer.withUnsafeMutableBufferPointer { outPtr in
                    _ = df_process_frame(st, inPtr.baseAddress, outPtr.baseAddress)
                }
            }
            outputAccumulator.append(contentsOf: frameOutputBuffer)
        }

        let available = min(outputAccumulator.count, frameCount)
        for i in 0..<available {
            buffer[i] = outputAccumulator[i]
        }
        outputAccumulator.removeFirst(available)
        for i in available..<frameCount {
            buffer[i] = 0
        }
    }

    func reset() {
        inputAccumulator.removeAll()
        outputAccumulator.removeAll()
        frameOutputBuffer = [Float](repeating: 0, count: frameLength)
    }
}

#else

/// Stub noise reducer — passthrough when DeepFilterNet is not available.
final class DeepFilterNetProcessor: StreamingProcessor {
    let sampleRate: Double = 48000
    let latencySamples: Int = 0

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
