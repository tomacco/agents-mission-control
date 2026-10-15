import { M as MODE_FRAMES, r as resolvePreset } from '../vendor/thinking-orbs/engine.js'

// One frame of a thinking orb as Braille rows: each cell holds 2x4 dots, so the orb keeps its curves.
// Each character comes with an ink level (1 faint, 2, 3 strong) for coloring.
export type OrbCell = { ch: string; level: number }
const BITS: [number, number, number][] = [[0, 0, 1], [0, 1, 2], [0, 2, 4], [1, 0, 8], [1, 1, 16], [1, 2, 32], [0, 3, 64], [1, 3, 128]]

export function orbRows(state: string, seconds: number, cols = 18, rows = 9): OrbCell[][] {
  const { mode, speed, opts } = resolvePreset(state, 64)
  const frame = MODE_FRAMES[mode]!(64, seconds * speed, opts)
  const dw = cols * 2, dh = rows * 4, sx = dw / 64, sy = dh / 64
  const ink = Array.from({ length: dh }, () => new Array<number>(dw).fill(0))
  const put = (x: number, y: number, v: number) => {
    const ix = Math.round(x), iy = Math.round(y)
    if (ix >= 0 && iy >= 0 && ix < dw && iy < dh) ink[iy]![ix] = Math.max(ink[iy]![ix]!, v)
  }
  for (const l of frame.lines) {
    const n = Math.ceil(Math.hypot((l.x2 - l.x1) * sx, (l.y2 - l.y1) * sy)) + 1
    for (let i = 0; i <= n; i++) put((l.x1 + ((l.x2 - l.x1) * i) / n) * sx, (l.y1 + ((l.y2 - l.y1) * i) / n) * sy, (1 - l.white) * (l.a ?? 1) * 0.6)
  }
  for (const d of frame.dots) {
    const v = (1 - d.white) * (d.a ?? 1), rad = Math.max(0.5, d.r * sx)
    for (let dy = -rad; dy <= rad; dy += 0.5) for (let dx = -rad; dx <= rad; dx += 0.5) if (dx * dx + dy * dy <= rad * rad) put(d.x * sx + dx, d.y * sy + dy, v)
  }
  const out: OrbCell[][] = []
  for (let cy = 0; cy < dh; cy += 4) {
    const line: OrbCell[] = []
    for (let cx = 0; cx < dw; cx += 2) {
      let code = 0, peak = 0
      for (const [dx, dy, bit] of BITS) {
        const v = ink[cy + dy]![cx + dx]!
        if (v > 0.12) { code |= bit; peak = Math.max(peak, v) }
      }
      line.push({ ch: code ? String.fromCharCode(0x2800 + code) : ' ', level: peak > 0.66 ? 3 : peak > 0.38 ? 2 : peak > 0 ? 1 : 0 })
    }
    out.push(line)
  }
  return out
}
