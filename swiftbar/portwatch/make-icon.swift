// Renders the cubist menu bar icon: a faceted antenna whose broken, offset waves sit on tilted planes.
// Template image (alpha only), 36px at 144 dpi = 18pt. Usage: swift make-icon.swift
import AppKit

func render(_ out: String, dim: CGFloat) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 36, pixelsHigh: 36, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: 18, height: 18)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let cg = NSGraphicsContext.current!.cgContext
    cg.scaleBy(x: 0.5, y: 0.5)  // draw in 36x36 pixel units on an 18pt canvas
    func poly(_ p: [(CGFloat, CGFloat)], _ a: CGFloat) {
        cg.setFillColor(NSColor.black.withAlphaComponent(a * dim).cgColor)
        cg.beginPath(); cg.move(to: CGPoint(x: p[0].0, y: p[0].1))
        for q in p.dropFirst() { cg.addLine(to: CGPoint(x: q.0, y: q.1)) }
        cg.closePath(); cg.fillPath()
    }
    func chevron(_ p: [(CGFloat, CGFloat)], _ a: CGFloat) {
        cg.setStrokeColor(NSColor.black.withAlphaComponent(a * dim).cgColor)
        cg.setLineWidth(3); cg.setLineJoin(.miter); cg.setLineCap(.butt)
        cg.beginPath(); cg.move(to: CGPoint(x: p[0].0, y: p[0].1))
        for q in p.dropFirst() { cg.addLine(to: CGPoint(x: q.0, y: q.1)) }
        cg.strokePath()
    }
    poly([(3, 9), (29, 3), (34, 25), (9, 32)], 0.18)          // tilted ground plane
    poly([(18, 21), (11, 2), (18, 2)], 1.0)                   // mast, lit facet
    poly([(18, 21), (18, 2), (25, 2)], 0.5)                   // mast, shadow facet
    poly([(18, 28), (22, 23), (18, 19), (14, 23)], 1.0)       // emitter diamond
    chevron([(12, 30), (8, 23), (12, 16)], 1.0)               // inner waves, right one displaced
    chevron([(24, 33), (28, 26), (24, 19)], 0.55)
    chevron([(6, 35), (1, 24), (6, 13)], 0.55)                // outer waves, left one displaced
    chevron([(30, 31), (35, 22), (30, 11)], 1.0)
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
}
render("icon.png", dim: 1.0)
render("icon-idle.png", dim: 0.4)
