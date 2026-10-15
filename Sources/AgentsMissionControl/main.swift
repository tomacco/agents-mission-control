import AppKit

// Agents Mission Control: holds the Full Disk Access grant and runs, as its own children, the commands a
// person approved with Touch ID for a Claude Code session (Privileged.swift). It shows nothing in the menu
// bar: everything the person sees happens in the installer and the Claude Code plugin.

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Privileged.shared.onGrant = { requestFullDiskAccess() }
        Privileged.shared.start()
    }
}

// Finder first, System Settings last and after a beat, so the settings window ends up in front: both
// calls return before their window appears, and the later window would otherwise be left behind.
func requestFullDiskAccess() {
    NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
