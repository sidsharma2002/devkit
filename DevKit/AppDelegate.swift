import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = KeystrokeMonitor()

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("[DevKit] App launched.")
        requestAccessibilityIfNeeded()
    }

    private func requestAccessibilityIfNeeded() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        if AXIsProcessTrustedWithOptions(opts) {
            monitor.start()
        } else {
            print("[DevKit] Accessibility not granted — waiting. Go to System Settings > Privacy & Security > Accessibility > add DevKit.")
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
                if AXIsProcessTrusted() {
                    self?.monitor.start()
                    timer.invalidate()
                }
            }
        }
    }
}
