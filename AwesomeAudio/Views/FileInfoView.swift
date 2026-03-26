import SwiftUI

// MARK: - FileInfoView

struct FileInfoView: View {

    var viewModel: AudioProcessingViewModel

    var body: some View {
        HStack(spacing: 12) {
            fileIcon
            fileDetails
            Spacer()
            lufsDisplay
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    // MARK: - File Icon

    private var fileIcon: some View {
        Image(systemName: iconName)
            .font(.system(size: 28))
            .foregroundStyle(.secondary)
            .frame(width: 36)
    }

    private var iconName: String {
        guard let url = viewModel.audioFileInfo?.sourceURL else { return "waveform" }
        switch url.pathExtension.lowercased() {
        case "mp3": return "music.note"
        case "wav": return "waveform"
        case "aiff", "aif": return "waveform.badge.mic"
        case "m4a": return "play.rectangle.fill"
        default: return "waveform"
        }
    }

    // MARK: - File Details

    private var fileDetails: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(viewModel.audioFileInfo?.sourceURL.lastPathComponent ?? "—")
                .font(.callout.weight(.medium))
                .lineLimit(1)
                .truncationMode(.middle)

            Text(formatDetails)
                .font(.caption)
                .foregroundStyle(.secondary)

            if showsMonoProcessingWarning {
                Text("Current processing path exports mono output for stereo sources.")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var formatDetails: String {
        guard let info = viewModel.audioFileInfo else { return "" }
        let sr = formatSampleRate(info.originalSampleRate)
        let ch = info.originalChannelCount == 1 ? "Mono" : "Stereo"
        let bd = info.originalBitDepth > 0 ? "\(info.originalBitDepth)-bit" : ""
        let dur = formatDuration(info.duration)
        let size = ByteCountFormatter.string(fromByteCount: Int64(info.fileSizeBytes), countStyle: .file)
        return [bd, sr, ch, dur, size].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func formatSampleRate(_ rate: Double) -> String {
        if rate >= 1000 {
            let khz = rate / 1000
            return khz.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(khz)) kHz"
                : String(format: "%.1f kHz", khz)
        }
        return "\(Int(rate)) Hz"
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var showsMonoProcessingWarning: Bool {
        (viewModel.audioFileInfo?.originalChannelCount ?? 1) > 1
    }

    // MARK: - LUFS Display

    private var lufsDisplay: some View {
        HStack(spacing: 8) {
            if viewModel.isAnalyzingInput {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 16, height: 16)
                Text("Analyzing…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let lufs = viewModel.inputLUFS {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(String(format: "%.1f LUFS", lufs))
                        .font(.callout.monospacedDigit().weight(.medium))
                        .foregroundStyle(lufsColor(lufs))
                    Text("Input Level")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func lufsColor(_ lufs: Float) -> Color {
        if lufs > -10 { return .red }
        if lufs > -18 { return .primary }
        return .secondary
    }
}
