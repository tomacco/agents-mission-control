// What Terminal, and so every agent started from it, reads without AMC. macOS guards only its own list of
// places; the rest of home stays open, keys and tokens included, and Touch ID in AMC is no gate for those.
// Each place is checked by listing it: macOS answers "Operation not permitted" where it guards it.
import type { Reach } from '../types'

export const QUIET = ['.ssh', '.aws', '.config', '.amc', 'Library/Mail', 'Library/Messages', 'Library/Safari']
// Listing these raises a macOS prompt while Terminal has no answer for them yet, so only /amc checks them.
export const ASKING = ['Desktop', 'Documents', 'Downloads']

const DENIED = /Operation not permitted/
const name = (path: string) => path.replace(/^Library\//, '')

export function sortReach(checked: { path: string; exitCode: number; stderr: string }[], asked: boolean): Reach {
  const reach: Reach = { terminal: [], amcOnly: [], asked }
  for (const c of checked) {
    if (c.exitCode === 0) reach.terminal.push(name(c.path))
    else if (DENIED.test(c.stderr)) reach.amcOnly.push(name(c.path))
    // anything else (the place does not exist) is left out
  }
  return reach
}
