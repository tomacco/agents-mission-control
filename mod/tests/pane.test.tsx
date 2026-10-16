import { expect, test } from 'claude-code/testing'

import { GENERIC, ago, newestFirst, sessionName } from '../hooks/format'
import { lockRows, tone } from '../hooks/lock'
import { orbRows } from '../hooks/orb'
import { sortReach } from '../hooks/reach'
import type { RunView } from '../types'

// Every string drawn, in order, so the test reads the pane as the person does.
function texts(node: unknown): string[] {
  if (typeof node === 'string') return [node]
  if (Array.isArray(node)) return node.flatMap(texts)
  if (node && typeof node === 'object') {
    const o = node as { children?: unknown; props?: { children?: unknown } }
    return texts(o.children ?? o.props?.children ?? [])
  }
  return []
}

const props = (placement: 'dock' | 'inline') =>
  ({ title: 'Privileged', isFocused: false, bodyColumns: 36, placement, scroll: undefined, view: undefined }) as never

test('relative times read the way a person says them', () => {
  expect(ago(10_000)).toBe('just now')
  expect(ago(70_000)).toBe('a minute ago')
  expect(ago(5 * 60_000)).toBe('5 minutes ago')
  expect(ago(65 * 60_000)).toBe('an hour ago')
  expect(ago(3 * 3600_000)).toBe('3 hours ago')
})

test('the newest run comes first, and only the last few', () => {
  const run = (id: string) => ({ id, command: id, reason: '', exit: 0, tail: [], at: 0 }) as RunView
  expect(newestFirst([run('a'), run('b'), run('c')], 5).map(r => r.id)).toEqual(['c', 'b', 'a'])
  expect(newestFirst([run('a'), run('b'), run('c')], 2).map(r => r.id)).toEqual(['c', 'b'])
})

test('the pane draws, and says how to get the side panel when it sits above the prompt', async $ => {
  const ui = await $.ui.mount({ plugin: 'amc', surface: 'terminal', component: 'Pane', requestId: 'amc', props: props('dock') })
  const docked = texts(await ui.drawn()).join('|')
  expect(docked).toContain('NO ACCESS')
  expect(docked).not.toContain('fullscreen')
  await ui.redraw(props('inline'))
  const inline = texts(await ui.drawn()).join('|')
  expect(inline).toContain('fullscreen in /config')
})

// The hint after "Operation not permitted": the test's own Bash stands for the real tool beneath the plugin.
const HINT = /no Full Disk Access/
test('no hint when the words only appear in successful output', async ($, on) => {
  on('tool.call', { tool: 'Bash' }, () => ({ result: { stdout: "const DENIED = /Operation not permitted/", stderr: '' } }) as never)
  const ran = await $.tool.call({ tool: 'Bash', command: 'grep -r Operation .' } as never)
  expect(JSON.stringify(ran)).not.toMatch(HINT)
})

test('a hint when a command failed on it', async ($, on) => {
  on('tool.call', { tool: 'Bash' }, () => ({ result: { stdout: '', stderr: 'ls: ~/Library/Mail: Operation not permitted' } }) as never)
  const ran = await $.tool.call({ tool: 'Bash', command: 'ls ~/Library/Mail' } as never)
  expect(JSON.stringify(ran)).toMatch(HINT)
})

test('a session without a usable name gets a stable one', () => {
  expect(sessionName('abc-123')).toBe(sessionName('abc-123'))
  expect(sessionName('abc-123')).toMatch(/^[A-Z][a-z]+ [A-Z][a-z]+$/)
  for (const generic of ['claude', 'Claude Code', 'claude-code', 'agent', 'Assistant', '']) expect(GENERIC.test(generic)).toBe(true)
  expect(GENERIC.test('Quartermaster Overclocked Walrus')).toBe(false)
})

test('a thinking orb frame is drawn as Braille rows', () => {
  const rows = orbRows('breathing', 1.3, 18, 9)
  expect(rows.length).toBe(9)
  expect(rows.every(r => r.length === 18)).toBe(true)
  const inked = rows.flat().filter(c => c.level > 0)
  expect(inked.length).toBeGreaterThan(20)
  expect(inked.every(c => c.ch.charCodeAt(0) >= 0x2800 && c.ch.charCodeAt(0) <= 0x28ff)).toBe(true)
  expect(orbRows('breathing', 1.3).map(r => r.map(c => c.ch).join(''))).not.toEqual(orbRows('breathing', 2.1).map(r => r.map(c => c.ch).join('')))
})

test('the lock is drawn in Braille and its shackle rises when open', () => {
  const shut = lockRows(0), open = lockRows(4)
  expect(shut.length).toBe(7)
  expect(shut.every(r => r.length === 10)).toBe(true)
  expect(shut.flat().some(c => c.part === 'steel')).toBe(true)
  expect(shut.flat().some(c => c.part === 'body' && c.shade === 3)).toBe(true)
  // raised, the shackle's arc fills more of the top row
  const topSteel = (rows: typeof shut) => rows[0]!.filter(c => c.part === 'steel').length
  expect(topSteel(open)).toBeGreaterThan(topSteel(shut))
  expect(tone('#808080', 1)).toBe('#ffffff')
  expect(tone('#808080', -1)).toBe('#000000')
})

test('the header sorts places into what Terminal reads and what only AMC reaches', () => {
  const r = sortReach([
    { path: '.ssh', exitCode: 0, stderr: '' },
    { path: 'Library/Mail', exitCode: 1, stderr: 'ls: /Users/x/Library/Mail: Operation not permitted' },
    { path: 'Desktop', exitCode: 1, stderr: 'ls: /Users/x/Desktop: Operation not permitted' },
    { path: '.aws', exitCode: 1, stderr: 'ls: /Users/x/.aws: No such file or directory' },
  ], true)
  expect(r.terminal).toEqual(['.ssh'])
  expect(r.amcOnly).toEqual(['Mail', 'Desktop'])
  expect(r.asked).toBe(true)
})
