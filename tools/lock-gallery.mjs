#!/usr/bin/env node
// Six ways to draw the lock in a terminal, side by side, shut and open. Compare in the real terminal:
//   node tools/lock-gallery.mjs
// A-C are one flat pixel-art sprite, designed on the grid (every pixel on or off, a fixed palette) and mapped
// to characters exactly; D is an outline in heavy box-drawing lines; E-F convert the 3D render with chafa.
import { execFileSync } from 'node:child_process'
import { mkdtempSync, readFileSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..')
const T = JSON.parse(readFileSync(join(ROOT, 'design/tokens.json'), 'utf8'))
const rgb = h => [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16))
const hex = c => '#' + c.map(v => Math.max(0, Math.min(255, Math.round(v))).toString(16).padStart(2, '0')).join('')
const mix = (a, b, t) => rgb(a).map((v, i) => v + (rgb(b)[i] - v) * t)
const aurora = t => { t = Math.min(1, Math.max(0, t)) * 2; const k = Math.min(1, Math.floor(t)); return hex(mix(T.aurora[k], T.aurora[k + 1], t - k)) }
const shadeHex = (h, f) => hex(rgb(h).map(v => v * f))
const ESC = '\x1b[', R = '\x1b[0m'
const FG = h => `${ESC}38;2;${rgb(h).join(';')}m`, BG = h => `${ESC}48;2;${rgb(h).join(';')}m`
const visible = s => s.replace(/\x1b\[[0-9;]*m/g, '').length

// ── the sprite: shapes on a pixel grid, no anti-aliasing ────────────────────
// Returns rows of colors ('' = empty). w x h pixels; `open` raises the shackle and frees its right leg.
function sprite(w, lockH, open = false) {
  const head = Math.round(lockH * 0.2), h = lockH + head      // room above for the raised shackle
  const px = Array.from({ length: h }, () => Array(w).fill(''))
  const cx = (w - 1) / 2
  const bodyTop = head + Math.round(lockH * 0.45), bodyBot = h - 1, r = Math.max(2, Math.round(w * 0.13))
  const thick = Math.max(2, Math.round(w * 0.15))
  const ringR = w * 0.3                                   // the arch: centre line of the shackle
  const lift = open ? head : 0
  const ringCy = head + Math.round(lockH * 0.36) - lift
  const steelL = '#E3E6EE', steelM = '#B4BACB', steelD = '#7E8499'
  const inBody = (x, y) => {
    const qx = Math.max(r - x, 0, x - (w - 1 - r)), qy = Math.max(bodyTop + r - y, 0, y - (bodyBot - r))
    return y >= bodyTop && y <= bodyBot && x >= 0 && x <= w - 1 && Math.hypot(qx, qy) <= r + 0.3
  }
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    if (inBody(x, y)) {
      let c = aurora(x / (w - 1))
      if (y === bodyTop + 1 && x > r - 1 && x < w - r) c = hex(mix(c, '#FFFFFF', 0.22))   // one highlight line inside            // shaded base
      px[y][x] = c; continue
    }
    const d = Math.hypot(x - cx, (y - ringCy) * 1.0)
    const arch = y <= ringCy && Math.abs(d - ringR) <= thick / 2 + 0.3   // + 0.3: no gaps where the curve crosses pixel rows
    const legL = Math.abs(x - (cx - ringR)) <= thick / 2 && y > ringCy && y < bodyTop
    const legR = Math.abs(x - (cx + ringR)) <= thick / 2 && y > ringCy && y < (open ? ringCy + Math.round(lockH * 0.12) : bodyTop)
    if (arch || legL || legR) {
      // lit from the top left: light outer-left, mid, dark right
      const t = (x - (cx - ringR - thick / 2)) / (2 * ringR + thick)
      px[y][x] = t < 0.3 ? steelL : t < 0.7 ? steelM : steelD
    }
  }
  // keyhole: a hand-placed stamp per size (a computed circle this small rasterizes into a cross)
  const STAMPS = {
    s: ['XX', 'XX', 'XX'],
    m: ['.XX.', 'XXXX', '.XX.', '.XX.', 'XXXX'],
    l: ['.XXX.', 'XXXXX', 'XXXXX', '.XXX.', '.XXX.', 'XXXXX'],
  }
  const stamp = w >= 20 ? STAMPS.l : w >= 15 ? STAMPS.m : STAMPS.s
  const sw = stamp[0].length, sx = Math.round(cx - (sw - 1) / 2)
  const sy = bodyTop + Math.round((bodyBot - bodyTop - stamp.length) / 2) + 1
  stamp.forEach((row, j) => [...row].forEach((ch, i) => { if (ch === 'X' && px[sy + j]?.[sx + i]) px[sy + j][sx + i] = '#1A1622' }))
  return px
}

