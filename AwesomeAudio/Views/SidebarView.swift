import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - SidebarView

struct SidebarView: View {

    var presetManager: PresetManager
    var viewModel: AudioProcessingViewModel
    @Binding var showingPresetEditor: Bool
    @Binding var editingPreset: Preset?

    @State private var selectedPresetID: UUID?
    @State private var presetErrorMessage: String?

    var body: some View {
        List(selection: $selectedPresetID) {
            presetsSection
            historySection
        }
        .listStyle(.sidebar)
        .navigationTitle("Awesome Audio")
        .toolbar {
            ToolbarItem(placement: .secondaryAction) {
                Menu {
                    Button {
                        importPresets()
                    } label: {
                        Label("Import Presets…", systemImage: "square.and.arrow.down.on.square")
                    }

                    Button {
                        exportUserPresets()
                    } label: {
                        Label("Export User Presets…", systemImage: "square.and.arrow.up")
                    }
                    .disabled(presetManager.customPresets().isEmpty)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .help("Preset library actions")
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    editingPreset = nil
                    showingPresetEditor = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("Save current settings as preset")
                .disabled(viewModel.appState == .empty)
            }
        }
        .onChange(of: selectedPresetID) { _, newID in
            guard let id = newID,
                  let preset = presetManager.allPresets().first(where: { $0.id == id }) else { return }
            viewModel.applyPreset(preset)
        }
        .alert("Preset Action Failed", isPresented: presetErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(presetErrorMessage ?? presetManager.lastErrorMessage ?? "The preset library could not be updated.")
        }
    }

    // MARK: - Sections

    private var presetsSection: some View {
        Section("Presets") {
            ForEach(presetManager.allPresets(), id: \.id) { preset in
                presetRow(preset)
                    .tag(preset.id)
            }
        }
    }

    private var historySection: some View {
        Section("Recent Files") {
            VStack(alignment: .leading, spacing: 4) {
                Label("Ready for new audio", systemImage: "waveform")
                    .foregroundStyle(.secondary)
                Text("Drop or choose a file in the main workspace.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Preset Row

    private func presetRow(_ preset: Preset) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 1) {
                Text(preset.name)
                    .font(.callout)
                Text(presetSubtitle(preset))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: preset.isBuiltIn ? "sparkles" : "slider.horizontal.3")
                .foregroundStyle(preset.isBuiltIn ? .blue : .purple)
        }
        .contextMenu {
            Button {
                editingPreset = preset
                showingPresetEditor = true
            } label: {
                Label(preset.isBuiltIn ? "Customize…" : "Edit…", systemImage: "slider.horizontal.3")
            }

            Button {
                let copy = presetManager.duplicatePreset(preset)
                selectedPresetID = copy.id
                viewModel.applyPreset(copy)
            } label: {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }

            Button {
                exportPreset(preset)
            } label: {
                Label("Export…", systemImage: "square.and.arrow.up")
            }

            if !preset.isBuiltIn {
                Divider()
                Button(role: .destructive) {
                    presetManager.deletePreset(preset)
                    if selectedPresetID == preset.id {
                        selectedPresetID = nil
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Helpers

    private func presetSubtitle(_ preset: Preset) -> String {
        let origin = preset.isBuiltIn ? "Factory" : "Custom"
        return "\(origin) · \(Int(preset.targetLUFS)) LUFS · \(preset.compressionPreset.rawValue.capitalized)"
    }

    private func exportPreset(_ preset: Preset) {
        let panel = NSSavePanel()
        panel.title = "Export Preset"
        panel.nameFieldStringValue = "\(preset.name).awesomepreset"
        panel.allowedContentTypes = [UTType(filenameExtension: "awesomepreset") ?? .json]
        panel.canCreateDirectories = true
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try presetManager.exportPreset(preset, to: url)
            } catch {
                presetErrorMessage = error.localizedDescription
            }
        }
    }

    private func exportUserPresets() {
        let panel = NSSavePanel()
        panel.title = "Export User Presets"
        panel.nameFieldStringValue = "Awesome Audio Presets.awesomepresets"
        panel.allowedContentTypes = [UTType(filenameExtension: "awesomepresets") ?? .json]
        panel.canCreateDirectories = true
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try presetManager.exportUserPresets(to: url)
            } catch {
                presetErrorMessage = error.localizedDescription
            }
        }
    }

    private func importPresets() {
        let panel = NSOpenPanel()
        panel.title = "Import Presets"
        panel.allowedContentTypes = [
            UTType(filenameExtension: "awesomepreset") ?? .json,
            UTType(filenameExtension: "awesomepresets") ?? .json,
            .json
        ]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                let imported = try presetManager.importPresets(from: url)
                if let first = imported.first {
                    selectedPresetID = first.id
                    viewModel.applyPreset(first)
                }
            } catch {
                presetErrorMessage = error.localizedDescription
            }
        }
    }

    private var presetErrorBinding: Binding<Bool> {
        Binding(
            get: { presetErrorMessage != nil || presetManager.lastErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    presetErrorMessage = nil
                    presetManager.lastErrorMessage = nil
                }
            }
        )
    }
}
