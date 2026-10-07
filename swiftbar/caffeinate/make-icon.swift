// Renders the cubist menu bar icons: a coffee cup seen from two viewpoints at once (side-on body,
// rim from above, displaced facets) with a Picasso eye that opens when the screen is kept on.
// 36px at 144 dpi = 18pt. Off is a template image (alpha only); active states are colored.
// Usage: swift make-icon.swift
import AppKit

struct Palette { let lit, shade, rim, eye: NSColor; let eyeOpen: Bool }

func hex(_ v: Int, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat(v >> 16 & 255) / 255, green: CGFloat(v >> 8 & 255) / 255, blue: CGFloat(v & 255) / 255, alpha: a)
}

func render(_ out: String, _ p: Palette, px: Int = 36) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: px / 2, height: px / 2)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let cg = NSGraphicsContext.current!.cgContext
    cg.scaleBy(x: CGFloat(px) / 72, y: CGFloat(px) / 72)  // draw in 36x36 pixel units on an 18pt canvas
    func path(_ pts: [(CGFloat, CGFloat)]) {
        cg.beginPath(); cg.move(to: CGPoint(x: pts[0].0, y: pts[0].1))
        pts.dropFirst().forEach { cg.addLine(to: CGPoint(x: $0.0, y: $0.1)) }
    }
    func poly(_ pts: [(CGFloat, CGFloat)], _ c: NSColor) { cg.setFillColor(c.cgColor); path(pts); cg.closePath(); cg.fillPath() }
    func line(_ pts: [(CGFloat, CGFloat)], _ c: NSColor, _ w: CGFloat = 3) {
        cg.setStrokeColor(c.cgColor); cg.setLineWidth(w); cg.setLineJoin(.miter); cg.setLineCap(.butt)
        path(pts); cg.strokePath()
    }
    poly([(1, 3), (29, 0), (35, 6), (6, 9)], p.shade.withAlphaComponent(0.55))   // saucer, tilted plane
    poly([(7, 7), (18, 6), (18, 22), (5, 21)], p.lit)                            // body, lit facet
    poly([(18, 9), (27, 10), (25, 24), (18, 24)], p.shade)                       // body, shadow facet raised
    poly([(4, 21), (15, 18), (28, 23), (16, 27)], p.rim)                         // rim, seen from above
    line([(26, 20), (33, 16), (27, 11)], p.shade)                                // handle, displaced down
    line([(10, 28), (14, 31), (11, 35)], p.lit)                                  // steam, broken and offset
    line([(19, 29), (23, 33), (21, 36)], p.shade.withAlphaComponent(0.8))
    if p.eyeOpen {
        poly([(8, 14), (12, 17), (16, 14), (12, 11)], p.eye)                     // almond eye
        poly([(11, 14), (12, 15.2), (13, 14), (12, 12.8)], p.lit)               // pupil glint
    } else {
        line([(8, 14), (12, 12.5), (16, 14)], p.eye, 1.6)                        // closed eye
    }
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
}

let states: [(String, Palette)] = [
    ("icon-off", Palette(lit: hex(0), shade: hex(0, 0.55), rim: hex(0, 0.3), eye: .clear, eyeOpen: false)),
    ("icon-awake", Palette(lit: hex(0xFF9F0A), shade: hex(0xC2410C), rim: hex(0xFDE68A), eye: hex(0x3B1D0A), eyeOpen: false)),
    ("icon-screen", Palette(lit: hex(0xFFD60A), shade: hex(0xE4572E), rim: hex(0x2EC4B6), eye: hex(0x1B1B3A), eyeOpen: true)),
    ("icon-external", Palette(lit: hex(0x64D2FF), shade: hex(0x1D4E89), rim: hex(0xBFE9FF), eye: hex(0x0B1E3A), eyeOpen: false)),
]
states.forEach { render("\($0.0).png", $0.1) }
if CommandLine.arguments.contains("--preview") { states.forEach { render("preview-\($0.0).png", $0.1, px: 288) } }
