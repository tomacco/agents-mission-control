// The lock in the pane header, drawn in Braille from simple shapes: a ring and two legs for the shackle, a
// rounded body lit from the top left, and a keyhole. `lift` (0 shut to 4 open) raises the shackle; the right
// leg leaves the body as it does on a real padlock. Each cell carries what it shows, for coloring.
export type LockCell = { ch: string; part: 'none' | 'steel' | 'body'; shade: number }
const BITS: [number, number, number][] = [[0, 0, 1], [0, 1, 2], [0, 2, 4], [1, 0, 8], [1, 1, 16], [1, 2, 32], [0, 3, 64], [1, 3, 128]]

export function lockRows(lift: number, cols = 10, rows = 7): LockCell[][] {
  const W = cols * 2, H = rows * 4
  const bx0 = 1, bx1 = W - 1, by0 = 16, by1 = H - 0.5, rr = 2.5
  const cx = W / 2, R = W * 0.29, t = 1.8, cy = 9.5 - lift
  const kx = W / 2, ky = by0 + 4.2
  // 0 nothing, 1..3 body shade (3 brightest), 4 steel
  const ink = (x: number, y: number): number => {
    const qx = Math.max(bx0 + rr - x, 0, x - (bx1 - rr)), qy = Math.max(by0 + rr - y, 0, y - (by1 - rr))
    if (Math.hypot(qx, qy) <= rr && x >= bx0 && x <= bx1 && y >= by0 && y <= by1) {
      if (Math.hypot(x - kx, y - ky) < 1.9 || (Math.abs(x - kx) < 0.8 && y >= ky && y <= ky + 4.6)) return 0
      const shade = 1 - ((x - bx0) / (bx1 - bx0)) * 0.7 - ((y - by0) / (by1 - by0)) * 0.2
      return shade > 0.72 ? 3 : shade > 0.45 ? 2 : 1
    }
    const ring = y <= cy && Math.abs(Math.hypot(x - cx, y - cy) - R) <= t / 2
    const left = Math.abs(x - (cx - R)) <= t / 2 && y > cy && y < by0
    const right = Math.abs(x - (cx + R)) <= t / 2 && y > cy && y < (lift ? by0 - lift : by0)
    return ring || left || right ? 4 : 0
  }
  const out: LockCell[][] = []
  for (let y0 = 0; y0 < H; y0 += 4) {
    const line: LockCell[] = []
    for (let x0 = 0; x0 < W; x0 += 2) {
      let code = 0, body = 0, steel = false
      for (const [dx, dy, bit] of BITS) {
        const v = ink(x0 + dx + 0.5, y0 + dy + 0.5)
        if (v) code |= bit
        if (v === 4) steel = true
        else if (v) body = Math.max(body, v)
      }
      line.push({ ch: code ? String.fromCharCode(0x2800 + code) : ' ', part: body ? 'body' : steel ? 'steel' : 'none', shade: body })
    }
    out.push(line)
  }
  return out
}

// A hex color mixed toward white (amount > 0) or black (amount < 0).
export function tone(hex: string, amount: number): string {
  const n = parseInt(hex.slice(1), 16), to = amount > 0 ? 255 : 0, a = Math.abs(amount)
  const ch = (v: number) => Math.round(v + (to - v) * a).toString(16).padStart(2, '0')
  return `#${ch((n >> 16) & 255)}${ch((n >> 8) & 255)}${ch(n & 255)}`
}
