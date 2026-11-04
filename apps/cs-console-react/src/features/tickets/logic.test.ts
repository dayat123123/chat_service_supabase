import { describe, expect, it } from 'vitest'

import { ticketFixture } from '@/test/fixtures'

import {
  assignmentAlerts,
  claimedByOther,
  currentTab,
  findTicket,
  newerActiveTicket,
  isFiltered,
  matchesFilter,
  noFilter,
  ticketTabs,
  unreadMine,
  visibleTickets,
  withoutTicket,
} from './logic'
import { emptyLists } from './types'

const p1 = ticketFixture({
  id: 'p1',
  priority: 'P1',
  topic: 'deposit',
  flags: ['fraud'],
  waiting_since: '2026-10-30T02:10:00Z',
})
const p3old = ticketFixture({
  id: 'p3old',
  priority: 'P3',
  topic: 'order',
  waiting_since: '2026-10-30T01:00:00Z',
})
const p3new = ticketFixture({
  id: 'p3new',
  priority: 'P3',
  topic: 'order',
  waiting_since: '2026-10-30T02:30:00Z',
})

describe('ticket filters', () => {
  it('matches topic, priority and flag together', () => {
    expect(isFiltered(noFilter)).toBe(false)
    expect(matchesFilter(p1, { topic: 'deposit', priority: 'P1', flag: 'fraud', label: null })).toBe(true)
    expect(matchesFilter(p1, { topic: 'order', priority: null, flag: null, label: null })).toBe(false)
    expect(matchesFilter(p3old, { topic: null, priority: null, flag: 'vip', label: null })).toBe(false)
  })

  it('sorts open tickets by priority then longest wait', () => {
    const lists = { ...emptyLists, open: [p3new, p1, p3old] }
    expect(visibleTickets(lists, 'open', noFilter, null).map((ticket) => ticket.id)).toEqual([
      'p1',
      'p3old',
      'p3new',
    ])
    expect(
      visibleTickets(lists, 'open', { topic: 'order', priority: null, flag: null, label: null }, null).map(
        (ticket) => ticket.id,
      ),
    ).toEqual(['p3old', 'p3new'])
  })

  it('keeps search results in server order', () => {
    expect(visibleTickets(emptyLists, 'open', noFilter, [p3new, p1]).map((ticket) => ticket.id)).toEqual([
      'p3new',
      'p1',
    ])
  })
})

describe('ticket tabs per role', () => {
  it('gives agents their own tabs and Super Admins watching all active tickets', () => {
    expect(ticketTabs({ roles: ['cs_agent'] })).toEqual(['open', 'mine', 'resolved_today'])
    expect(ticketTabs({ roles: ['cs_agent', 'cs_super_admin'] })).toEqual([
      'open',
      'mine',
      'resolved_today',
      'all_active',
    ])
    expect(ticketTabs({ roles: ['cs_super_admin'] })).toEqual(['all_active', 'open'])
    expect(ticketTabs({ roles: ['compliance'] })).toEqual([])
  })

  it('falls back to the first tab of the role when none or an unavailable tab is chosen', () => {
    const monitor = ticketTabs({ roles: ['cs_super_admin'] })
    expect(currentTab(monitor, null)).toBe('all_active')
    expect(currentTab(monitor, 'mine')).toBe('all_active')
    expect(currentTab(monitor, 'open')).toBe('open')
    expect(currentTab(ticketTabs({ roles: ['cs_agent'] }), null)).toBe('open')
  })
})

describe('ticket list updates from realtime', () => {
  it('detects a claim by another agent but not by me', () => {
    const event = {
      type: 'ticket' as const,
      event: 'ticket_claimed',
      ticketId: 'p1',
      ownerId: 'other',
      ownerName: 'Sari',
    }
    expect(claimedByOther(event, 'me')).toEqual({ ticketId: 'p1', name: 'Sari' })
    expect(claimedByOther({ ...event, ownerId: 'me' }, 'me')).toBeNull()
    expect(claimedByOther({ ...event, event: 'ticket_released' }, 'me')).toBeNull()
  })

  it('alerts once per automatic assignment to me, even when it arrives on two channels', () => {
    const assigned = assignmentAlerts('me')
    const event = {
      type: 'ticket' as const,
      event: 'ticket_assigned',
      ticketId: 'p1',
      ticketNumber: 'CS-20261031-0042',
      ownerId: 'me',
      version: 3,
    }
    expect(assigned(event)).toEqual({ ticketId: 'p1', ticketNumber: 'CS-20261031-0042' })
    expect(assigned(event)).toBeNull()
    expect(assigned({ ...event, version: 7 })).toEqual({ ticketId: 'p1', ticketNumber: 'CS-20261031-0042' })
    expect(assigned({ ...event, ticketId: 'p2', ownerId: 'other' })).toBeNull()
    expect(assigned({ ...event, ticketId: 'p3', event: 'ticket_claimed' })).toBeNull()
  })

  it('removes a claimed ticket from the open list only', () => {
    const lists = { ...emptyLists, open: [p1, p3old], mine: [p3new] }
    const next = withoutTicket(lists, 'p1')
    expect(next.open.map((ticket) => ticket.id)).toEqual(['p3old'])
    expect(next.mine).toBe(lists.mine)
  })

  it('points a finished ticket to the active ticket in the same chat', () => {
    const closed = ticketFixture({ id: 'old', status: 'closed', room_id: 'room-1' })
    const active = ticketFixture({ id: 'new', status: 'claimed', room_id: 'room-1' })
    const otherRoom = ticketFixture({ id: 'other', status: 'claimed', room_id: 'room-2' })
    const lists = { ...emptyLists, mine: [otherRoom, active] }

    expect(newerActiveTicket(lists, closed)?.id).toBe('new')
    expect(newerActiveTicket(lists, { ...closed, status: 'resolved' })?.id).toBe('new')
    expect(newerActiveTicket({ ...emptyLists, open: [{ ...active, status: 'open' }] }, closed)?.id).toBe(
      'new',
    )
    expect(newerActiveTicket(lists, { ...closed, status: 'claimed' })).toBeUndefined()
    expect(newerActiveTicket({ ...emptyLists, mine: [otherRoom] }, closed)).toBeUndefined()
  })

  it('finds tickets in any list and counts unread messages', () => {
    const lists = {
      ...emptyLists,
      mine: [
        { ...p3new, unread_count: 2 },
        { ...p3old, unread_count: 3 },
      ],
      transfers_in: [{ id: 'x', note: null, expires_at: null, from_name: 'Sari', ticket: p1 }],
    }
    expect(findTicket(lists, 'p1')?.id).toBe('p1')
    expect(findTicket(lists, 'missing')).toBeUndefined()
    expect(unreadMine(lists)).toBe(5)
  })
})
