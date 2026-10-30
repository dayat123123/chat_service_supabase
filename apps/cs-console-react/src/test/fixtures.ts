import type { ChatMessage } from '@/features/conversation/types'
import { defaultSettings, type AgentProfile } from '@/features/presence/types'
import type { Ticket } from '@/features/tickets/types'

export const agentFixture: AgentProfile = {
  id: '11111111-1111-4111-8111-111111111111',
  agent_code: 'CS01',
  display_name: 'Rina',
  roles: ['cs_agent'],
  team: 'general',
  languages: ['id'],
  max_active_tickets: 5,
  status: 'online',
  reason: null,
  active_tickets: 1,
  skills: {},
  settings: {
    ...defaultSettings,
    reveal_reasons: { verification: { id: 'Verifikasi nasabah', en: 'Customer verification' } },
    outcomes: { answered: { id: 'Terjawab', en: 'Answered' } },
  },
}

export function ticketFixture(overrides: Partial<Ticket> = {}): Ticket {
  return {
    id: '22222222-2222-4222-8222-222222222222',
    ticket_number: 'CS-000123',
    room_id: '33333333-3333-4333-8333-333333333333',
    status: 'claimed',
    version: 3,
    topic: 'order',
    priority: 'P3',
    flags: [],
    language: 'id',
    customer: { id: '44444444-4444-4444-8444-444444444444', display_name: 'Budi Santoso', username: 'budi' },
    owner: { id: agentFixture.id, display_name: 'Rina', agent_code: 'CS01', status: 'online' },
    is_mine: true,
    queued_at: '2026-10-30T02:00:00.000Z',
    created_at: '2026-10-30T02:00:00.000Z',
    claimed_at: '2026-10-30T02:05:00.000Z',
    first_response_at: null,
    last_customer_message_at: '2026-10-30T02:04:00.000Z',
    last_agent_message_at: null,
    resolved_at: null,
    closed_at: null,
    outcome: null,
    resolution_summary: null,
    returned_reason: null,
    complaint_received_at: null,
    complaint_due_at: null,
    rating: null,
    rating_comment: null,
    transfer: null,
    preview: 'Order saya belum masuk',
    unread_count: 0,
    waiting_since: '2026-10-30T02:04:00.000Z',
    ...overrides,
  }
}

export function messageFixture(overrides: Partial<ChatMessage> = {}): ChatMessage {
  const created = overrides.created_at ?? '2026-10-30T02:04:00.000Z'
  return {
    id: 'm-1',
    room_id: '33333333-3333-4333-8333-333333333333',
    sender_id: '44444444-4444-4444-8444-444444444444',
    sender_username: 'budi',
    sender_display_name: 'Budi Santoso',
    body: 'Halo',
    is_deleted: false,
    reply_to_id: null,
    reply_to_body: null,
    reply_to_sender_username: null,
    attachments: [],
    client_id: null,
    created_at: created,
    cursor: created,
    kind: 'text',
    payload: {},
    session_id: null,
    sender_role: 'customer',
    ...overrides,
  }
}
