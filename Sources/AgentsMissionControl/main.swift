import AppKit

// Agents Mission Control: holds the Full Disk Access grant and runs, as its own children, the commands a
// person approved with Touch ID for a Claude Code session (Privileged.swift). It shows nothing in the menu
// bar: everything the person sees happens in the installer and the Claude Code plugin.

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Privileged.shared.onGrant = { requestFullDiskAccess() }
        // One instance serves the socket. launchd keeps its copy alive; a copy macOS reopens on its own (after
        // the Full Disk Access switch) must not take the socket from a live one, so it leaves instead.
        if Privileged.socketAnswers() {
            // launchd names its job "<bundle id>.app"; macOS-started apps get "application.<bundle id>.<n>.<n>".
            let job = ProcessInfo.processInfo.environment["XPC_SERVICE_NAME"] ?? ""
            if job != (Bundle.main.bundleIdentifier ?? "") + ".app" { exit(0) }
            DispatchQueue.global().async {  // launchd's copy waits until the other one is gone, then serves
                while Privileged.socketAnswers() { sleep(2) }
                DispatchQueue.main.async { Privileged.shared.start() }
            }
            return
        }
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
