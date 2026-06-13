import Foundation
import AppKit
import SwiftUI
import GameController

public class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    public var statusItem: NSStatusItem?
    public var window: NSWindow?
    
    public var controllerManager = ControllerManager()
    public var presetManager = PresetManager()
    public var udpListener = UDPListener()
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        GCController.shouldMonitorBackgroundEvents = true
        NSApp.setActivationPolicy(.accessory)
        setupMenuBar()
        showMainWindow()
        
        // Auto-start UDP server if it was enabled
        if UserDefaults.standard.bool(forKey: "autoStartUdp") {
            udpListener.start(manager: controllerManager)
        }
        
        // Setup App Profile Observer
        controllerManager.setupAppProfileObserver(presetManager: presetManager)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(statusChanged),
            name: NSNotification.Name("DualSenseTStatusChanged"),
            object: nil
        )
        
        // Background focus restoration observers using raw HID bypass
        NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            logToFile("Application resigned active. Switching to raw HID output mode.")
            self.controllerManager.isAppInForeground = false
            // Immediately send raw HID report to override the OS reset
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.controllerManager.applyTriggerSettingsViaHID()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.controllerManager.applyTriggerSettingsViaHID()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            logToFile("Application became active. Switching to GameController API mode.")
            self.controllerManager.isAppInForeground = true
            self.controllerManager.applyTriggerSettings()
        }
    }
    
    public func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            let config = NSImage.SymbolConfiguration(scale: .medium)
            button.image = NSImage(systemSymbolName: "gamecontroller", accessibilityDescription: "DualSenseT")?.withSymbolConfiguration(config)
            button.imagePosition = .imageLeft
            button.title = " --%"
        }
        updateMenu()
    }
    
    public func updateMenu() {
        let menu = NSMenu()
        
        if controllerManager.activeController != nil {
            let infoItem = NSMenuItem(title: "DualSense Connection: Connected (\(controllerManager.connectionType))", action: nil, keyEquivalent: "")
            menu.addItem(infoItem)
            
            let batteryString = String(format: "Battery Level: %.0f%%", controllerManager.batteryLevel * 100)
            let batteryItem = NSMenuItem(title: batteryString, action: nil, keyEquivalent: "")
            menu.addItem(batteryItem)
        } else {
            let infoItem = NSMenuItem(title: "No Controller Connected", action: nil, keyEquivalent: "")
            menu.addItem(infoItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // Quick Presets
        let presetsMenu = NSMenu()
        for preset in controllerManager.defaultPresets {
            let item = NSMenuItem(title: preset.name, action: #selector(applyQuickPreset(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = preset
            presetsMenu.addItem(item)
        }
        
        let presetsContainer = NSMenuItem(title: "Quick Presets", action: nil, keyEquivalent: "")
        presetsContainer.submenu = presetsMenu
        menu.addItem(presetsContainer)
        
        menu.addItem(NSMenuItem.separator())
        
        let showItem = NSMenuItem(title: "Open Main Window", action: #selector(showMainWindow), keyEquivalent: "o")
        showItem.target = self
        menu.addItem(showItem)
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    @objc public func statusChanged() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let button = self.statusItem?.button {
                if self.controllerManager.activeController != nil {
                    button.title = String(format: " [%@] %.0f%%", self.controllerManager.connectionType, self.controllerManager.batteryLevel * 100)
                } else {
                    button.title = " --%"
                }
            }
            self.updateMenu()
        }
    }
    
    @objc public func applyQuickPreset(_ sender: NSMenuItem) {
        if let preset = sender.representedObject as? TriggerPreset {
            controllerManager.applyPreset(preset)
        }
    }
    
    @objc public func showMainWindow() {
        if let window = self.window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            controllerManager.isUIVisible = true
            return
        }
        
        let contentView = ContentView(manager: controllerManager, presetManager: presetManager, udpListener: udpListener)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 850, height: 550),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        
        window.center()
        window.setFrameAutosaveName("DualSenseT Main Window")
        window.title = "DualSenseT"
        window.contentView = NSHostingView(rootView: contentView)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.delegate = self
        
        self.window = window
        controllerManager.isUIVisible = true
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    public func windowShouldClose(_ sender: NSWindow) -> Bool {
        window?.orderOut(nil)
        controllerManager.isUIVisible = false
        return false
    }
    
    public func windowDidMiniaturize(_ notification: Notification) {
        controllerManager.isUIVisible = false
    }
    
    public func windowDidDeminiaturize(_ notification: Notification) {
        controllerManager.isUIVisible = true
    }
    
    @objc public func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
