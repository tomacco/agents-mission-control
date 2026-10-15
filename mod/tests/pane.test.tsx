import { expect, test } from 'claude-code/testing'

import { ago, newestFirst } from '../hooks/format'
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
  expect(docked).toContain('no access')
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
