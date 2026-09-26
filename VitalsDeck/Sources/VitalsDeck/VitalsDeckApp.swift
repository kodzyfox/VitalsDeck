import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as menu-bar accessory (no dock icon clutter)
        NSApp.setActivationPolicy(.accessory)
        
        // Initialize menu bar status item & floating HUD
        statusBarController = StatusBarController()
        
        print("VitalsDeck initialized and running in menu bar.")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        CaffeineManager.shared.stopCaffeine()
        SystemMonitor.shared.stop()
    }
}

@main
enum VitalsDeckMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
