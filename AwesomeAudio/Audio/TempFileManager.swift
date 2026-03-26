import Foundation

// MARK: - TempFileManager

/// Manages temporary audio files created during the two-pass processing pipeline.
///
/// Pass 1 writes a Float32 CAF temp file; Pass 2 writes a PCM WAV temp file.
/// Both are tracked per session and deleted via `cleanupSession()`.
/// A startup sweep (`cleanupStaleFiles()`) removes any leftover files from
/// crashed or force-quit sessions.
final class TempFileManager {

    // MARK: - Constants

    private let prefix = "AwesomeAudio_"

    /// Safety margin added on top of estimated audio bytes.
    private static let safetyMarginBytes: UInt64 = 50 * 1024 * 1024  // 50 MB

    // MARK: - State

    private var sessionFiles: [URL] = []

    // MARK: - Temp URL Management

    /// Creates a new unique temp-file URL, registers it for session cleanup, and returns it.
    ///
    /// The file itself is **not** created on disk; the caller is responsible for writing to it.
    /// - Parameter ext: File extension without leading dot, e.g. "caf" or "wav".
    /// - Returns: A URL inside `NSTemporaryDirectory()` with the managed prefix.
    func createTempURL(extension ext: String) -> URL {
        let filename = "\(prefix)\(UUID().uuidString).\(ext)"
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(filename)
        sessionFiles.append(url)
        return url
    }

    // MARK: - Disk Space Queries

    /// Returns available bytes on the volume that hosts `NSTemporaryDirectory()`.
    func availableTempSpace() -> UInt64 {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
        return availableSpace(at: tempDir)
    }

    /// Returns available bytes on the volume that hosts the given URL.
    ///
    /// Falls back to 0 on any error so callers can treat zero as "unknown / insufficient".
    func availableSpace(at url: URL) -> UInt64 {
        // Walk up to an existing ancestor when the path itself doesn't exist yet
        // (e.g. when `url` is an output file not yet created).
        var query = url
        while !FileManager.default.fileExists(atPath: query.path) {
            let parent = query.deletingLastPathComponent()
            if parent == query { break }  // hit filesystem root
            query = parent
        }

        do {
            let values = try query.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            if let capacity = values.volumeAvailableCapacityForImportantUsage {
                return UInt64(max(capacity, 0))
            }
        } catch {}

        // Fallback: use statvfs
        var stat = statvfs()
        if statvfs(query.path, &stat) == 0 {
            return UInt64(stat.f_bavail) * UInt64(stat.f_frsize)
        }
        return 0
    }

    /// Estimates disk space needed for one full processing run.
    ///
    /// The estimate accounts for:
    /// - A Float32 CAF temp file (Pass 1 output): 4 bytes/frame × 48 000 Hz × duration
    /// - A PCM WAV temp file (Pass 2 output): (outputBitDepth / 8) bytes/frame × 48 000 Hz × duration
    /// - A 50 MB safety margin
    ///
    /// - Parameters:
    ///   - durationSeconds: Audio duration in seconds.
    ///   - outputBitDepth: Bit depth of the final WAV (16 or 24).
    /// - Returns: Estimated bytes required.
    func estimatedTempSpace(durationSeconds: Double, outputBitDepth: Int) -> UInt64 {
        let frames = UInt64(durationSeconds * 48_000)
        let cafBytes = frames * 4                               // Float32 = 4 bytes/frame
        let wavBytes = frames * UInt64(outputBitDepth / 8)     // 16-bit → 2, 24-bit → 3
        return cafBytes + wavBytes + Self.safetyMarginBytes
    }

    // MARK: - Cleanup

    /// Deletes all temp files created during this session and clears the tracking list.
    func cleanupSession() {
        for url in sessionFiles {
            try? FileManager.default.removeItem(at: url)
        }
        sessionFiles.removeAll()
    }

    /// Scans `NSTemporaryDirectory()` for stale `AwesomeAudio_*.caf` and
    /// `AwesomeAudio_*.wav` files older than one hour and deletes them.
    ///
    /// Intended to be called once at app startup to recover from prior crashes.
    static func cleanupStaleFiles() {
        let fm = FileManager.default
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
        let cutoff = Date().addingTimeInterval(-3600)  // 1 hour ago

        guard let items = try? fm.contentsOfDirectory(
            at: tempDir,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else { return }

        for item in items {
            let name = item.lastPathComponent
            let ext = item.pathExtension.lowercased()

            guard name.hasPrefix("AwesomeAudio_"), ext == "caf" || ext == "wav" else {
                continue
            }

            if let values = try? item.resourceValues(forKeys: [.creationDateKey]),
               let created = values.creationDate,
               created < cutoff {
                try? fm.removeItem(at: item)
            }
        }
    }
}
