import { rpc } from '@/lib/supabase'

import type { AgentNote, HistoryItem } from './types'

export const customerApi = {
  history: (customerId: string) => rpc<HistoryItem[]>('customer_history', { p_customer_id: customerId }),
  notes: (customerId: string) => rpc<AgentNote[]>('notes', { p_customer_id: customerId }),
}
