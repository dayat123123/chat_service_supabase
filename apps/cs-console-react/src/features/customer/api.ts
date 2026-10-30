import { ApiError } from '@/lib/errors'
import { accessToken, appEnv, rpc } from '@/lib/supabase'

import type {
  AgentNote,
  CashTransaction,
  CustomerOrder,
  CustomerProfile,
  HistoryItem,
  RevealField,
  SecurityStatus,
  Sessions,
} from './types'

type Envelope = { available?: boolean; data?: unknown; code?: string; message?: string }

async function adapter<T>(
  ticketId: string,
  path: string,
  init: { method?: string; body?: unknown } = {},
): Promise<T> {
  const env = appEnv()
  let response: Response
  try {
    response = await fetch(
      `${env.adapterUrl}/agent/tickets/${encodeURIComponent(ticketId)}/customer/${path}`,
      {
        method: init.method ?? 'GET',
        headers: {
          apikey: env.anonKey,
          Authorization: `Bearer ${await accessToken()}`,
          'Content-Type': 'application/json',
        },
        body: init.body === undefined ? undefined : JSON.stringify(init.body),
      },
    )
  } catch {
    throw new ApiError('network')
  }
  let envelope: Envelope
  try {
    envelope = (await response.json()) as Envelope
  } catch {
    throw new ApiError('adapter_invalid_response', undefined, response.status)
  }
  if (response.ok && envelope.available === true) return envelope.data as T
  if (envelope.available === false) throw new ApiError('olt_unavailable', undefined, 503)
  if (response.status === 401) throw new ApiError('session_expired', undefined, 401)
  throw new ApiError(envelope.code ?? 'adapter_error', envelope.message, response.status)
}

export const customerApi = {
  profile: (ticketId: string) => adapter<CustomerProfile>(ticketId, 'profile'),
  orders: async (ticketId: string) =>
    (await adapter<{ orders?: CustomerOrder[] }>(ticketId, 'orders?limit=5')).orders ?? [],
  order: (ticketId: string, ref: string) =>
    adapter<Record<string, unknown>>(ticketId, `orders/${encodeURIComponent(ref)}`),
  cash: async (ticketId: string) =>
    (await adapter<{ transactions?: CashTransaction[] }>(ticketId, 'cash-transactions?limit=5'))
      .transactions ?? [],
  cashDetail: (ticketId: string, ref: string) =>
    adapter<Record<string, unknown>>(ticketId, `cash-transactions/${encodeURIComponent(ref)}`),
  sessions: (ticketId: string) => adapter<Sessions>(ticketId, 'sessions'),
  security: (ticketId: string) => adapter<SecurityStatus>(ticketId, 'security'),
  reveal: async (ticketId: string, field: RevealField, reason: string) => {
    const data = await adapter<{ value?: string; valid_seconds?: number }>(ticketId, 'reveal', {
      method: 'POST',
      body: { field, reason },
    })
    return { field, value: data.value ?? '', until: Date.now() + (data.valid_seconds ?? 300) * 1000 }
  },
  secureAccount: (ticketId: string) =>
    adapter<{ ok?: boolean }>(ticketId, 'secure-account', { method: 'POST' }),
  history: (customerId: string) => rpc<HistoryItem[]>('customer_history', { p_customer_id: customerId }),
  notes: (customerId: string) => rpc<AgentNote[]>('notes', { p_customer_id: customerId }),
}
