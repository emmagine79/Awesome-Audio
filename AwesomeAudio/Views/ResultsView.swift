import SwiftUI

// MARK: - ResultsView

struct ResultsView: View {

    var viewModel: AudioProcessingViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                successHeader
                comparisonTable
                processingTimeRow
                toleranceNote
                actionButtons
            }
            .padding(40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Success Header

    private var successHeader: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(.green)
                .symbolEffect(.bounce, value: true)

            Text("Processing Complete")
                .font(.title2.bold())

            if let url = viewModel.audioFileInfo?.sourceURL {
                Text(url.lastPathComponent)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Comparison Table

    private var comparisonTable: some View {
        VStack(spacing: 0) {
            // Header row
            comparisonHeaderRow

            Divider()

            // LUFS row
            if let result = viewModel.processingResult {
                comparisonRow(
                    label: "Integrated Loudness",
                    before: String(format: "%.1f LUFS", result.beforeLUFS),
                    after: String(format: "%.1f LUFS", result.afterLUFS),
                    afterColor: lufsResultColor(result.afterLUFS)
                )

                Divider()

                comparisonRow(
                    label: "True Peak",
                    before: String(format: "%.1f dBTP", result.beforeTruePeak),
                    after: String(format: "%.1f dBTP", result.afterTruePeak),
                    afterColor: peakResultColor(result.afterTruePeak)
                )
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .frame(maxWidth: 480)
    }

    private var comparisonHeaderRow: some View {
        HStack {
            Text("Metric")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Before")
                .frame(width: 110, alignment: .center)
            Text("After")
                .frame(width: 110, alignment: .center)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func comparisonRow(
        label: String,
        before: String,
        after: String,
        afterColor: Color
    ) -> some View {
        HStack {
            Text(label)
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(before)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .center)
            Text(after)
                .font(.callout.monospacedDigit().weight(.semibold))
                .foregroundStyle(afterColor)
                .frame(width: 110, alignment: .center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Processing Time

    private var processingTimeRow: some View {
        Group {
            if let duration = viewModel.processingResult?.processingDuration, duration > 0 {
                Label(
                    String(format: "Processed in %.1f seconds", duration),
                    systemImage: "timer"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Tolerance Note

    @ViewBuilder
    private var toleranceNote: some View {
        if let result = viewModel.processingResult {
            let delta = abs(result.afterLUFS - viewModel.targetLUFS)
            if delta > 0.5 {
                Label(
                    String(format: "Output is %.1f LUFS (target: %.0f). Delta: ±%.1f",
                           result.afterLUFS, viewModel.targetLUFS, delta),
                    systemImage: "info.circle"
                )
                .font(.caption)
                .foregroundStyle(.orange)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.orange.opacity(0.1))
                )
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button {
                viewModel.processAnother()
            } label: {
                Label("Process Another", systemImage: "arrow.counterclockwise")
                    .frame(minWidth: 160)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Button {
                viewModel.exportFile()
            } label: {
                Label("Save As…", systemImage: "square.and.arrow.down")
                    .frame(minWidth: 160)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    // MARK: - Color Helpers

    private func lufsResultColor(_ lufs: Float) -> Color {
        let delta = abs(lufs - viewModel.targetLUFS)
        if delta <= 0.5 { return .green }
        if delta <= 1.5 { return .orange }
        return .red
    }

    private func peakResultColor(_ peak: Float) -> Color {
        if peak <= -1.0 { return .green }
        if peak <= 0.0 { return .orange }
        return .red
    }
}

import AppKit
