import Testing
import Foundation
@testable import AwesomeAudio

@Suite("TempFileManager")
struct TempFileManagerTests {

    // MARK: - createTempURL

    @Test func createTempURLReturnsURLWithExpectedExtension() {
        let manager = TempFileManager()
        let url = manager.createTempURL(extension: "caf")
        #expect(url.pathExtension == "caf",
                "Expected .caf extension, got '\(url.pathExtension)'")
    }

    @Test func createTempURLReturnsURLWithExpectedWavExtension() {
        let manager = TempFileManager()
        let url = manager.createTempURL(extension: "wav")
        #expect(url.pathExtension == "wav",
                "Expected .wav extension, got '\(url.pathExtension)'")
    }

    @Test func createTempURLUsesAwesomeAudioPrefix() {
        let manager = TempFileManager()
        let url = manager.createTempURL(extension: "caf")
        #expect(url.lastPathComponent.hasPrefix("AwesomeAudio_"),
                "Filename should start with 'AwesomeAudio_', got '\(url.lastPathComponent)'")
    }

    @Test func createTempURLProducesUniqueURLsEachCall() {
        let manager = TempFileManager()
        let url1 = manager.createTempURL(extension: "caf")
        let url2 = manager.createTempURL(extension: "caf")
        #expect(url1 != url2, "Each call should produce a unique URL")
    }

    @Test func createTempURLResolvesToTempDirectory() {
        let manager = TempFileManager()
        let url = manager.createTempURL(extension: "caf")
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
        #expect(url.deletingLastPathComponent().standardized == tempDir.standardized,
                "Temp URL should live in NSTemporaryDirectory()")
    }

    // MARK: - cleanupSession

    @Test func cleanupSessionDeletesTrackedFiles() throws {
        let manager = TempFileManager()
        let url = manager.createTempURL(extension: "wav")

        // Actually create the file so we can verify deletion
        try "test".write(to: url, atomically: true, encoding: .utf8)
        #expect(FileManager.default.fileExists(atPath: url.path),
                "File should exist before cleanup")

        manager.cleanupSession()

        #expect(!FileManager.default.fileExists(atPath: url.path),
                "File should be deleted after cleanupSession()")
    }

    @Test func cleanupSessionHandlesMissingFilesGracefully() {
        let manager = TempFileManager()
        // Register a URL but never create the file on disk
        _ = manager.createTempURL(extension: "caf")
        // Should not throw or crash
        manager.cleanupSession()
    }

    @Test func cleanupSessionDeletesMultipleTrackedFiles() throws {
        let manager = TempFileManager()
        let caf = manager.createTempURL(extension: "caf")
        let wav = manager.createTempURL(extension: "wav")

        try "caf content".write(to: caf, atomically: true, encoding: .utf8)
        try "wav content".write(to: wav, atomically: true, encoding: .utf8)

        manager.cleanupSession()

        #expect(!FileManager.default.fileExists(atPath: caf.path),
                "CAF temp file should be deleted")
        #expect(!FileManager.default.fileExists(atPath: wav.path),
                "WAV temp file should be deleted")
    }

    @Test func cleanupSessionOnlyDeletesSessionFiles() throws {
        let manager1 = TempFileManager()
        let manager2 = TempFileManager()

        let url1 = manager1.createTempURL(extension: "wav")
        let url2 = manager2.createTempURL(extension: "wav")

        try "data".write(to: url1, atomically: true, encoding: .utf8)
        try "data".write(to: url2, atomically: true, encoding: .utf8)

        // Clean up only manager1's session
        manager1.cleanupSession()

        #expect(!FileManager.default.fileExists(atPath: url1.path),
                "manager1's file should be deleted")
        #expect(FileManager.default.fileExists(atPath: url2.path),
                "manager2's file should still exist")

        // Clean up manager2 so we leave no stray files
        manager2.cleanupSession()
    }

    // MARK: - availableTempSpace

    @Test func availableTempSpaceReturnsPositiveValue() {
        let manager = TempFileManager()
        let space = manager.availableTempSpace()
        #expect(space > 0, "Available temp space should be > 0 on a normal system")
    }

    // MARK: - availableSpace(at:)

    @Test func availableSpaceAtExistingDirectoryReturnsPositiveValue() {
        let manager = TempFileManager()
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let space = manager.availableSpace(at: homeDir)
        #expect(space > 0, "Available space at home directory should be > 0")
    }

    @Test func availableSpaceAtNonExistentURLWalksUpToAncestor() {
        let manager = TempFileManager()
        // A URL that almost certainly doesn't exist on disk
        let phantom = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("phantom_\(UUID().uuidString)")
            .appendingPathComponent("nested")
            .appendingPathExtension("wav")
        let space = manager.availableSpace(at: phantom)
        // Should return the space of the temp dir itself (not 0)
        #expect(space > 0, "Should walk up to a real ancestor and return its space")
    }

    // MARK: - estimatedTempSpace

    @Test func estimatedTempSpaceFor1MinuteAudio16Bit() {
        let manager = TempFileManager()
        let duration = 60.0   // 1 minute
        let space = manager.estimatedTempSpace(durationSeconds: duration, outputBitDepth: 16)

        // CAF:  60 × 48000 × 4  = 11 520 000 bytes  (Float32)
        // WAV:  60 × 48000 × 2  =  5 760 000 bytes  (Int16)
        // Margin: 50 × 1024 × 1024 = 52 428 800 bytes
        // Total ≈ 69 708 800 bytes
        let expectedMin: UInt64 = 17_280_000   // audio bytes without margin
        let expectedMax: UInt64 = 70_000_000   // total with margin, rounded up
        #expect(space >= expectedMin,
                "Estimate should be at least the raw audio bytes, got \(space)")
        #expect(space <= expectedMax,
                "Estimate should not vastly exceed expected total, got \(space)")
    }

    @Test func estimatedTempSpaceFor1MinuteAudio24Bit() {
        let manager = TempFileManager()
        let duration = 60.0
        let space = manager.estimatedTempSpace(durationSeconds: duration, outputBitDepth: 24)

        // CAF:  60 × 48000 × 4  = 11 520 000
        // WAV:  60 × 48000 × 3  =  8 640 000
        // Margin: 52 428 800
        // Total ≈ 72 588 800
        let expectedMin: UInt64 = 20_160_000
        let expectedMax: UInt64 = 75_000_000
        #expect(space >= expectedMin)
        #expect(space <= expectedMax)
    }

    @Test func estimatedTempSpaceIncludesMarginOver50MB() {
        let manager = TempFileManager()
        // Near-zero duration — space should still include the 50 MB margin
        let space = manager.estimatedTempSpace(durationSeconds: 0.001, outputBitDepth: 16)
        let fiftyMB: UInt64 = 50 * 1024 * 1024
        #expect(space >= fiftyMB,
                "Estimate should always include the 50 MB safety margin, got \(space)")
    }

    @Test func estimatedTempSpace24BitLargerThan16Bit() {
        let manager = TempFileManager()
        let duration = 30.0
        let space16 = manager.estimatedTempSpace(durationSeconds: duration, outputBitDepth: 16)
        let space24 = manager.estimatedTempSpace(durationSeconds: duration, outputBitDepth: 24)
        #expect(space24 > space16,
                "24-bit output requires more space than 16-bit, 16-bit: \(space16), 24-bit: \(space24)")
    }

    // MARK: - cleanupStaleFiles

    @Test func cleanupStaleFilesRemovesOldAwesomeAudioFiles() throws {
        // Create a stale file by backdating its creation date via FileManager attributes
        let filename = "AwesomeAudio_stale_\(UUID().uuidString).wav"
        let staleURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(filename)
        try "stale".write(to: staleURL, atomically: true, encoding: .utf8)

        // Modify the creation date to 2 hours ago (older than the 1-hour threshold)
        let twoHoursAgo = Date().addingTimeInterval(-7300)
        try FileManager.default.setAttributes(
            [.creationDate: twoHoursAgo],
            ofItemAtPath: staleURL.path
        )

        TempFileManager.cleanupStaleFiles()

        #expect(!FileManager.default.fileExists(atPath: staleURL.path),
                "Stale AwesomeAudio_ file older than 1 hour should be deleted")
    }

    @Test func cleanupStaleFilesKeepsRecentFiles() throws {
        // Create a fresh file (just now)
        let filename = "AwesomeAudio_recent_\(UUID().uuidString).wav"
        let recentURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(filename)
        try "recent".write(to: recentURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: recentURL) }

        TempFileManager.cleanupStaleFiles()

        #expect(FileManager.default.fileExists(atPath: recentURL.path),
                "Recent AwesomeAudio_ file should NOT be deleted by stale cleanup")
    }

    @Test func cleanupStaleFilesIgnoresNonAwesomeAudioFiles() throws {
        // Create an old file WITHOUT the AwesomeAudio_ prefix
        let filename = "unrelated_old_file_\(UUID().uuidString).wav"
        let unrelatedURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(filename)
        try "content".write(to: unrelatedURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: unrelatedURL) }

        // Backdate it
        let twoHoursAgo = Date().addingTimeInterval(-7300)
        try FileManager.default.setAttributes(
            [.creationDate: twoHoursAgo],
            ofItemAtPath: unrelatedURL.path
        )

        TempFileManager.cleanupStaleFiles()

        #expect(FileManager.default.fileExists(atPath: unrelatedURL.path),
                "Files without the AwesomeAudio_ prefix should not be deleted")
    }
}
