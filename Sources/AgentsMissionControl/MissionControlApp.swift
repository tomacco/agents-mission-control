import SwiftUI
import Observation

// Agents Mission Control: one menu bar pill for working next to local agents: Clawd (hands off), caffeinate,
// localhost. Clicking Clawd toggles hands off; anywhere else opens the glass panel.
// Hands off only flips a flag; enforcement lives in bin/amcd and hooks/hands-off-guard.sh,
// so the switch keeps working when this app is not running.

@main
struct MissionControlApp: App {
    @NSApplicationDelegateAdaptor(BarItem.self) private var bar
    var body: some Scene { Settings { EmptyView() } }
}

struct Server: Identifiable, Hashable {
    let name: String, port: Int, pid: Int32, cmd: String, cwd: String, title: String
    var id: Int { port }

    static func parse(_ tsv: String) -> [Server] {
        tsv.split(separator: "\n").compactMap { line in
            let f = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard f.count >= 6, let port = Int(f[1]), let pid = Int32(f[2]) else { return nil }
            return Server(name: f[0], port: port, pid: pid, cmd: f[3], cwd: f[4], title: f[5])
        }
    }
}

struct Caffeine {
    let pid: Int32
    let screen: Bool
    let left: Int?  // seconds, nil = until stopped
    let total: Int? // the -t it was started with, to show which preset is on
}

@Observable
final class MissionControl {
    static let shared = MissionControl()
    static let root = Bundle.main.object(forInfoDictionaryKey: "AMCRoot") as? String
        ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("git/github.com/tomacco/agents-mission-control").path
    static let flag = Privileged.dir.appendingPathComponent("hands-off")

    var handsOff = false
    var handsOffSince: Date?
    var enforcerRunning = true
    var caffeine: Caffeine?
    var servers: [Server] = []
    var leases: [[String: Any]] = []
    var fullDiskAccess = true
    private var timer: Timer?
    private var serverTimer: Timer?

    init() {
        refreshFast()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.refreshFast() }
        refreshServers()
        serverTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in self?.refreshServers() }
        if !CommandLine.arguments.contains("--preview") {
            Privileged.shared.onChange = { [weak self] in self?.leases = Privileged.shared.statusRows() }
            Privileged.shared.onGrant = { [weak self] in self?.requestFullDiskAccess() }
            Privileged.shared.start()
        }
    }

    // Cheap state, polled for the menu bar icon.
    func refreshFast() {
        let attrs = try? FileManager.default.attributesOfItem(atPath: Self.flag.path)
        handsOff = attrs != nil
        handsOffSince = attrs?[.creationDate] as? Date
        enforcerRunning = !sh("/usr/bin/pgrep", "-f", "bin/amcd").isEmpty
        caffeine = Self.readCaffeine()
        fullDiskAccess = Privileged.hasFullDiskAccess
    }

    // macOS has no prompt for Full Disk Access, so take the person to the one toggle: the settings pane,
    // and this app selected in Finder, ready to drag into the list.
    // Finder first, System Settings last and after a beat, so the settings window ends up in front: both
    // calls return before their window appears, and the later window would otherwise be left behind.
    func requestFullDiskAccess() {
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
        }
    }

    func refreshServers() {
        let script = Self.root + "/bin/servers"
        DispatchQueue.global().async {
            let rows = Server.parse(sh(script))
            DispatchQueue.main.async { self.servers = rows }
        }
    }

    func toggleHandsOff() {
        if handsOff {
            try? FileManager.default.removeItem(at: Self.flag)
        } else {
            try? FileManager.default.createDirectory(at: Self.flag.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? "\(ISO8601DateFormatter().string(from: Date())) panel\n".write(to: Self.flag, atomically: true, encoding: .utf8)
            // Silence now, even if amcd is not running.
            _ = sh("/usr/bin/pkill", "-9", "-U", "\(getuid())", "-x", "say|afplay|uidriver|cliclick")
        }
        refreshFast()
    }

    // Caffeinate goes through the SwiftBar plugin's start/stop so both agree on what is "ours".
    func caffeinate(_ flags: String?, seconds: Int? = nil) {
        let script = Self.root + "/swiftbar/caffeinate/caffeinate.5s.sh"
        if let flags {
            _ = sh(script, "start", flags, seconds.map(String.init) ?? "")
        } else {
            _ = sh(script, "stop")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.refreshFast() }
    }

    func kill(_ s: Server) {
        Darwin.kill(s.pid, SIGTERM)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.refreshServers() }
    }

    static func readCaffeine() -> Caffeine? {
        for line in sh("/bin/ps", "-axo", "pid=,etime=,comm=,args=").split(separator: "\n") {
            let f = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard f.count >= 3, f[2] == "caffeinate-bar", let pid = Int32(f[0]) else { continue }
            let args = f.dropFirst(3)
            var left: Int?, total: Int?
            if let i = args.firstIndex(of: "-t"), i + 1 < args.endIndex, let t = Int(args[i + 1]) {
                left = max(0, t - seconds(etime: f[1])); total = t
            }
            return Caffeine(pid: pid, screen: args.contains { $0.hasPrefix("-") && $0.contains("d") }, left: left, total: total)
        }
        return nil
    }

    static func seconds(etime: String) -> Int {  // [[dd-]hh:]mm:ss
        var days = 0, t = Substring(etime)
        if let dash = t.firstIndex(of: "-") { days = Int(t[..<dash]) ?? 0; t = t[t.index(after: dash)...] }
        let p = t.split(separator: ":").compactMap { Int($0) }
        let hms = (Array(repeating: 0, count: max(0, 3 - p.count)) + p).suffix(3)
        let a = Array(hms)
        return days * 86400 + a[0] * 3600 + a[1] * 60 + a[2]
    }
}

@discardableResult
func sh(_ path: String, _ args: String...) -> String {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: path)
    p.arguments = args.filter { !$0.isEmpty }
    let out = Pipe()
    p.standardOutput = out
    p.standardError = FileHandle.nullDevice
    guard (try? p.run()) != nil else { return "" }
    let data = out.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
}

func short(_ secs: Int) -> String {
    let m = (secs + 59) / 60
    return m >= 60 ? "\(m / 60)h" + (m % 60 > 0 ? " \(m % 60)m" : "") : "\(m)m"
}
