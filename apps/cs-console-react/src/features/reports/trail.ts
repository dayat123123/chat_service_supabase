import type { CustomerReport, TrailTicket } from './types'

export const closeReasons = ['rated', 'reopen_window_passed', 'customer', 'superseded'] as const

export type CloseReason = (typeof closeReasons)[number] | 'other'

export function closeReason(reason: string | null): CloseReason | null {
  if (!reason) return null
  return (closeReasons as readonly string[]).includes(reason) ? (reason as CloseReason) : 'other'
}

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

export function readableEventData(data: Record<string, unknown>) {
  return Object.fromEntries(
    Object.entries(data).filter(([, value]) => !(typeof value === 'string' && uuid.test(value))),
  )
}

export function customerLabel(customer: Pick<CustomerReport, 'display_name' | 'username'>) {
  return customer.display_name || customer.username || '–'
}

function average(values: (number | null)[]) {
  const known = values.filter((value): value is number => value !== null)
  if (known.length === 0) return null
  return Math.round((known.reduce((sum, value) => sum + value, 0) / known.length) * 10) / 10
}

export function trailSummary(tickets: TrailTicket[]) {
  const ratings = tickets.map((ticket) => ticket.rating).filter((value): value is number => value !== null)
  return {
    tickets: tickets.length,
    avgFirstResponse: average(tickets.map((ticket) => ticket.first_response_minutes)),
    avgResolution: average(tickets.map((ticket) => ticket.resolution_minutes)),
    avgRating:
      ratings.length === 0
        ? null
        : Math.round((ratings.reduce((sum, value) => sum + value, 0) / ratings.length) * 100) / 100,
    ratings: ratings.length,
    closedUnrated: tickets.filter((ticket) => ticket.close_reason === 'reopen_window_passed').length,
  }
}
