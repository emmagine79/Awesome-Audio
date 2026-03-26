import Testing
import Foundation
import AVFoundation
@testable import AwesomeAudio

@Suite("AudioFormatAdapter")
struct AudioFormatAdapterTests {

    // MARK: - Helpers

    /// Write a PCM sine wave to a temporary WAV file and return its URL.
    /// The caller is responsible for deleting the file when finished.
    private func makeWAVFile(
        sampleRate: Double = 44100,
        channels: AVAudioChannelCount = 1,
        duration: Double = 2.0,
        frequency: Double = 440
    ) throws -> URL {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: channels,
            interleaved: false
        ) else {
            throw NSError(domain: "AudioFormatAdapterTests", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Could not create AVAudioFormat"])
        }

        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw NSError(domain: "AudioFormatAdapterTests", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Could not create PCM buffer"])
        }
        buffer.frameLength = frameCount

        // Fill each channel with a sine wave.
        for ch in 0..<Int(channels) {
            guard let channelData = buffer.floatChannelData?[ch] else { continue }
            let angularFreq = 2.0 * Double.pi * frequency / sampleRate
            for i in 0..<Int(frameCount) {
                channelData[i] = Float(0.5 * sin(angularFreq * Double(i)))
            }
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")

        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        return url
    }

    // MARK: - Tests

    @Test("Reads a WAV file and returns 48 kHz mono Float32")
    func audioFormatAdapterReadsWAVFile() throws {
        let url = try makeWAVFile(sampleRate: 44100, channels: 1, duration: 2.0)
        defer { try? FileManager.default.removeItem(at: url) }

        let adapter = AudioFormatAdapter()
        let info = try adapter.load(url: url)

        #expect(info.sampleRate == 48_000, "sampleRate should be 48 000")
        #expect(info.channelCount == 1, "channelCount should be 1 (mono)")
        #expect(info.frameCount == info.samples.count,
                "frameCount must equal samples.count")
        #expect(info.samples.count > 0, "samples must not be empty")
        #expect(info.originalSampleRate == 44_100,
                "originalSampleRate should reflect the source file")
        #expect(info.originalChannelCount == 1)
        #expect(info.duration >= 2.0 - 0.01,
                "duration should be approximately 2 seconds")
        #expect(info.sourceURL == url)
    }

    @Test("Reads a stereo WAV file and downmixes to mono")
    func audioFormatAdapterDownmixesStereoToMono() throws {
        let url = try makeWAVFile(sampleRate: 48000, channels: 2, duration: 2.0)
        defer { try? FileManager.default.removeItem(at: url) }

        let adapter = AudioFormatAdapter()
        let info = try adapter.load(url: url)

        #expect(info.channelCount == 1, "Output must always be mono")
        #expect(info.originalChannelCount == 2, "Original should be stereo")
        #expect(info.sampleRate == 48_000)
    }

    @Test("Rejects a file with an unsupported extension")
    func audioFormatAdapterRejectsUnsupported() throws {
        // Write arbitrary bytes with an unrecognised extension.
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("xyz")
        try Data("not audio".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let adapter = AudioFormatAdapter()
        #expect(throws: ProcessingError.self) {
            _ = try adapter.load(url: url)
        }
    }

    @Test("Rejects a WAV file shorter than 1 second")
    func audioFormatAdapterRejectsShortFile() throws {
        // 0.5-second file — below the 1-second minimum.
        let url = try makeWAVFile(sampleRate: 44100, channels: 1, duration: 0.5)
        defer { try? FileManager.default.removeItem(at: url) }

        let adapter = AudioFormatAdapter()
        #expect(throws: ProcessingError.self) {
            _ = try adapter.load(url: url)
        }
    }
}
