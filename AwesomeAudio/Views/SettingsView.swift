import SwiftUI

public struct SettingsView: View {
    @Bindable var settings: AppSettings
    var presetManager: PresetManager

    public init(settings: AppSettings, presetManager: PresetManager) {
        self.settings = settings
        self.presetManager = presetManager
    }

    public var body: some View {
        TabView {
            processingTab
                .tabItem {
                    Label("Processing", systemImage: "waveform")
                }

            presetsTab
                .tabItem {
                    Label("Presets", systemImage: "slider.horizontal.3")
                }
        }
        .frame(width: 560, height: 360)
        .padding(20)
    }

    private var processingTab: some View {
        Form {
            Section("Default processing") {
                Picker("Target loudness", selection: $settings.defaultTargetLUFS) {
                    Text("Podcast / speech (-16 LUFS)").tag(Float(-16))
                    Text("Video platforms (-14 LUFS)").tag(Float(-14))
                }
                .pickerStyle(.segmented)

                Picker("Output bit depth", selection: $settings.defaultOutputBitDepth) {
                    Text("16-bit").tag(16)
                    Text("24-bit").tag(24)
                }
                .pickerStyle(.segmented)

                HStack {
                    Text("True peak ceiling")
                    Slider(value: $settings.truePeakCeiling, in: -3.0 ... -1.0, step: 0.5)
                    Text(String(format: "%.1f dBTP", settings.truePeakCeiling))
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 72, alignment: .trailing)
                }
            }

            Section("Export") {
                TextField("Output suffix", text: $settings.outputSuffix)
                Toggle("Reveal exported file in Finder", isOn: $settings.revealExportInFinder)
                Toggle("Clean temporary files on launch", isOn: $settings.cleanupTemporaryFilesOnLaunch)
            }

            Button("Reset Processing Defaults") {
                settings.reset()
            }
        }
        .formStyle(.grouped)
    }

    private var presetsTab: some View {
        Form {
            Section("Preset library") {
                LabeledContent("Factory presets", value: "\(presetManager.allPresets().filter(\.isBuiltIn).count)")
                LabeledContent("User presets", value: "\(presetManager.customPresets().count)")
                Text("Factory presets can be customized from the sidebar. Saving a factory edit creates a user preset so the original remains recoverable.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button(role: .destructive) {
                    presetManager.resetUserPresets()
                } label: {
                    Label("Delete All User Presets", systemImage: "trash")
                }
                .disabled(presetManager.customPresets().isEmpty)
            }
        }
        .formStyle(.grouped)
    }
}
