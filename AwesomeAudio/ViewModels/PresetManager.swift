import Foundation
import Observation

// MARK: - PresetManager

@Observable
public final class PresetManager {

    // MARK: - State

    var lastErrorMessage: String?
    private var presets: [Preset] = []
    private let storageURL: URL?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - Init

    public init(storageURL: URL? = PresetManager.defaultStorageURL) {
        self.storageURL = storageURL
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        seedBuiltIns()
        loadCustomPresets()
    }

    // MARK: - Public API

    func allPresets() -> [Preset] {
        presets
    }

    func customPresets() -> [Preset] {
        presets.filter { !$0.isBuiltIn }
    }

    /// Creates a new user preset copied from `source` with the given name.
    @discardableResult
    func createPreset(from source: Preset, name: String) -> Preset {
        let copy = source.copy(name: sanitizedName(name, fallback: source.name), isBuiltIn: false)
        presets.append(copy)
        saveCustomPresets()
        return copy
    }

    /// Saves edits to a user preset. Editing a built-in creates a customizable user variant.
    @discardableResult
    func savePreset(target: Preset?, from source: Preset, name: String) -> Preset {
        let cleanName = sanitizedName(name, fallback: source.name)
        guard let target, !target.isBuiltIn,
              let index = presets.firstIndex(where: { $0.id == target.id }) else {
            return createPreset(from: source, name: cleanName)
        }

        presets[index] = source.copy(
            id: target.id,
            name: cleanName,
            isBuiltIn: false,
            createdAt: target.createdAt
        )
        saveCustomPresets()
        return presets[index]
    }

    @discardableResult
    func duplicatePreset(_ preset: Preset) -> Preset {
        createPreset(from: preset, name: uniqueCopyName(for: preset.name))
    }

    /// Deletes a user-created preset. Built-in presets are protected and silently ignored.
    func deletePreset(_ preset: Preset) {
        guard !preset.isBuiltIn else { return }
        presets.removeAll { $0.id == preset.id }
        saveCustomPresets()
    }

    func resetUserPresets() {
        presets.removeAll { !$0.isBuiltIn }
        saveCustomPresets()
    }

    func exportPreset(_ preset: Preset, to url: URL) throws {
        try write(PresetLibraryFile(presets: [preset.copy(isBuiltIn: false)]), to: url)
    }

    func exportUserPresets(to url: URL) throws {
        try write(PresetLibraryFile(presets: customPresets()), to: url)
    }

    @discardableResult
    func importPresets(from url: URL) throws -> [Preset] {
        let data = try Data(contentsOf: url)
        let file = try decoder.decode(PresetLibraryFile.self, from: data)
        var existingNames = Set(presets.map(\.name))
        let imported: [Preset] = file.presets.map { incoming in
            let name = uniqueName(startingWith: incoming.name, existingNames: existingNames)
            existingNames.insert(name)
            return incoming.copy(
                name: name,
                isBuiltIn: false
            )
        }
        presets.append(contentsOf: imported)
        saveCustomPresets()
        return imported
    }

    // MARK: - Private

    public static var defaultStorageURL: URL? {
        guard let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return applicationSupport
            .appendingPathComponent("Awesome Audio", isDirectory: true)
            .appendingPathComponent("Presets.json")
    }

    private func seedBuiltIns() {
        presets = Preset.builtInPresets
    }

    private func loadCustomPresets() {
        guard let storageURL, FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            let file = try decoder.decode(PresetLibraryFile.self, from: data)
            presets.append(contentsOf: file.presets.map { $0.copy(id: $0.id, name: $0.name, isBuiltIn: false, createdAt: $0.createdAt) })
        } catch {
            lastErrorMessage = "Could not load presets: \(error.localizedDescription)"
        }
    }

    private func saveCustomPresets() {
        guard let storageURL else { return }
        do {
            try write(PresetLibraryFile(presets: customPresets()), to: storageURL)
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = "Could not save presets: \(error.localizedDescription)"
        }
    }

    private func write(_ file: PresetLibraryFile, to url: URL) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(file)
        try data.write(to: url, options: .atomic)
    }

    private func sanitizedName(_ name: String, fallback: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private func uniqueCopyName(for name: String) -> String {
        uniqueName(startingWith: "\(name) Copy", existingNames: Set(presets.map(\.name)))
    }

    private func uniqueName(startingWith base: String, existingNames: Set<String>) -> String {
        guard existingNames.contains(base) else { return base }
        var index = 2
        while existingNames.contains("\(base) \(index)") {
            index += 1
        }
        return "\(base) \(index)"
    }
}

// MARK: - PresetLibraryFile

private struct PresetLibraryFile: Codable {
    var version: Int = 1
    var presets: [Preset]
}
