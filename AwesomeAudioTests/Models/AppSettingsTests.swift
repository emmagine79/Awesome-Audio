import Foundation
import Testing
@testable import AwesomeAudio

@Suite("App Settings Tests")
struct AppSettingsTests {

    @Test func settingsPersistAcrossInstances() throws {
        let defaults = try testDefaults()
        let settings = AppSettings(defaults: defaults)

        settings.defaultTargetLUFS = -14
        settings.defaultOutputBitDepth = 16
        settings.truePeakCeiling = -1.5
        settings.outputSuffix = "_mastered"
        settings.revealExportInFinder = true

        let reloaded = AppSettings(defaults: defaults)
        #expect(reloaded.defaultTargetLUFS == -14)
        #expect(reloaded.defaultOutputBitDepth == 16)
        #expect(reloaded.truePeakCeiling == -1.5)
        #expect(reloaded.outputSuffix == "_mastered")
        #expect(reloaded.revealExportInFinder)
    }

    @Test func resetRestoresSafePodcastDefaults() throws {
        let settings = AppSettings(defaults: try testDefaults())
        settings.defaultTargetLUFS = -14
        settings.defaultOutputBitDepth = 16
        settings.outputSuffix = "_loud"

        settings.reset()

        #expect(settings.defaultTargetLUFS == -16)
        #expect(settings.defaultOutputBitDepth == 24)
        #expect(settings.outputSuffix == "_processed")
    }

    private func testDefaults() throws -> UserDefaults {
        let suiteName = "AwesomeAudioTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
