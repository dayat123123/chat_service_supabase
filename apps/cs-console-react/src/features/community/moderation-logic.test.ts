import { describe, expect, it } from 'vitest'

import {
  appealBlock,
  canEditHistory,
  communityTabsFor,
  evidenceIds,
  evidenceNumber,
  hasZeroTolerance,
  moderationQueuesFor,
  scorePercent,
  slowModeProblem,
  topScores,
} from './logic'
import type { Appeal, Sanction } from './types'

function appeal(overrides: Partial<Appeal> = {}): Appeal {
  return {
    id: 'appeal-1',
    status: 'pending',
    target_type: 'post',
    target_id: 'post-1',
    reason: 'Postingan saya bukan promosi, hanya analisis.',
    created_at: '2026-11-03T02:00:00.000Z',
    decided_at: null,
    decision_note: null,
    user: { id: 'u-1', username: 'sari_invest', display_name: 'Sari', avatar_url: null, banned: false },
    target: { state: 'hidden', excerpt: 'Analisis BBCA', decided_at: '2026-11-02T02:00:00.000Z' },
    original_decider: { id: 'me', name: 'Nadia' },
    decided_by: null,
    can_decide: false,
    ...overrides,
  }
}

describe('permission-gated community tabs and queues', () => {
  it('adds the stock room tab for moderators only', () => {
    expect(communityTabsFor(['community.moderate'])).toEqual(['moderation', 'rooms'])
    expect(communityTabsFor(['community.sanction'])).toEqual(['moderation'])
  })

  it('shows each moderation queue only to the permission that can act on it', () => {
    expect(moderationQueuesFor(['community.moderate'])).toEqual([
      'reports',
      'held',
      'media',
      'alerts',
      'appeals',
    ])
    expect(moderationQueuesFor(['community.sanction'])).toEqual(['reports', 'appeals'])
    expect(moderationQueuesFor(['community.post'])).toEqual([])
  })

  it('offers edit history for posts and comments to moderators', () => {
    expect(canEditHistory(['community.moderate'], 'post')).toBe(true)
    expect(canEditHistory(['community.moderate'], 'message')).toBe(false)
    expect(canEditHistory(['community.sanction'], 'comment')).toBe(false)
  })
})

describe('appealBlock', () => {
  it('explains why a pending appeal cannot be decided', () => {
    expect(appealBlock(appeal(), 'me', ['community.moderate'])).toBe('conflict')
    expect(appealBlock(appeal({ target_type: 'sanction' }), 'me', ['community.moderate'])).toBe(
      'needSanction',
    )
    expect(appealBlock(appeal({ original_decider: null }), 'me', ['community.sanction'])).toBe('needModerate')
  })

  it('returns nothing when the appeal can be decided or is closed', () => {
    expect(appealBlock(appeal({ can_decide: true }), 'me', ['community.moderate'])).toBeNull()
    expect(appealBlock(appeal({ status: 'accepted' }), 'me', ['community.moderate'])).toBeNull()
  })
})

describe('slowModeProblem', () => {
  const now = new Date('2026-11-03T03:00:00.000Z')

  it('accepts off, permanent, and future end times within 30 days', () => {
    expect(slowModeProblem(0, '', now)).toBeNull()
    expect(slowModeProblem(30, '', now)).toBeNull()
    expect(slowModeProblem(30, '2026-11-03T12:00', now)).toBeNull()
  })

  it('rejects invalid seconds and end times', () => {
    expect(slowModeProblem(3601, '', now)).toBe('seconds')
    expect(slowModeProblem(Number.NaN, '', now)).toBe('seconds')
    expect(slowModeProblem(30, '2026-11-03T09:00', now)).toBe('untilPast')
    expect(slowModeProblem(30, '2026-12-10T09:00', now)).toBe('untilFar')
    expect(slowModeProblem(30, 'besok', now)).toBe('untilFormat')
  })
})

describe('zero tolerance and evidence helpers', () => {
  const sanction = (overrides: Partial<Sanction>): Sanction => ({
    id: 's-1',
    kind: 'ban',
    category: null,
    reason: 'Spam',
    starts_at: '2026-11-01T00:00:00.000Z',
    ends_at: null,
    created_at: '2026-11-01T00:00:00.000Z',
    created_by: 'Nadia',
    revoked_at: null,
    revoke_reason: null,
    active: true,
    ...overrides,
  })

  it('detects an active zero tolerance sanction', () => {
    expect(hasZeroTolerance({ sanctions: [sanction({})] })).toBe(false)
    expect(hasZeroTolerance({ sanctions: [sanction({ category: 'zero_tolerance' })] })).toBe(true)
    expect(hasZeroTolerance({ sanctions: [sanction({ category: 'zero_tolerance', active: false })] })).toBe(
      false,
    )
  })

  it('reads alert evidence and classifier scores defensively', () => {
    expect(evidenceNumber({ mentions_last_hour: 42 }, 'mentions_last_hour')).toBe(42)
    expect(evidenceNumber({ hourly_average: '3.5' }, 'hourly_average')).toBe(3.5)
    expect(evidenceNumber({}, 'authors')).toBeNull()
    expect(evidenceIds({ post_ids: ['a', 2, 'b'] }, 'post_ids')).toEqual(['a', 'b'])
    expect(scorePercent(0.9234)).toBe(92.3)
    expect(topScores({ porn: 0.2, sexy: 0.7, neutral: 0.1 }, 2)).toEqual([
      ['sexy', 0.7],
      ['porn', 0.2],
    ])
  })
})
