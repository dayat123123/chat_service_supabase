import { describe, expect, it } from 'vitest'

import { presetRange, rangeDays, rangeLabel, rangeProblem } from './range'

const today = new Date(2026, 9, 30)

describe('report ranges', () => {
  it('builds inclusive preset ranges ending today', () => {
    expect(presetRange('today', today)).toEqual({ from: '2026-10-30', to: '2026-10-30' })
    expect(presetRange('week', today)).toEqual({ from: '2026-10-24', to: '2026-10-30' })
    expect(presetRange('month', today)).toEqual({ from: '2026-10-01', to: '2026-10-30' })
    expect(rangeDays(presetRange('week', today))).toBe(7)
  })

  it('accepts up to 93 days and rejects anything else', () => {
    expect(rangeProblem({ from: '2026-07-30', to: '2026-10-30' }, today)).toBeNull()
    expect(rangeProblem({ from: '2026-07-29', to: '2026-10-30' }, today)).toBe('tooLong')
    expect(rangeProblem({ from: '2026-10-30', to: '2026-10-29' }, today)).toBe('order')
    expect(rangeProblem({ from: '2026-10-30', to: '2026-10-31' }, today)).toBe('future')
    expect(rangeProblem({ from: '', to: '2026-10-30' }, today)).toBe('invalid')
    expect(rangeProblem({ from: '2026-02-31', to: '2026-03-01' }, today)).toBe('invalid')
  })

  it('formats single days and spans', () => {
    expect(rangeLabel({ from: '2026-10-30', to: '2026-10-30' })).toBe('30 Okt 2026')
    expect(rangeLabel({ from: '2026-10-24', to: '2026-10-30' })).toBe('24 Okt 2026 – 30 Okt 2026')
  })
})
