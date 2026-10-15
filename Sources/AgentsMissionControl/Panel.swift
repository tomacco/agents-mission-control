import SwiftUI

// Liquid Glass tiles in the style of Control Center: a circular glyph that turns solid when
// the control is on, glass capsules for quick actions.

struct Tile<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: .rect(cornerRadius: 22))
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
            .glassEffect(on ? .regular.tint(.white) : .regular, in: .circle)
    }
}

struct Panel: View {
    let mc: MissionControl
    var body: some View {
        GlassEffectContainer(spacing: 10) {
            VStack(spacing: 10) {
                if !mc.fullDiskAccess { AccessTile(mc: mc) }
                HandsOffTile(mc: mc)
                CaffeineTile(mc: mc)
                ServersTile(mc: mc)
            }
        }
        .padding(12)
        .frame(width: 340)
    }
}

// Shown only while the app lacks Full Disk Access, which privileged sessions need.
struct AccessTile: View {
    let mc: MissionControl
    var body: some View {
        Button { mc.requestFullDiskAccess() } label: {
            Tile {
                HStack(spacing: 12) {
                    Glyph(symbol: "lock.shield", on: false, tint: .orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Grant Full Disk Access").font(.headline)
                        Text("Needed for privileged sessions · opens Settings").font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
    }
}

struct HandsOffTile: View {
    let mc: MissionControl
    var body: some View {
        Button { mc.toggleHandsOff() } label: {
            Tile {
                HStack(spacing: 12) {
                    Glyph(symbol: mc.handsOff ? "hand.raised.fill" : "hand.raised", on: mc.handsOff, tint: .red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mc.handsOff ? "Hands off" : "Agents").font(.headline)
                        Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
    }

    var subtitle: String {
        if !mc.enforcerRunning { return "Enforcer not running (run install.sh)" }
        guard mc.handsOff else { return "May talk and use the mouse" }
        let since = mc.handsOffSince.map { $0.formatted(date: .omitted, time: .shortened) } ?? ""
        return "No voice, sound or mouse · since \(since)"
    }
}

struct CaffeineTile: View {
    let mc: MissionControl
    var body: some View {
        let c = mc.caffeine
        Tile {
            VStack(alignment: .leading, spacing: 10) {
                Button { c == nil ? start(nil) : mc.caffeinate(nil) } label: {
                    HStack(spacing: 12) {
                        Mug(size: 26, color: c == nil ? .primary : .white, steaming: c != nil).offset(y: -1)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(c == nil ? .clear : (c!.screen ? Art.amber : Art.roast)))
                            .glassEffect(.regular, in: .circle)
                            .overlay(alignment: .top) { if c != nil { Vapor(tint: c!.screen ? Art.amber : Art.roast) } }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Caffeinate").font(.headline)
                            Text(subtitle).font(.subheadline.weight(c == nil ? .regular : .semibold))
                                .foregroundStyle(c == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                GlassEffectContainer(spacing: 2) { HStack(spacing: 6) {
                    duration("∞", nil); duration("30m", 1800); duration("1h", 3600); duration("2h", 7200)
                    Spacer()
                    screenChip
                } }
            }
        }
    }

    var subtitle: String {
        guard let c = mc.caffeine else { return "Off" }
        let mode = c.screen ? "Screen on" : "Awake"
        return c.left.map { "\(mode) · \(short($0)) left" } ?? "\(mode) · until stopped"
    }

    // A duration chip is lit while that preset runs; clicking a lit chip stops caffeinate.
    func duration(_ label: String, _ secs: Int?) -> some View {
        let on = mc.caffeine.map { $0.total == secs } ?? false
        return chip(Text(label), on: on) { on ? mc.caffeinate(nil) : start(secs) }
    }

    // Screen is a modifier: it keeps the current duration and switches the display on or off.
    var screenChip: some View {
        let c = mc.caffeine, on = c?.screen ?? false
        return chip(Label("Screen", systemImage: "display"), on: on, tint: Art.amber) {
            mc.caffeinate(on ? "-i" : "-di", seconds: c?.left)
        }
    }

    func start(_ secs: Int?) { mc.caffeinate(mc.caffeine?.screen == true ? "-di" : "-i", seconds: secs) }

    func chip<L: View>(_ label: L, on: Bool, tint: Color = Art.roast, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            label
                .font(.caption.weight(on ? .bold : .medium))
                .foregroundStyle(on ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Capsule().fill(on ? tint : .clear))
                .glassEffect(.regular.interactive(), in: .capsule)
        }
        .buttonStyle(.plain)
    }
}

// Soft vapor puffs that rise off the glass circle while caffeinate runs.
struct Vapor: View {
    let tint: Color
    var body: some View {
        ZStack {
            ForEach(0..<5) { i in Puff(tint: tint, x: [-13, 9, -3, 14, -10][i], delay: Double(i) * 0.5) }
        }
        .frame(width: 40, height: 40)
        .allowsHitTesting(false)
    }
}

struct Puff: View {
    let tint: Color
    let x: CGFloat
    let delay: Double
    @State private var up = false
    var body: some View {
        Circle()
            .fill(RadialGradient(colors: [.white, .white.opacity(0.6), tint.opacity(0)], center: .center, startRadius: 0, endRadius: 9))
            .frame(width: 18, height: 18)
            .blur(radius: 1.5)
            .scaleEffect(up ? 1.7 : 0.6)
            .offset(x: up ? x * 1.4 : x * 0.7, y: up ? -22 : 4)
            .opacity(up ? 0 : 0.95)
            .onAppear { withAnimation(.easeOut(duration: 2.4).repeatForever(autoreverses: false).delay(delay)) { up = true } }
    }
}

struct ServersTile: View {
    let mc: MissionControl

    // One row per project; a project often serves several ports (a deck build spawns many).
    var groups: [(name: String, servers: [Server])] {
        Dictionary(grouping: mc.servers, by: \.name).map { ($0.key, $0.value.sorted { $0.port < $1.port }) }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        Tile {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Localhost").font(.headline)
                    Spacer()
                    Button { mc.refreshServers() } label: { Image(systemName: "arrow.clockwise") }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                }
                if mc.servers.isEmpty {
                    Text("Nothing served from ~").font(.subheadline).foregroundStyle(.secondary)
                }
                ForEach(groups, id: \.name) { g in row(g.name, g.servers) }
                if !mc.servers.isEmpty {
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
                        .glassEffect(.regular.interactive(), in: .capsule)
                }
                .buttonStyle(.plain)
                .help(s.title.isEmpty ? s.cmd : s.title)
                .contextMenu { Button("Stop \(s.cmd) (pid \(s.pid))") { mc.kill(s) } }
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
