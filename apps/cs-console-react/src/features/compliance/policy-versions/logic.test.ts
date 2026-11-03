import { describe, expect, it } from 'vitest'

import {
  countDelta,
  diffEntries,
  hiddenItems,
  objectValue,
  outcomeShift,
  percentText,
  reasonProblem,
  scalarText,
  settingLabel,
  thresholdParts,
  windowsText,
} from './logic'

describe('diffEntries', () => {
  it('orders sections like the policy and fills missing items', () => {
    const entries = diffEntries({
      total: 3,
      sections: {
        settings: { added: 0, removed: 0, changed: 1 },
        banned_words: {
          added: 1,
          removed: 1,
          changed: 0,
          items: [{ key: 'judol', op: 'added', to: 'block' }],
        },
      },
    })
    expect(entries.map((entry) => entry.section)).toEqual(['banned_words', 'settings'])
    expect(entries[1]?.items).toEqual([])
    expect(hiddenItems(entries[0]!)).toBe(1)
    expect(hiddenItems(entries[1]!)).toBe(1)
  })

  it('returns nothing for an empty diff', () => {
    expect(diffEntries({ total: 0, sections: {} })).toEqual([])
  })
})

describe('reasonProblem', () => {
  it('requires 5–500 characters after trimming', () => {
    expect(reasonProblem('  abc  ')).toBe('short')
    expect(reasonProblem('Blokir judi')).toBeNull()
    expect(reasonProblem('x'.repeat(501))).toBe('long')
    expect(reasonProblem('x'.repeat(500))).toBeNull()
  })
})

describe('outcomeShift', () => {
  it('compares action severity', () => {
    expect(outcomeShift('allow', 'block')).toBe('stricter')
    expect(outcomeShift('hold', 'censor')).toBe('looser')
    expect(outcomeShift('hold', 'hold')).toBe('same')
  })

  it('formats count deltas with a sign', () => {
    expect(countDelta(3, 5)).toBe('+2')
    expect(countDelta(5, 3)).toBe('-2')
    expect(countDelta(4, 4)).toBe('±0')
  })
})

describe('setting labels and values', () => {
  it('maps known policy settings', () => {
    expect(settingLabel('manipulation.spike_factor')).toEqual({
      kind: 'number',
      id: 'spikeFactor',
      percent: false,
    })
    expect(settingLabel('manipulation.similarity')).toEqual({
      kind: 'number',
      id: 'similarity',
      percent: true,
    })
    expect(settingLabel('manipulation.auto_slow_mode')).toEqual({ kind: 'autoSlow' })
    expect(settingLabel('manipulation.auto_hold_similar')).toEqual({ kind: 'autoHold' })
    expect(settingLabel('rooms.busy_windows')).toEqual({ kind: 'windows' })
    expect(settingLabel('safety.new_account_days')).toEqual({ kind: 'newAccount' })
    expect(settingLabel('manipulation.future_knob')).toEqual({ kind: 'raw' })
  })

  it('formats percents, windows, and scalars', () => {
    expect(percentText(0.855)).toBe('85.5%')
    expect(percentText('x')).toBe('–')
    expect(
      windowsText([
        ['09:00', '09:30'],
        ['15:30', '16:00'],
      ]),
    ).toBe('09:00–09:30, 15:30–16:00')
    expect(windowsText([])).toBe('–')
    expect(scalarText(null)).toBe('–')
    expect(scalarText(3)).toBe('3')
    expect(scalarText(true)).toBe('true')
    expect(scalarText({ a: 1 })).toBe('{"a":1}')
  })

  it('splits image thresholds into hold and block parts', () => {
    expect(thresholdParts({ hold: 0.6, block: 0.95 })).toEqual({ hold: '60%', block: '95%' })
    expect(thresholdParts({ hold: 0.85 })).toEqual({ hold: '85%', block: null })
    expect(thresholdParts(null)).toEqual({ hold: null, block: null })
    expect(objectValue(['x'])).toEqual({})
  })
})
