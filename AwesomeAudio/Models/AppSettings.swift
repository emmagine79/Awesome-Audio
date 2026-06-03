import Foundation
import Observation

@Observable
public final class AppSettings {
    public var defaultTargetLUFS: Float { didSet { defaults.set(defaultTargetLUFS, forKey: Keys.defaultTargetLUFS) } }
    public var defaultOutputBitDepth: Int { didSet { defaults.set(defaultOutputBitDepth, forKey: Keys.defaultOutputBitDepth) } }
    public var truePeakCeiling: Float { didSet { defaults.set(truePeakCeiling, forKey: Keys.truePeakCeiling) } }
    public var outputSuffix: String { didSet { defaults.set(outputSuffix, forKey: Keys.outputSuffix) } }
    public var revealExportInFinder: Bool { didSet { defaults.set(revealExportInFinder, forKey: Keys.revealExportInFinder) } }
    public var cleanupTemporaryFilesOnLaunch: Bool { didSet { defaults.set(cleanupTemporaryFilesOnLaunch, forKey: Keys.cleanupTemporaryFilesOnLaunch) } }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaultTargetLUFS = (defaults.object(forKey: Keys.defaultTargetLUFS) as? NSNumber)?.floatValue ?? -16
        defaultOutputBitDepth = defaults.object(forKey: Keys.defaultOutputBitDepth) as? Int ?? 24
        truePeakCeiling = (defaults.object(forKey: Keys.truePeakCeiling) as? NSNumber)?.floatValue ?? -2.0
        outputSuffix = defaults.string(forKey: Keys.outputSuffix) ?? "_processed"
        revealExportInFinder = defaults.object(forKey: Keys.revealExportInFinder) as? Bool ?? false
        cleanupTemporaryFilesOnLaunch = defaults.object(forKey: Keys.cleanupTemporaryFilesOnLaunch) as? Bool ?? true
    }

    public func reset() {
        defaultTargetLUFS = -16
        defaultOutputBitDepth = 24
        truePeakCeiling = -2.0
        outputSuffix = "_processed"
        revealExportInFinder = false
        cleanupTemporaryFilesOnLaunch = true
    }

    private enum Keys {
        static let defaultTargetLUFS = "settings.defaultTargetLUFS"
        static let defaultOutputBitDepth = "settings.defaultOutputBitDepth"
        static let truePeakCeiling = "settings.truePeakCeiling"
        static let outputSuffix = "settings.outputSuffix"
        static let revealExportInFinder = "settings.revealExportInFinder"
        static let cleanupTemporaryFilesOnLaunch = "settings.cleanupTemporaryFilesOnLaunch"
    }
}
