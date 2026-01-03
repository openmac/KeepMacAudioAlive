import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) var instance: AppDelegate! = nil
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.instance = self
    }
}
