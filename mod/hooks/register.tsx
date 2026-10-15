import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { Identity, LeaseView, RunView } from '../types'

// Full Disk Access for agents without giving it to Terminal. Agents Mission Control (the menu bar app) holds
// the grant, asks the person with Touch ID before it opens access for a session, and runs the commands as
// its own children. This mod gives the model the tool, shows what is happening beside the transcript, and
// talks to the app over its socket. An agent reaching the socket on its own still meets Touch ID.

const S = { plugin: 'amc' } as const
const color = atom({ ...S, key: 'color' } as const, '')
const identity = atom({ ...S, key: 'identity' } as const, null as Identity | null)
const lease = atom({ ...S, key: 'lease' } as const, null as LeaseView | null)
const runs = atom({ ...S, key: 'runs' } as const, [] as RunView[])

const TOOL = 'privileged_bash'
const PANE = 'amc'
const COLORS = ['#D97757', '#E5484D', '#30A46C', '#3E63DD', '#8E4EC6', '#F76B15', '#12A594', '#D6409F', '#FFC53D']
const DENIED = /Operation not permitted|permission to view it|EPERM/

type Reply = { error?: string; fda?: boolean; exit?: number; log?: string; bytes?: number; sha256?: string; timed_out?: boolean }

// The socket client lives here, so the plugin works when installed alone from the marketplace.
const CLIENT = [
  'import os, socket, sys',
  's = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)',
  'try: s.connect(sys.argv[1])',
  'except OSError as e: print(\'{"error": "Agents Mission Control is not running (%s)"}\' % e.strerror); sys.exit(0)',
  's.sendall(sys.stdin.read().strip().encode() + b"\\n")',
  'buf = b""',
  'while not buf.endswith(b"\\n"):',
  '    c = s.recv(65536)',
  '    if not c: break',
  '    buf += c',
  'sys.stdout.write(buf.decode())',
].join('\n')

async function call($: EngineInterface, req: Record<string, unknown>, timeoutMs = 15000): Promise<Reply> {
  const socket = (await $.env.get('AMC_SOCKET')) || `${await $.env.get('HOME')}/.amc/amc.sock`
  const { stdout } = await $.process.run(['/usr/bin/python3', '-I', '-c', CLIENT, socket], { stdin: JSON.stringify(req), timeoutMs })
  try { return JSON.parse(stdout) } catch { return { error: `no reply from Agents Mission Control: ${stdout.slice(0, 200)}` } }
}

const APPROVAL_MS = 150000  // the app waits up to 2 minutes for Touch ID
const MAX_RUN_S = 585       // $.process.run allows ten minutes; the app's run plus a margin must fit inside

// The app forgets leases when it restarts (macOS relaunches it when Full Disk Access is switched on):
// ask for the session's access again, which shows Touch ID again, then retry.
async function send($: EngineInterface, req: Record<string, unknown>, timeoutMs?: number): Promise<Reply> {
  let r = await call($, req, timeoutMs)
  const l = await read($, lease), who = await read($, identity)
  if (req.op === 'run' && r.error?.includes('no open lease') && l?.scope === 'session' && who) {
    const again = await call($, { op: 'open', ...who, reason: l.reason, paths: l.paths, scope: 'session' }, APPROVAL_MS)
    if (again.error) { await update($, lease, () => null); return again }
    r = await call($, req, timeoutMs)
  }
  return r
}

// Installed in the middle of a session, the plugin misses session.start; the first prompt sets it up instead.
async function setUp($: EngineInterface) {
  if (!(await read($, color))) await update($, color, () => COLORS[Math.floor(Math.random() * COLORS.length)])
  const st = await call($, { op: 'status' })
  if (st.error) $.ui.status('⚠ Agents Mission Control is not running: privileged sessions are off')
  else if (st.fda === false) $.ui.status('⚠ Agents Mission Control has no Full Disk Access yet (asked on first use)')
  await $.tool.register({
    name: TOOL,
    isDeferred: false,
    description:
      'Run a shell command with Full Disk Access, for paths macOS protects from Terminal (Mail, Messages, ' +
      'Safari, other apps\' containers, ~/Library/Group Containers, TCC data). The person approves the first ' +
      'request of the session with Touch ID; every command is logged with its reason. Use it only after a normal ' +
      'Bash or Read call failed with "Operation not permitted", never as a general shell. Read-only commands ' +
      'unless the person asked for a change. Never call the app\'s socket yourself.',
    inputSchema: {
      type: 'object',
      properties: {
        command: { type: 'string', description: 'The zsh command to run (pipefail is on).' },
        reason: { type: 'string', description: 'Why this access is needed, one sentence the person will read.' },
        paths: { type: 'array', items: { type: 'string' }, description: 'The protected paths it touches.' },
        agent: { type: 'string', description: 'Your agent name (first call pins it for the session).' },
        subtitle: { type: 'string', description: 'Short context of this session, up to 8 words (pinned on first call).' },
        cwd: { type: 'string' },
        timeout_seconds: { type: 'number', description: 'Default 120, at most 585.' },
      },
      required: ['command', 'reason', 'paths', 'agent', 'subtitle'],
    },
  })
}

// macOS has no prompt for Full Disk Access: the app opens the settings pane and shows itself in Finder,
// and this waits for the switch so the agent's request carries on by itself.
async function waitForAccess($: EngineInterface): Promise<boolean> {
  for (let i = 0; i < 150; i++) {
    if ((await call($, { op: 'status' })).fda === true) return true
    await $.process.run(['/bin/sleep', '2'])
  }
  return false
}

