import Foundation
import AppKit

#if !TESTING
autoreleasepool {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
#else
TestSuite().run()
#endif
