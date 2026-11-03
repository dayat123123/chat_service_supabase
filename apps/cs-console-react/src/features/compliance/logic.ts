import { startOfQuarter, startOfYear, subDays } from 'date-fns'

import { compareMessages } from '@/features/conversation/cache'
import type { ChatMessage } from '@/features/conversation/types'
import type { AgentNote } from '@/features/customer/types'
import { toCsv } from '@/features/reports/csv'
import type { DateRange } from '@/features/reports/types'
import type { WaitTone } from '@/lib/sla'
import { format, isoDay, todayInJakarta } from '@/lib/time'

import type { AuditEntry, CaseDetail, CaseRow, ComplianceOverview, DeadlineState, Verdict } from './types'

export const auditActions = [
  'agent.auto_break',
  'agent.bootstrap',
  'agent.community_permissions',
  'agent.create',
  'agent.reset_password',
  'agent.status',
  'agent.update',
  'alerts.email_set',
  'alerts.options_set',
  'alerts.telegram_set',
  'alerts.test_sent',
  'allowed_domain.delete',
  'allowed_domain.save',
  'backup.requested',
  'backup.schedule_set',
  'backup.target_set',
  'banned_word.add',
  'banned_word.delete',
  'banned_word.import',
  'banned_word.update',
  'blocked_domain.delete',
  'blocked_domain.save',
  'client.min_version_set',
  'community.account_create',
  'community.account_disable',
  'community.account_enable',
  'community.account_update',
  'community.appeal_decide',
  'community.campaign_approve',
  'community.campaign_cancel',
  'community.campaign_reject',
  'community.campaign_save',
  'community.campaign_sent',
  'community.campaign_submit',
  'community.manipulation_review',
  'community.media_approve',
  'community.media_remove',
  'community.post_approve',
  'community.post_cancel',
  'community.post_delete',
  'community.post_failed',
  'community.post_pin',
  'community.post_publish',
  'community.post_reject',
  'community.post_save',
  'community.post_submit',
  'community.post_unpin',
  'community.private_message_view',
  'community.report_resolve',
  'community.room_pin',
  'community.room_settings',
  'community.room_unpin',
  'community.sanction',
  'community.sanction_revoke',
  'community.sessions_revoke',
  'community.verify_user',
  'community.zero_tolerance',
  'compliance.case_view',
  'compliance.deadline_extended',
  'compliance.policy_confirm',
  'compliance.review',
  'compliance.transcript_export',
  'content_rule.new_account_days',
  'content_rule.update',
  'customer_data.cash_transactions',
  'customer_data.orders',
  'customer_data.profile',
  'customer_data.reveal',
  'customer_data.security',
  'customer_data.sessions',
  'feature_flag.delete',
  'feature_flag.set',
  'health.alert_acknowledged',
  'holiday.delete',
  'holiday.save',
  'integration.key_create',
  'integration.key_revoke',
  'integration.key_update',
  'kill_switch.set',
  'legal.draft_created',
  'legal.draft_deleted',
  'legal.published',
  'legal.rejected',
  'legal.required_changed',
  'legal.schedule_cancelled',
  'legal.submitted',
  'legal.withdrawn',
  'manipulation.settings',
  'media.thresholds_set',
  'message.secret_request_blocked',
  'policy_allowlist.add',
  'policy_allowlist.delete',
  'promo_phrase.add',
  'promo_phrase.delete',
  'push.credentials_removed',
  'push.credentials_set',
  'push.test',
  'quick_reply.save',
  'report.customer_trail',
  'secure_account.requested',
  'secure_account.result',
  'session.accept',
  'session.close',
  'session.complaint_requested',
  'session.fake_cs_reported',
  'session.flag',
  'session.reject',
  'session.transfer',
  'setting.nasabah_integration',
  'setting.nasabah_integration_cleared',
  'setting.update',
  'ticket.claim',
  'ticket.complaint_requested',
  'ticket.fake_cs_reported',
  'ticket.flag',
  'ticket.join',
  'ticket.priority',
  'ticket.reassign',
  'ticket.release',
  'ticket.resolve',
  'ticket.transfer_accept',
  'ticket.transfer_request',
  'topic.save',
] as const

export function actionKey(action: string) {
  return (auditActions as readonly string[]).includes(action)
    ? `compliance.actions.${action.replace('.', '_')}`
    : null
}

