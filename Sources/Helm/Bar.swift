import SwiftUI

// The menu bar pill. A status item button is 22 pt tall on this Mac (the bar itself is 33 pt),
// so the pill uses the full 22 pt and grows sideways with its content.

final class BarItem: NSObject, NSApplicationDelegate {
    private var item: NSStatusItem!
    private let popover = NSPopover()
    private var clawdWidth: CGFloat = 0

    func applicationDidFinishLaunching(_ note: Notification) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let host = PassThroughHost(rootView: Pill(helm: .shared) { [weak self] in self?.clawdWidth = $0 })
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
        popover.contentViewController = NSHostingController(rootView: Panel(helm: .shared))
        // `Helm --preview` opens the panel and the pill in a plain window and prints its number,
        // so an agent can capture them (screencapture -o -l <n>) without clicking the menu bar.
        if CommandLine.arguments.contains("--preview") { Preview.show() }
    }

    @objc private func click() {
        guard let button = item.button, let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(withTitle: "Quit Helm", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            item.menu = menu
            button.performClick(nil)
            item.menu = nil
            return
        }
        let x = button.convert(event.locationInWindow, from: nil).x
        if x <= clawdWidth {
            Helm.shared.toggleHandsOff()
        } else if popover.isShown {
            popover.performClose(nil)
        } else {
            Helm.shared.refreshServers()
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
    let helm: Helm
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
            Pixels(grid: Art.clawd, cell: 1.5, color: helm.handsOff ? .red : Art.orange)
            Pixels(grid: helm.handsOff ? Art.pause : Art.waves, cell: 1.5,
                   color: helm.handsOff ? .red : .primary.opacity(0.7))
        }
        .padding(.leading, 9).padding(.trailing, 6)
        .frame(maxHeight: .infinity)
        .background(helm.handsOff ? AnyShapeStyle(.red.opacity(0.22)) : AnyShapeStyle(.clear),
                    in: UnevenRoundedRectangle(topLeadingRadius: 11, bottomLeadingRadius: 11))
    }

    // On: a solid orange (amber with the screen kept on) block with white content, so it reads
    // on light and dark menu bars alike.
    var caffeine: some View {
        let c = helm.caffeine
        return HStack(spacing: 3) {
            Pixels(grid: Art.cup, cell: 1.5, color: c == nil ? .primary.opacity(0.35) : .white)
            if let c {
                Text(c.left.map(short) ?? "∞").font(.system(size: 11, weight: .bold).monospacedDigit())
                    .foregroundStyle(.white)
                if c.screen { Pixels(grid: Art.screen, cell: 1.5, color: .white) }
            }
        }
        .padding(.horizontal, 6)
        .frame(maxHeight: .infinity)
        .background(c == nil ? AnyShapeStyle(.clear) : AnyShapeStyle(c!.screen ? Art.amber : Art.orange))
    }

    var servers: some View {
        let n = Set(helm.servers.map(\.name)).count
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

enum Art {
    static let orange = Color(red: 0.85, green: 0.47, blue: 0.34)  // Clawd orange
    static let amber = Color(red: 0.80, green: 0.55, blue: 0.0)    // screen kept on; dark enough for white text
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
    static let cup = [".X.X.", "X.X..", ".....", "XXX..", "XXXX.", "XXX.X", "XXXX.", ".XX.."]
    static let screen = ["XXXXX", "X...X", "X...X", "XXXXX", "..X..", ".XXX."]
    static let rack = ["XXXXX", "X.XXX", ".....", "XXXXX", "X.XXX", ".....", "XXXXX", "X.XXX"]
}

enum Preview {
    static func show() {
        let helm = Helm.shared
        helm.servers = Server.parse(sh(Helm.root + "/bin/servers"))
        let view = VStack(alignment: .leading, spacing: 20) {
            Pill(helm: helm).scaleEffect(3, anchor: .topLeading).frame(width: 600, height: 70, alignment: .topLeading)
            Panel(helm: helm)
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