export const register: Register = on => {
  let isSetUp = false
  on('session.start', async ($, e, next) => {
    const started = await next(e)
    await setUp($); isSetUp = true
    return started
  })
  on('prompt.submit', async ($, e, next) => {
    if (!isSetUp) { isSetUp = true; await setUp($) }
    return next(e)
  })

  on('tool.call', { tool: `mcp__amc__${TOOL}` }, async ($, e: any) => {
    const st = await call($, { op: 'status' })
    if (st.error) return { deny: `amc: ${st.error}. Tell the person to install or start Agents Mission Control.` }
    let who = await read($, identity)
    if (!who) {
      who = { agent: String(e.agent).slice(0, 40), subtitle: String(e.subtitle).slice(0, 80) }
      await update($, identity, () => who)
    }
    const paths: string[] = Array.isArray(e.paths) ? e.paths.map(String) : []

    if (st.fda === false) {
      let answer = 'Not now'
      try {
        answer = await $.ui.ask(
          `${who.agent} (${who.subtitle}) asks for Full Disk Access (${e.reason}), but Agents Mission Control does not have it yet. ` +
          'Open System Settings and Finder so you can switch it on?',
          { header: 'Disk access', options: ['Open settings, then allow for this session', 'Not now'] },
        )
      } catch { /* dismissed or headless */ }
      if (!answer.startsWith('Open settings')) {
        return { deny: 'Agents Mission Control has no Full Disk Access and the person chose not to grant it now. Continue without it.' }
      }
      await call($, { op: 'grant' })
      $.ui.status('🔒 waiting for Full Disk Access: drag AgentsMissionControl.app into the list and switch it on')
      if (!(await waitForAccess($))) {
        return { deny: 'Full Disk Access was not switched on within 5 minutes. Ask the person to finish it in System Settings, then retry.' }
      }
    }

    // The app asks the person with Touch ID (or their password); that is the only approval.
    if (!(await read($, lease))) {
      $.ui.status(`🔒 ${who.agent} asks for Full Disk Access: confirm with Touch ID`)
      const opened = await call($, { op: 'open', ...who, reason: e.reason, paths, scope: 'session' }, APPROVAL_MS)
      if (opened.error) {
        $.ui.status(undefined)
        return { deny: `Full Disk Access not granted: ${opened.error}. Do not retry unless the person asks; continue without it.` }
      }
      await update($, lease, () => ({ scope: 'session', reason: String(e.reason), paths, since: new Date().toISOString() }))
    }

    const opened = await $.ui.open({ id: PANE, title: 'Privileged', columns: 36 })
    const id = `r${Date.now().toString(36)}${Math.random().toString(36).slice(2, 6)}`
    const run: RunView = { id, command: String(e.command), reason: String(e.reason), exit: null, tail: [] }
    await update($, runs, list => [...list, run].slice(-20))
    $.ui.status(`🔒 ${who.agent}: privileged run${opened.isPlaced ? '' : ` (${e.command.slice(0, 50)})`}`)

    // Live output for the pane while the app runs the command.
    const sock = (await $.env.get('AMC_SOCKET')) || `${await $.env.get('HOME')}/.amc/amc.sock`
    const live = $.process.spawn({ argv: ['/usr/bin/tail', '-n', '+1', '-F', sock.replace(/amc\.sock$/, `runs/${id}.log`)] })
    void (async () => {
      try {
        for await (const piece of live) {
          if (!('text' in piece)) break
          const lines = String(piece.text).split('\n').filter(Boolean)
          await update($, runs, list => list.map(r => (r.id === id ? { ...r, tail: [...r.tail, ...lines].slice(-12) } : r)))
        }
      } catch { /* tail ended */ }
    })()

    const timeout = Math.min(Math.max(Number(e.timeout_seconds) || 120, 1), MAX_RUN_S)
    let r: Reply
    try {
      r = await send($, { op: 'run', run_id: id, command: e.command, reason: e.reason, cwd: e.cwd, paths, timeout },
                     (timeout + 15) * 1000)
    } catch (err) {
      r = { error: `the call to the app failed: ${String(err).slice(0, 200)}` }
    }
    await live.return?.(undefined as never)
    await update($, runs, list => list.map(x => (x.id === id ? { ...x, exit: r.exit ?? -1 } : x)))
    if ((await read($, lease))?.scope === 'once') await update($, lease, () => null)
    $.ui.status(`🔒 ${who.agent}: privileged session`)
    if (r.error) return { deny: `amc: ${r.error}` }

    const out = await $.process.run(['/bin/cat', r.log!])
    const text = out.stdout.length > 30000 ? out.stdout.slice(0, 30000) + `\n[truncated: ${r.bytes} bytes in ${r.log}]` : out.stdout
    return { result: `exit ${r.exit}${r.timed_out ? ' (timed out)' : ''}\n${text}` }
  }).catch(($, e, next) => ({
    // A hook that throws is skipped and the model reads only "no hook answered": say what went wrong instead.
    deny: `amc: the privileged_bash handler failed (${String(next.error?.cause ?? next.error ?? 'unknown').slice(0, 200)}). Tell the person; do not work around it.`,
  }))

  // Point the model at the privileged tool when Terminal's lack of Full Disk Access is the cause.
  const hint = `This failed because Terminal has no Full Disk Access. If the access is needed, retry with mcp__amc__${TOOL} and a reason.`
  on('tool.call', { tool: /^(Read|Bash)$/ }, async ($, e, next) => {
    const ran = await next(e)
    return ran.deny === undefined && DENIED.test(JSON.stringify(ran.result ?? '')) ? { ...ran, context: [...(ran.context ?? []), hint] } : ran
  })

  on('session.end', async ($, e, next) => {
    if (await read($, lease)) await call($, { op: 'end' })
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