export const ticketEvents = [
  'opened',
  'queued',
  'requeued',
  'claimed',
  'assigned',
  'offered',
  'accepted',
  'released',
  'transfer_requested',
  'transfer_rejected',
  'transfer_expired',
  'transfer_cancelled',
  'transferred',
  'reassigned',
  'waiting_customer',
  'customer_replied',
  'resolved',
  'reopened',
  'closed',
  'rated',
  'flagged',
  'priority_changed',
  'owner_away',
  'secret_request_blocked',
  'supervisor_joined',
  'secure_account_requested',
  'secure_account_done',
  'fake_cs_reported',
  'complaint_extended',
] as const

export type TicketEvent = (typeof ticketEvents)[number]

export function isKnownEvent(type: string): type is TicketEvent {
  return (ticketEvents as readonly string[]).includes(type)
}

const deadlineTones: Record<DeadlineState, WaitTone> = {
  running: 'ok',
  due_soon: 'warn',
  overdue: 'late',
  met: 'ok',
  missed: 'late',
}

export function deadlineTone(state: DeadlineState): WaitTone {
  return deadlineTones[state]
}

export function finishedAt(row: Pick<CaseRow, 'resolved_at' | 'closed_at'>) {
  return row.resolved_at ?? row.closed_at
}

export function isActiveCase(row: Pick<CaseRow, 'status'>) {
  return row.status === 'open' || row.status === 'claimed' || row.status === 'waiting_customer'
}

export function caseAttention(overview: Pick<ComplianceOverview, 'overdue' | 'due_soon'> | undefined) {
  return overview ? overview.overdue + overview.due_soon : 0
}

export function onTimePercent(onTime: ComplianceOverview['on_time']) {
  return onTime.total === 0 ? null : Math.round((onTime.met * 100) / onTime.total)
}

export type CasePreset = 'all' | 'month' | 'quarter' | 'year' | 'custom'

export function casePresetRange(preset: Exclude<CasePreset, 'custom'>, today: Date = todayInJakarta()) {
  const to = isoDay(today)
  if (preset === 'month') return { from: isoDay(subDays(today, 29)), to }
  if (preset === 'quarter') return { from: isoDay(startOfQuarter(today)), to }
  if (preset === 'year') return { from: isoDay(startOfYear(today)), to }
  return null
}

function isEmptyDetail(value: unknown) {
  if (value === null || value === undefined || value === '') return true
  if (Array.isArray(value)) return value.length === 0
  return typeof value === 'object' && Object.keys(value).length === 0
}

const isoTimestamp = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}/

type Change = { from: unknown; to: unknown }

function isChange(value: object): value is Change {
  const keys = Object.keys(value)
  return keys.length === 2 && keys.includes('from') && keys.includes('to')
}

function changeSide(value: unknown, formatTime: ((value: string) => string) | undefined): string {
  return value === null || value === undefined || value === '' ? '–' : detailValue(value, formatTime)
}

function detailValue(value: unknown, formatTime: ((value: string) => string) | undefined): string {
  if (typeof value === 'string') return formatTime && isoTimestamp.test(value) ? formatTime(value) : value
  if (value === null || typeof value !== 'object' || Array.isArray(value)) return JSON.stringify(value)
  if (isChange(value)) return `${changeSide(value.from, formatTime)} → ${changeSide(value.to, formatTime)}`
  return Object.entries(value)
    .map(([key, item]) => `${key} ${detailValue(item, formatTime)}`)
    .join(', ')
}

export function detailsText(details: Record<string, unknown>, formatTime?: (value: string) => string) {
  return Object.entries(details)
    .filter(([, value]) => !isEmptyDetail(value))
    .map(([key, value]) => `${key}: ${detailValue(value, formatTime)}`)
    .join(' · ')
}

const csvTime = (value: string | null | undefined) => (value ? format(value, 'yyyy-MM-dd HH:mm') : null)

export const caseCsvColumns = [
  'ticket',
  'customer',
  'username',
  'kind',
  'fakeCs',
  'topic',
  'status',
  'agent',
  'agentCode',
  'created',
  'received',
  'due',
  'extended',
  'finished',
  'deadline',
  'lateDays',
  'outcome',
  'review',
  'reviewer',
  'reviewedAt',
] as const

export type CaseCsvColumn = (typeof caseCsvColumns)[number]

export type CaseCsvText = {
  header: (column: CaseCsvColumn) => string
  kind: (row: CaseRow) => string
  status: (status: string) => string
  deadline: (state: DeadlineState) => string
  verdict: (verdict: Verdict) => string
  yes: string
}

