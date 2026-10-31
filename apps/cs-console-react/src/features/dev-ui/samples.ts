import type { ChatMessage, PendingMessage } from '@/features/conversation/types'
import type { AgentNote, HistoryItem } from '@/features/customer/types'
import { defaultSettings, type AgentProfile } from '@/features/presence/types'
import type { Ticket } from '@/features/tickets/types'

export const sampleNow = new Date()

const minutesAgo = (minutes: number) => new Date(sampleNow.getTime() - minutes * 60_000).toISOString()

export const sampleAgent: AgentProfile = {
  id: 'dev-agent',
  agent_code: 'CS-0045',
  display_name: 'Nadia',
  roles: ['cs_agent'],
  team: 'general',
  languages: ['id'],
  max_active_tickets: 5,
  status: 'online',
  reason: null,
  active_tickets: 2,
  skills: {},
  settings: defaultSettings,
}

function ticket(overrides: Partial<Ticket>): Ticket {
  return {
    id: 'dev-ticket',
    ticket_number: 'CS-20261030-0042',
    room_id: 'dev-room',
    status: 'open',
    version: 1,
    topic: 'order',
    priority: 'P3',
    flags: [],
    language: 'id',
    customer: { id: 'dev-customer', display_name: 'Sari Wulandari', username: 'sari_invest' },
    owner: null,
    is_mine: false,
    queued_at: minutesAgo(3),
    created_at: minutesAgo(3),
    claimed_at: null,
    first_response_at: null,
    last_customer_message_at: minutesAgo(3),
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
    preview: 'order saya belum tereksekusi dari tadi',
    unread_count: 2,
    waiting_since: minutesAgo(3),
    ...overrides,
  }
}

export const sampleTickets: { ticket: Ticket; selected?: boolean; claimable?: boolean; topic: string }[] = [
  { ticket: ticket({ id: 't1', priority: 'P2' }), claimable: true, topic: 'Order & Transaksi' },
  {
    ticket: ticket({
      id: 't2',
      priority: 'P1',
      flags: ['fraud'],
      customer: { id: 'c2', display_name: 'Budi Santoso', username: 'budi' },
      preview: 'ada transaksi yang bukan saya lakukan',
      unread_count: 1,
      waiting_since: minutesAgo(9),
      queued_at: minutesAgo(9),
    }),
    claimable: true,
    selected: true,
    topic: 'Keamanan akun',
  },
  {
    ticket: ticket({
      id: 't3',
      status: 'claimed',
      flags: ['complaint'],
      customer: { id: 'c3', display_name: 'Andi Pratama', username: 'andi_trader' },
      preview: 'Baik, kami cek status penarikannya sekarang.',
      unread_count: 0,
      waiting_since: minutesAgo(22),
    }),
    topic: 'Dana & penarikan',
  },
  {
    ticket: ticket({
      id: 't4',
      priority: 'P4',
      returned_reason: 'Perlu dicek tim lain',
      customer: { id: 'c4', display_name: 'Rina Saham', username: 'rina_saham' },
      unread_count: 0,
      waiting_since: minutesAgo(1),
      queued_at: minutesAgo(1),
    }),
    claimable: true,
    topic: 'Lainnya',
  },
  {
    ticket: ticket({
      id: 't5',
      status: 'resolved',
      customer: { id: 'c5', display_name: 'Dewi Cuan', username: 'dewi_cuan' },
      preview: 'Terima kasih kak, sudah masuk',
      unread_count: 0,
      resolved_at: minutesAgo(40),
      waiting_since: null,
    }),
    topic: 'Order & Transaksi',
  },
]

export const conversationTicket = ticket({
  id: 'dev-conversation',
  status: 'claimed',
  owner: { id: sampleAgent.id, display_name: 'Nadia', agent_code: 'CS-0045', status: 'online' },
  is_mine: true,
  claimed_at: minutesAgo(12),
})

