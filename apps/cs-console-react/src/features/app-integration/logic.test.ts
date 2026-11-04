import { describe, expect, it } from 'vitest'

import { ago, normalizeOverview, prodConfig, shortKey } from './logic'
import type { AppIntegrationOverview } from './types'

describe('app integration logic', () => {
  it('builds config/prod.json for the Flutter app', () => {
    expect(JSON.parse(prodConfig('https://api.olt.test', 'anon'))).toEqual({
      SOCIAL_API_URL: 'https://api.olt.test',
      SOCIAL_ANON_KEY: 'anon',
    })
  })

  it('shortens long keys and keeps short ones', () => {
    expect(shortKey('abc')).toBe('abc')
    expect(shortKey('a'.repeat(12) + 'b'.repeat(40) + 'c'.repeat(6))).toBe(
      `${'a'.repeat(12)}…${'c'.repeat(6)}`,
    )
  })

  it('describes how long ago something happened', () => {
    const now = new Date('2026-11-04T08:00:00Z')
    expect(ago('2026-11-04T07:59:40Z', now)).toEqual({ unit: 'now', count: 0 })
    expect(ago('2026-11-04T07:45:00Z', now)).toEqual({ unit: 'minutes', count: 15 })
    expect(ago('2026-11-04T05:10:00Z', now)).toEqual({ unit: 'hours', count: 2 })
    expect(ago('2026-11-01T08:00:00Z', now)).toEqual({ unit: 'days', count: 3 })
    expect(ago('2026-11-04T08:05:00Z', now)).toEqual({ unit: 'now', count: 0 })
  })

  it('drops unknown warnings and treats an empty instance list as no heartbeat', () => {
    const raw = {
      now: '2026-11-04T08:00:00Z',
      status: 'active',
      warnings: ['dev_key', 'something_new'],
      instances: null,
      last_seen_at: null,
      logins: null,
    } as unknown as AppIntegrationOverview
    expect(normalizeOverview(raw)).toEqual({
      now: '2026-11-04T08:00:00Z',
      status: 'no_heartbeat',
      warnings: ['dev_key'],
      instances: [],
      last_seen_at: null,
      logins: { last_login_at: null, users_24h: 0 },
    })
  })
})
