import { describe, expect, it } from 'vitest'

import {
  cleanDomain,
  domainEntry,
  domainProblem,
  manipulationChanges,
  manipulationForm,
  manipulationProblems,
  normalizeTerm,
  parsePercent,
  sameThresholds,
  sortRules,
  termProblem,
  thresholdForm,
  thresholdPayload,
  thresholdProblems,
  thresholdsValid,
} from './logic'

describe('sortRules', () => {
  it('orders categories from the most to the least severe', () => {
    const rule = (category: 'blocked' | 'gambling' | 'other_link' | 'phone') => ({
      category,
      action: 'block' as const,
      scope: 'all' as const,
      updated_at: '2026-11-03T01:00:00.000Z',
      updated_by: null,
    })
    expect(
      sortRules([rule('other_link'), rule('blocked'), rule('phone'), rule('gambling')]).map(
        (item) => item.category,
      ),
    ).toEqual(['gambling', 'blocked', 'phone', 'other_link'])
  })
})

describe('domains', () => {
  it('cleans a pasted link the same way the server does', () => {
    expect(cleanDomain('  HTTPS://www.Contoh-Judi.com:8443/promo?x=1 ')).toBe('contoh-judi.com')
    expect(domainEntry(' Slot88 ', 'keyword')).toBe('slot88')
  })

  it('validates domains and keywords', () => {
    expect(domainProblem('contoh.com', 'domain')).toBeNull()
    expect(domainProblem('contoh', 'domain')).toBe('invalid')
    expect(domainProblem('', 'domain')).toBe('required')
    expect(domainProblem('slot88', 'keyword')).toBeNull()
    expect(domainProblem('ab', 'keyword')).toBe('invalid')
    expect(domainProblem('slot.88', 'keyword')).toBe('invalid')
  })
})

describe('terms', () => {
  it('normalizes and validates allowlist terms and promotion phrases', () => {
    expect(normalizeTerm('  Bandar   SAHAM ')).toBe('bandar saham')
    expect(termProblem('bandar saham', 2)).toBeNull()
    expect(termProblem('vi', 3)).toBe('length')
    expect(termProblem('grup-vip', 3)).toBe('characters')
  })
})

describe('image thresholds', () => {
  const current = {
    porn: { hold: 0.5, block: 0.9 },
    hentai: { hold: 0.6, block: 0.95 },
    sexy: { hold: 0.85 },
  }

  it('shows fractions as percentages and round-trips them', () => {
    const form = thresholdForm(current)
    expect(form.porn).toEqual({ hold: '50', block: '90' })
    expect(form.sexy).toEqual({ hold: '85', block: '' })
    expect(form.neutral).toEqual({ hold: '', block: '' })
    expect(sameThresholds(thresholdPayload(form), current)).toBe(true)
  })

  it('parses percentages with a comma or dot and rejects values outside 0–100', () => {
    expect(parsePercent('92,5')).toBe(92.5)
    expect(parsePercent('')).toBeNull()
    expect(parsePercent('101')).toBe('invalid')
    expect(parsePercent('abc')).toBe('invalid')
  })

  it('requires hold ≤ block and a pornography threshold', () => {
    const form = thresholdForm(current)
    const swapped = { ...form, hentai: { hold: '96', block: '95' } }
    expect(thresholdProblems(swapped).categories.hentai).toBe('order')
    expect(thresholdsValid(thresholdProblems(swapped))).toBe(false)

    const noPorn = { ...form, porn: { hold: '', block: '' } }
    expect(thresholdProblems(noPorn).pornRequired).toBe(true)

    const bad = { ...form, sexy: { hold: '85', block: 'x' } }
    expect(thresholdProblems(bad).categories.sexy).toBe('block')
    expect(thresholdsValid(thresholdProblems(form))).toBe(true)
  })

  it('omits empty categories and converts back to fractions', () => {
    const form = {
      ...thresholdForm(current),
      sexy: { hold: '', block: '' },
      drawings: { hold: '70.25', block: '' },
    }
    expect(thresholdPayload(form)).toEqual({
      porn: { hold: 0.5, block: 0.9 },
      hentai: { hold: 0.6, block: 0.95 },
      drawings: { hold: 0.7025 },
    })
  })
})

describe('manipulation settings', () => {
  const settings = {
    'manipulation.spike_factor': 5,
    'manipulation.spike_min_mentions': 20,
    'manipulation.baseline_days': 7,
    'manipulation.new_account_share': 0.6,
    'manipulation.new_account_min_mentions': 10,
    'manipulation.new_account_age_days': 7,
    'manipulation.similarity': 0.8,
    'manipulation.similar_min_authors': 5,
    'manipulation.similar_window_minutes': 30,
    'manipulation.auto_slow_mode': true,
    'manipulation.auto_slow_mode_seconds': 30,
    'manipulation.auto_slow_mode_minutes': 60,
    'manipulation.auto_hold_similar': true,
    'rooms.busy_slow_mode': 10,
    'rooms.busy_windows': [
      ['08:55', '09:30'],
      ['15:50', '16:15'],
    ],
  }

  it('shows shares as percentages and finds no changes initially', () => {
    const form = manipulationForm(settings)
    expect(form.numbers.newShare).toBe('60')
    expect(form.numbers.similarity).toBe('80')
    expect(form.windows).toEqual([
      { start: '08:55', end: '09:30' },
      { start: '15:50', end: '16:15' },
    ])
    expect(manipulationChanges(settings, form)).toEqual({})
  })

  it('sends only the changed keys in server units', () => {
    const form = manipulationForm(settings)
    form.numbers.newShare = '70'
    form.booleans.autoHold = false
    form.windows = [{ start: '09:00', end: '09:15' }]
    expect(manipulationChanges(settings, form)).toEqual({
      'manipulation.new_account_share': 0.7,
      'manipulation.auto_hold_similar': false,
      'rooms.busy_windows': [['09:00', '09:15']],
    })
  })

  it('flags values outside the server ranges and bad windows', () => {
    const form = manipulationForm(settings)
    form.numbers.spikeFactor = '1'
    form.numbers.baselineDays = '2.5'
    form.numbers.similarity = '20'
    form.windows = [{ start: '10:00', end: '09:00' }]
    const problems = manipulationProblems(form)
    expect(problems.numbers).toEqual(['spikeFactor', 'baselineDays', 'similarity'])
    expect(problems.windows).toEqual([0])
  })
})
