import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) var instance: AppDelegate! = nil
    private var devicesMenu: NSMenu!
    
    var engine = AudioEngine()
    
    var statusItem: NSStatusItem?
    
    var currentScriptSelectionMenuItem: NSMenuItem?

    private var _statusItemTitle = "Loading..."
    var statusItemTitle: String {
        get {
            return _statusItemTitle
        }
        set {
            _statusItemTitle = newValue
            statusItemDisplay()
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.instance = self
    }
    
    func statusItemDisplay() {
        if engine.isRunning {
            self.statusItem?.button?.image = NSImage(systemSymbolName: "waveform.circle", accessibilityDescription: "")
            self.statusItem?.button?.title = ""
        } else {
            self.statusItem?.button?.image = nil
            self.statusItem?.button?.title = statusItemTitle
        }
    }
}
