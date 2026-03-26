import SwiftUI

@main
struct AwesomeAudioApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 900, height: 600)
    }

    init() {
        TempFileManager.cleanupStaleFiles()
    }
}
