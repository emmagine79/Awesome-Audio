import SwiftUI

@main
struct AwesomeAudioApp: App {

    init() {
        TempFileManager.cleanupStaleFiles()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 900, height: 620)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
