import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { Identity, LeaseView, RunView } from '../types'

// Full Disk Access for agents without giving it to Terminal. Agents Mission Control (the menu bar app) holds
// the grant and runs approved commands as its own children; this mod asks the person, shows what is
// happening beside the transcript, and talks to the app over ~/.amc/amc.sock through bin/amc-call.
// Approvals live in $.state only, so they never outlive the session.

const S = { plugin: 'amc' } as const
const key = atom({ ...S, key: 'key' } as const, '')
const color = atom({ ...S, key: 'color' } as const, '')
const identity = atom({ ...S, key: 'identity' } as const, null as Identity | null)
const lease = atom({ ...S, key: 'lease' } as const, null as LeaseView | null)
const runs = atom({ ...S, key: 'runs' } as const, [] as RunView[])

const TOOL = 'privileged_bash'
const PANE = 'amc'
const COLORS = ['#D97757', '#E5484D', '#30A46C', '#3E63DD', '#8E4EC6', '#F76B15', '#12A594', '#D6409F', '#FFC53D']
const DENIED = /Operation not permitted|permission to view it|EPERM/

type Reply = { error?: string; key?: string; exit?: number; log?: string; bytes?: number; sha256?: string; timed_out?: boolean }

async function call($: EngineInterface, req: Record<string, unknown>, timeoutMs = 15000): Promise<Reply> {
  const { stdout } = await $.process.run([`${$.plugin.root}/../bin/amc-call`], { stdin: JSON.stringify(req), timeoutMs })
  try { return JSON.parse(stdout) } catch { return { error: `no reply from Agents Mission Control: ${stdout.slice(0, 200)}` } }
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    const started = await next(e)
    if (!(await read($, color))) await update($, color, () => COLORS[Math.floor(Math.random() * COLORS.length)])
    // The key is bound to this Claude Code process by the first caller, so take it before the model can.
    if (!(await read($, key))) {
      const r = await call($, { op: 'register' })
      if (r.key) await update($, key, () => r.key!)
      else $.ui.log(`amc: ${r.error}`, { to: 'debug' })
    }
    await $.tool.register({
      name: TOOL,
      isDeferred: false,
      description:
        'Run a shell command with Full Disk Access, for paths macOS protects from Terminal (Mail, Messages, ' +
        'Safari, other apps\' containers, ~/Library/Group Containers, TCC data). The person approves the first ' +
        'request of the session; every command is logged with its reason. Use it only after a normal Bash or ' +
        'Read call failed with "Operation not permitted", never as a general shell. Read-only commands unless ' +
        'the person asked for a change.',
      inputSchema: {
        type: 'object',
        properties: {
          command: { type: 'string', description: 'The zsh command to run.' },
          reason: { type: 'string', description: 'Why this access is needed, one sentence the person will read.' },
          paths: { type: 'array', items: { type: 'string' }, description: 'The protected paths it touches.' },
          agent: { type: 'string', description: 'Your agent name (first call pins it for the session).' },
          subtitle: { type: 'string', description: 'Short context of this session, up to 8 words (pinned on first call).' },
          cwd: { type: 'string' },
          timeout_seconds: { type: 'number', description: 'Default 120, at most 600.' },
        },
        required: ['command', 'reason', 'paths', 'agent', 'subtitle'],
      },
    })
    return started
  })

  on('tool.call', { tool: `mcp__amc__${TOOL}` }, async ($, e: any) => {
    const sessionKey = await read($, key)
    if (!sessionKey) return { deny: 'amc: this session has no key from Agents Mission Control (is the app running?). Tell the person.' }
    let who = await read($, identity)
    if (!who) {
      who = { agent: String(e.agent).slice(0, 40), subtitle: String(e.subtitle).slice(0, 80) }
      await update($, identity, () => who)
    }
    const paths: string[] = Array.isArray(e.paths) ? e.paths.map(String) : []

    if (!(await read($, lease))) {
      let answer = 'Deny'
      try {
        answer = await $.ui.ask(
          `${who.agent} (${who.subtitle}) asks for Full Disk Access. Reason: ${e.reason} Paths: ${paths.join(', ') || 'not stated'}. Allow?`,
          { header: 'Disk access', options: ['Allow for this session', 'Allow once', 'Deny'] },
        )
      } catch { /* dismissed or headless: deny */ }
      if (answer !== 'Allow for this session' && answer !== 'Allow once') {
        return { deny: 'The person denied Full Disk Access. Do not retry; continue without it or ask them why.' }
      }
      const scope = answer === 'Allow once' ? 'once' : 'session'
      const opened = await call($, { op: 'open', key: sessionKey, ...who, reason: e.reason, paths, scope })
      if (opened.error) return { deny: `amc: ${opened.error}` }
      await update($, lease, () => ({ scope, reason: String(e.reason), paths, since: new Date().toISOString() }))
    }

    const opened = await $.ui.open({ id: PANE, title: 'Privileged', columns: 36 })
    const id = `r${Date.now().toString(36)}${Math.random().toString(36).slice(2, 6)}`
    const run: RunView = { id, command: String(e.command), reason: String(e.reason), exit: null, tail: [] }
    await update($, runs, list => [...list, run].slice(-20))
    $.ui.status(`🔒 ${who.agent}: privileged run${opened.isPlaced ? '' : ` (${e.command.slice(0, 50)})`}`)

    // Live output for the pane while the app runs the command.
    const home = await $.env.get('HOME')
    const live = $.process.spawn({ argv: ['/usr/bin/tail', '-n', '+1', '-F', `${home}/.amc/runs/${id}.log`] })
    void (async () => {
      try {
        for await (const piece of live) {
          if (!('text' in piece)) break
          const lines = String(piece.text).split('\n').filter(Boolean)
          await update($, runs, list => list.map(r => (r.id === id ? { ...r, tail: [...r.tail, ...lines].slice(-12) } : r)))
        }
      } catch { /* tail ended */ }
    })()

    const timeout = Math.min(Math.max(Number(e.timeout_seconds) || 120, 1), 600)
    const r = await call($, { op: 'run', key: sessionKey, run_id: id, command: e.command, reason: e.reason, cwd: e.cwd, paths, timeout },
                         (timeout + 15) * 1000)
    await live.return?.(undefined as never)
    await update($, runs, list => list.map(x => (x.id === id ? { ...x, exit: r.exit ?? -1 } : x)))
    if ((await read($, lease))?.scope === 'once') await update($, lease, () => null)
    $.ui.status(`🔒 ${who.agent}: privileged session`)
    if (r.error) return { deny: `amc: ${r.error}` }

    const out = await $.process.run(['/bin/cat', r.log!])
    const text = out.stdout.length > 30000 ? out.stdout.slice(0, 30000) + `\n[truncated: ${r.bytes} bytes in ${r.log}]` : out.stdout
    return { result: `exit ${r.exit}${r.timed_out ? ' (timed out)' : ''}\n${text}` }
  })

  // Point the model at the privileged tool when Terminal's lack of Full Disk Access is the cause.
  const hint = `This failed because Terminal has no Full Disk Access. If the access is needed, retry with mcp__amc__${TOOL} and a reason.`
  on('tool.call', { tool: /^(Read|Bash)$/ }, async ($, e, next) => {
    const ran = await next(e)
    return ran.deny === undefined && DENIED.test(JSON.stringify(ran.result ?? '')) ? { ...ran, context: [...(ran.context ?? []), hint] } : ran
  })

  on('session.end', async ($, e, next) => {
    const k = await read($, key)
    if (k && (await read($, lease))) await call($, { op: 'end', key: k })
    return next(e)
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e: any) => {
    const { Box, Text } = $.ui.resolve(e)
    const [c, who, l, list] = await Promise.all([read($, color), read($, identity), read($, lease), read($, runs)])
    const narrow = (e.bodyColumns ?? 36) < 30
    return (
      <Box flexDirection="column">
        <Box flexDirection="row">
          <Box flexDirection="column">
            <Text color={c}>{' ▐▛███▜▌'}</Text>
            <Text color={c}>{'▝▜█████▛▘'}</Text>
            <Text color={c}>{'  ▘▘ ▝▝'}</Text>
          </Box>
          <Box flexDirection="column" marginLeft={1}>
            <Text bold>{who?.agent ?? 'agent'}</Text>
            <Text dimColor>{who?.subtitle ?? ''}</Text>
            <Text color={l ? 'warning' : undefined}>{l ? `Full Disk Access · ${l.scope === 'once' ? 'once' : 'this session'}` : 'no access'}</Text>
          </Box>
        </Box>
        {l && !narrow && <Text>Why: {l.reason}</Text>}
        {l && !narrow && l.paths.map(p => <Text dimColor>{p}</Text>)}
        {list.slice(narrow ? -2 : -5).map(r => (
          <Box flexDirection="column" marginTop={1}>
            <Text color={r.exit === null ? 'warning' : r.exit === 0 ? 'success' : 'error'}>
              {r.exit === null ? '…' : r.exit === 0 ? '✓' : `✗ ${r.exit}`} {r.command}
            </Text>
            {!narrow && r.tail.slice(-4).map(t => <Text dimColor>{t}</Text>)}
          </Box>
        ))}
      </Box>
    )
  })
}
