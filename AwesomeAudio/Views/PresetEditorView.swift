import SwiftUI

// MARK: - PresetEditorView

struct PresetEditorView: View {

    var viewModel: AudioProcessingViewModel
    var presetManager: PresetManager
    var editingPreset: Preset?
    @Binding var isPresented: Bool

    @State private var presetName: String = ""
    @State private var highPassCutoff: Float = 80
    @State private var noiseReductionStrength: Float = 0.35
    @State private var deEssAmount: Float = 0.5
    @State private var presenceAmount: Float = 0.25
    @State private var airAmount: Float = 0.15
    @State private var compressionPreset: CompressionPreset = .medium
    @State private var targetLUFS: Float = -16
    @State private var outputBitDepth: Int = 24

    private var isEditing: Bool { editingPreset != nil }
    private var savesAsCopy: Bool { editingPreset?.isBuiltIn == true }

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
            Text(title)
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

            EditorSliderRow(
                title: "Presence",
                icon: "speaker.wave.2.circle",
                iconColor: .pink,
                value: $presenceAmount,
                range: 0...1,
                displayValue: "\(Int(presenceAmount * 100))%"
            )

            EditorSliderRow(
                title: "Air",
                icon: "sparkles",
                iconColor: .mint,
                value: $airAmount,
                range: 0...1,
                displayValue: "\(Int(airAmount * 100))%"
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

            Button(actionTitle) {
                savePreset()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isNameValid)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: - Actions

    private func loadFromViewModel() {
        let source = editingPreset ?? viewModel.selectedPreset
        presetName = editingPreset.map { $0.isBuiltIn ? "\($0.name) Custom" : $0.name } ?? ""
        highPassCutoff = source?.highPassCutoff ?? viewModel.highPassCutoff
        noiseReductionStrength = source?.noiseReductionStrength ?? viewModel.noiseReductionStrength
        deEssAmount = source?.deEssAmount ?? viewModel.deEssAmount
        presenceAmount = source?.presenceAmount ?? viewModel.presenceAmount
        airAmount = source?.airAmount ?? viewModel.airAmount
        compressionPreset = source?.compressionPreset ?? viewModel.compressionPreset
        targetLUFS = source?.targetLUFS ?? viewModel.targetLUFS
        outputBitDepth = source?.outputBitDepth ?? viewModel.outputBitDepth
    }

    private func savePreset() {
        let source = Preset(
            name: presetName.trimmingCharacters(in: .whitespaces),
            isBuiltIn: false,
            highPassCutoff: highPassCutoff,
            noiseReductionStrength: noiseReductionStrength,
            deEssAmount: deEssAmount,
            presenceAmount: presenceAmount,
            airAmount: airAmount,
            compressionPreset: compressionPreset,
            targetLUFS: targetLUFS,
            truePeakCeiling: viewModel.truePeakCeiling,
            outputBitDepth: outputBitDepth
        )
        let saved = presetManager.savePreset(target: editingPreset, from: source, name: source.name)
        viewModel.applyPreset(saved)
        isPresented = false
    }

    private var title: String {
        if savesAsCopy { return "Customize Factory Preset" }
        return isEditing ? "Edit Preset" : "Save as Preset"
    }

    private var actionTitle: String {
        if savesAsCopy { return "Save Custom Copy" }
        return isEditing ? "Save Changes" : "Create Preset"
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
