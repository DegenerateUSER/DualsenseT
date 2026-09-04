import Foundation

public enum AppIdentity {
    public static let displayName = "Sticky Fingers"
    public static let executableName = "StickyFingers"
    public static let bundleIdentifier = "com.degenerateuser.stickyfingers"

    /// Preserve existing presets while moving public-facing support files to the new name.
    public static let applicationSupportDirectory: URL = {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        let current = base.appendingPathComponent("Sticky Fingers", isDirectory: true)
        let legacy = base.appendingPathComponent("DualSenseT", isDirectory: true)

        if !FileManager.default.fileExists(atPath: current.path),
           FileManager.default.fileExists(atPath: legacy.path) {
            try? FileManager.default.copyItem(at: legacy, to: current)
        }
        try? FileManager.default.createDirectory(
            at: current,
            withIntermediateDirectories: true
        )
        return current
    }()
}

public extension Notification.Name {
    static let stickyFingersStatusChanged =
        Notification.Name("StickyFingersStatusChanged")
}
