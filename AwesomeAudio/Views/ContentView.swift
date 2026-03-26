import SwiftUI

// MARK: - ContentView

struct ContentView: View {

    @State private var viewModel = AudioProcessingViewModel()
    @State private var presetManager = PresetManager()
    @State private var showingPresetEditor = false

    var body: some View {
        NavigationSplitView {
            SidebarView(
                presetManager: presetManager,
                viewModel: viewModel,
                showingPresetEditor: $showingPresetEditor
            )
        } detail: {
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 780, minHeight: 520)
        .sheet(isPresented: $showingPresetEditor) {
            PresetEditorView(
                viewModel: viewModel,
                presetManager: presetManager,
                isPresented: $showingPresetEditor
            )
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
                ProcessingControlsView(viewModel: viewModel)
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
