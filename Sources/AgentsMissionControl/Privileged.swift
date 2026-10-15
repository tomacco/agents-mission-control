import Foundation
import Security
import CryptoKit
import Darwin

// Privileged sessions: this app holds the Full Disk Access grant, and commands an agent needs it for run
// here, as this app's children, so they inherit the grant. Terminal never gets it.
//
// One JSON request per connection on ~/.amc/amc.sock, one JSON line back:
//   register                 -> { key }   first caller per Claude Code process (the mod, at session start)
//   open  key agent subtitle reason paths scope(session|once)   after the person approved it in the mod
//   run   key run_id command reason cwd paths timeout          output goes to ~/.amc/runs/<run_id>.log
//   end   key                closes the lease
//   status                   active leases (no keys) and whether this app has Full Disk Access
//   grant                    opens the Full Disk Access settings and shows this app in Finder, ready to drag in
// Every caller must descend from a Claude Code binary signed by Anthropic, checked live by its code
// signature, and every request lands in ~/.amc/trace.jsonl, each line chained to the hash of the previous.

struct Lease: Codable {
    var agent: String, subtitle: String, reason: String, paths: [String], scope: String
    var since: Date, runs: Int
    var claudePid: Int32
}

final class Privileged {
    static let shared = Privileged()
    static let dir = (Bundle.main.object(forInfoDictionaryKey: "AMCHome") as? String).map { URL(fileURLWithPath: $0) }
        ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".amc")
    static let socketPath = ProcessInfo.processInfo.environment["AMC_SOCKET"] ?? dir.appendingPathComponent("amc.sock").path
    static let tracePath = ProcessInfo.processInfo.environment["AMC_TRACE"] ?? dir.appendingPathComponent("trace.jsonl").path
    static let runsDir = dir.appendingPathComponent("runs")
    static let claudeRequirement = #"identifier "com.anthropic.claude-code" and anchor apple generic and certificate leaf[subject.OU] = "Q6L2SF6YDW""#

    private let lock = NSLock()
    private var keys: [Int32: String] = [:]   // Claude Code pid -> key
    private(set) var leases: [Int32: Lease] = [:]
    private var lastHash = ""
    var onChange: (() -> Void)?
    var onGrant: (() -> Void)?

    // The system TCC database exists on every Mac and only Full Disk Access opens it.
    static var hasFullDiskAccess: Bool {
        let fd = open("/Library/Application Support/com.apple.TCC/TCC.db", O_RDONLY)
        if fd >= 0 { close(fd); return true }
        return false
    }

    func start() {
        try? FileManager.default.createDirectory(at: Self.runsDir, withIntermediateDirectories: true,
                                                 attributes: [.posixPermissions: 0o700])
        chmod(Self.dir.path, 0o700)
        lastHash = (try? String(contentsOfFile: Self.tracePath, encoding: .utf8))?
            .split(separator: "\n").last.map { sha256(Data($0.utf8)) } ?? ""
        Thread.detachNewThread { self.serve() }
        Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in self.reap() }
    }

    // MARK: socket

    private func serve() {
        unlink(Self.socketPath)
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        withUnsafeMutableBytes(of: &addr.sun_path) { buf in
            Self.socketPath.utf8CString.withUnsafeBytes { buf.copyMemory(from: UnsafeRawBufferPointer(rebasing: $0.prefix(buf.count - 1))) }
        }
        let bound = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard bound == 0, listen(fd, 16) == 0 else { NSLog("amc: cannot listen on \(Self.socketPath)"); return }
        chmod(Self.socketPath, 0o600)
        while true {
            let c = accept(fd, nil, nil)
            if c >= 0 { Thread.detachNewThread { self.handle(c) } }
        }
    }

    private func handle(_ c: Int32) {
        defer { close(c) }
        var data = Data(), byte: UInt8 = 0
        while read(c, &byte, 1) == 1 { if byte == 10 { break }; data.append(byte) }
        var pid: pid_t = 0, len = socklen_t(MemoryLayout<pid_t>.size)
        getsockopt(c, SOL_LOCAL, LOCAL_PEERPID, &pid, &len)
        let reply = respond(to: (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:], peer: pid)
        var out = (try? JSONSerialization.data(withJSONObject: reply)) ?? Data("{}".utf8)
        out.append(10)
        _ = out.withUnsafeBytes { write(c, $0.baseAddress, out.count) }
    }

    // MARK: requests

    func respond(to r: [String: Any], peer: pid_t) -> [String: Any] {
        let op = r["op"] as? String ?? ""
        let chain = ancestors(of: peer)
        var entry: [String: Any] = ["op": op, "peer_chain": chain.map { "\($0.pid) \($0.path)" }]
        for k in ["agent", "subtitle", "reason", "paths", "scope", "command", "cwd", "run_id"] { entry[k] = r[k] }
        let reply = answer(op, r, chain: chain, entry: &entry)
        entry["ok"] = reply["error"] == nil
        if let e = reply["error"] { entry["error"] = e }
        trace(entry)
        return reply
    }

    private func answer(_ op: String, _ r: [String: Any], chain: [(pid: Int32, path: String)],
                        entry: inout [String: Any]) -> [String: Any] {
        if op == "status" { return ["leases": statusRows(), "fda": Self.hasFullDiskAccess] }
        if op == "grant" { if r["dry"] == nil { DispatchQueue.main.async { self.onGrant?() } }; return ["ok": true, "fda": Self.hasFullDiskAccess] }
        guard let claude = chain.first(where: { isClaude($0.pid) })?.pid else {
            return ["error": "caller is not a Claude Code session signed by Anthropic"]
        }
        entry["claude_pid"] = claude
        if op == "register" {
            lock.lock(); defer { lock.unlock() }
            if keys[claude] != nil { return ["error": "this session is already registered"] }
            let key = (0..<32).map { _ in String(format: "%02x", UInt8.random(in: 0...255)) }.joined()
            keys[claude] = key
            return ["key": key]
        }
        lock.lock()
        let valid = keys[claude] != nil && keys[claude] == r["key"] as? String
        lock.unlock()
        guard valid else { return ["error": "bad or missing session key"] }

        switch op {
        case "open":
            let lease = Lease(agent: r["agent"] as? String ?? "?", subtitle: r["subtitle"] as? String ?? "",
                              reason: r["reason"] as? String ?? "", paths: r["paths"] as? [String] ?? [],
                              scope: r["scope"] as? String == "once" ? "once" : "session",
                              since: Date(), runs: 0, claudePid: claude)
            lock.lock(); leases[claude] = lease; lock.unlock()
            changed()
            return ["ok": true]
        case "end":
            lock.lock(); let had = leases.removeValue(forKey: claude) != nil; lock.unlock()
            changed()
            return ["ok": had]
        case "run":
            guard Self.hasFullDiskAccess else {
                return ["error": "Agents Mission Control has no Full Disk Access yet: grant it in System Settings (op grant opens it)"]
            }
            lock.lock()
            guard var lease = leases[claude] else { lock.unlock(); return ["error": "no open lease: ask the person first"] }
            lease.runs += 1
            if lease.scope == "once" { leases.removeValue(forKey: claude) } else { leases[claude] = lease }
            lock.unlock()
            changed()
            entry["agent"] = lease.agent; entry["subtitle"] = lease.subtitle
            return run(r, entry: &entry)
        default:
            return ["error": "unknown op \(op)"]
        }
    }

    private func run(_ r: [String: Any], entry: inout [String: Any]) -> [String: Any] {
        guard let command = r["command"] as? String, !command.isEmpty else { return ["error": "missing command"] }
        let id = (r["run_id"] as? String).flatMap { $0.range(of: #"^[A-Za-z0-9_-]{1,64}$"#, options: .regularExpression) != nil ? $0 : nil }
            ?? UUID().uuidString
        let log = Self.runsDir.appendingPathComponent("\(id).log")
        FileManager.default.createFile(atPath: log.path, contents: nil, attributes: [.posixPermissions: 0o600])
        guard let out = try? FileHandle(forWritingTo: log) else { return ["error": "cannot write \(log.path)"] }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/zsh")
        p.arguments = ["-c", command]
        p.currentDirectoryURL = URL(fileURLWithPath: (r["cwd"] as? String) ?? NSHomeDirectory())
        p.standardOutput = out; p.standardError = out; p.standardInput = FileHandle.nullDevice
        let started = Date()
        do { try p.run() } catch { return ["error": "cannot start: \(error.localizedDescription)"] }
        let timeout = min(max(r["timeout"] as? Double ?? 120, 1), 600)
        let timer = DispatchWorkItem { if p.isRunning { p.terminate() } }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timer)
        p.waitUntilExit(); timer.cancel(); try? out.close()
        let bytes = (try? Data(contentsOf: log)) ?? Data()
        let reply: [String: Any] = ["exit": p.terminationStatus, "log": log.path, "bytes": bytes.count,
                                    "sha256": sha256(bytes), "ms": Int(Date().timeIntervalSince(started) * 1000),
                                    "timed_out": p.terminationReason == .uncaughtSignal && Date().timeIntervalSince(started) >= timeout]
        for (k, v) in reply { entry[k] = v }
        entry["run_id"] = id
        return reply
    }

    func revoke(_ pid: Int32) {
        lock.lock(); leases.removeValue(forKey: pid); lock.unlock()
        trace(["op": "revoke", "claude_pid": pid, "ok": true, "by": "panel"])
        changed()
    }

    // Leases and keys die with their Claude Code process.
    private func reap() {
        lock.lock()
        let dead = Set(keys.keys).union(leases.keys).filter { kill($0, 0) != 0 && errno == ESRCH }
        for pid in dead { keys.removeValue(forKey: pid); leases.removeValue(forKey: pid) }
        lock.unlock()
        for pid in dead { trace(["op": "reap", "claude_pid": pid, "ok": true]) }
        if !dead.isEmpty { changed() }
    }

    func statusRows() -> [[String: Any]] {
        lock.lock(); defer { lock.unlock() }
        return leases.map { pid, l in
            ["claude_pid": pid, "agent": l.agent, "subtitle": l.subtitle, "reason": l.reason, "paths": l.paths,
             "scope": l.scope, "runs": l.runs, "since": ISO8601DateFormatter().string(from: l.since)]
        }
    }

    private func changed() { DispatchQueue.main.async { self.onChange?() } }

    // MARK: trace

    private func trace(_ e: [String: Any]) {
        lock.lock(); defer { lock.unlock() }
        var e = e
        e["ts"] = ISO8601DateFormatter().string(from: Date())
        e["prev"] = lastHash
        guard let line = try? JSONSerialization.data(withJSONObject: e, options: [.sortedKeys]) else { return }
        lastHash = sha256(line)
        if let h = FileHandle(forWritingAtPath: Self.tracePath) {
            h.seekToEndOfFile(); h.write(line + Data([10])); try? h.close()
        } else {
            FileManager.default.createFile(atPath: Self.tracePath, contents: line + Data([10]),
                                           attributes: [.posixPermissions: 0o600])
        }
    }

    // MARK: process identity

    private func ancestors(of pid: pid_t) -> [(pid: Int32, path: String)] {
        var out: [(Int32, String)] = [], p = pid
        while p > 1 && out.count < 16 {
            var buf = [CChar](repeating: 0, count: 4096)
            proc_pidpath(p, &buf, UInt32(buf.count))
            out.append((p, String(cString: buf)))
            var info = kinfo_proc(), size = MemoryLayout<kinfo_proc>.size
            var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, p]
            guard sysctl(&mib, 4, &info, &size, nil, 0) == 0, size > 0 else { break }
            p = info.kp_eproc.e_ppid
        }
        return out
    }

    // Checked against the running process, not its file on disk.
    private func isClaude(_ pid: Int32) -> Bool {
        var code: SecCode?, req: SecRequirement?
        guard SecCodeCopyGuestWithAttributes(nil, [kSecGuestAttributePid: pid] as CFDictionary, [], &code) == errSecSuccess,
              let code, SecRequirementCreateWithString(Self.claudeRequirement as CFString, [], &req) == errSecSuccess
        else { return false }
        return SecCodeCheckValidity(code, [], req) == errSecSuccess
    }
}

func sha256(_ d: Data) -> String { SHA256.hash(data: d).map { String(format: "%02x", $0) }.joined() }
