import SwiftUI

// MARK: - SidebarView

struct SidebarView: View {

    var presetManager: PresetManager
    var viewModel: AudioProcessingViewModel
    @Binding var showingPresetEditor: Bool

    @State private var selectedPresetID: UUID?

    var body: some View {
        List(selection: $selectedPresetID) {
            presetsSection
            historySection
        }
        .listStyle(.sidebar)
        .navigationTitle("Awesome Audio")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
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
            Label("History coming soon", systemImage: "clock")
                .foregroundStyle(.tertiary)
                .font(.callout)
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
            if !preset.isBuiltIn {
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
        "\(Int(preset.targetLUFS)) LUFS · \(preset.compressionPreset.rawValue.capitalized)"
    }
}
