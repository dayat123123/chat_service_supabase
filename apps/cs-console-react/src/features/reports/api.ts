import { rpc } from '@/lib/supabase'

import {
  emptyStats,
  type CustomerReport,
  type CustomerTrail,
  type DateRange,
  type ReportSummary,
} from './types'

export const reportsApi = {
  summary: async (range: DateRange): Promise<ReportSummary> => {
    const raw = await rpc<Partial<ReportSummary>>('report_summary', { p_from: range.from, p_to: range.to })
    return {
      from: raw.from ?? range.from,
      to: raw.to ?? range.to,
      totals: { ...emptyStats, ...raw.totals },
      daily: (raw.daily ?? []).map((day) => ({ ...emptyStats, ...day })),
      agents: raw.agents ?? [],
      topics: raw.topics ?? [],
    }
  },
  customers: (range: DateRange, search: string) =>
    rpc<CustomerReport[]>('report_customers', {
      p_from: range.from,
      p_to: range.to,
      p_search: search.trim() === '' ? null : search.trim(),
    }),
  customerTrail: (customerId: string, range: DateRange) =>
    rpc<CustomerTrail>('report_customer_trail', {
      p_customer_id: customerId,
      p_from: range.from,
      p_to: range.to,
    }),
}
