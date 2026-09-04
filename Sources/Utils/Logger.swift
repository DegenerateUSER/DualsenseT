import Foundation

public func logToFile(_ message: String) {
    let logFile = AppIdentity.applicationSupportDirectory
        .appendingPathComponent("sticky-fingers.log")
    
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    let dateStr = formatter.string(from: Date())
    let line = "[\(dateStr)] \(message)\n"
    
    print(line, terminator: "")
    
    if let data = line.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: logFile.path) {
            if let fileHandle = try? FileHandle(forWritingTo: logFile) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            }
        } else {
            try? data.write(to: logFile)
        }
    }
}
