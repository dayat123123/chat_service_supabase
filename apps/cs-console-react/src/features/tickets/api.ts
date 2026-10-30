import { rpc } from '@/lib/supabase'

import { emptyLists, type SupportTopic, type Ticket, type TicketLists } from './types'

export const ticketsApi = {
  lists: async (): Promise<TicketLists> => ({
    ...emptyLists,
    ...(await rpc<Partial<TicketLists>>('ticket_lists')),
  }),
  search: (query: string) => rpc<Ticket[]>('search_tickets', { p_query: query }),
  detail: (ticketId: string) => rpc<Ticket>('ticket_detail', { p_ticket_id: ticketId }),
  claim: (ticketId: string) => rpc<Ticket>('claim_ticket', { p_ticket_id: ticketId }),
  release: (ticket: Ticket, reason: string) =>
    rpc<Ticket>('release_ticket', { p_ticket_id: ticket.id, p_reason: reason, p_version: ticket.version }),
  requestTransfer: (ticket: Ticket, toAgentId: string, note: string) =>
    rpc<unknown>('request_transfer', {
      p_ticket_id: ticket.id,
      p_to_agent_id: toAgentId,
      p_note: note,
      p_version: ticket.version,
    }),
  respondTransfer: (transferId: string, accept: boolean, reason?: string) =>
    rpc<Ticket>('respond_transfer', {
      p_transfer_id: transferId,
      p_accept: accept,
      p_reason: reason || undefined,
    }),
  cancelTransfer: (transferId: string) => rpc<null>('cancel_transfer', { p_transfer_id: transferId }),
  waitCustomer: (ticket: Ticket) =>
    rpc<Ticket>('wait_customer', { p_ticket_id: ticket.id, p_version: ticket.version }),
  resolve: (ticket: Ticket, outcome: string, summary: string) =>
    rpc<Ticket>('resolve_ticket', {
      p_ticket_id: ticket.id,
      p_outcome: outcome,
      p_summary: summary,
      p_tags: [],
      p_version: ticket.version,
    }),
  setPriority: (ticket: Ticket, priority: string) =>
    rpc<Ticket>('set_ticket_priority', {
      p_ticket_id: ticket.id,
      p_priority: priority,
      p_version: ticket.version,
    }),
  join: (ticketId: string) => rpc<Ticket>('join_ticket', { p_ticket_id: ticketId }),
  reassign: (ticketId: string, toAgentId: string, reason: string) =>
    rpc<Ticket>('reassign_ticket', { p_ticket_id: ticketId, p_to_agent_id: toAgentId, p_reason: reason }),
  topics: (language: string) => rpc<SupportTopic[]>('topics', { p_language: language }),
}
