import { describe, expect, it } from 'vitest'

import { analyticsRange, countRows, retentionRows, retentionShade } from './logic'

describe('analyticsRange', () => {
  it('counts the end day in the preset length', () => {
    const today = new Date(2026, 10, 3)
    expect(analyticsRange('week', today)).toEqual({ from: '2026-10-28', to: '2026-11-03' })
    expect(analyticsRange('month', today)).toEqual({ from: '2026-10-05', to: '2026-11-03' })
    expect(analyticsRange('quarter', today)).toEqual({ from: '2026-08-06', to: '2026-11-03' })
  })
})

describe('retentionRows', () => {
  it('places each week in its column and leaves future weeks empty', () => {
    const rows = retentionRows([
      {
        cohort_week: '2026-10-26',
        users: 40,
        weeks: [
          { week: 0, active: 40, pct: 100 },
          { week: 1, active: 12, pct: 30 },
        ],
      },
    ])
    expect(rows[0]?.cells.map((cell) => cell?.pct ?? null)).toEqual([
      100,
      30,
      null,
      null,
      null,
      null,
      null,
      null,
    ])
  })

  it('shades cells by percentage band', () => {
    expect(retentionShade(0)).toBe('bg-transparent')
    expect(retentionShade(5)).toBe('bg-primary/5')
    expect(retentionShade(30)).toBe('bg-primary/20')
    expect(retentionShade(100)).toBe('bg-primary/40')
  })
})

describe('countRows', () => {
  it('sorts counts descending, then by name', () => {
    expect(countRows({ search: 3, feed_open: 9, order_tap: 3 })).toEqual([
      { name: 'feed_open', count: 9 },
      { name: 'order_tap', count: 3 },
      { name: 'search', count: 3 },
    ])
  })
})
