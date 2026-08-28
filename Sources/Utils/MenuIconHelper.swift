import AppKit

public struct MenuIconHelper {
    public static func createUSBIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let img = NSImage(size: size)
        img.lockFocus()
        
        NSColor.black.setStroke()
        NSColor.black.setFill()
        
        let path = NSBezierPath()
        path.lineWidth = 1.2
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        
        // Base circle at (9, 3.5)
        let baseCircle = NSBezierPath(ovalIn: NSRect(x: 7.5, y: 2, width: 3, height: 3))
        baseCircle.fill()
        
        // Main stem
        path.move(to: NSPoint(x: 9, y: 5))
        path.line(to: NSPoint(x: 9, y: 13))
        
        // Left branch
        path.move(to: NSPoint(x: 9, y: 7))
        path.line(to: NSPoint(x: 6, y: 9.5))
        path.line(to: NSPoint(x: 6, y: 12))
        
        // Right branch
        path.move(to: NSPoint(x: 9, y: 9))
        path.line(to: NSPoint(x: 12, y: 11))
        path.line(to: NSPoint(x: 12, y: 12))
        
        path.stroke()
        
        // Center Tip: Triangle pointing up
        let centerTip = NSBezierPath()
        centerTip.move(to: NSPoint(x: 7, y: 13))
        centerTip.line(to: NSPoint(x: 11, y: 13))
        centerTip.line(to: NSPoint(x: 9, y: 16))
        centerTip.close()
        centerTip.fill()
        
        // Left Tip: Square
        let squareRect = NSRect(x: 4.5, y: 12, width: 3, height: 3)
        let squarePath = NSBezierPath(rect: squareRect)
        squarePath.fill()
        
        // Right Tip: Circle
        let circleRect = NSRect(x: 10.5, y: 12, width: 3, height: 3)
        let circlePath = NSBezierPath(ovalIn: circleRect)
        circlePath.fill()
        
        img.unlockFocus()
        img.isTemplate = true
        return img
    }
    
    public static func createBluetoothIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let img = NSImage(size: size)
        img.lockFocus()
        
        NSColor.black.setStroke()
        
        let path = NSBezierPath()
        path.lineWidth = 1.5
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        
        // Draw Bluetooth symbol in a single stroke
        path.move(to: NSPoint(x: 5.5, y: 12.5))
        path.line(to: NSPoint(x: 12.5, y: 5.5))
        path.line(to: NSPoint(x: 9, y: 2))
        path.line(to: NSPoint(x: 9, y: 16))
        path.line(to: NSPoint(x: 12.5, y: 12.5))
        path.line(to: NSPoint(x: 5.5, y: 5.5))
        
        path.stroke()
        
        img.unlockFocus()
        img.isTemplate = true
        return img
    }
}
