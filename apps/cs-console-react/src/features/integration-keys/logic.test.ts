import { describe, expect, it } from 'vitest'

import {
  dailySeries,
  deliveryRatio,
  keyDailySeries,
  keyProblems,
  parseCidrs,
  toggleScope,
  validCidr,
} from './logic'
import type { KeyDraft } from './types'

const draft = (overrides: Partial<KeyDraft> = {}): KeyDraft => ({
  name: 'notifEngine produksi',
  scopes: ['notify'],
  official_account_id: null,
  allowed_cidrs: [],
  rate_limit_per_minute: 600,
  enabled: true,
  ...overrides,
})

describe('validCidr', () => {
  it('accepts IPv4 and IPv6 addresses with or without a prefix', () => {
    expect(validCidr('203.0.113.7')).toBe(true)
    expect(validCidr('10.20.0.0/16')).toBe(true)
    expect(validCidr('2001:db8::/32')).toBe(true)
    expect(validCidr('::1')).toBe(true)
  })

  it('rejects malformed addresses and prefixes', () => {
    expect(validCidr('10.20.0.256')).toBe(false)
    expect(validCidr('10.20.0.0/33')).toBe(false)
    expect(validCidr('10.20/16')).toBe(false)
    expect(validCidr('2001:db8::1::2')).toBe(false)
    expect(validCidr('server.local')).toBe(false)
    expect(validCidr('10.0.0.0/8/1')).toBe(false)
  })
})

describe('parseCidrs', () => {
  it('splits on lines, commas and spaces and drops duplicates', () => {
    expect(parseCidrs('10.20.0.0/16\n203.0.113.7, 203.0.113.7  \n\n')).toEqual([
      '10.20.0.0/16',
      '203.0.113.7',
    ])
  })
})

describe('keyProblems', () => {
  it('accepts a complete notify key', () => {
    expect(keyProblems(draft())).toEqual({})
  })

  it('flags each invalid field', () => {
    expect(
      keyProblems(
        draft({
          name: 'ab',
          scopes: [],
          rate_limit_per_minute: 0,
          allowed_cidrs: ['10.0.0.0/40'],
        }),
      ),
    ).toEqual({ name: 'length', scopes: 'required', rate: 'range', cidrs: 'invalid' })
    expect(keyProblems(draft({ name: '   ' })).name).toBe('required')
    expect(keyProblems(draft({ rate_limit_per_minute: 1.5 })).rate).toBe('range')
    expect(keyProblems(draft({ rate_limit_per_minute: 100_001 })).rate).toBe('range')
  })

  it('requires an official account for bot posts and caps the address list', () => {
    expect(keyProblems(draft({ scopes: ['bot_post'] })).official).toBe('required')
    expect(keyProblems(draft({ scopes: ['bot_post'], official_account_id: 'acc-1' }))).toEqual({})
    const many = Array.from({ length: 21 }, (_, i) => `10.0.0.${i}`)
    expect(keyProblems(draft({ allowed_cidrs: many })).cidrs).toBe('tooMany')
  })
})

describe('toggleScope', () => {
  it('keeps scopes ordered and unique', () => {
    expect(toggleScope(['bot_post'], 'notify', true)).toEqual(['notify', 'bot_post'])
    expect(toggleScope(['notify', 'bot_post'], 'notify', false)).toEqual(['bot_post'])
    expect(toggleScope(['notify'], 'notify', true)).toEqual(['notify'])
  })
})

describe('dailySeries', () => {
  it('fills missing days with zeros for a continuous chart', () => {
    const series = dailySeries(
      [{ day: '2026-11-02', received: 4, queued: 3, no_recipient: 1, posts: 0 }],
      '2026-11-01',
      3,
    )
    expect(series.map((row) => [row.day, row.received])).toEqual([
      ['2026-11-01', 0],
      ['2026-11-02', 4],
      ['2026-11-03', 0],
    ])
  })
})

describe('keyDailySeries', () => {
  it('maps the rows of one key onto the same continuous days as the totals', () => {
    const row = {
      day: '2026-11-02',
      received: 5,
      queued: 4,
      devices: 7,
      no_recipient: 1,
      duplicate: 0,
      invalid: 0,
      posts: 2,
      posts_rejected: 0,
    }
    expect(keyDailySeries([row], '2026-11-01', 2)).toEqual([
      { day: '2026-11-01', received: 0, queued: 0, no_recipient: 0, posts: 0 },
      { day: '2026-11-02', received: 5, queued: 4, no_recipient: 1, posts: 2 },
    ])
  })
})

describe('deliveryRatio', () => {
  it('is null without deliveries', () => {
    expect(deliveryRatio(0, 0)).toBeNull()
    expect(deliveryRatio(3, 1)).toBe(0.75)
  })
})
