import AppKit
import Foundation
import Observation

// MARK: - AppState

enum AppState: Equatable {
    case empty
    case fileLoaded
    case processing
    case results
    case error(String)
}

// MARK: - AudioProcessingViewModel

@Observable
@MainActor
final class AudioProcessingViewModel {

    // MARK: - App State

    var appState: AppState = .empty

    // MARK: - File / Audio Info

    var audioFileInfo: AudioFileInfo?

    // MARK: - Preset Selection

    var selectedPreset: Preset?

    // MARK: - Analysis

    var inputLUFS: Float?
    var isAnalyzingInput: Bool = false

    // MARK: - Processing Progress

    var progress: ProcessingProgress?

    // MARK: - Processing Result

    var processingResult: ProcessingCoordinator.ProcessingResult?

    // MARK: - Editable Settings (mirror of active preset, user-adjustable)

    var highPassCutoff: Float = 80
    var noiseReductionStrength: Float = 0.7
    var deEssAmount: Float = 0.5
    var compressionPreset: CompressionPreset = .medium
    var targetLUFS: Float = -16
    var outputBitDepth: Int = 24

    // MARK: - Computed

    /// Rough estimate of temp disk space needed (3× source file for processing headroom).
    var estimatedTempStorage: String {
        guard let info = audioFileInfo else { return "—" }
        let bytes = info.fileSizeBytes * 3
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    // MARK: - Private

    private let coordinator = ProcessingCoordinator()
    private let adapter = AudioFormatAdapter()
    private var processingTask: Task<Void, Never>?
    private var analysisTask: Task<Void, Never>?

    // MARK: - File Loading

    func loadFile(url: URL) {
        do {
            let info = try adapter.load(url: url)
            audioFileInfo = info
            appState = .fileLoaded
            startLUFSAnalysis(for: info)
        } catch {
            appState = .error(error.localizedDescription)
        }
    }

    // MARK: - Preset Application

    func applyPreset(_ preset: Preset) {
        selectedPreset = preset
        highPassCutoff = preset.highPassCutoff
        noiseReductionStrength = preset.noiseReductionStrength
        deEssAmount = preset.deEssAmount
        compressionPreset = preset.compressionPreset
        targetLUFS = preset.targetLUFS
        outputBitDepth = preset.outputBitDepth
    }

    // MARK: - Processing

    func startProcessing() {
        guard let info = audioFileInfo else { return }
        appState = .processing
        progress = ProcessingProgress(stageName: "Starting…", fractionComplete: 0.0, passNumber: 1)

        let snapshot = makeSnapshot()

        processingTask = Task {
            do {
                let result = try await coordinator.process(
                    audioInfo: info,
                    preset: snapshot,
                    progress: { [weak self] prog in
                        Task { @MainActor [weak self] in
                            self?.progress = prog
                        }
                    }
                )
                self.processingResult = result
                self.appState = .results
            } catch ProcessingError.cancelled {
                self.appState = .fileLoaded
            } catch {
                self.appState = .error(error.localizedDescription)
            }
        }
    }

    func cancelProcessing() {
        processingTask?.cancel()
        processingTask = nil
        Task {
            await coordinator.cancelAndCleanup()
        }
        appState = .fileLoaded
    }

    // MARK: - Export

    func exportFile() {
        guard let result = processingResult else { return }

        let panel = NSSavePanel()
        panel.title = "Save Processed Audio"
        panel.allowedContentTypes = [.wav, .aiff, .audio]
        panel.nameFieldStringValue = suggestedOutputFilename()
        panel.canCreateDirectories = true

        let tempURL = result.tempOutputURL
        panel.begin { [weak self] response in
            guard response == .OK, let destURL = panel.url else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                do {
                    try await self.coordinator.export(tempURL: tempURL, to: destURL)
                } catch {
                    self.appState = .error(error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Reset

    func processAnother() {
        processingTask?.cancel()
        analysisTask?.cancel()
        audioFileInfo = nil
        processingResult = nil
        progress = nil
        inputLUFS = nil
        isAnalyzingInput = false
        selectedPreset = nil
        appState = .empty
    }

    // MARK: - Private Helpers

    private func makeSnapshot() -> PresetSnapshot {
        PresetSnapshot(
            highPassCutoff: highPassCutoff,
            noiseReductionStrength: noiseReductionStrength,
            noiseReductionAttenLimitDB: noiseReductionStrength * 100.0,
            deEssAmount: deEssAmount,
            compressionPreset: compressionPreset,
            targetLUFS: targetLUFS,
            truePeakCeiling: -1.0,
            outputBitDepth: outputBitDepth
        )
    }

    private func startLUFSAnalysis(for info: AudioFileInfo) {
        analysisTask?.cancel()
        isAnalyzingInput = true
        inputLUFS = nil

        analysisTask = Task.detached(priority: .userInitiated) { [weak self] in
            let analyzer = LUFSAnalyzer()
            let samples = info.samples
            samples.withUnsafeBufferPointer { ptr in
                if let base = ptr.baseAddress {
                    analyzer.analyze(base, frameCount: samples.count)
                }
            }
            let result = analyzer.finalize()

            await MainActor.run { [weak self] in
                self?.inputLUFS = result.measuredLUFS
                self?.isAnalyzingInput = false
            }
        }
    }

    private func suggestedOutputFilename() -> String {
        guard let info = audioFileInfo else { return "processed_audio.wav" }
        let base = info.sourceURL.deletingPathExtension().lastPathComponent
        return "\(base)_processed.wav"
    }
}
