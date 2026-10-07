import SwiftUI
import Observation

// Helm: a Control Center style panel for the local agent fleet.
// The panel only flips state; enforcement lives in bin/helmd and hooks/hands-off-guard.sh,
// so the switch keeps working when this app is not running.

@main
struct HelmApp: App {
    @State private var helm = Helm()

    init() {
        // `Helm --snapshot out.png` renders the panel to a file and exits: lets an agent check
        // the layout without clicking the menu bar.
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count {
            let helm = Helm()
            helm.servers = Server.parse(sh(Helm.root + "/bin/servers"))
            let r = ImageRenderer(content: Panel(helm: helm).background(Color(white: 0.11)).environment(\.colorScheme, .dark))
            r.scale = 2
            if let img = r.nsImage, let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) {
                try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: args[i + 1]))
            }
            exit(0)
        }
    }

    var body: some Scene {
        MenuBarExtra {
            Panel(helm: helm)
        } label: {
            Image(systemName: helm.handsOff ? "hand.raised.fill" : "steeringwheel")
        }
        .menuBarExtraStyle(.window)
    }
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
}

@Observable
final class Helm {
    static let root = Bundle.main.object(forInfoDictionaryKey: "HelmRoot") as? String
        ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("git/local/personal/helm").path
    static let flag = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".helm/hands-off")

    var handsOff = false
    var handsOffSince: Date?
    var enforcerRunning = true
    var caffeine: Caffeine?
    var servers: [Server] = []
    private var timer: Timer?

    init() {
        refreshFast()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.refreshFast() }
    }

    // Cheap state, polled for the menu bar icon.
    func refreshFast() {
        let attrs = try? FileManager.default.attributesOfItem(atPath: Self.flag.path)
        handsOff = attrs != nil
        handsOffSince = attrs?[.creationDate] as? Date
        enforcerRunning = !sh("/usr/bin/pgrep", "-f", "bin/helmd").isEmpty
        caffeine = Self.readCaffeine()
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
            // Silence now, even if helmd is not running.
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
            var left: Int?
            if let i = args.firstIndex(of: "-t"), i + 1 < args.endIndex, let total = Int(args[i + 1]) {
                left = max(0, total - seconds(etime: f[1]))
            }
            return Caffeine(pid: pid, screen: args.contains { $0.hasPrefix("-") && $0.contains("d") }, left: left)
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
    secs >= 3600 ? "\(secs / 3600)h \(secs % 3600 / 60)m" : "\((secs + 59) / 60)m"
}
