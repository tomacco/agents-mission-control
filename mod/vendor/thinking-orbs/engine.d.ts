// Types for the two functions the plugin uses from the vendored engine.
export type Dot = { x: number; y: number; z: number; r: number; white: number; a?: number }
export type Line = { x1: number; y1: number; x2: number; y2: number; white: number; a?: number; w: number }
export const M: Record<string, (size: number, t: number, opts: unknown) => { dots: Dot[]; lines: Line[] }>
export function r(state: string, size: 64 | 20): { mode: string; speed: number; opts: unknown }