function message(overrides: Partial<ChatMessage> & { id: string; created_at: string }): ChatMessage {
  return {
    room_id: 'dev-room',
    sender_id: 'dev-customer',
    sender_username: 'sari_invest',
    sender_display_name: 'Sari Wulandari',
    body: '',
    is_deleted: false,
    reply_to_id: null,
    reply_to_body: null,
    reply_to_sender_username: null,
    attachments: [],
    client_id: null,
    cursor: overrides.created_at,
    kind: 'text',
    payload: {},
    session_id: 'dev-session',
    sender_role: 'customer',
    ...overrides,
  }
}

const staff = {
  sender_id: sampleAgent.id,
  sender_username: 'CS-0045',
  sender_display_name: 'Nadia',
  sender_role: 'agent' as const,
}

export const sampleMessages: ChatMessage[] = [
  message({
    id: 'm0',
    created_at: minutesAgo(1500),
    kind: 'system',
    sender_role: 'system',
    sender_id: null,
    body: 'Tiket #CS-20261029-0310 ditutup.',
  }),
  message({
    id: 'm1',
    created_at: minutesAgo(14),
    kind: 'system',
    sender_role: 'system',
    sender_id: null,
    body: 'Tiket #CS-20261030-0042 dibuka.',
  }),
  message({
    id: 'm2',
    created_at: minutesAgo(14),
    body: 'Halo kak, order BBCA saya belum tereksekusi dari tadi.',
  }),
  message({ id: 'm3', created_at: minutesAgo(13), body: 'Padahal harganya sudah lewat.' }),
  message({
    id: 'm4',
    created_at: minutesAgo(12),
    kind: 'system',
    sender_role: 'system',
    sender_id: null,
    body: 'Tiket #CS-20261030-0042 diambil oleh Nadia.',
  }),
  message({
    id: 'm5',
    created_at: minutesAgo(11),
    ...staff,
    body: 'Halo Kak Sari, saya Nadia. Kami cek dulu ya.',
  }),
  message({
    id: 'm6',
    created_at: minutesAgo(10),
    ...staff,
    body: 'Order BBCA yang dipasang pagi ini ya, Kak?',
  }),
  message({
    id: 'm7',
    created_at: minutesAgo(4),
    body: 'Iya kak, yang itu. Nomor HP saya ****1234',
    payload: { masked: ['nomor HP'] },
  }),
]

export const sampleNotes: AgentNote[] = [
  {
    id: 'n1',
    kind: 'note',
    body: 'Order tertahan karena auto-reject harga. Sudah dicek di OLT.',
    created_at: minutesAgo(8),
    ticket_id: 'dev-conversation',
    author: { display_name: 'Nadia' },
  },
]

const sampleTopics: Record<string, string> = {
  withdrawal: 'Dana & penarikan',
  account: 'Keamanan akun',
}

export const sampleTopicName = (code: string) => sampleTopics[code] ?? code

export const sampleHistory: HistoryItem[] = [
  {
    id: 'h1',
    ticket_number: 'CS-20261012-0187',
    topic: 'withdrawal',
    status: 'closed',
    flags: [],
    created_at: minutesAgo(26_000),
    resolved_at: minutesAgo(25_950),
    closed_at: minutesAgo(22_000),
    outcome: 'answered',
    rating: 5,
    agent: 'Bima',
  },
  {
    id: 'h2',
    ticket_number: 'CS-20260918-0031',
    topic: 'account',
    status: 'closed',
    flags: ['complaint'],
    created_at: minutesAgo(61_000),
    resolved_at: minutesAgo(60_800),
    closed_at: minutesAgo(57_000),
    outcome: 'answered',
    rating: null,
    agent: 'Nadia',
  },
]

export const samplePending: PendingMessage[] = [
  {
    clientId: 'p1',
    roomId: 'dev-room',
    ticketId: 'dev-conversation',
    body: 'Ordernya kami bantu cek ke tim trading.',
    files: [],
    replyTo: null,
    status: 'failed',
    createdAt: minutesAgo(1),
  },
]
