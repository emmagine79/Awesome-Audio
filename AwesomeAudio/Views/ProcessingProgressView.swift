import SwiftUI

// MARK: - ProcessingProgressView

struct ProcessingProgressView: View {

    var viewModel: AudioProcessingViewModel

    @State private var pulseAmount = 1.0

    var body: some View {
        VStack(spacing: 32) {
            animatedIcon
            stageInfo
            progressBar
            cancelButton
        }
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Animated Icon

    private var animatedIcon: some View {
        Image(systemName: "waveform")
            .font(.system(size: 64, weight: .ultraLight))
            .foregroundStyle(Color.accentColor)
            .scaleEffect(pulseAmount)
            .animation(
                .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                value: pulseAmount
            )
            .onAppear {
                pulseAmount = 1.12
            }
    }

    // MARK: - Stage Info

    private var stageInfo: some View {
        VStack(spacing: 8) {
            Text(viewModel.progress?.stageName ?? "Processing…")
                .font(.title3.weight(.medium))
                .contentTransition(.numericText())
                .animation(.default, value: viewModel.progress?.stageName)

            if let pass = viewModel.progress?.passNumber, pass > 1 {
                Text("Pass \(pass)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        let fraction = viewModel.progress?.fractionComplete ?? 0

        return VStack(spacing: 8) {
            ProgressView(value: fraction)
                .progressViewStyle(.linear)
                .frame(maxWidth: 360)
                .tint(Color.accentColor)

            Text("\(Int(fraction * 100))%")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
                .animation(.default, value: Int(fraction * 100))
        }
    }

    // MARK: - Cancel Button

    private var cancelButton: some View {
        Button("Cancel") {
            viewModel.cancelProcessing()
        }
        .buttonStyle(.bordered)
        .foregroundStyle(.secondary)
    }
}
