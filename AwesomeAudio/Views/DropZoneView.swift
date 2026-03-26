import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - DropZoneView

struct DropZoneView: View {

    var viewModel: AudioProcessingViewModel

    @State private var isTargeted = false

    private let supportedUTTypes: [UTType] = [
        .wav, .mp3, .aiff, .audio,
        UTType("public.m4a-audio") ?? .audio
    ]

    var body: some View {
        ZStack {
            dropZone
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Drop Zone

    private var dropZone: some View {
        VStack(spacing: 24) {
            waveformIcon
            instructionText
            chooseFileButton
            formatsNote
        }
        .padding(48)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.secondary.opacity(0.35),
                    style: StrokeStyle(lineWidth: 2, dash: [8, 5])
                )
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isTargeted
                              ? Color.accentColor.opacity(0.07)
                              : Color.clear)
                )
        )
        .padding(40)
        .onDrop(of: supportedUTTypes, isTargeted: $isTargeted, perform: handleDrop)
        .animation(.easeInOut(duration: 0.15), value: isTargeted)
    }

    // MARK: - Sub-views

    private var waveformIcon: some View {
        Image(systemName: "waveform")
            .font(.system(size: 56, weight: .ultraLight))
            .foregroundStyle(isTargeted ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.secondary))
            .symbolEffect(.variableColor, isActive: isTargeted)
    }

    private var instructionText: some View {
        VStack(spacing: 6) {
            Text("Drop audio file here")
                .font(.title2.weight(.medium))
            Text("or")
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
    }

    private var chooseFileButton: some View {
        Button("Choose File…") {
            openFilePicker()
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    private var formatsNote: some View {
        Text("Supports WAV, MP3, M4A, AIFF")
            .font(.caption)
            .foregroundStyle(.tertiary)
    }

    // MARK: - Actions

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        // Try each supported type until one works
        let typeIdentifiers = supportedUTTypes.map(\.identifier)
        for uti in typeIdentifiers {
            if provider.hasItemConformingToTypeIdentifier(uti) {
                provider.loadItem(forTypeIdentifier: uti, options: nil) { item, _ in
                    guard let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    Task { @MainActor in
                        viewModel.loadFile(url: url)
                    }
                }
                return true
            }
        }
        return false
    }

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.title = "Choose an Audio File"
        panel.allowedContentTypes = supportedUTTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                viewModel.loadFile(url: url)
            }
        }
    }
}
