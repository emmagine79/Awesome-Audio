import SwiftUI
import SwiftData

@main
struct AwesomeAudioApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Preset.self, ProcessingRecord.self])
    }
}
