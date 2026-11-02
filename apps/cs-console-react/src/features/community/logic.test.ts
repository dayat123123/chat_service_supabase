import { describe, expect, it } from 'vitest'

import {
  canCancel,
  canEdit,
  canReview,
  canSubmit,
  cleanStock,
  communityTabsFor,
  fromJakartaInput,
  jakartaInput,
  reviewBlockedByFourEyes,
  staffMediaUrl,
} from './logic'

const maya = { id: 'maya', perms: ['community.post'], fourEyes: true }
const kirana = { id: 'kirana', perms: ['community.post', 'community.publish'], fourEyes: true }
const draft = { status: 'draft', created_by: { id: 'maya' } }
const pending = { status: 'pending', created_by: { id: 'maya' } }

describe('communityTabsFor', () => {
  it('shows only the tabs a permission set can use', () => {
    expect(communityTabsFor(['community.post'])).toEqual(['stream', 'notifications'])
    expect(communityTabsFor(['community.sanction'])).toEqual(['moderation'])
    expect(communityTabsFor(['community.accounts', 'community.publish'])).toEqual([
      'stream',
      'notifications',
      'accounts',
    ])
    expect(communityTabsFor([])).toEqual([])
  })
})

describe('four-eyes review', () => {
  it('lets only another publisher approve a pending post', () => {
    expect(canReview(pending, maya)).toBe(false)
    expect(canReview(pending, kirana)).toBe(true)
    const own = { status: 'pending', created_by: { id: 'kirana' } }
    expect(canReview(own, kirana)).toBe(false)
    expect(reviewBlockedByFourEyes(own, kirana)).toBe(true)
  })

  it('allows publishing your own draft directly when four-eyes is off', () => {
    const own = { status: 'draft', created_by: { id: 'kirana' } }
    expect(canReview(own, kirana)).toBe(false)
    expect(canReview(own, { ...kirana, fourEyes: false })).toBe(true)
  })
})

describe('author actions', () => {
  it('lets the author edit, submit, and cancel their own work only', () => {
    expect(canEdit(draft, maya)).toBe(true)
    expect(canSubmit(draft, maya)).toBe(true)
    expect(canEdit(draft, kirana)).toBe(false)
    expect(canEdit(pending, maya)).toBe(false)
    expect(canCancel(pending, maya)).toBe(true)
    expect(canCancel({ status: 'published', created_by: { id: 'maya' } }, maya)).toBe(false)
    expect(canCancel({ status: 'scheduled', created_by: { id: 'maya' } }, kirana)).toBe(true)
  })
})

describe('helpers', () => {
  it('reads schedule inputs as Jakarta time', () => {
    expect(fromJakartaInput('2026-11-03T09:30')).toBe('2026-11-03T02:30:00.000Z')
    expect(jakartaInput('2026-11-03T02:30:00.000Z')).toBe('2026-11-03T09:30')
    expect(fromJakartaInput('besok')).toBeNull()
  })

  it('serves official avatars from the staff origin', () => {
    expect(
      staffMediaUrl(
        'https://social-api.example/storage/v1/object/public/avatars/a/logo.png',
        'https://social-api.example',
        'https://cs.example',
      ),
    ).toBe('https://cs.example/storage/v1/object/public/avatars/a/logo.png')
    expect(staffMediaUrl(null, undefined, 'https://cs.example')).toBeNull()
  })

  it('normalises stock codes', () => {
    expect(cleanStock(' $bbca ')).toBe('BBCA')
  })
})
