import SwiftUI

// MARK: - ContentView

public struct ContentView: View {

    @State private var viewModel = AudioProcessingViewModel()
    var appSettings: AppSettings
    var presetManager: PresetManager
    @State private var showingPresetEditor = false
    @State private var editingPreset: Preset?

    public init(appSettings: AppSettings, presetManager: PresetManager) {
        self.appSettings = appSettings
        self.presetManager = presetManager
    }

    public var body: some View {
        NavigationSplitView {
            SidebarView(
                presetManager: presetManager,
                viewModel: viewModel,
                showingPresetEditor: $showingPresetEditor,
                editingPreset: $editingPreset
            )
            .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 360)
        } detail: {
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 1080, minHeight: 680)
        .onAppear {
            viewModel.applySettings(appSettings)
        }
        .onChange(of: appSettings.defaultTargetLUFS) { _, _ in viewModel.applySettings(appSettings) }
        .onChange(of: appSettings.defaultOutputBitDepth) { _, _ in viewModel.applySettings(appSettings) }
        .onChange(of: appSettings.truePeakCeiling) { _, _ in viewModel.applySettings(appSettings) }
        .onChange(of: appSettings.outputSuffix) { _, _ in viewModel.applySettings(appSettings) }
        .onChange(of: appSettings.revealExportInFinder) { _, _ in viewModel.applySettings(appSettings) }
        .sheet(isPresented: $showingPresetEditor) {
            PresetEditorView(
                viewModel: viewModel,
                presetManager: presetManager,
                editingPreset: editingPreset,
                isPresented: $showingPresetEditor
            )
        }
        .onChange(of: showingPresetEditor) { _, isShowing in
            if !isShowing {
                editingPreset = nil
            }
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailView: some View {
        switch viewModel.appState {
        case .empty:
            DropZoneView(viewModel: viewModel)
        case .fileLoaded:
            VStack(spacing: 0) {
                FileInfoView(viewModel: viewModel)
                Divider()
                ProcessingControlsView(
                    viewModel: viewModel,
                    onSavePreset: {
                        editingPreset = viewModel.selectedPreset
                        showingPresetEditor = true
                    }
                )
            }
        case .processing:
            ProcessingProgressView(viewModel: viewModel)
        case .results:
            ResultsView(viewModel: viewModel)
        case .error(let message):
            errorView(message: message)
        }
    }

    @ViewBuilder
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("Something went wrong")
                .font(.title2.bold())
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
            Button("Start Over") {
                viewModel.processAnother()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(40)
    }
}
