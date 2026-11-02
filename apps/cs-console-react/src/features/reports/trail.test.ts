import { describe, expect, it } from 'vitest'

import { closeReason, customerLabel, readableEventData, trailSummary } from './trail'
import type { TrailTicket } from './types'

function ticket(overrides: Partial<TrailTicket>): TrailTicket {
  return {
    id: 't',
    ticket_number: 'CS-20261102-0001',
    topic: 'account',
    topic_name: 'Akun',
    status: 'closed',
    priority: 'P3',
    flags: [],
    outcome: 'answered',
    close_reason: null,
    agent: 'Rina',
    created_at: '2026-11-02T03:00:00.000Z',
    first_claimed_at: null,
    first_response_at: null,
    resolved_at: null,
    closed_at: null,
    claim_minutes: null,
    first_response_minutes: null,
    resolution_minutes: null,
    rating: null,
    rating_comment: null,
    rated_at: null,
    reopened: 0,
    transfers: 0,
    events: [],
    ...overrides,
  }
}

describe('closeReason', () => {
  it('maps known reasons and folds unknown ones into other', () => {
    expect(closeReason('rated')).toBe('rated')
    expect(closeReason('reopen_window_passed')).toBe('reopen_window_passed')
    expect(closeReason('agent_disabled')).toBe('other')
    expect(closeReason(null)).toBeNull()
  })
})

describe('customerLabel', () => {
  it('falls back to the username', () => {
    expect(customerLabel({ display_name: null, username: 'budi' })).toBe('budi')
    expect(customerLabel({ display_name: '', username: null })).toBe('–')
  })
})

describe('trailSummary', () => {
  it('averages only known values and splits closures', () => {
    expect(
      trailSummary([
        ticket({ first_response_minutes: 2, resolution_minutes: 30, rating: 5, close_reason: 'rated' }),
        ticket({ first_response_minutes: 5, rating: 4, close_reason: 'reopen_window_passed' }),
        ticket({ status: 'open' }),
      ]),
    ).toEqual({
      tickets: 3,
      avgFirstResponse: 3.5,
      avgResolution: 30,
      avgRating: 4.5,
      ratings: 2,
      closedUnrated: 1,
    })
    expect(trailSummary([]).avgRating).toBeNull()
  })
})

describe('readableEventData', () => {
  it('drops raw ids so the trail stays readable', () => {
    expect(
      readableEventData({ agent_id: '5e000000-0000-4000-8000-0000000000d1', status: 'claimed', auto: true }),
    ).toEqual({ status: 'claimed', auto: true })
  })
})
