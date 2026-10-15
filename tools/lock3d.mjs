#!/usr/bin/env node
// The lock, modelled in 3D and rendered frame by frame into terminal cells (one pixel = two columns of background
// color, the installer's big-type technique: bold and seamless). Run once; it writes design/lock-frames.json,
// which the installer and the Claude Code plugin play back.
//   node tools/lock3d.mjs            write the frames
//   node tools/lock3d.mjs --preview  play them here
import { readFileSync, writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..')
const TOKENS = JSON.parse(readFileSync(join(ROOT, 'design/tokens.json'), 'utf8'))
const hex = h => [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16) / 255)
const AURORA = TOKENS.aurora.map(hex)
const aurora = t => {
  t = Math.min(1, Math.max(0, t)) * (AURORA.length - 1)
  const k = Math.min(Math.floor(t), AURORA.length - 2), f = t - k
  return AURORA[k].map((v, i) => v + (AURORA[k + 1][i] - v) * f)
}

// ── vector helpers ───────────────────────────────────────────────────────────
const len = (x, y, z = 0) => Math.hypot(x, y, z)
const norm = v => { const l = len(...v) || 1; return v.map(c => c / l) }
const dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
const rotY = ([x, y, z], a) => [x * Math.cos(a) + z * Math.sin(a), y, -x * Math.sin(a) + z * Math.cos(a)]
const rotX = ([x, y, z], a) => [x, y * Math.cos(a) - z * Math.sin(a), y * Math.sin(a) + z * Math.cos(a)]

// ── the model: signed distances ──────────────────────────────────────────────
const roundBox = ([x, y, z], [bx, by, bz], r) => {
  const qx = Math.abs(x) - bx + r, qy = Math.abs(y) - by + r, qz = Math.abs(z) - bz + r
  return len(Math.max(qx, 0), Math.max(qy, 0), Math.max(qz, 0)) + Math.min(Math.max(qx, qy, qz), 0) - r
}
const capsule = ([x, y, z], ay, by_, r) => len(x, y - Math.min(Math.max(y, ay), by_), z) - r
const R = 0.4, T = 0.15                     // shackle: radius of its arc, thickness (bold at terminal size)
const BODY_TOP = -0.08

// The scene at shackle `lift` (0..1 up) and `swing` (radians around the left leg). Returns [distance, material].
function scene(p, lift, swing) {
  // body with a keyhole cut into its front face
  const bp = [p[0], p[1] + 0.48, p[2]]
  let body = roundBox(bp, [0.72, 0.42, 0.3], 0.14)
  const kp = [p[0], p[1] + 0.4, p[2]]
  const hole = Math.min(len(kp[0], kp[1] - 0.06) - 0.095, Math.max(Math.abs(kp[0]) - 0.04, Math.abs(kp[1] + 0.12) - 0.15))
  const cut = Math.max(hole, -(p[2] - 0.2))
  body = Math.max(body, -cut)
  // shackle: arc + two legs, raised by lift, then swung around the left leg (x = -R)
  let s = [p[0] + R, p[1] - (0.3 + 0.25 * lift), p[2]]
  s = rotY(s, -swing)
  s = [s[0] - R, s[1], s[2]]
  const arc = s[1] > 0 ? Math.abs(len(s[0], s[1]) - R) : 1e9
  const arcD = arc === 1e9 ? 1e9 : len(arc, s[2]) - T
  const leftLeg = capsule([s[0] + R, s[1], s[2]], -0.4 - 0.25 * lift, 0, T)
  const rightLeg = capsule([s[0] - R, s[1], s[2]], -0.4 + 0.25 * lift * 0, 0, T)
  const shackle = Math.min(arcD, leftLeg, rightLeg)
  if (cut < 0.004 && body < 0.02 && p[2] > 0.15) return [body, 'hole']
  return shackle < body ? [shackle, 'steel'] : [body, 'body']
}

