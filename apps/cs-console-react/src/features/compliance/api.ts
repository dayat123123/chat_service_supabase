import { compareMessages } from '@/features/conversation/cache'
import type { ChatMessage } from '@/features/conversation/types'
import { rpc } from '@/lib/supabase'

import type {
  AuditCursor,
  AuditFilter,
  AuditPage,
  CaseDetail,
  CaseFilter,
  CaseList,
  CaseRow,
  ComplianceOverview,
  Policy,
  PolicyBook,
  PolicyKey,
  Review,
  TranscriptExport,
  Verdict,
} from './types'

function normalizeMessage(message: ChatMessage): ChatMessage {
  return { ...message, attachments: message.attachments ?? [], payload: message.payload ?? {} }
}

export const complianceApi = {
  overview: async (): Promise<ComplianceOverview> => {
    const raw = await rpc<ComplianceOverview>('compliance_overview')
    return {
      ...raw,
      deadlines: raw.deadlines ?? [],
      fraud: raw.fraud ?? [],
      to_review: raw.to_review ?? [],
      secret_agents: raw.secret_agents ?? [],
    }
  },
  cases: (filter: CaseFilter) =>
    rpc<CaseList>('compliance_cases', {
      p_kind: filter.kind,
      p_state: filter.state,
      p_from: filter.range?.from ?? null,
      p_to: filter.range?.to ?? null,
      p_query: filter.query.trim() || null,
    }),
  detail: async (ticketId: string): Promise<CaseDetail> => {
    const raw = await rpc<CaseDetail>('compliance_case', { p_ticket_id: ticketId })
    return { ...raw, events: raw.events ?? [], notes: raw.notes ?? [], reviews: raw.reviews ?? [] }
  },
  messages: async (ticketId: string) =>
    (await rpc<ChatMessage[]>('ticket_messages', { p_ticket_id: ticketId }))
      .map(normalizeMessage)
      .sort(compareMessages),
  review: (ticketId: string, verdict: Verdict, note: string) =>
    rpc<Review>('compliance_review', { p_ticket_id: ticketId, p_verdict: verdict, p_note: note }),
  extend: (ticketId: string, reason: string, version: number) =>
    rpc<CaseRow>('compliance_extend_deadline', {
      p_ticket_id: ticketId,
      p_reason: reason,
      p_version: version,
    }),
  transcriptExported: (ticketId: string, sha256: string, messages: number) =>
    rpc<TranscriptExport>('compliance_transcript_exported', {
      p_ticket_id: ticketId,
      p_sha256: sha256,
      p_messages: messages,
    }),
  audit: async (filter: AuditFilter, cursor: AuditCursor | null, limit: number): Promise<AuditPage> => {
    const raw = await rpc<AuditPage>('compliance_audit', {
      p_from: filter.range.from,
      p_to: filter.range.to,
      p_action: filter.action,
      p_query: filter.query.trim() || null,
      p_before_at: cursor?.before_at ?? null,
      p_before_id: cursor?.before_id ?? null,
      p_limit: limit,
    })
    return { rows: raw.rows ?? [], next: raw.next ?? null, actions: raw.actions ?? null }
  },
  policies: async (): Promise<PolicyBook> => {
    const raw = await rpc<PolicyBook>('compliance_policies')
    return { policies: raw.policies ?? [], history: raw.history ?? [] }
  },
  confirmPolicy: (key: PolicyKey, value: number, note: string) =>
    rpc<Policy>('compliance_confirm_policy', { p_key: key, p_value: value, p_note: note.trim() || null }),
}
