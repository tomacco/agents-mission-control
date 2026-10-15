export type Identity = { agent: string; subtitle: string }
export type LeaseView = { scope: 'session' | 'once'; reason: string; paths: string[]; since: string }
export type RunView = { id: string; command: string; reason: string; exit: number | null; tail: string[] }

declare module 'claude-code' {
  interface PluginState {
    amc: {
      key: string
      color: string
      identity: Identity | null
      lease: LeaseView | null
      runs: RunView[]
    }
  }
}
