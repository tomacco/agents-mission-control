// The lock in the pane header: the installer's lock, pixel for pixel. One pixel is two columns of background
// color (no glyphs, so no seams). `lift` (0 shut, up to 2 open) raises the shackle; its left leg stays in the body.
// Colors are the design tokens: Aurora across the body, steel from neutral 70 to 100, the keyhole neutral 0.
// Two sizes of one design: full (the installer's, 18 columns) and mini (10 columns) for narrow panes.
const SIZES = {
  full: { shackle: ['..XXXXX..', '.XX...XX.', '.X.....X.', '.X.....X.'],
          body: ['XXXXXXXXX', 'XXX...XXX', 'XXXX.XXXX', 'XXXX.XXXX', 'XXXXXXXXX', 'XXXXXXXXX'], lift: 2 },
  mini: { shackle: ['.XXX.', 'X...X'], body: ['XXXXX', 'XX.XX', 'XXXXX'], lift: 1 },
}
export type LockSize = keyof typeof SIZES
export const LIFT = SIZES.full.lift
const AURORA = ['#D97757', '#D6409F', '#8E4EC6'], STEEL = ['#AEB4C6', '#EDEDF2'], KEYHOLE = '#1E1A26'

const rgb = (h: string) => [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16))
const mixHex = (a: string, b: string, t: number) =>
  '#' + rgb(a).map((v, i) => Math.round(v + (rgb(b)[i]! - v) * t).toString(16).padStart(2, '0')).join('')
const aurora = (t: number) => (t < 0.5 ? mixHex(AURORA[0]!, AURORA[1]!, t * 2) : mixHex(AURORA[1]!, AURORA[2]!, (t - 0.5) * 2))

// Rows of pixel colors, '' where empty; always LIFT + 4 + 6 rows, so the header does not jump when it opens.
export function lockPixels(lift: number, size: LockSize = 'full'): string[][] {
  const { shackle: SHACKLE, body: BODY, lift: LIFT } = SIZES[size]
  const width = BODY[0]!.length, rows = LIFT + SHACKLE.length + BODY.length
  const px: string[][] = Array.from({ length: rows }, () => Array<string>(width).fill(''))
  const top = LIFT - Math.round(Math.min(LIFT, Math.max(0, lift)))
  SHACKLE.forEach((row, r) => [...row].forEach((ch, c) => { if (ch === 'X') px[top + r]![c] = mixHex(STEEL[0]!, STEEL[1]!, c / width) }))
  for (let r = top + SHACKLE.length; r < LIFT + SHACKLE.length; r++)          // open: the left leg stays in the body
    [...SHACKLE[SHACKLE.length - 1]!.slice(0, Math.floor(width / 2))].forEach((ch, c) => { if (ch === 'X') px[r]![c] = mixHex(STEEL[0]!, STEEL[1]!, c / width) })
  BODY.forEach((row, r) => [...row].forEach((ch, c) => { px[LIFT + SHACKLE.length + r]![c] = ch === 'X' ? aurora(c / (width - 1)) : KEYHOLE }))
  return px
}
