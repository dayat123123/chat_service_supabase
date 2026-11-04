export const labelColors = ['neutral', 'info', 'success', 'warning', 'danger'] as const
export type LabelColor = (typeof labelColors)[number]

export const MAX_LABEL_NAME = 30
export const MAX_ACTIVE_LABELS = 50
export const MAX_TICKET_LABELS = 5

export type TicketLabel = { id: string; name: string; color: LabelColor }

export type LabelConfig = TicketLabel & {
  active: boolean
  sort_order: number
  updated_at: string | null
  tickets: number
}

export type LabelDraft = { id: string | null; name: string; color: LabelColor; active: boolean }

export type LabelReportRow = TicketLabel & { active: boolean; count: number }

export type LabelReport = {
  from: string
  to: string
  total: number
  unlabeled: number
  labels: LabelReportRow[]
}

export const isLabelColor = (value: unknown): value is LabelColor =>
  typeof value === 'string' && (labelColors as readonly string[]).includes(value)
