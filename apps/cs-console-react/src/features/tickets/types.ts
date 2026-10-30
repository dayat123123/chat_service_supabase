import type { AgentStatus } from '@/features/presence/types'

export type TicketStatus = 'open' | 'claimed' | 'waiting_customer' | 'resolved' | 'closed'

export const ticketPriorities = ['P1', 'P2', 'P3', 'P4'] as const
export const ticketFlags = ['complaint', 'fraud', 'vip'] as const

export type TicketCustomer = {
  id: string
  display_name: string | null
  username: string | null
  deleted?: boolean
}
export type TicketOwner = { id: string; display_name: string; agent_code: string | null; status: AgentStatus }

export type PendingTransfer = {
  id: string
  from_id: string | null
  from_name: string | null
  to_id: string | null
  to_name: string | null
  note: string | null
  expires_at: string | null
}

export type TicketEventItem = {
  type: string
  actor_type: string | null
  actor_name: string | null
  data: Record<string, unknown>
  created_at: string
}

export type Ticket = {
  id: string
  ticket_number: string
  room_id: string
  status: TicketStatus
  version: number
  topic: string
  priority: string
  flags: string[]
  language: string
  customer: TicketCustomer | null
  owner: TicketOwner | null
  is_mine: boolean
  queued_at: string | null
  created_at: string | null
  claimed_at: string | null
  first_response_at: string | null
  last_customer_message_at: string | null
  last_agent_message_at: string | null
  resolved_at: string | null
  closed_at: string | null
  outcome: string | null
  resolution_summary: string | null
  returned_reason: string | null
  complaint_received_at: string | null
  complaint_due_at: string | null
  rating: number | null
  rating_comment: string | null
  transfer: PendingTransfer | null
  preview: string | null
  unread_count: number
  waiting_since: string | null
  events?: TicketEventItem[]
}

export type TransferRequest = {
  id: string
  note: string | null
  expires_at: string | null
  from_name: string | null
  ticket: Ticket
}

export type OutgoingTransfer = {
  id: string
  ticket_id: string
  expires_at: string | null
  to_name: string | null
}

export type TicketLists = {
  open: Ticket[]
  mine: Ticket[]
  resolved_today: Ticket[]
  all_active: Ticket[]
  transfers_in: TransferRequest[]
  transfers_out: OutgoingTransfer[]
}

export type SupportTopic = { code: string; name: string; help_url: string | null; urgent: boolean }

export type TicketTab = 'open' | 'mine' | 'resolved_today' | 'all_active'

export type TicketFilter = { topic: string | null; priority: string | null; flag: string | null }

export const emptyLists: TicketLists = {
  open: [],
  mine: [],
  resolved_today: [],
  all_active: [],
  transfers_in: [],
  transfers_out: [],
}

export const customerName = (ticket: Pick<Ticket, 'customer'>) =>
  ticket.customer?.display_name?.trim() || ticket.customer?.username || ''
