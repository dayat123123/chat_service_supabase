import { isSuperAdmin, worksTickets, type AgentProfile } from '@/features/presence/types'
import type { QueueEvent } from '@/lib/realtime'

import type { Ticket, TicketFilter, TicketLists, TicketTab } from './types'

export const noFilter: TicketFilter = { topic: null, priority: null, flag: null }

export function ticketTabs(agent: Pick<AgentProfile, 'roles'>): TicketTab[] {
  if (!worksTickets(agent)) return isSuperAdmin(agent) ? ['all_active', 'open'] : []
  const tabs: TicketTab[] = ['open', 'mine', 'resolved_today']
  return isSuperAdmin(agent) ? [...tabs, 'all_active'] : tabs
}

export function currentTab(tabs: TicketTab[], chosen: TicketTab | null): TicketTab {
  return chosen !== null && tabs.includes(chosen) ? chosen : (tabs[0] ?? 'open')
}

export function isFiltered(filter: TicketFilter) {
  return filter.topic !== null || filter.priority !== null || filter.flag !== null
}

export function matchesFilter(ticket: Ticket, filter: TicketFilter) {
  return (
    (filter.topic === null || ticket.topic === filter.topic) &&
    (filter.priority === null || ticket.priority === filter.priority) &&
    (filter.flag === null || ticket.flags.includes(filter.flag))
  )
}

export function sortTime(ticket: Ticket) {
  return ticket.waiting_since ?? ticket.queued_at ?? ticket.created_at ?? ''
}

export function byPriorityThenWait(a: Ticket, b: Ticket) {
  const priority = a.priority.localeCompare(b.priority)
  return priority !== 0 ? priority : sortTime(a).localeCompare(sortTime(b))
}

export function tabTickets(lists: TicketLists, tab: TicketTab) {
  return lists[tab]
}

export function visibleTickets(
  lists: TicketLists,
  tab: TicketTab,
  filter: TicketFilter,
  results: Ticket[] | null,
) {
  const source = results ?? tabTickets(lists, tab)
  const filtered = source.filter((ticket) => matchesFilter(ticket, filter))
  if (results !== null || tab === 'resolved_today') return filtered
  return [...filtered].sort(byPriorityThenWait)
}

export function findTicket(lists: TicketLists, ticketId: string): Ticket | undefined {
  for (const list of [lists.mine, lists.open, lists.all_active, lists.resolved_today]) {
    const hit = list.find((ticket) => ticket.id === ticketId)
    if (hit) return hit
  }
  return lists.transfers_in.find((request) => request.ticket.id === ticketId)?.ticket
}

export function withoutTicket(lists: TicketLists, ticketId: string): TicketLists {
  return { ...lists, open: lists.open.filter((ticket) => ticket.id !== ticketId) }
}

export function claimedByOther(event: QueueEvent, meId: string): { ticketId: string; name: string } | null {
  if (event.type !== 'ticket' || event.event !== 'ticket_claimed') return null
  if (!event.ownerId || event.ownerId === meId) return null
  return { ticketId: event.ticketId, name: event.ownerName ?? '' }
}

export function assignmentAlerts(meId: string) {
  const seen = new Set<string>()
  return (event: QueueEvent): { ticketId: string; ticketNumber: string } | null => {
    if (event.type !== 'ticket' || event.event !== 'ticket_assigned' || event.ownerId !== meId) return null
    const key = `${event.ticketId}:${event.version ?? ''}`
    if (seen.has(key)) return null
    seen.add(key)
    return { ticketId: event.ticketId, ticketNumber: event.ticketNumber ?? '' }
  }
}

export function unreadMine(lists: TicketLists) {
  return lists.mine.reduce((total, ticket) => total + ticket.unread_count, 0)
}
