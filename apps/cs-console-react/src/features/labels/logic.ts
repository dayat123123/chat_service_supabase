import { isSuperAdmin, worksTickets, type AgentProfile } from '@/features/presence/types'
import type { DateRange } from '@/features/reports/types'
import type { Ticket, TicketLists } from '@/features/tickets/types'
import i18n from '@/i18n'
import { errorText } from '@/lib/error-text'
import { toApiError } from '@/lib/errors'

import {
  isLabelColor,
  MAX_TICKET_LABELS,
  type LabelConfig,
  type LabelReport,
  type LabelReportRow,
  type TicketLabel,
} from './types'

const labelErrorCodes = [
  'invalid_label_name',
  'invalid_label_color',
  'duplicate_label',
  'label_limit',
  'label_not_found',
  'label_inactive',
  'ticket_label_limit',
  'invalid_label_order',
  'not_ticket_owner',
] as const

type LabelErrorCode = (typeof labelErrorCodes)[number]

const isLabelErrorCode = (code: string): code is LabelErrorCode =>
  (labelErrorCodes as readonly string[]).includes(code)

export function labelErrorText(error: unknown) {
  const code = toApiError(error).code
  return isLabelErrorCode(code) ? i18n.t(`labels.errors.${code}`) : errorText(error)
}

export function normalizeLabel<T extends TicketLabel>(label: T): T {
  return { ...label, color: isLabelColor(label.color) ? label.color : 'neutral' }
}

export function normalizeReport(raw: Partial<LabelReport>, range: DateRange): LabelReport {
  return {
    from: raw.from ?? range.from,
    to: raw.to ?? range.to,
    total: raw.total ?? 0,
    unlabeled: raw.unlabeled ?? 0,
    labels: (raw.labels ?? []).map((row: LabelReportRow) => normalizeLabel(row)),
  }
}

export const ticketLabels = (ticket: Pick<Ticket, 'labels'>): TicketLabel[] => ticket.labels ?? []

const activeStatuses = new Set(['claimed', 'waiting_customer'])

export function canEditLabels(
  agent: Pick<AgentProfile, 'id' | 'roles'>,
  ticket: Pick<Ticket, 'status' | 'owner'>,
) {
  if (isSuperAdmin(agent)) return true
  return worksTickets(agent) && ticket.owner?.id === agent.id && activeStatuses.has(ticket.status)
}

export const atLabelLimit = (labels: TicketLabel[]) => labels.length >= MAX_TICKET_LABELS

export function addableLabels(options: TicketLabel[], current: TicketLabel[]) {
  const used = new Set(current.map((label) => label.id))
  return options.filter((label) => !used.has(label.id))
}

export function withLabels<T extends Pick<Ticket, 'id' | 'labels'>>(
  ticket: T,
  ticketId: string,
  labels: TicketLabel[],
) {
  return ticket.id === ticketId ? { ...ticket, labels } : ticket
}

export function listsWithLabels(lists: TicketLists, ticketId: string, labels: TicketLabel[]): TicketLists {
  const apply = (items: Ticket[]) => items.map((ticket) => withLabels(ticket, ticketId, labels))
  return {
    ...lists,
    open: apply(lists.open),
    mine: apply(lists.mine),
    resolved_today: apply(lists.resolved_today),
    all_active: apply(lists.all_active),
    transfers_in: lists.transfers_in.map((request) => ({
      ...request,
      ticket: withLabels(request.ticket, ticketId, labels),
    })),
  }
}

export function labelsInLists(lists: TicketLists): TicketLabel[] {
  const found = new Map<string, TicketLabel>()
  const tickets = [
    ...lists.open,
    ...lists.mine,
    ...lists.resolved_today,
    ...lists.all_active,
    ...lists.transfers_in.map((request) => request.ticket),
  ]
  for (const ticket of tickets) {
    for (const label of ticketLabels(ticket)) if (!found.has(label.id)) found.set(label.id, label)
  }
  return [...found.values()].sort((a, b) => a.name.localeCompare(b.name, 'id'))
}

export function moveLabel(ids: string[], index: number, step: number) {
  const target = index + step
  if (index < 0 || index >= ids.length || target < 0 || target >= ids.length) return ids
  const next = [...ids]
  const [moved] = next.splice(index, 1)
  if (moved !== undefined) next.splice(target, 0, moved)
  return next
}

export const activeLabelCount = (labels: Pick<LabelConfig, 'active'>[]) =>
  labels.filter((label) => label.active).length

export function reportShares(report: LabelReport) {
  return report.labels.map((row) => ({
    ...row,
    share: report.total === 0 ? undefined : row.count / report.total,
  }))
}
