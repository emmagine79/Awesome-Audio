import AVFoundation
import Foundation

// MARK: - ProcessingCoordinator

/// Orchestrates the two-pass audio processing pipeline.
///
/// **Pass 1** — Quality processing:
///   HPF → DeepFilterNet → De-esser → Compressor → Float32 CAF temp file + LUFS measurement
///
/// **Pass 2** — Loudness normalisation:
///   Read CAF → Gain (configured from Pass 1 LUFS) → True-peak limiter → TPDF dither (16-bit) → WAV temp file
///
/// **Delay compensation**: total latency (sum of `latencySamples` across all processors in both
/// passes) is trimmed from the leading edge of the final output.
///
/// **Export**: copies the temp WAV to a user-chosen destination after checking disk space and
/// writability.
actor ProcessingCoordinator {

    // MARK: - Model Path

    /// Resolves the bundled DeepFilterNet model path.
    private static func resolveModelPath() -> String {
        if let path = Bundle.main.path(forResource: "DeepFilterNet3_onnx", ofType: "tar.gz") {
            return path
        }
        // Fallback: check Resources directory directly
        let resourcesDir = Bundle.main.bundlePath + "/Contents/Resources"
        let fallback = resourcesDir + "/DeepFilterNet3_onnx.tar.gz"
        if FileManager.default.fileExists(atPath: fallback) {
            return fallback
        }
        return ""
    }

    // MARK: - Result

    struct ProcessingResult {
        let tempOutputURL: URL
        let beforeLUFS: Float
        let afterLUFS: Float
        let beforeTruePeak: Float
        let afterTruePeak: Float
        let processingDuration: TimeInterval
    }

    // MARK: - Constants

    private static let chunkSize = 4096
    private static let sampleRate: Double = 48_000
    private static let gainOvershootLU: Float = 0.3

    // MARK: - Dependencies

    private let tempManager = TempFileManager()
    private var isCancelled = false

    // MARK: - Public API

    /// Runs the full two-pass pipeline and returns a `ProcessingResult` with the temp WAV URL.
    ///
    /// Progress is reported as fractions:
    ///   - Pass 1: 0 % → 70 %
    ///   - Pass 2: 70 % → 95 %
    ///   - Verification: 95 % → 100 %
    ///
    /// - Throws: `ProcessingError` on disk space shortfalls, cancellation, or AVFoundation errors.
    func process(
        audioInfo: AudioFileInfo,
        preset: PresetSnapshot,
        progress: @Sendable (ProcessingProgress) -> Void
    ) async throws -> ProcessingResult {
        isCancelled = false
        let startTime = Date()

        // ── Disk space preflight ────────────────────────────────────────────
        let needed = tempManager.estimatedTempSpace(
            durationSeconds: audioInfo.duration,
            outputBitDepth: preset.outputBitDepth
        )
        let available = tempManager.availableTempSpace()
        guard available >= needed else {
            throw ProcessingError.insufficientDiskSpace(needed: needed, available: available)
        }

        // ── Measure "before" LUFS on the raw input ──────────────────────────
        let beforeAnalyzer = LUFSAnalyzer()
        audioInfo.samples.withUnsafeBufferPointer { ptr in
            guard let base = ptr.baseAddress else { return }
            beforeAnalyzer.analyze(base, frameCount: audioInfo.frameCount)
        }
        let beforeResult = beforeAnalyzer.finalize()

        // ── Pass 1 ──────────────────────────────────────────────────────────
        let cafURL = tempManager.createTempURL(extension: "caf")
        let pass1Output = try await runPass1(
            audioInfo: audioInfo,
            preset: preset,
            cafURL: cafURL,
            progress: progress
        )

        // ── Pass 2 ──────────────────────────────────────────────────────────
        let wavURL = tempManager.createTempURL(extension: "wav")
        try await runPass2(
            cafURL: cafURL,
            wavURL: wavURL,
            pass1AnalysisResult: pass1Output.analysis,
            pass1Latency: pass1Output.pass1Latency,
            preset: preset,
            progress: progress
        )

        // Delete temp CAF now that Pass 2 is done
        try? FileManager.default.removeItem(at: cafURL)

        // ── Verification: re-measure the final WAV ──────────────────────────
        progress(ProcessingProgress(stageName: "Verifying", fractionComplete: 0.95, passNumber: 2))
        try Task.checkCancellation()

        let afterResult = try measureLUFS(fileURL: wavURL)

        progress(ProcessingProgress(stageName: "Verifying", fractionComplete: 1.0, passNumber: 2))

        return ProcessingResult(
            tempOutputURL: wavURL,
            beforeLUFS: beforeResult.measuredLUFS,
            afterLUFS: afterResult.measuredLUFS,
            beforeTruePeak: beforeResult.measuredTruePeak,
            afterTruePeak: afterResult.measuredTruePeak,
            processingDuration: Date().timeIntervalSince(startTime)
        )
    }

    /// Copies the temp WAV to `destinationURL` after verifying disk space and writability.
    ///
    /// - Throws: `ProcessingError.insufficientDiskSpace` or `ProcessingError.outputNotWritable`.
    func export(tempURL: URL, to destinationURL: URL) throws {
        // Check writability of the destination directory
        let destDir = destinationURL.deletingLastPathComponent()
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: destDir.path, isDirectory: &isDirectory)

        guard exists && isDirectory.boolValue else {
            throw ProcessingError.outputNotWritable(destinationURL)
        }
        guard FileManager.default.isWritableFile(atPath: destDir.path) else {
            throw ProcessingError.outputNotWritable(destinationURL)
        }

        // Check output volume has enough space for the file being exported
        if let attrs = try? FileManager.default.attributesOfItem(atPath: tempURL.path),
           let fileSize = attrs[.size] as? UInt64 {
            let available = tempManager.availableSpace(at: destDir)
            guard available >= fileSize else {
                throw ProcessingError.insufficientDiskSpace(needed: fileSize, available: available)
            }
        }

        // Remove existing file at destination (overwrite semantics)
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        try FileManager.default.copyItem(at: tempURL, to: destinationURL)
    }

    /// Cancels any in-flight processing and deletes session temp files.
    func cancelAndCleanup() {
        isCancelled = true
        tempManager.cleanupSession()
    }

    // MARK: - Pass 1

    private func runPass1(
        audioInfo: AudioFileInfo,
        preset: PresetSnapshot,
        cafURL: URL,
        progress: @Sendable (ProcessingProgress) -> Void
    ) async throws -> (analysis: AnalysisResult, pass1Latency: Int) {
        // Build processor chain
        let hpf = HighPassFilter(cutoffHz: preset.highPassCutoff)
        let dfn = try DeepFilterNetProcessor(
            modelPath: Self.resolveModelPath(),
            attenuationLimitDb: preset.noiseReductionAttenLimitDB
        )
        dfn.setStrength(preset.noiseReductionStrength)
        let deEsser = DeEsser(amount: preset.deEssAmount)
        let compressor = Compressor(preset: preset.compressionPreset)

        let pass1Processors: [StreamingProcessor] = [hpf, dfn, deEsser, compressor]
        let pass1Latency = pass1Processors.reduce(0) { $0 + $1.latencySamples }

        // LUFS analyzer for Pass 1 output
        let lufsAnalyzer = LUFSAnalyzer()

        // Open CAF file for writing (Float32, mono, 48 kHz)
        guard let cafFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Self.sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw ProcessingError.engineInitFailed
        }

        let cafFile: AVAudioFile
        do {
            cafFile = try AVAudioFile(forWriting: cafURL, settings: cafFormat.settings)
        } catch {
            throw ProcessingError.processingFailed(stage: "Pass1 file open", underlying: error)
        }

        let totalFrames = audioInfo.frameCount
        var framesProcessed = 0
        let chunkSize = Self.chunkSize

        // Allocate a reusable chunk buffer
        var chunkBuffer = [Float](repeating: 0, count: chunkSize)

        while framesProcessed < totalFrames {
            try Task.checkCancellation()

            let remaining = totalFrames - framesProcessed
            let thisChunk = min(chunkSize, remaining)

            // Copy input samples into chunk buffer
            chunkBuffer.withUnsafeMutableBufferPointer { ptr in
                for i in 0..<thisChunk {
                    ptr[i] = audioInfo.samples[framesProcessed + i]
                }
            }

            // Run through each processor in place
            chunkBuffer.withUnsafeMutableBufferPointer { ptr in
                guard let base = ptr.baseAddress else { return }
                for processor in pass1Processors {
                    processor.process(base, frameCount: thisChunk)
                }
            }

            // Feed processed chunk to LUFS analyzer
            chunkBuffer.withUnsafeBufferPointer { ptr in
                guard let base = ptr.baseAddress else { return }
                lufsAnalyzer.analyze(base, frameCount: thisChunk)
            }

            // Write chunk to CAF file
            try chunkBuffer.withUnsafeMutableBufferPointer { ptr in
                guard let base = ptr.baseAddress,
                      let writeBuffer = AVAudioPCMBuffer(
                          pcmFormat: cafFormat,
                          frameCapacity: AVAudioFrameCount(thisChunk)
                      ) else {
                    throw ProcessingError.processingFailed(
                        stage: "Pass1 buffer create",
                        underlying: NSError(domain: "AwesomeAudio", code: -1)
                    )
                }
                writeBuffer.frameLength = AVAudioFrameCount(thisChunk)
                if let channelData = writeBuffer.floatChannelData?[0] {
                    channelData.initialize(from: base, count: thisChunk)
                }
                try cafFile.write(from: writeBuffer)
            }

            framesProcessed += thisChunk

            let fraction = Double(framesProcessed) / Double(totalFrames)
            // Pass 1 maps to 0 % – 70 %
            progress(ProcessingProgress(
                stageName: "Pass 1",
                fractionComplete: fraction * 0.70,
                passNumber: 1
            ))
        }

        return (analysis: lufsAnalyzer.finalize(), pass1Latency: pass1Latency)
    }

    // MARK: - Pass 2

    private func runPass2(
        cafURL: URL,
        wavURL: URL,
        pass1AnalysisResult: AnalysisResult,
        pass1Latency: Int,
        preset: PresetSnapshot,
        progress: @Sendable (ProcessingProgress) -> Void
    ) async throws {
        // Build Pass 2 processor chain
        let gainProcessor = GainProcessor()
        gainProcessor.configure(
            from: pass1AnalysisResult,
            targetLUFS: preset.targetLUFS,
            overshootLU: Self.gainOvershootLU
        )
        let limiter = TruePeakLimiter(ceilingDbTP: preset.truePeakCeiling)
        let pass2StreamingProcessors: [StreamingProcessor] = [gainProcessor, limiter]

        // Ditherer only for 16-bit output
        let ditherer: TPDFDitherer? = preset.outputBitDepth == 16
            ? TPDFDitherer(targetBitDepth: 16)
            : nil

        // Total latency = pass1 latency (from actual processors) + pass2 latency
        let pass2Latency = pass2StreamingProcessors.reduce(0) { $0 + $1.latencySamples }
        let totalLatency = pass1Latency + pass2Latency

        // Open CAF file for reading
        let cafFile: AVAudioFile
        do {
            cafFile = try AVAudioFile(forReading: cafURL)
        } catch {
            throw ProcessingError.processingFailed(stage: "Pass2 CAF open", underlying: error)
        }

        let totalFrames = Int(cafFile.length)

        let wavWriter: WAVExportWriter
        do {
            wavWriter = try WAVExportWriter(
                url: wavURL,
                sampleRate: Self.sampleRate,
                bitDepth: preset.outputBitDepth
            )
        } catch {
            throw ProcessingError.processingFailed(stage: "Pass2 WAV open", underlying: error)
        }

        let chunkSize = Self.chunkSize
        var framesProcessed = 0
        var leadingSamplesToTrim = totalLatency

        guard let readBuffer = AVAudioPCMBuffer(
            pcmFormat: cafFile.processingFormat,
            frameCapacity: AVAudioFrameCount(chunkSize)
        ) else {
            throw ProcessingError.engineInitFailed
        }

        while framesProcessed < totalFrames {
            try Task.checkCancellation()

            let remaining = totalFrames - framesProcessed
            let requestFrames = min(chunkSize, remaining)

            readBuffer.frameLength = AVAudioFrameCount(requestFrames)
            do {
                try cafFile.read(into: readBuffer, frameCount: AVAudioFrameCount(requestFrames))
            } catch {
                throw ProcessingError.processingFailed(stage: "Pass2 CAF read", underlying: error)
            }

            let actualFrames = Int(readBuffer.frameLength)
            guard actualFrames > 0 else { break }

            // Extract Float32 samples
            var chunkSamples = [Float](repeating: 0, count: actualFrames)
            chunkSamples.withUnsafeMutableBufferPointer { ptr in
                guard let base = ptr.baseAddress,
                      let src = readBuffer.floatChannelData?[0] else { return }
                base.initialize(from: src, count: actualFrames)
            }

            // Run through Pass 2 streaming processors in place
            chunkSamples.withUnsafeMutableBufferPointer { ptr in
                guard let base = ptr.baseAddress else { return }
                for processor in pass2StreamingProcessors {
                    processor.process(base, frameCount: actualFrames)
                }
            }

            // Apply TPDF dither if configured
            if let ditherer {
                chunkSamples.withUnsafeMutableBufferPointer { ptr in
                    guard let base = ptr.baseAddress else { return }
                    ditherer.apply(base, frameCount: actualFrames)
                }
            }

            // Delay compensation: trim leading samples
            var writeStart = 0
            if leadingSamplesToTrim > 0 {
                let skip = min(leadingSamplesToTrim, actualFrames)
                leadingSamplesToTrim -= skip
                writeStart = skip
            }

            let framesToWrite = actualFrames - writeStart
            if framesToWrite > 0 {
                try chunkSamples.withUnsafeMutableBufferPointer { ptr in
                    guard let src = ptr.baseAddress else { return }
                    try wavWriter.append(samples: src + writeStart, frameCount: framesToWrite)
                }
            }

            framesProcessed += actualFrames

            let fraction = Double(framesProcessed) / Double(totalFrames)
            // Pass 2 maps to 70 % – 95 %
            progress(ProcessingProgress(
                stageName: "Pass 2",
                fractionComplete: 0.70 + fraction * 0.25,
                passNumber: 2
            ))
        }
    }

    // MARK: - Helpers

    /// Reads `fileURL` in chunks and returns the LUFS / true-peak measurement.
    private func measureLUFS(fileURL: URL) throws -> AnalysisResult {
        let analyzer = LUFSAnalyzer()

        let audioFile: AVAudioFile
        do {
            audioFile = try AVAudioFile(forReading: fileURL)
        } catch {
            throw ProcessingError.processingFailed(stage: "Verification open", underlying: error)
        }

        guard let floatFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Self.sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw ProcessingError.engineInitFailed
        }

        let chunkSize = Self.chunkSize
        let totalFrames = Int(audioFile.length)
        var framesRead = 0

        guard let readBuf = AVAudioPCMBuffer(
            pcmFormat: audioFile.processingFormat,
            frameCapacity: AVAudioFrameCount(chunkSize)
        ) else {
            throw ProcessingError.engineInitFailed
        }

        // Convert from the WAV's integer format to Float32 for the LUFS analyzer
        let needsConversion = audioFile.processingFormat.commonFormat != .pcmFormatFloat32
        let converter: AVAudioConverter? = needsConversion
            ? AVAudioConverter(from: audioFile.processingFormat, to: floatFormat)
            : nil

        while framesRead < totalFrames {
            let remaining = totalFrames - framesRead
            let request = min(chunkSize, remaining)

            do {
                readBuf.frameLength = 0
                try audioFile.read(into: readBuf, frameCount: AVAudioFrameCount(request))
            } catch {
                break  // EOF or error — finalize with what we have
            }

            let actual = Int(readBuf.frameLength)
            guard actual > 0 else { break }

            if let conv = converter {
                guard let floatBuf = AVAudioPCMBuffer(
                    pcmFormat: floatFormat,
                    frameCapacity: AVAudioFrameCount(actual)
                ) else { break }

                var inputConsumed = false
                _ = conv.convert(to: floatBuf, error: nil) { _, outStatus in
                    if inputConsumed { outStatus.pointee = .noDataNow; return nil }
                    outStatus.pointee = .haveData
                    inputConsumed = true
                    return readBuf
                }

                let frames = Int(floatBuf.frameLength)
                if let src = floatBuf.floatChannelData?[0] {
                    analyzer.analyze(src, frameCount: frames)
                }
            } else {
                if let src = readBuf.floatChannelData?[0] {
                    analyzer.analyze(src, frameCount: actual)
                }
            }

            framesRead += actual
        }

        return analyzer.finalize()
    }
}