// ── renderer ─────────────────────────────────────────────────────────────────
const LIGHT = norm([-0.55, 0.75, 0.6]), FILL = norm([0.7, -0.1, 0.5]), VIEW = [0, 0, 1]
function shade(px, py, yaw, tilt, lift, swing, cel = false) {
  // orthographic camera looking down -z; the object is turned by yaw and tilt
  let ro = [px, py, 3], rd = [0, 0, -1]
  const toObj = v => rotX(rotY(v, -yaw), -tilt)
  const o = toObj(ro), d = toObj(rd)
  let t = 0
  for (let i = 0; i < 90; i++) {
    const p = [o[0] + d[0] * t, o[1] + d[1] * t, o[2] + d[2] * t]
    const [dist, mat] = scene(p, lift, swing)
    if (dist < 0.002) {
      const e = 0.002, f = q => scene(q, lift, swing)[0]
      const n = norm([f([p[0] + e, p[1], p[2]]) - f([p[0] - e, p[1], p[2]]),
                      f([p[0], p[1] + e, p[2]]) - f([p[0], p[1] - e, p[2]]),
                      f([p[0], p[1], p[2] + e]) - f([p[0], p[1], p[2] - e])])
      const nw = rotY(rotX(n, tilt), yaw)            // normal in world space for lighting
      const diff = Math.max(0, dot(nw, LIGHT)), fill = Math.max(0, dot(nw, FILL)) * 0.35
      const h = norm(LIGHT.map((l, k) => l + VIEW[k])), spec = Math.pow(Math.max(0, dot(nw, h)), mat === 'steel' ? 40 : 18)
      const rim = Math.pow(1 - Math.max(0, dot(nw, VIEW)), 3) * 0.35
      if (mat === 'hole') return [0.07, 0.05, 0.09]
      const base = mat === 'steel' ? [0.72, 0.75, 0.82] : aurora((p[0] + 0.75) / 1.5)
      const amb = 0.28
      if (cel) {
        // Flat tones and a hard highlight: edges stay crisp at terminal resolution.
        const light = amb + diff * 0.85 + fill
        const band = light > 0.95 ? 1.12 : light > 0.62 ? 0.9 : light > 0.38 ? 0.66 : 0.46
        if (spec > (mat === 'steel' ? 0.55 : 0.7)) return base.map(c => Math.min(1, c * 0.35 + 0.72))
        return base.map(c => Math.min(1, c * band))
      }
      return base.map(c => Math.min(1, c * (amb + diff * 0.85 + fill) + spec * (mat === 'steel' ? 0.9 : 0.45) + rim * c))
    }
    t += dist
    if (t > 6) break
  }
  return null
}

// One frame: w x h pixels, 3x3 samples per pixel; a pixel is drawn when most samples hit.
function frame(w, h, { yaw, tilt, lift, swing }, cel = false) {
  const rows = [], scale = 2.25 / h, ss = 3   // room above for the raised shackle
  for (let y = 0; y < h; y++) {
    const row = []
    for (let x = 0; x < w; x++) {
      let acc = [0, 0, 0], hits = 0
      for (let sy = 0; sy < ss; sy++) for (let sx = 0; sx < ss; sx++) {
        const px = (x + (sx + 0.5) / ss - w / 2) * scale, py = (h / 2 - (y + (sy + 0.5) / ss)) * scale + 0.02
        const c = shade(px, py, yaw, tilt, lift, swing, cel)
        if (c) { acc = acc.map((v, i) => v + c[i]); hits++ }
      }
      let col = hits ? acc.map(v => v / hits) : null
      if (cel && hits) {  // the centre sample's own colour, no blend across an edge
        const px = (x + 0.5 - w / 2) * scale, py = (h / 2 - (y + 0.5)) * scale + 0.02
        col = shade(px, py, yaw, tilt, lift, swing, true) ?? col
      }
      row.push(hits >= ss * ss * 0.5 ? '#' + col.map(v => Math.round(v * 255).toString(16).padStart(2, '0')).join('') : '')
    }
    rows.push(row)
  }
  return rows
}