export function casesCsv(rows: CaseRow[], text: CaseCsvText) {
  return toCsv([
    caseCsvColumns.map(text.header),
    ...rows.map((row) => [
      row.ticket_number,
      row.customer?.display_name,
      row.customer?.username,
      text.kind(row),
      row.fake_cs ? text.yes : null,
      row.topic_name ?? row.topic,
      text.status(row.status),
      row.agent?.display_name,
      row.agent?.agent_code,
      csvTime(row.created_at),
      csvTime(row.complaint_received_at),
      csvTime(row.complaint_due_at),
      csvTime(row.complaint_extended_at),
      csvTime(finishedAt(row)),
      row.deadline ? text.deadline(row.deadline.state) : null,
      row.deadline && (row.deadline.state === 'missed' || row.deadline.state === 'overdue')
        ? row.deadline.business_days
        : null,
      row.outcome,
      row.review ? text.verdict(row.review.verdict) : null,
      row.review?.reviewer,
      csvTime(row.review?.created_at),
    ]),
  ])
}

export const auditCsvColumns = [
  'time',
  'actor',
  'actorCode',
  'actorType',
  'action',
  'actionCode',
  'ticket',
  'customer',
  'details',
] as const

export type AuditCsvColumn = (typeof auditCsvColumns)[number]

export function auditCsv(
  rows: AuditEntry[],
  text: { header: (column: AuditCsvColumn) => string; action: (action: string) => string },
) {
  return toCsv([
    auditCsvColumns.map(text.header),
    ...rows.map((row) => [
      format(row.created_at, 'yyyy-MM-dd HH:mm:ss'),
      row.actor?.display_name,
      row.actor?.agent_code ?? row.actor?.username,
      row.actor_type,
      text.action(row.action),
      row.action,
      row.ticket?.ticket_number,
      row.customer?.display_name ?? row.customer?.username,
      detailsText(row.details),
    ]),
  ])
}

export function rangeFileSuffix(range: DateRange | null, today: Date = todayInJakarta()) {
  return range ? `${range.from}-${range.to}` : `semua-${isoDay(today)}`
}

export type TranscriptText = {
  title: string
  fields: { label: string; value: string | null | undefined }[]
  customer: string
  agent: string
  system: string
  note: string
  attachment: string
  deleted: string
}

type TranscriptEntry =
  { at: string; kind: 'message'; message: ChatMessage } | { at: string; kind: 'note'; note: AgentNote }

const stampOf = (value: string) => `${format(value, 'yyyy-MM-dd HH:mm:ss')} WIB`

function speaker(message: ChatMessage, text: TranscriptText) {
  if (message.sender_role === 'system' || message.kind === 'system' || message.kind === 'csat')
    return text.system
  const name = message.sender_display_name ?? message.sender_username ?? '?'
  return `${name} (${message.sender_role === 'customer' ? text.customer : text.agent})`
}

function messageBody(message: ChatMessage, text: TranscriptText) {
  if (message.is_deleted) return text.deleted
  const files = message.attachments.length > 0 ? ` [${text.attachment}: ${message.attachments.length}]` : ''
  return `${message.body}${files}`
}

export function transcriptText(
  detail: Pick<CaseDetail, 'notes'>,
  messages: ChatMessage[],
  text: TranscriptText,
) {
  const entries: TranscriptEntry[] = [
    ...[...messages]
      .sort(compareMessages)
      .map((message): TranscriptEntry => ({ at: message.created_at, kind: 'message', message })),
    ...detail.notes.map((note): TranscriptEntry => ({ at: note.created_at, kind: 'note', note })),
  ].sort((a, b) => a.at.localeCompare(b.at))
  const width = Math.max(...text.fields.map((field) => field.label.length))
  const lines = [
    text.title,
    ...text.fields.map((field) => `${field.label.padEnd(width)} : ${field.value ?? '–'}`),
    '-'.repeat(60),
    ...entries.map((entry) =>
      entry.kind === 'message'
        ? `[${stampOf(entry.at)}] ${speaker(entry.message, text)}: ${messageBody(entry.message, text)}`
        : `[${stampOf(entry.at)}] ${text.note}${entry.note.author?.display_name ? ` – ${entry.note.author.display_name}` : ''}: ${entry.note.body}`,
    ),
  ]
  return `${lines.join('\n')}\n`
}

export async function sha256Hex(content: string) {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(content))
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, '0')).join('')
}

export function transcriptFileName(ticketNumber: string, sha256: string) {
  return `transkrip-${ticketNumber}-${sha256.slice(0, 12)}.txt`
}

export function policyDraftProblem(value: string, min: number, max: number) {
  if (!/^\d+$/.test(value.trim())) return 'invalid'
  const number = Number(value)
  return number < min || number > max ? 'outOfRange' : null
}
