import AwesomeAudio
import SwiftUI

@main
struct AwesomeAudioExecutable: App {
    @State private var appSettings = AppSettings()
    @State private var presetManager = PresetManager()

    var body: some Scene {
        WindowGroup {
            ContentView(appSettings: appSettings, presetManager: presetManager)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1180, height: 760)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }

        Settings {
            SettingsView(settings: appSettings, presetManager: presetManager)
        }
    }
}
