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
