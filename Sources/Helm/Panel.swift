import SwiftUI

// Tiles in the style of macOS Control Center: dark rounded modules, a circular glyph that
// turns solid when the control is on.

struct Panel: View {
    let helm: Helm

    var body: some View {
        VStack(spacing: 10) {
            HandsOffTile(helm: helm)
            CaffeineTile(helm: helm)
            ServersTile(helm: helm)
            HStack {
                Text("Helm").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.plain).font(.caption)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(.white.opacity(0.08)))
            }
            .padding(.horizontal, 4)
        }
        .padding(12)
        .frame(width: 340)
        .onAppear { helm.refreshFast(); helm.refreshServers() }
    }
}

struct Tile<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white.opacity(0.07)))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.08)))
    }
}

struct Glyph: View {
    let symbol: String
    let on: Bool
    var tint: Color = .accentColor
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(on ? tint : .primary)
            .frame(width: 40, height: 40)
            .background(Circle().fill(on ? .white : .white.opacity(0.12)))
    }
}

struct HandsOffTile: View {
    let helm: Helm
    var body: some View {
        Button { helm.toggleHandsOff() } label: {
            Tile {
                HStack(spacing: 12) {
                    Glyph(symbol: helm.handsOff ? "hand.raised.fill" : "hand.raised", on: helm.handsOff, tint: .red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(helm.handsOff ? "Hands off" : "Agents").font(.headline)
                        Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Click to stop every local agent from speaking, playing sounds or driving the mouse.")
    }

    var subtitle: String {
        if !helm.enforcerRunning { return "Enforcer not running (run install.sh)" }
        guard helm.handsOff else { return "May talk and use the mouse" }
        let since = helm.handsOffSince.map { $0.formatted(date: .omitted, time: .shortened) } ?? ""
        return "No voice, sound or mouse · since \(since)"
    }
}

struct CaffeineTile: View {
    let helm: Helm
    var body: some View {
        Tile {
            VStack(alignment: .leading, spacing: 10) {
                Button { helm.caffeinate(helm.caffeine == nil ? "-i" : nil) } label: {
                    HStack(spacing: 12) {
                        Glyph(symbol: "cup.and.saucer.fill", on: helm.caffeine != nil, tint: .orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Caffeinate").font(.headline)
                            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                HStack(spacing: 6) {
                    chip("∞", nil); chip("30m", 1800); chip("1h", 3600); chip("2h", 7200)
                    Spacer()
                    chip("Screen", nil, flags: "-di", symbol: "display")
                }
            }
        }
    }

    var subtitle: String {
        guard let c = helm.caffeine else { return "Off" }
        let mode = c.screen ? "Screen on" : "Awake"
        return c.left.map { "\(mode) · \(short($0)) left" } ?? "\(mode) · until stopped"
    }

    func chip(_ label: String, _ secs: Int?, flags: String = "-i", symbol: String? = nil) -> some View {
        Button { helm.caffeinate(flags, seconds: secs) } label: {
            Group {
                if let symbol { Label(label, systemImage: symbol) } else { Text(label) }
            }
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(.white.opacity(0.1)))
        }
        .buttonStyle(.plain)
    }
}

struct ServersTile: View {
    let helm: Helm

    // One row per project; a project often serves several ports (a deck build spawns many).
    var groups: [(name: String, servers: [Server])] {
        Dictionary(grouping: helm.servers, by: \.name).map { ($0.key, $0.value.sorted { $0.port < $1.port }) }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        Tile {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Localhost").font(.headline)
                    Spacer()
                    Button { helm.refreshServers() } label: { Image(systemName: "arrow.clockwise") }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                }
                if helm.servers.isEmpty {
                    Text("Nothing served from ~").font(.subheadline).foregroundStyle(.secondary)
                }
                ForEach(groups, id: \.name) { g in row(g.name, g.servers) }
                if !helm.servers.isEmpty {
                    Text("Click a port to open · right-click to stop").font(.caption2).foregroundStyle(.tertiary)
                }
            }
        }
    }

    func row(_ name: String, _ servers: [Server]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(name).font(.callout.weight(.medium)).lineLimit(1)
                if let t = servers.first(where: { !$0.title.isEmpty })?.title {
                    Text(t).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            .help(servers[0].cwd.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
            FlowRow(servers) { s in
                Button { NSWorkspace.shared.open(URL(string: "http://localhost:\(s.port)")!) } label: {
                    Text(verbatim: ":\(s.port)").font(.system(.caption, design: .monospaced))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(.white.opacity(0.1)))
                }
                .buttonStyle(.plain)
                .help(s.title.isEmpty ? s.cmd : s.title)
                .contextMenu { Button("Stop \(s.cmd) (pid \(s.pid))") { helm.kill(s) } }
            }
        }
        .padding(.vertical, 2)
    }
}

// Port chips wrap onto as many lines as they need.
struct FlowRow<Content: View>: View {
    let items: [Server]
    let content: (Server) -> Content
    init(_ items: [Server], @ViewBuilder content: @escaping (Server) -> Content) {
        self.items = items; self.content = content
    }
    var body: some View {
        WrapLayout(spacing: 4) { ForEach(items) { content($0) } }
    }
}

struct WrapLayout: Layout {
    var spacing: CGFloat
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        place(proposal.width ?? .infinity, subviews).size
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (v, p) in zip(subviews, place(bounds.width, subviews).points) {
            v.place(at: CGPoint(x: bounds.minX + p.x, y: bounds.minY + p.y), proposal: .unspecified)
        }
    }
    func place(_ width: CGFloat, _ subviews: Subviews) -> (points: [CGPoint], size: CGSize) {
        var pts: [CGPoint] = [], x: CGFloat = 0, y: CGFloat = 0, line: CGFloat = 0, maxX: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0, x + s.width > width { x = 0; y += line + spacing; line = 0 }
            pts.append(CGPoint(x: x, y: y)); x += s.width + spacing; line = max(line, s.height); maxX = max(maxX, x)
        }
        return (pts, CGSize(width: maxX, height: y + line))
    }
}
