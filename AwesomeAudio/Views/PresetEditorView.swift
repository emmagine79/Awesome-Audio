import SwiftUI

// MARK: - PresetEditorView

struct PresetEditorView: View {

    var viewModel: AudioProcessingViewModel
    var presetManager: PresetManager
    @Binding var isPresented: Bool

    @State private var presetName: String = ""
    @State private var highPassCutoff: Float = 80
    @State private var noiseReductionStrength: Float = 0.35
    @State private var deEssAmount: Float = 0.5
    @State private var compressionPreset: CompressionPreset = .medium
    @State private var targetLUFS: Float = -16
    @State private var outputBitDepth: Int = 24

    private var isNameValid: Bool {
        !presetName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                formContent
                    .padding(24)
            }
            Divider()
            footer
        }
        .frame(minWidth: 460, maxWidth: 520, minHeight: 480)
        .onAppear {
            loadFromViewModel()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "slider.horizontal.3")
                .font(.title3)
                .foregroundStyle(.purple)
            Text("Save as Preset")
                .font(.title3.bold())
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: - Form Content

    private var formContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Preset name
            VStack(alignment: .leading, spacing: 6) {
                Label("Preset Name", systemImage: "tag")
                    .font(.callout.weight(.medium))
                TextField("My Preset", text: $presetName)
                    .textFieldStyle(.roundedBorder)
            }

            Divider()

            // Noise Reduction
            EditorSliderRow(
                title: "Noise Reduction",
                icon: "waveform.badge.minus",
                iconColor: .blue,
                value: $noiseReductionStrength,
                range: 0...1,
                displayValue: "\(Int(noiseReductionStrength * 100))%"
            )

            // High-Pass Filter
            EditorSliderRow(
                title: "High-Pass Filter",
                icon: "waveform.path.ecg",
                iconColor: .green,
                value: $highPassCutoff,
                range: 60...120,
                step: 5,
                displayValue: "\(Int(highPassCutoff)) Hz"
            )

            // De-Essing
            EditorSliderRow(
                title: "De-Essing",
                icon: "mic.fill",
                iconColor: .orange,
                value: $deEssAmount,
                range: 0...1,
                displayValue: "\(Int(deEssAmount * 100))%"
            )

            // Compression
            VStack(alignment: .leading, spacing: 6) {
                Label("Compression", systemImage: "dial.medium.fill")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.purple)
                Picker("Compression", selection: $compressionPreset) {
                    ForEach(CompressionPreset.allCases, id: \.self) { p in
                        Text(p.rawValue.capitalized).tag(p)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            // Target Loudness
            VStack(alignment: .leading, spacing: 6) {
                Label("Target Loudness", systemImage: "speaker.wave.3.fill")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.teal)
                Picker("Target Loudness", selection: $targetLUFS) {
                    Text("-16 LUFS").tag(Float(-16))
                    Text("-14 LUFS").tag(Float(-14))
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            // Output Bit Depth
            VStack(alignment: .leading, spacing: 6) {
                Label("Output Bit Depth", systemImage: "waveform.and.magnifyingglass")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.indigo)
                Picker("Output Bit Depth", selection: $outputBitDepth) {
                    Text("16-bit").tag(16)
                    Text("24-bit").tag(24)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("Cancel") {
                isPresented = false
            }
            .buttonStyle(.bordered)

            Spacer()

            Button("Create Preset") {
                createPreset()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isNameValid)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: - Actions

    private func loadFromViewModel() {
        highPassCutoff = viewModel.highPassCutoff
        noiseReductionStrength = viewModel.noiseReductionStrength
        deEssAmount = viewModel.deEssAmount
        compressionPreset = viewModel.compressionPreset
        targetLUFS = viewModel.targetLUFS
        outputBitDepth = viewModel.outputBitDepth
    }

    private func createPreset() {
        let source = Preset(
            name: presetName.trimmingCharacters(in: .whitespaces),
            isBuiltIn: false,
            highPassCutoff: highPassCutoff,
            noiseReductionStrength: noiseReductionStrength,
            deEssAmount: deEssAmount,
            compressionPreset: compressionPreset,
            targetLUFS: targetLUFS,
            outputBitDepth: outputBitDepth
        )
        presetManager.createPreset(from: source, name: source.name)
        isPresented = false
    }
}

// MARK: - EditorSliderRow

private struct EditorSliderRow: View {
    let title: String
    let icon: String
    let iconColor: Color
    @Binding var value: Float
    let range: ClosedRange<Float>
    var step: Float = 0
    let displayValue: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(iconColor)
                Spacer()
                Text(displayValue)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if step > 0 {
                Slider(value: $value, in: range, step: step)
                    .tint(iconColor)
            } else {
                Slider(value: $value, in: range)
                    .tint(iconColor)
            }
        }
    }
}
