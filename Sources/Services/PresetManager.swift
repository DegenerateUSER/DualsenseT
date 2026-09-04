import Foundation

public class PresetManager: ObservableObject {
    @Published public var customPresets: [TriggerPreset] = []
    
    private var presetsFolder: URL {
        let presetsDir = AppIdentity.applicationSupportDirectory
            .appendingPathComponent("presets", isDirectory: true)
        
        try? FileManager.default.createDirectory(at: presetsDir, withIntermediateDirectories: true, attributes: nil)
        return presetsDir
    }
    
    public init() {
        loadCustomPresets()
    }
    
    public func loadCustomPresets() {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: presetsFolder, includingPropertiesForKeys: nil)
            var loaded: [TriggerPreset] = []
            for file in files {
                if file.pathExtension == "json" {
                    let data = try Data(contentsOf: file)
                    let preset = try JSONDecoder().decode(TriggerPreset.self, from: data)
                    loaded.append(preset)
                }
            }
            DispatchQueue.main.async {
                self.customPresets = loaded.sorted(by: { $0.name < $1.name })
            }
        } catch {
            print("Failed to load presets: \(error)")
        }
    }
    
    /// Maps a preset name to a stable, filesystem-safe filename. Names made up entirely of
    /// punctuation would otherwise collapse to an empty string (→ a stray ".json" that could
    /// collide or delete the wrong file), so we fall back to a deterministic hash.
    private func fileName(for name: String) -> String {
        let safe = name.lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }
        return safe.isEmpty ? "preset_\(abs(name.hashValue))" : safe
    }

    public func savePreset(preset: TriggerPreset) {
        do {
            let fileURL = presetsFolder.appendingPathComponent("\(fileName(for: preset.name)).json")
            let data = try JSONEncoder().encode(preset)
            try data.write(to: fileURL)
            loadCustomPresets()
        } catch {
            print("Failed to save preset: \(error)")
        }
    }

    public func deletePreset(preset: TriggerPreset) {
        do {
            let fileURL = presetsFolder.appendingPathComponent("\(fileName(for: preset.name)).json")
            try FileManager.default.removeItem(at: fileURL)
            loadCustomPresets()
        } catch {
            print("Failed to delete preset: \(error)")
        }
    }
}
