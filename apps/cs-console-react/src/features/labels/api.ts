import type { DateRange } from '@/features/reports/types'
import { rpc } from '@/lib/supabase'

import { normalizeLabel, normalizeReport } from './logic'
import type { LabelConfig, LabelDraft, LabelReport, TicketLabel } from './types'

export const labelsApi = {
  options: async () => (await rpc<TicketLabel[]>('ticket_labels')).map(normalizeLabel),
  configs: async () => (await rpc<LabelConfig[]>('admin_ticket_labels')).map(normalizeLabel),
  save: async (draft: LabelDraft) =>
    (
      await rpc<LabelConfig[]>('admin_save_ticket_label', {
        p_id: draft.id,
        p_name: draft.name,
        p_color: draft.color,
        p_active: draft.active,
      })
    ).map(normalizeLabel),
  reorder: async (ids: string[]) =>
    (await rpc<LabelConfig[]>('admin_reorder_ticket_labels', { p_ids: ids })).map(normalizeLabel),
  add: async (ticketId: string, labelId: string) =>
    (await rpc<TicketLabel[]>('add_ticket_label', { p_ticket_id: ticketId, p_label_id: labelId })).map(
      normalizeLabel,
    ),
  remove: async (ticketId: string, labelId: string) =>
    (await rpc<TicketLabel[]>('remove_ticket_label', { p_ticket_id: ticketId, p_label_id: labelId })).map(
      normalizeLabel,
    ),
  report: async (range: DateRange) =>
    normalizeReport(
      await rpc<Partial<LabelReport>>('report_ticket_labels', { p_from: range.from, p_to: range.to }),
      range,
    ),
}
