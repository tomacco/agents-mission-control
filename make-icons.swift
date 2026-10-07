// Render Helm's menu bar icons: Clawd (pixel art) plus a small accessory that shows status.
// 36x36 px at 144 dpi = 18 pt @2x. Template icons use alpha only; "on" states are coloured.
// Run: swift make-icons.swift assets
import AppKit

let clawd = [  // 12 x 8 cells
    "..XXXXXXXX..",
    "..X.XXXX.X..",
    "XXX.XXXX.XXX",
    "XXXXXXXXXXXX",
    "..XXXXXXXX..",
    "..XXXXXXXX..",
    "..X.X..X.X..",
    "..X.X..X.X..",
]
let waves = ["X..X.", ".X..X", ".X..X", ".X..X", "X..X."]
let cup = [".X.X.", "X.X..", ".....", "XXX..", "XXXX.", "XXX.X", "XXXX.", ".XX.."]
let rack = ["XXXXX", "X.XXX", ".....", "XXXXX", "X.XXX", ".....", "XXXXX", "X.XXX"]
let pause = ["XX.XX", "XX.XX", "XX.XX", "XX.XX", "XX.XX", "XX.XX"]

func draw(_ grid: [String], x: Int, top: Int, cell: Int = 2, color: NSColor) {
    color.setFill()
    for (r, row) in grid.enumerated() {
        for (c, ch) in row.enumerated() where ch == "X" {
            NSRect(x: x + c * cell, y: 36 - (top + (r + 1) * cell), width: cell, height: cell).fill()
        }
    }
}

func icon(_ name: String, body: NSColor, extra: [String]?, extraColor: NSColor? = nil, alpha: CGFloat = 1, top: Int = 4) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 36, pixelsHigh: 36, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw(clawd, x: 0, top: 14, color: body.withAlphaComponent(alpha))
    if let extra { draw(extra, x: 26, top: top, color: (extraColor ?? body).withAlphaComponent(alpha)) }
    NSGraphicsContext.current = nil
    rep.size = NSSize(width: 18, height: 18)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(CommandLine.arguments[1])/\(name).png"))
}

let black = NSColor.black
let orange = NSColor(srgbRed: 0.85, green: 0.47, blue: 0.34, alpha: 1)  // Clawd orange
let red = NSColor.systemRed
icon("handsoff-idle", body: black, extra: waves, top: 10)    // agents may talk
icon("handsoff-on", body: red, extra: pause, top: 8)         // agents paused
icon("caffeine-off", body: black, extra: cup, alpha: 0.45)
icon("caffeine-awake", body: orange, extra: cup)
icon("caffeine-screen", body: orange, extra: cup, extraColor: .systemYellow)
icon("servers-idle", body: black, extra: rack, alpha: 0.45)
icon("servers-on", body: black, extra: rack)
