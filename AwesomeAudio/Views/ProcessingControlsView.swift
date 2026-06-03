import AppKit
import SwiftUI

// MARK: - ProcessingControlsView

struct ProcessingControlsView: View {

    @Bindable var viewModel: AudioProcessingViewModel
    var onSavePreset: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                controlGrid
                targetOutputRow
                storageNote
                processButton
            }
            .frame(maxWidth: 980, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Processing Chain")
                    .font(.title2.bold())
                Text("Tune cleanup, tone, dynamics, and delivery target before rendering.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                onSavePreset()
            } label: {
                Label(viewModel.selectedPreset == nil ? "Save Preset" : "Edit Preset", systemImage: "slider.horizontal.3")
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Control Grid

    private var controlGrid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 260), spacing: 14)],
            spacing: 14
        ) {
            noiseReductionCard
            hpfCard
            deEssingCard
            compressionCard
            presenceCard
            airCard
        }
    }

    // MARK: - Cards

    private var noiseReductionCard: some View {
        ControlCard(
            title: "Noise Reduction",
            icon: "waveform.badge.minus",
            iconColor: .blue
        ) {
            VStack(spacing: 6) {
                Slider(value: $viewModel.noiseReductionStrength, in: 0...1)
                    .tint(.blue)
                HStack {
                    Text("Off").font(.caption2).foregroundStyle(.tertiary)
                    Spacer()
                    Text("\(Int(viewModel.noiseReductionStrength * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Max").font(.caption2).foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var hpfCard: some View {
        ControlCard(
            title: "High-Pass Filter",
            icon: "waveform.path.ecg",
            iconColor: .green
        ) {
            VStack(spacing: 6) {
                Slider(value: $viewModel.highPassCutoff, in: 60...120, step: 5)
                    .tint(.green)
                HStack {
                    Text("60 Hz").font(.caption2).foregroundStyle(.tertiary)
                    Spacer()
                    Text("\(Int(viewModel.highPassCutoff)) Hz")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("120 Hz").font(.caption2).foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var deEssingCard: some View {
        ControlCard(
            title: "De-Essing",
            icon: "mic.fill",
            iconColor: .orange
        ) {
            VStack(spacing: 6) {
                Slider(value: $viewModel.deEssAmount, in: 0...1)
                    .tint(.orange)
                HStack {
                    Text("Off").font(.caption2).foregroundStyle(.tertiary)
                    Spacer()
                    Text("\(Int(viewModel.deEssAmount * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Max").font(.caption2).foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var compressionCard: some View {
        ControlCard(
            title: "Compression",
            icon: "dial.medium.fill",
            iconColor: .purple
        ) {
            Picker("Compression", selection: $viewModel.compressionPreset) {
                ForEach(CompressionPreset.allCases, id: \.self) { preset in
                    Text(preset.rawValue.capitalized).tag(preset)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    private var presenceCard: some View {
        ControlCard(
            title: "Presence",
            icon: "speaker.wave.2.circle",
            iconColor: .pink
        ) {
            VStack(spacing: 6) {
                Slider(value: $viewModel.presenceAmount, in: 0...1)
                    .tint(.pink)
                HStack {
                    Text("Flat").font(.caption2).foregroundStyle(.tertiary)
                    Spacer()
                    Text("\(Int(viewModel.presenceAmount * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Lift").font(.caption2).foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var airCard: some View {
        ControlCard(
            title: "Air",
            icon: "sparkles",
            iconColor: .mint
        ) {
            VStack(spacing: 6) {
                Slider(value: $viewModel.airAmount, in: 0...1)
                    .tint(.mint)
                HStack {
                    Text("Flat").font(.caption2).foregroundStyle(.tertiary)
                    Spacer()
                    Text("\(Int(viewModel.airAmount * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Lift").font(.caption2).foregroundStyle(.tertiary)
                }
            }
        }
    }

    // MARK: - Target & Output Row

    private var targetOutputRow: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 14)], spacing: 14) {
            ControlCard(
                title: "Target Loudness",
                icon: "speaker.wave.3.fill",
                iconColor: .teal
            ) {
                Picker("Target Loudness", selection: $viewModel.targetLUFS) {
                    Text("-16 LUFS").tag(Float(-16))
                    Text("-14 LUFS").tag(Float(-14))
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            ControlCard(
                title: "Output Bit Depth",
                icon: "waveform.and.magnifyingglass",
                iconColor: .indigo
            ) {
                Picker("Output Bit Depth", selection: $viewModel.outputBitDepth) {
                    Text("16-bit").tag(16)
                    Text("24-bit").tag(24)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            ControlCard(
                title: "True Peak Ceiling",
                icon: "gauge.with.dots.needle.33percent",
                iconColor: .red
            ) {
                VStack(spacing: 6) {
                    Slider(value: $viewModel.truePeakCeiling, in: -3.0 ... -1.0, step: 0.5)
                        .tint(.red)
                    HStack {
                        Text("-3 dBTP").font(.caption2).foregroundStyle(.tertiary)
                        Spacer()
                        Text(String(format: "%.1f dBTP", viewModel.truePeakCeiling))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("-1 dBTP").font(.caption2).foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    // MARK: - Storage Note

    private var storageNote: some View {
        HStack(spacing: 6) {
            Image(systemName: "internaldrive")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Temp storage estimate: \(viewModel.estimatedTempStorage)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Process Button

    private var processButton: some View {
        Button {
            viewModel.startProcessing()
        } label: {
            Label("Process Audio", systemImage: "sparkles")
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }
}

// MARK: - ControlCard

private struct ControlCard<Content: View>: View {

    let title: String
    let icon: String
    let iconColor: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text(title)
                    .font(.callout.weight(.medium))
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
            }

            content()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        )
    }
}
