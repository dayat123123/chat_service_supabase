import { rpc } from '@/lib/supabase'

import type { DraftInput, LegalDocument, LegalDraft, LegalKind, LegalOverview } from './types'

export const legalApi = {
  overview: async (): Promise<LegalOverview> => {
    const raw = await rpc<LegalOverview>('legal_overview')
    return {
      ...raw,
      required_kinds: raw.required_kinds ?? [],
      kinds: (raw.kinds ?? []).map((kind) => ({
        ...kind,
        current: kind.current ?? null,
        scheduled: kind.scheduled ?? null,
        history: kind.history ?? [],
      })),
      drafts: raw.drafts ?? [],
    }
  },
  document: (id: string) => rpc<LegalDocument>('legal_document', { p_id: id }),
  draft: (id: string) => rpc<LegalDraft>('legal_draft', { p_id: id }),
  save: (input: DraftInput) =>
    rpc<LegalDraft>('legal_draft_save', {
      p_id: input.id,
      p_kind: input.kind,
      p_title: input.title.trim(),
      p_body: input.body,
      p_change_summary: input.changeSummary.trim() || null,
      p_effective_at: input.effectiveAt,
    }),
  submit: (id: string) => rpc<LegalDraft>('legal_draft_submit', { p_id: id }),
  withdraw: (id: string) => rpc<LegalDraft>('legal_draft_withdraw', { p_id: id }),
  reject: (id: string, note: string) => rpc<LegalDraft>('legal_draft_reject', { p_id: id, p_note: note }),
  approve: (id: string) => rpc<LegalDocument>('legal_draft_approve', { p_id: id }),
  remove: (id: string) => rpc<null>('legal_draft_delete', { p_id: id }),
  cancelScheduled: (documentId: string) =>
    rpc<{ draft: string | null }>('legal_cancel_scheduled', { p_document_id: documentId }),
  setRequired: (kinds: LegalKind[]) => rpc<LegalKind[]>('legal_set_required', { p_kinds: kinds }),
}
