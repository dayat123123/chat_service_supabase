import type { AgentNote } from '@/features/customer/types'
import type { DateRange } from '@/features/reports/types'
import type { TicketCustomer, TicketEventItem, TicketStatus } from '@/features/tickets/types'

export const deadlineStates = ['running', 'due_soon', 'overdue', 'met', 'missed'] as const
export type DeadlineState = (typeof deadlineStates)[number]
export type Deadline = { state: DeadlineState; business_days: number }

export const verdicts = ['compliant', 'needs_action', 'violation'] as const
export type Verdict = (typeof verdicts)[number]

export type ReviewSummary = { verdict: Verdict; note: string; created_at: string; reviewer: string | null }
export type Review = ReviewSummary & { id: string }

export type CaseAgent = { id: string; display_name: string; agent_code: string | null }

export type CaseRow = {
  id: string
  ticket_number: string
  room_id: string
  version: number
  status: TicketStatus
  priority: string
  flags: string[]
  topic: string
  topic_name: string | null
  language: string
  fake_cs: boolean
  customer: TicketCustomer | null
  agent: CaseAgent | null
  created_at: string
  complaint_received_at: string | null
  complaint_due_at: string | null
  complaint_extended_at: string | null
  resolved_at: string | null
  closed_at: string | null
  outcome: string | null
  rating: number | null
  deadline: Deadline | null
  review: ReviewSummary | null
}

export type CaseDetail = CaseRow & {
  resolution_summary: string | null
  returned_reason: string | null
  rating_comment: string | null
  context: Record<string, unknown>
  complaint_extension_reason: string | null
  extension_days: number
  can_extend: boolean
  events: TicketEventItem[]
  notes: AgentNote[]
  reviews: Review[]
}

export type SecretAgent = {
  id: string
  display_name: string
  agent_code: string | null
  count: number
  last_at: string
}

export type ComplianceOverview = {
  generated_at: string
  active_complaints: number
  due_soon: number
  overdue: number
  on_time: { met: number; total: number }
  active_fraud: number
  fake_cs_reports: number
  secret_blocked: number
  unreviewed: number
  policies_unconfirmed: number
  deadlines: CaseRow[]
  fraud: CaseRow[]
  to_review: CaseRow[]
  secret_agents: SecretAgent[]
}

export const caseKinds = ['all', 'complaint', 'fraud'] as const
export type CaseKind = (typeof caseKinds)[number]

export const caseStates = ['all', 'active', 'attention', 'done', 'unreviewed'] as const
export type CaseState = (typeof caseStates)[number]

export type CaseFilter = { kind: CaseKind; state: CaseState; range: DateRange | null; query: string }

export type CaseList = { rows: CaseRow[]; total: number; truncated: boolean }

export const MAX_CASE_DAYS = 366
export const MAX_AUDIT_DAYS = 366
export const AUDIT_PAGE_SIZE = 100
export const AUDIT_EXPORT_LIMIT = 5000

export type AuditActor = {
  id: string
  display_name: string | null
  agent_code?: string | null
  username?: string | null
}

export type AuditEntry = {
  id: number
  created_at: string
  action: string
  actor_type: string
  actor_roles: string[]
  actor: AuditActor | null
  ticket: { id: string; ticket_number: string; case: boolean } | null
  customer: { id: string; display_name: string | null; username: string | null } | null
  details: Record<string, unknown>
}

export type AuditCursor = { before_at: string; before_id: number }
export type ActionCount = { action: string; count: number }
export type AuditPage = { rows: AuditEntry[]; next: AuditCursor | null; actions: ActionCount[] | null }
export type AuditFilter = { range: DateRange; action: string | null; query: string }

export const policyKeys = ['complaint.days', 'complaint.extension_days', 'retention.chat_years'] as const
export type PolicyKey = (typeof policyKeys)[number]

export type PolicyConfirmation = {
  version: number
  value: number
  note: string | null
  confirmed_at: string
  confirmed_by: string | null
}

export type Policy = {
  key: PolicyKey
  value: number
  description: string
  version: number
  updated_at: string
  updated_by: string | null
  min: number
  max: number
  unit: 'business_days' | 'years'
  confirmed: boolean
  confirmation: PolicyConfirmation | null
}

export type PolicyChange = {
  key: PolicyKey
  version: number
  old_value: number | null
  new_value: number
  changed_at: string
  changed_by: string | null
}

export type PolicyBook = { policies: Policy[]; history: PolicyChange[] }

export type TranscriptExport = { ticket_id: string; sha256: string; exported_at: string }
