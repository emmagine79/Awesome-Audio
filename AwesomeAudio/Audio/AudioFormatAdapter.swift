import AVFoundation
import Foundation

// MARK: - AudioFileInfo

struct AudioFileInfo {
    /// PCM samples normalised to 48 kHz mono Float32.
    let samples: [Float]
    /// Always 48 000.
    let sampleRate: Double
    /// Always 1.
    let channelCount: Int
    /// Equal to `samples.count`.
    let frameCount: Int

    // Original file metadata
    let originalSampleRate: Double
    let originalChannelCount: Int
    let originalBitDepth: Int
    let duration: TimeInterval
    let fileSizeBytes: UInt64
    let sourceURL: URL
}

// MARK: - AudioFormatAdapter

/// Reads an audio file (WAV / MP3 / M4A / AIFF) and returns it as
/// 48 kHz mono Float32, regardless of the original format.
final class AudioFormatAdapter {

    // Target pipeline format
    private static let targetSampleRate: Double = 48_000

    // MARK: Public API

    func load(url: URL) throws -> AudioFileInfo {
        // --- Open file --------------------------------------------------
        let audioFile: AVAudioFile
        do {
            audioFile = try AVAudioFile(forReading: url)
        } catch {
            throw ProcessingError.unsupportedFormat(url.pathExtension)
        }

        let sourceFormat = audioFile.fileFormat
        let processingFormat = audioFile.processingFormat   // client-side PCM

        let frameCapacity = AVAudioFrameCount(audioFile.length)
        guard frameCapacity > 0 else {
            throw ProcessingError.fileTooShort
        }

        // --- Duration check ---------------------------------------------
        let originalSampleRate = processingFormat.sampleRate
        let duration = Double(audioFile.length) / originalSampleRate
        guard duration >= 1.0 else {
            throw ProcessingError.fileTooShort
        }

        // --- Read all frames into a buffer ------------------------------
        guard let readBuffer = AVAudioPCMBuffer(
            pcmFormat: processingFormat,
            frameCapacity: frameCapacity
        ) else {
            throw ProcessingError.unsupportedFormat(url.pathExtension)
        }
        try audioFile.read(into: readBuffer)

        // --- Downmix to mono --------------------------------------------
        let monoBuffer = try downmixToMono(readBuffer)

        // --- Resample to 48 kHz if needed -------------------------------
        let finalBuffer: AVAudioPCMBuffer
        if originalSampleRate != Self.targetSampleRate {
            finalBuffer = try resample(monoBuffer, to: Self.targetSampleRate)
        } else {
            finalBuffer = monoBuffer
        }

        // --- Extract Float samples --------------------------------------
        let samples = extractSamples(from: finalBuffer)

        // --- File size --------------------------------------------------
        let fileSizeBytes: UInt64
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? UInt64 {
            fileSizeBytes = size
        } else {
            fileSizeBytes = 0
        }

        // --- Original bit depth from the file format -------------------
        let originalBitDepth = Int(sourceFormat.streamDescription.pointee.mBitsPerChannel)

        return AudioFileInfo(
            samples: samples,
            sampleRate: Self.targetSampleRate,
            channelCount: 1,
            frameCount: samples.count,
            originalSampleRate: originalSampleRate,
            originalChannelCount: Int(processingFormat.channelCount),
            originalBitDepth: originalBitDepth,
            duration: duration,
            fileSizeBytes: fileSizeBytes,
            sourceURL: url
        )
    }

    // MARK: Private Helpers

    /// Downmix a (potentially multi-channel) PCM buffer to mono Float32.
    private func downmixToMono(_ source: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer {
        let channelCount = Int(source.format.channelCount)

        // Build a mono Float32 format at the same sample rate.
        guard let monoFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: source.format.sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw ProcessingError.unsupportedFormat("mono format creation")
        }

        let frameCount = source.frameLength

        guard let monoBuffer = AVAudioPCMBuffer(
            pcmFormat: monoFormat,
            frameCapacity: frameCount
        ) else {
            throw ProcessingError.unsupportedFormat("mono buffer creation")
        }
        monoBuffer.frameLength = frameCount

        guard let monoData = monoBuffer.floatChannelData?[0] else {
            throw ProcessingError.unsupportedFormat("mono channel data")
        }

        if channelCount == 1 {
            // Already mono — just copy.
            if let srcData = source.floatChannelData?[0] {
                monoData.initialize(from: srcData, count: Int(frameCount))
            }
        } else {
            // Average all channels.
            let scale = Float(1.0) / Float(channelCount)
            for frame in 0..<Int(frameCount) {
                var sum: Float = 0
                if let channelDataArray = source.floatChannelData {
                    for ch in 0..<channelCount {
                        sum += channelDataArray[ch][frame]
                    }
                }
                monoData[frame] = sum * scale
            }
        }

        return monoBuffer
    }

    /// Resample a mono Float32 buffer to `targetSampleRate`.
    private func resample(_ source: AVAudioPCMBuffer, to targetRate: Double) throws -> AVAudioPCMBuffer {
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetRate,
            channels: 1,
            interleaved: false
        ) else {
            throw ProcessingError.unsupportedFormat("resample format creation")
        }

        guard let converter = AVAudioConverter(from: source.format, to: targetFormat) else {
            throw ProcessingError.unsupportedFormat("resampler creation")
        }

        // Compute output frame count proportionally.
        let ratio = targetRate / source.format.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(Double(source.frameLength) * ratio + 1)

        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: outputFrameCapacity
        ) else {
            throw ProcessingError.unsupportedFormat("resample output buffer creation")
        }

        var inputConsumed = false
        var conversionError: NSError?

        let status = converter.convert(to: outputBuffer, error: &conversionError) { _, outStatus in
            if inputConsumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            outStatus.pointee = .haveData
            inputConsumed = true
            return source
        }

        if let err = conversionError {
            throw ProcessingError.processingFailed(stage: "resample", underlying: err)
        }

        guard status != .error else {
            throw ProcessingError.unsupportedFormat("resampling failed")
        }

        return outputBuffer
    }

    /// Copy Float samples out of a mono PCM buffer into a Swift array.
    private func extractSamples(from buffer: AVAudioPCMBuffer) -> [Float] {
        guard let channelData = buffer.floatChannelData?[0] else { return [] }
        let count = Int(buffer.frameLength)
        return Array(UnsafeBufferPointer(start: channelData, count: count))
    }
}
