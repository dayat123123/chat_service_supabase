import { describe, expect, it } from 'vitest'

import {
  canCancel,
  canEdit,
  canReview,
  canSubmit,
  cleanStock,
  communityPageTabs,
  communityTabsFor,
  fromJakartaInput,
  parseDays,
  segmentProblem,
  segmentQuery,
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

describe('communityPageTabs', () => {
  it('adds Analitik only for Super Admins, after the tabs their permissions allow', () => {
    expect(communityPageTabs({ roles: ['cs_super_admin'], community_permissions: [] })).toEqual(['analytics'])
    expect(
      communityPageTabs({ roles: ['cs_super_admin'], community_permissions: ['community.moderate'] }),
    ).toEqual(['moderation', 'rooms', 'analytics'])
    expect(communityPageTabs({ roles: ['community'], community_permissions: ['community.post'] })).toEqual([
      'stream',
      'notifications',
    ])
    expect(communityPageTabs({ roles: ['cs_agent'], community_permissions: [] })).toEqual([])
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

describe('campaign segments', () => {
  const input = { audience: 'all' as const, stock: ' $bbca ', days: '30', platform: null, account_id: null }

  it('keeps only the parameter of the chosen segment', () => {
    expect(segmentQuery(input)).toEqual({
      audience: 'all',
      stock: null,
      days: null,
      platform: null,
      account_id: null,
    })
    expect(segmentQuery({ ...input, audience: 'stock' }).stock).toBe('BBCA')
    expect(segmentQuery({ ...input, audience: 'new_users' }).days).toBe(30)
    expect(segmentQuery({ ...input, audience: 'platform', platform: 'ios' }).platform).toBe('ios')
    expect(segmentQuery({ ...input, audience: 'followers', account_id: 'acc-1' }).account_id).toBe('acc-1')
  })

  it('accepts 1 to 365 days only', () => {
    expect(parseDays('1')).toBe(1)
    expect(parseDays(' 365 ')).toBe(365)
    expect(parseDays('0')).toBeNull()
    expect(parseDays('366')).toBeNull()
    expect(parseDays('2.5')).toBeNull()
  })

  it('reports the missing parameter', () => {
    expect(segmentProblem(segmentQuery(input))).toBeNull()
    expect(segmentProblem(segmentQuery({ ...input, audience: 'stock', stock: '1' }))).toBe('stock')
    expect(segmentProblem(segmentQuery({ ...input, audience: 'inactive', days: '' }))).toBe('days')
    expect(segmentProblem(segmentQuery({ ...input, audience: 'platform' }))).toBe('platform')
    expect(segmentProblem(segmentQuery({ ...input, audience: 'followers' }))).toBe('account')
  })
})