// ── mappings from pixels to characters ──────────────────────────────────────
// B: one pixel = two columns of background color.
const asCells = px => px.map(row => row.map(c => c ? BG(c) + '  ' + R : '  ').join(''))
// C: two pixels stacked per cell (half blocks); background for the upper pixel where both exist.
const asHalves = px => {
  const out = []
  for (let y = 0; y < px.length; y += 2) {
    const a = px[y], b = px[y + 1] ?? a.map(() => '')
    out.push(a.map((t, x) => t && b[x] ? BG(t) + FG(b[x]) + '▄' + R : b[x] ? FG(b[x]) + '▄' + R : t ? FG(t) + '▀' + R : ' ').join(''))
  }
  return out
}
// A: 2x2 pixels per cell (quadrants): keep the two most common colors, the rest go to the nearer one.
const QUAD = ' ▘▝▀▖▌▞▛▗▚▐▜▄▙▟█'
const asQuads = px => {
  const out = []
  for (let y = 0; y < px.length; y += 2) {
    let line = ''
    for (let x = 0; x < px[0].length; x += 2) {
      const q = [px[y][x], px[y][x + 1], px[y + 1]?.[x], px[y + 1]?.[x + 1]].map(c => c ?? '')
      const counts = {}; q.forEach(c => { if (c) counts[c] = (counts[c] || 0) + 1 })
      const cols = Object.keys(counts).sort((m, n) => counts[n] - counts[m])
      if (!cols.length) { line += ' '; continue }
      const hasEmpty = q.some(c => !c)
      const dist = (m, n) => rgb(m).reduce((s, v, i) => s + (v - rgb(n)[i]) ** 2, 0)
      if (hasEmpty) {           // against the terminal's own background: one color, glyph shows the shape
        const f = cols[0]; let mask = 0; q.forEach((c, i) => { if (c) mask |= 1 << i })
        line += FG(f) + QUAD[mask] + R; continue
      }
      if (cols.length === 1) { line += BG(cols[0]) + ' ' + R; continue }
      const [fc, bc] = cols; let mask = 0
      q.forEach((c, i) => { const toF = c === fc || (c !== bc && dist(c, fc) < dist(c, bc)); if (toF) mask |= 1 << i })
      line += BG(bc) + FG(fc) + QUAD[mask] + R
    }
    out.push(line)
  }
  return out
}

// D: an outline icon in heavy box-drawing lines, colored along Aurora.
function outline(open) {
  const rows = open
    ? ['  ┏━━━━┓      ', '  ┃    ┃      ', '  ┃    ┃      ', '  ┃           ', '┏━┻━━━━━━━━━┓ ', '┃     ●     ┃ ', '┃     ┃     ┃ ', '┃           ┃ ', '┗━━━━━━━━━━━┛ ']
    : ['              ', '   ┏━━━━━┓    ', '   ┃     ┃    ', '   ┃     ┃    ', '┏━━┻━━━━━┻━━┓ ', '┃     ●     ┃ ', '┃     ┃     ┃ ', '┃           ┃ ', '┗━━━━━━━━━━━┛ ']
  return rows.map(r => [...r].map((ch, i) => ch === ' ' ? ' ' : FG(ch === '●' || (ch === '┃' && i === 6 && r.includes('●') === false && r.trim().length > 3 && r.indexOf('┃', 1) === 6) ? T.neutral['100'] : aurora(i / 13)) + ch + R).join(''))
}

// E-F: the 3D lock through chafa (block symbols without the thinnest eighths, which read as slivers).
function chafa3d(cel) {
  const dir = mkdtempSync(join(tmpdir(), 'amc-gal-'))
  execFileSync('node', [join(ROOT, 'tools/lock3d.mjs'), '--png', dir, ...(cel ? ['--cel'] : [])], { stdio: 'ignore' })
  const conv = f => execFileSync('chafa', ['-f', 'symbols', '--symbols', 'block+space-[▏▕▁▔]', '--probe', 'off', '-c', 'full',
    '--color-extractor', 'median', '--dither', 'none', '--size', '14x9', join(dir, f)], { encoding: 'utf8' })
    .replace(/\x1b\[\?25[lh]/g, '').split('\n').filter(l => visible(l) > 0)
  const shut = conv('lock-00.png'), open = conv('lock-21.png')
  rmSync(dir, { recursive: true }); return [shut, open]
}

const W = 18, H = 18
const SPRITES_ONLY = process.argv.includes('--sprites')
const variants = SPRITES_ONLY ? [
  ['C  half blocks 22', asHalves(sprite(22, 26)), asHalves(sprite(22, 26, true))],
  ['C  half blocks 16', asHalves(sprite(16, 20)), asHalves(sprite(16, 20, true))],
  ['C  half blocks 12', asHalves(sprite(12, 15)), asHalves(sprite(12, 15, true))],
  ['C  half blocks 24', asHalves(sprite(24, 28)), asHalves(sprite(24, 28, true))],
] : [
  ['A  sprite · quadrants', asQuads(sprite(W, H)), asQuads(sprite(W, H, true))],
  ['B  sprite · cells', asCells(sprite(9, 9)), asCells(sprite(9, 9, true))],
  ['C  sprite · half blocks', asHalves(sprite(12, 16)), asHalves(sprite(12, 16, true))],
  ['D  outline · box lines', outline(false), outline(true)],
  ['E  3D · chafa tuned', ...chafa3d(false)],
  ['F  3D cel · chafa', ...chafa3d(true)],
]
const colW = 22
const pad = (s, n) => s + ' '.repeat(Math.max(0, n - visible(s)))
for (const pose of [1, 2]) {
  console.log('\n  ' + variants.map(v => pad(`${FG(T.neutral['50'])}${v[0]}${R}`, colW)).join('  ') + `   ${FG(T.neutral['50'])}${pose === 1 ? 'shut' : 'open'}${R}`)
  const n = Math.max(...variants.map(v => v[pose].length))
  for (let i = 0; i < n; i++) {
    console.log('  ' + variants.map(v => { const rows = v[pose], off = n - rows.length; return pad(rows[i - off] ?? '', colW) }).join('  '))
  }
}
console.log()
