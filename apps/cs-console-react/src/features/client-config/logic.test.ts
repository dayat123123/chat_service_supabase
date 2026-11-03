import { describe, expect, it } from 'vitest'

import {
  bannerDraft,
  bannerProblems,
  compareVersions,
  featureRows,
  killReasonValid,
  phraseMatches,
  versionValid,
} from './logic'

describe('featureRows', () => {
  it('lists every known feature in a fixed order and treats a missing one as off', () => {
    const rows = featureRows([
      {
        key: 'analytics',
        enabled: true,
        percentage: 100,
        user_ids: [],
        platforms: [],
        min_app_version: null,
        description: null,
        updated_by: null,
        updated_at: '2026-11-03T01:00:00.000Z',
      },
      {
        key: 'legacy.flag',
        enabled: true,
        percentage: 100,
        user_ids: [],
        platforms: [],
        min_app_version: null,
        description: null,
        updated_by: null,
        updated_at: '2026-11-03T01:00:00.000Z',
      },
    ])
    expect(rows.map((row) => row.key)).toEqual([
      'search',
      'trending',
      'bookmarks',
      'post_edit',
      'message_reactions',
      'share_post_to_chat',
      'notification_prefs',
      'analytics',
    ])
    expect(rows[0]).toEqual({ key: 'search', enabled: false, updated_by: null, updated_at: null })
    expect(rows[7]?.enabled).toBe(true)
  })
})

describe('versionValid', () => {
  it('accepts dotted numbers only', () => {
    expect(versionValid('2.10.0')).toBe(true)
    expect(versionValid('2')).toBe(true)
    expect(versionValid('2.4.1+57')).toBe(false)
    expect(versionValid('v2.4')).toBe(false)
  })
})

describe('kill switch confirmation', () => {
  it('needs 10–500 characters after collapsing spaces', () => {
    expect(killReasonValid('   spam   ')).toBe(false)
    expect(killReasonValid('Spam masif dari bot')).toBe(true)
    expect(killReasonValid('x'.repeat(501))).toBe(false)
  })

  it('matches the confirmation phrase regardless of case and spacing', () => {
    expect(phraseMatches(' matikan ', 'MATIKAN')).toBe(true)
    expect(phraseMatches('turn   off', 'TURN OFF')).toBe(true)
    expect(phraseMatches('MATIKAN!', 'MATIKAN')).toBe(false)
  })
})

describe('banner validation', () => {
  const blank = { startsText: '', endsText: '' }

  it('compares versions per numeric part', () => {
    expect(compareVersions('2.10', '2.9.9')).toBeGreaterThan(0)
    expect(compareVersions('2.4', '2.4.0')).toBe(0)
    expect(compareVersions('1.0.0', '1.0.1')).toBeLessThan(0)
  })

  it('accepts a minimal banner', () => {
    expect(bannerProblems({ ...bannerDraft(null), title: 'Info' }, blank)).toEqual({})
  })

  it('reports every invalid field', () => {
    expect(
      bannerProblems(
        {
          ...bannerDraft(null),
          title: 'x'.repeat(81),
          body: 'y'.repeat(301),
          link_url: 'ftp://olt.example',
          min_app_version: '3.0',
          max_app_version: '2.9',
          priority: 1001,
          starts_at: '2026-11-10T03:00:00.000Z',
          ends_at: '2026-11-10T02:00:00.000Z',
        },
        { startsText: '2026-11-10T10:00', endsText: '2026-11-10T09:00' },
      ),
    ).toEqual({
      title: 'length',
      body: 'length',
      link: 'format',
      maxVersion: 'order',
      priority: 'range',
      ends: 'order',
    })
    expect(bannerProblems({ ...bannerDraft(null), title: ' ' }, blank).title).toBe('required')
    expect(
      bannerProblems({ ...bannerDraft(null), title: 'A', min_app_version: '2.x' }, blank).minVersion,
    ).toBe('format')
    expect(
      bannerProblems({ ...bannerDraft(null), title: 'A' }, { startsText: '2026-13', endsText: '' }),
    ).toEqual({
      starts: 'format',
    })
  })
})
