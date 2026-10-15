import SwiftUI

// The menu bar pill. A status item button is 22 pt tall on this Mac (the bar itself is 33 pt),
// so the pill uses the full 22 pt and grows sideways with its content.

final class BarItem: NSObject, NSApplicationDelegate {
    private var item: NSStatusItem!
    private let popover = NSPopover()
    private var clawdWidth: CGFloat = 0

    func applicationDidFinishLaunching(_ note: Notification) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let host = PassThroughHost(rootView: Pill(mc: .shared) { [weak self] in self?.clawdWidth = $0 })
        host.translatesAutoresizingMaskIntoConstraints = false
        guard let button = item.button else { return }
        button.addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            host.centerYAnchor.constraint(equalTo: button.centerYAnchor),
        ])
        button.target = self
        button.action = #selector(click)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: Panel(mc: .shared))
        // `AgentsMissionControl --preview` opens the panel and the pill in a plain window and prints its number,
        // so an agent can capture them (screencapture -o -l <n>) without clicking the menu bar.
        if CommandLine.arguments.contains("--preview") { Preview.show() }
    }

    @objc private func click() {
        guard let button = item.button, let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(withTitle: "Quit Agents Mission Control", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            item.menu = menu
            button.performClick(nil)
            item.menu = nil
            return
        }
        let x = button.convert(event.locationInWindow, from: nil).x
        if x <= clawdWidth {
            MissionControl.shared.toggleHandsOff()
        } else if popover.isShown {
            popover.performClose(nil)
        } else {
            MissionControl.shared.refreshServers()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}

// Lets clicks fall through to the status button underneath.
final class PassThroughHost<V: View>: NSHostingView<V> {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

struct Pill: View {
    let mc: MissionControl
    var onClawdWidth: (CGFloat) -> Void = { _ in }

    var body: some View {
        HStack(spacing: 0) {
            clawd
                .background(GeometryReader { g in Color.clear.onAppear { onClawdWidth(g.size.width) }
                    .onChange(of: g.size.width) { _, w in onClawdWidth(w) } })
            divider
            caffeine
            divider
            servers
        }
        .frame(height: 22)
        .background(Capsule().fill(.primary.opacity(0.12)))
        .padding(.horizontal, 2)
        .help("Click Clawd for hands off · click elsewhere for the panel · right-click to quit")
    }

    var clawd: some View {
        HStack(spacing: 3) {
            Pixels(grid: Art.clawd, cell: 1.5, color: mc.handsOff ? .red : Art.orange)
            Pixels(grid: mc.handsOff ? Art.pause : Art.waves, cell: 1.5,
                   color: mc.handsOff ? .red : .primary.opacity(0.7))
        }
        .padding(.leading, 9).padding(.trailing, 6)
        .frame(maxHeight: .infinity)
        .background(mc.handsOff ? AnyShapeStyle(.red.opacity(0.22)) : AnyShapeStyle(.clear),
                    in: UnevenRoundedRectangle(topLeadingRadius: 11, bottomLeadingRadius: 11))
    }

    // On: a solid roast (amber with the screen kept on) block with white content and rising steam,
    // so it reads on light and dark menu bars alike. Both fills keep white above 4.5:1.
    var caffeine: some View {
        let c = mc.caffeine
        return HStack(spacing: 3) {
            Mug(size: 15, color: c == nil ? .primary.opacity(0.4) : .white, steaming: c != nil)
            if let c {
                Text(c.left.map(short) ?? "∞").font(.system(size: 11, weight: .bold).monospacedDigit())
                    .foregroundStyle(.white)
                if c.screen { Pixels(grid: Art.screen, cell: 1.5, color: .white) }
            }
        }
        .padding(.horizontal, 6)
        .frame(maxHeight: .infinity)
        .background(c == nil ? AnyShapeStyle(.clear) : AnyShapeStyle(c!.screen ? Art.amber : Art.roast))
    }

    var servers: some View {
        let n = Set(mc.servers.map(\.name)).count
        return HStack(spacing: 3) {
            Pixels(grid: Art.rack, cell: 1.5, color: .primary.opacity(n == 0 ? 0.35 : 0.9))
            if n > 0 { Text(verbatim: "\(n)").font(.system(size: 11, weight: .semibold).monospacedDigit()) }
        }
        .padding(.leading, 6).padding(.trailing, 9)
    }

    var divider: some View { Rectangle().fill(.primary.opacity(0.2)).frame(width: 1, height: 12) }
}

// Pixel art drawn live, so colours follow the menu bar's light or dark appearance.
struct Pixels: View {
    let grid: [String]
    let cell: CGFloat
    let color: Color
    var body: some View {
        let w = CGFloat(grid.map(\.count).max() ?? 0) * cell, h = CGFloat(grid.count) * cell
        Canvas { ctx, _ in
            for (r, row) in grid.enumerated() {
                for (c, ch) in row.enumerated() where ch == "X" {
                    ctx.fill(Path(CGRect(x: CGFloat(c) * cell, y: CGFloat(r) * cell, width: cell, height: cell)), with: .color(color))
                }
            }
        }
        .frame(width: w, height: h)
    }
}

// Flat mug with steam wisps that rise and fade while `steaming`. Drawn in a square of `size` pt:
// the top 40% is room for the steam, the cup sits in the rest.
struct Mug: View {
    let size: CGFloat
    let color: Color
    var steaming = false

    var body: some View {
        ZStack {
            Canvas { ctx, sz in
                let u = sz.width / 16
                let body = Path(roundedRect: CGRect(x: 2 * u, y: 7 * u, width: 9.5 * u, height: 7 * u),
                                cornerRadii: RectangleCornerRadii(topLeading: 0.8 * u, bottomLeading: 3 * u,
                                                                  bottomTrailing: 3 * u, topTrailing: 0.8 * u))
                ctx.fill(body, with: .color(color))
                let handle = Path(roundedRect: CGRect(x: 10 * u, y: 8.3 * u, width: 4 * u, height: 3.6 * u), cornerRadius: 1.8 * u)
                ctx.stroke(handle, with: .color(color), lineWidth: 1.4 * u)
                ctx.fill(Path(roundedRect: CGRect(x: 0.5 * u, y: 14.6 * u, width: 13 * u, height: 1.2 * u), cornerRadius: 0.6 * u),
                         with: .color(color))
            }
            if steaming {
                ForEach(0..<3) { i in Wisp(size: size, color: color, delay: Double(i) * 0.55)
                    .offset(x: size * (CGFloat(i) - 1) * 0.19 - size * 0.06) }
            }
        }
        .frame(width: size, height: size)
    }
}

// One S-shaped wisp above the cup: drifts up, sways and fades out on a loop.
struct Wisp: View {
    let size: CGFloat
    let color: Color
    let delay: Double
    @State private var up = false

    var body: some View {
        Path { p in
            let h = size * 0.38, w = size * 0.1
            p.move(to: CGPoint(x: w, y: h))
            p.addCurve(to: CGPoint(x: w, y: 0), control1: CGPoint(x: -w, y: h * 0.66), control2: CGPoint(x: 3 * w, y: h * 0.33))
        }
        .stroke(color, style: StrokeStyle(lineWidth: max(1, size / 14), lineCap: .round))
        .frame(width: size * 0.2, height: size * 0.38)
        .offset(y: up ? -size * 0.42 : -size * 0.2)
        .scaleEffect(x: up ? 1.25 : 0.9, y: 1)
        .opacity(up ? 0 : 0.85)
        .onAppear {
            withAnimation(.easeOut(duration: 1.7).repeatForever(autoreverses: false).delay(delay)) { up = true }
        }
    }
}

enum Art {
    static let orange = Color(red: 0.85, green: 0.47, blue: 0.34)  // Clawd orange
    static let roast = Color(red: 0.70, green: 0.30, blue: 0.16)   // caffeinate on; white on it is 5.3:1
    static let amber = Color(red: 0.62, green: 0.40, blue: 0.0)    // screen kept on; white on it is 4.8:1
    static let clawd = [
        "..XXXXXXXX..",
        "..X.XXXX.X..",
        "XXX.XXXX.XXX",
        "XXXXXXXXXXXX",
        "..XXXXXXXX..",
        "..XXXXXXXX..",
        "..X.X..X.X..",
        "..X.X..X.X..",
    ]
    static let waves = ["X..X.", ".X..X", ".X..X", ".X..X", "X..X."]
    static let pause = ["XX.XX", "XX.XX", "XX.XX", "XX.XX", "XX.XX"]
    static let screen = ["XXXXX", "X...X", "X...X", "XXXXX", "..X..", ".XXX."]
    static let rack = ["XXXXX", "X.XXX", ".....", "XXXXX", "X.XXX", ".....", "XXXXX", "X.XXX"]
}

enum Preview {
    static func show() {
        let mc = MissionControl.shared
        mc.servers = Server.parse(sh(MissionControl.root + "/bin/servers"))
        let view = VStack(alignment: .leading, spacing: 20) {
            Pill(mc: mc).scaleEffect(3, anchor: .topLeading).frame(width: 600, height: 70, alignment: .topLeading)
            Panel(mc: mc)
        }
        .padding(24)
        .background(LinearGradient(colors: [.blue, .purple, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
        let w = NSWindow(contentViewController: NSHostingController(rootView: view))
        w.styleMask = [.titled, .fullSizeContentView]
        w.titlebarAppearsTransparent = true
        w.center()
        w.makeKeyAndOrderFront(nil)
        print(w.windowNumber); fflush(stdout)
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { exit(0) }
    }
}