// The film: a three-quarter view, the shackle lifts and swings open, then holds.
const YAW = -0.42, TILT = 0.18
const ease = t => t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2
const poses = []
for (let i = 0; i < 6; i++) poses.push({ yaw: YAW, tilt: TILT, lift: 0, swing: 0 })
for (let i = 1; i <= 6; i++) poses.push({ yaw: YAW, tilt: TILT, lift: ease(i / 6), swing: 0 })
for (let i = 1; i <= 10; i++) poses.push({ yaw: YAW, tilt: TILT, lift: 1, swing: ease(i / 10) * 1.75 })

const SIZES = { hero: [16, 13], pane: [12, 10] }
const rgbOf = c => `${parseInt(c.slice(1, 3), 16)};${parseInt(c.slice(3, 5), 16)};${parseInt(c.slice(5, 7), 16)}`
// Cells: one pixel = two columns of background (bold, seamless).
const asCells = rows => rows.map(r => r.map(c => c ? `\x1b[48;2;${rgbOf(c)}m  \x1b[0m` : '  ').join(''))
// Half blocks: two pixels per cell stacked, lower half in the glyph colour, upper half in the background.
const asHalves = rows => {
  const out = []
  for (let y = 0; y < rows.length; y += 2) {
    const top = rows[y], bot = rows[y + 1] ?? top.map(() => '')
    out.push(top.map((t, x) => {
      const b = bot[x]
      if (t && b) return `\x1b[48;2;${rgbOf(t)}m\x1b[38;2;${rgbOf(b)}m▄\x1b[0m`
      if (b) return `\x1b[38;2;${rgbOf(b)}m▄\x1b[0m`
      if (t) return `\x1b[38;2;${rgbOf(t)}m▀\x1b[0m`
      return ' '
    }).join(''))
  }
  return out
}
if (process.argv.includes('--preview')) {
  // Side by side: soft cells (now), cel-shaded cells, cel-shaded half blocks at double resolution.
  const [w, h] = SIZES[process.argv[3] || 'hero']
  const A = poses.map(p => asCells(frame(w, h, p)))
  const Bc = poses.map(p => asCells(frame(w, h, p, true)))
  const C = poses.map(p => asHalves(frame(w * 2, h * 2, p, true)))
  const pad = (line, cols) => line + ' '.repeat(Math.max(0, cols - line.replace(/\x1b\[[0-9;]*m/g, '').length))
  console.log(`  ${pad('soft (now)', w * 2 + 4)}${pad('sharp: cel shading', w * 2 + 4)}sharp: cel + half blocks (2x)`)
  process.stdout.write('\x1b[?25l')
  for (let loop = 0; loop < 2; loop++) for (let i = 0; i < poses.length + 8; i++) {
    const k = Math.min(i, poses.length - 1)
    for (let r = 0; r < h; r++) console.log('  ' + pad(A[k][r], w * 2 + 4) + pad(Bc[k][r], w * 2 + 4) + (C[k][r] ?? ''))
    process.stdout.write(`\x1b[${h}A`); await new Promise(res => setTimeout(res, 90))
  }
  process.stdout.write(`\x1b[${h}B\x1b[?25h\n`)
} else {
  const out = { note: 'Generated by tools/lock3d.mjs; do not edit. One pixel = two terminal columns of background color.', sizes: {} }
  for (const [name, [w, h]] of Object.entries(SIZES)) out.sizes[name] = { w, h, frames: poses.map(p => frame(w, h, p)) }
  writeFileSync(join(ROOT, 'design/lock-frames.json'), JSON.stringify(out))
  console.log(`wrote design/lock-frames.json: ${poses.length} frames at ${Object.keys(SIZES).join(', ')}`)
}
