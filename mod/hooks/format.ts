import type { RunView } from '../types'

// "just now", "a minute ago", "5 minutes ago": how long ago, the way a person says it.
export function ago(ms: number): string {
  const s = Math.max(0, Math.round(ms / 1000))
  if (s < 45) return 'just now'
  if (s < 90) return 'a minute ago'
  const m = Math.round(s / 60)
  if (m < 45) return `${m} minutes ago`
  if (m < 90) return 'an hour ago'
  return `${Math.round(m / 60)} hours ago`
}

// The latest runs first, at most `n`.
export function newestFirst(list: readonly RunView[], n: number): RunView[] {
  return list.slice(-n).reverse()
}

// Without PortCall or a name from the model, a session still needs one a person can tell apart.
export const GENERIC = /^(claude([ -]code)?|agent|assistant|ai|model|unknown|)$/i
const ADJ = ['Amber', 'Brisk', 'Calm', 'Clever', 'Coral', 'Swift', 'Lunar', 'Mellow', 'Nimble', 'Quiet', 'Rapid', 'Silver', 'Steady', 'Sunny', 'Tidy', 'Vivid']
const NOUN = ['Falcon', 'Otter', 'Heron', 'Lynx', 'Badger', 'Comet', 'Fox', 'Ibis', 'Koala', 'Marten', 'Orca', 'Puffin', 'Raven', 'Tern', 'Walrus', 'Wren']
export function sessionName(sessionId: string): string {
  let h = 0
  for (const ch of sessionId) h = (h * 31 + ch.charCodeAt(0)) >>> 0
  return `${ADJ[h % ADJ.length]} ${NOUN[(h >>> 8) % NOUN.length]}`
}


// A command AMC ran was refused an Apple event. A stored "Don't Allow" for AMC fails the same way with no prompt.
export function appleEventsHint(output: string, bundle: string): string {
  if (!/Not authorized to send Apple events|-1743/.test(output)) return ''
  return `\n[amc] macOS refused an Apple event from AMC itself. A stored "Don't Allow" fails like this with no prompt. ` +
    `Check \`tccutil list -s AppleEvents -b ${bundle}\`; if it says denied, ask the person before running ` +
    `\`tccutil reset AppleEvents ${bundle}\` (it clears every AMC Automation choice), then retry so macOS asks again.`
}
