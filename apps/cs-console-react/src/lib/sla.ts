export type WaitTone = 'ok' | 'warn' | 'late'

export function waitTone(minutes: number, warn: number, late: number): WaitTone {
  if (minutes < warn) return 'ok'
  if (minutes < late) return 'warn'
  return 'late'
}
