import Foundation

public class PresetManager: ObservableObject {
    @Published public var customPresets: [TriggerPreset] = []
    
    private var presetsFolder: URL {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupport = paths[0].appendingPathComponent("DualSenseT", isDirectory: true)
        let presetsDir = appSupport.appendingPathComponent("presets", isDirectory: true)
        
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
    
    public func savePreset(preset: TriggerPreset) {
        do {
            let safeName = preset.name.lowercased().replacingOccurrences(of: " ", with: "_").filter { $0.isLetter || $0.isNumber || $0 == "_" }
            let fileURL = presetsFolder.appendingPathComponent("\(safeName).json")
            let data = try JSONEncoder().encode(preset)
            try data.write(to: fileURL)
            loadCustomPresets()
        } catch {
            print("Failed to save preset: \(error)")
        }
    }
    
    public func deletePreset(preset: TriggerPreset) {
        do {
            let safeName = preset.name.lowercased().replacingOccurrences(of: " ", with: "_").filter { $0.isLetter || $0.isNumber || $0 == "_" }
            let fileURL = presetsFolder.appendingPathComponent("\(safeName).json")
            try FileManager.default.removeItem(at: fileURL)
            loadCustomPresets()
        } catch {
            print("Failed to delete preset: \(error)")
        }
    }
}
