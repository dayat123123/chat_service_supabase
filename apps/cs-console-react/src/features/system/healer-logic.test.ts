import { describe, expect, it } from 'vitest'

import { healerOutcome, healerStatus, healerTone, outcomeTone } from './logic'
import type { HealerState } from './types'

const fresh: HealerState = {
  reported_at: '2026-11-04T07:00:00.000Z',
  live: true,
  fresh: true,
  read_error: null,
  version: '0.1.0',
  project: 'olt-social',
  enabled: true,
  started_at: '2026-11-04T06:00:00.000Z',
  checked_at: '2026-11-04T06:59:55.000Z',
  rules: {},
  watched: 19,
  unhealthy: [],
  skip: null,
  gave_up: [],
  error: null,
}

describe('healerStatus', () => {
  it('reads the healer state in order of what matters most', () => {
    expect(healerStatus(null)).toBe('missing')
    expect(healerStatus({ ...fresh, live: false, read_error: 'x' })).toBe('noReport')
    expect(healerStatus({ ...fresh, read_error: 'state file not found' })).toBe('stale')
    expect(healerStatus({ ...fresh, fresh: false })).toBe('stale')
    expect(healerStatus({ ...fresh, error: 'permission denied', enabled: false })).toBe('error')
    expect(healerStatus({ ...fresh, enabled: false })).toBe('reportOnly')
    expect(healerStatus(fresh)).toBe('active')
  })

  it('maps states to tones', () => {
    expect(healerTone('active')).toBe('ok')
    expect(healerTone('reportOnly')).toBe('warn')
    expect(healerTone('stale')).toBe('late')
    expect(healerTone('error')).toBe('late')
    expect(healerTone('missing')).toBe('neutral')
  })
})

describe('healerOutcome', () => {
  it('names what happened to each event', () => {
    expect(healerOutcome({ action: 'restart', result: 'ok' })).toBe('restarted')
    expect(healerOutcome({ action: 'restart', result: 'failed' })).toBe('failed')
    expect(healerOutcome({ action: 'report', result: 'report_only' })).toBe('reportOnly')
    expect(healerOutcome({ action: 'give_up', result: 'gave_up' })).toBe('gaveUp')
    expect(healerOutcome({ action: 'skip', result: 'skipped' })).toBe('skipped')
    expect(outcomeTone('gaveUp')).toBe('late')
    expect(outcomeTone('restarted')).toBe('ok')
  })
})
