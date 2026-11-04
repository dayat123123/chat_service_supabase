import { describe, expect, it } from 'vitest'

import { matchesFilter, noFilter, visibleTickets } from '@/features/tickets/logic'
import { emptyLists } from '@/features/tickets/types'
import { agentFixture, monitorFixture, ticketFixture } from '@/test/fixtures'

import {
  activeLabelCount,
  addableLabels,
  atLabelLimit,
  canEditLabels,
  labelsInLists,
  listsWithLabels,
  moveLabel,
  normalizeLabel,
  reportShares,
} from './logic'
import type { TicketLabel } from './types'

const refund: TicketLabel = { id: 'refund', name: 'Refund', color: 'warning' }
const akun: TicketLabel = { id: 'akun', name: 'Akun terkunci', color: 'danger' }
const vip: TicketLabel = { id: 'vip', name: 'VIP', color: 'info' }

describe('canEditLabels', () => {
  it('lets the agent handling an active ticket and any Super Admin change labels', () => {
    expect(canEditLabels(agentFixture, ticketFixture())).toBe(true)
    expect(canEditLabels(agentFixture, ticketFixture({ status: 'waiting_customer' }))).toBe(true)
    expect(canEditLabels(monitorFixture, ticketFixture({ status: 'resolved' }))).toBe(true)
  })

  it('refuses other agents, queued tickets, and finished tickets for agents', () => {
    const other = ticketFixture({
      owner: { id: 'x', display_name: 'Bima', agent_code: 'CS02', status: 'online' },
    })
    expect(canEditLabels(agentFixture, other)).toBe(false)
    expect(canEditLabels(agentFixture, ticketFixture({ status: 'open', owner: null }))).toBe(false)
    expect(canEditLabels(agentFixture, ticketFixture({ status: 'resolved' }))).toBe(false)
    expect(canEditLabels({ ...agentFixture, roles: ['compliance'] }, ticketFixture())).toBe(false)
  })
})

describe('ticket label helpers', () => {
  it('caps a ticket at five labels and offers only unused ones', () => {
    const five = [refund, akun, vip, { ...vip, id: 'a' }, { ...vip, id: 'b' }]
    expect(atLabelLimit(five)).toBe(true)
    expect(atLabelLimit(five.slice(0, 4))).toBe(false)
    expect(addableLabels([refund, akun, vip], [akun]).map((label) => label.id)).toEqual(['refund', 'vip'])
  })

  it('falls back to the neutral color for unknown values', () => {
    expect(normalizeLabel({ ...refund, color: 'pink' as never }).color).toBe('neutral')
  })

  it('moves a label up or down and ignores moves past the ends', () => {
    expect(moveLabel(['a', 'b', 'c'], 2, -1)).toEqual(['a', 'c', 'b'])
    expect(moveLabel(['a', 'b', 'c'], 0, 1)).toEqual(['b', 'a', 'c'])
    expect(moveLabel(['a', 'b', 'c'], 0, -1)).toEqual(['a', 'b', 'c'])
  })

  it('counts active labels and computes report shares', () => {
    expect(activeLabelCount([{ active: true }, { active: false }, { active: true }])).toBe(2)
    const rows = reportShares({
      from: '2026-11-01',
      to: '2026-11-04',
      total: 4,
      unlabeled: 1,
      labels: [{ ...refund, active: true, count: 3 }],
    })
    expect(rows[0]?.share).toBe(0.75)
  })
})

describe('label filter', () => {
  const first = ticketFixture({ id: 't1', labels: [refund] })
  const second = ticketFixture({ id: 't2', labels: [akun, vip] })
  const third = ticketFixture({ id: 't3' })
  const lists = { ...emptyLists, mine: [first, second, third] }

  it('collects the labels found in the loaded lists for the filter menu', () => {
    expect(labelsInLists(lists).map((label) => label.name)).toEqual(['Akun terkunci', 'Refund', 'VIP'])
  })

  it('keeps only tickets carrying the chosen label', () => {
    expect(matchesFilter(first, { ...noFilter, label: 'refund' })).toBe(true)
    expect(matchesFilter(third, { ...noFilter, label: 'refund' })).toBe(false)
    expect(
      visibleTickets(lists, 'mine', { ...noFilter, label: 'vip' }, null).map((ticket) => ticket.id),
    ).toEqual(['t2'])
  })

  it('updates the labels of one ticket in every list', () => {
    const next = listsWithLabels(lists, 't3', [vip])
    expect(next.mine.find((ticket) => ticket.id === 't3')?.labels).toEqual([vip])
    expect(next.mine.find((ticket) => ticket.id === 't1')?.labels).toEqual([refund])
  })
})
