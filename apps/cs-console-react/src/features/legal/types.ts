export const legalKinds = ['terms', 'community_guidelines', 'privacy'] as const
export type LegalKind = (typeof legalKinds)[number]

export const draftStatuses = ['draft', 'pending', 'rejected', 'published'] as const
export type DraftStatus = (typeof draftStatuses)[number]

export const LEGAL_TITLE_MIN = 3
export const LEGAL_TITLE_MAX = 150
export const LEGAL_BODY_MIN = 50
export const LEGAL_BODY_MAX = 100_000
export const LEGAL_SUMMARY_MAX = 2000
export const LEGAL_NOTE_MIN = 5
export const LEGAL_NOTE_MAX = 1000

export type LegalDocument = {
  id: string
  kind: LegalKind
  version: number
  title: string
  body?: string
  change_summary?: string
  effective_at: string
  created_at: string
  created_by?: string
  approved_by?: string
  in_effect: boolean
  accepted: number
}

export type LegalDraft = {
  id: string
  kind: LegalKind
  title: string
  body?: string
  body_length: number
  change_summary?: string
  effective_at?: string
  status: DraftStatus
  created_by?: string
  created_by_id: string
  created_at: string
  updated_by?: string
  updated_by_id: string
  updated_at: string
  submitted_by?: string
  submitted_by_id?: string
  submitted_at?: string
  reviewed_by?: string
  reviewed_at?: string
  review_note?: string
  document_id?: string
}

export type LegalKindState = {
  kind: LegalKind
  required: boolean
  current: LegalDocument | null
  scheduled: LegalDocument | null
  history: LegalDocument[]
}

export type LegalOverview = {
  active_users: number
  reviewers: number
  four_eyes: boolean
  required_kinds: LegalKind[]
  kinds: LegalKindState[]
  drafts: LegalDraft[]
}

export type DraftInput = {
  id: string | null
  kind: LegalKind
  title: string
  body: string
  changeSummary: string
  effectiveAt: string | null
}
