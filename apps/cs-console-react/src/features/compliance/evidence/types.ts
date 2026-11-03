export const evidenceFilters = ['held', 'pending', 'problem', 'expiring'] as const
export type EvidenceFilter = (typeof evidenceFilters)[number]

export const evidenceSources = [
  'report',
  'moderator_remove',
  'system_remove',
  'media_removed',
  'zero_tolerance',
] as const
export type EvidenceSource = (typeof evidenceSources)[number]

export type EvidenceTarget = 'post' | 'comment' | 'message' | 'user' | 'media'

export type EvidenceFileStatus = 'pending' | 'copied' | 'missing' | 'failed'

export type EvidenceActor = {
  id: string
  display_name?: string | null
  agent_code?: string | null
  username?: string | null
} | null

export type EvidenceAuthor = {
  id?: string
  username?: string | null
  display_name?: string | null
  deleted?: boolean
} | null

export type EvidenceFileCounts = {
  total: number
  copied: number
  pending: number
  missing: number
  failed: number
}

export type EvidenceRow = {
  id: string
  code: string
  seq: number
  source: EvidenceSource
  target_type: EvidenceTarget
  target_id: string
  author: EvidenceAuthor
  captured_at: string
  retain_until: string
  legal_hold: boolean
  hold: { reason: string; at: string; by: EvidenceActor } | null
  files: EvidenceFileCounts
  links: number
}

export type EvidenceSummary = {
  total: number
  held: number
  expiring: number
  pending_files: number
  problem_files: number
  retention_days: number
}

export type EvidenceCursor = { before_seq: number }

export type EvidencePage = {
  rows: EvidenceRow[]
  next: EvidenceCursor | null
  can_manage: boolean
  summary: EvidenceSummary | null
}

export type EvidenceListFilter = {
  query: string
  filter: EvidenceFilter | null
  source: EvidenceSource | null
}

export type EvidenceFile = {
  id: number
  position: number
  bucket: 'evidence'
  object_name: string
  source_bucket: string
  source_name: string
  meta: Record<string, unknown>
  status: EvidenceFileStatus
  sha256: string | null
  size: number | null
  copied_at: string | null
  failures: number
  error: string | null
}

export type CustodyAction =
  | 'captured'
  | 'linked'
  | 'file_copied'
  | 'file_missing'
  | 'file_failed'
  | 'viewed'
  | 'verified'
  | 'file_verified'
  | 'exported'
  | 'hold_set'
  | 'hold_released'

export type CustodyEntry = {
  id: number
  at: string
  action: CustodyAction
  actor_type: string
  actor_roles: string[]
  actor: EvidenceActor
  details: Record<string, unknown>
  entry_sha256: string
}

export type EvidenceReport = {
  id: string
  reason: string
  details: string | null
  status: string
  created_at: string
  reporter: { id: string | null; username: string | null; display_name: string | null }
}

export type EvidenceContent = {
  target_type: EvidenceTarget
  target_id: string
  author_id: string | null
  body: string | null
  attachments: Record<string, unknown>[]
  username?: string | null
  display_name?: string | null
  avatar_url?: string | null
}

export type EvidenceStatus = EvidenceRow & { custody: CustodyEntry[] }

export type EvidenceDetail = EvidenceStatus & {
  content: EvidenceContent
  context: Record<string, unknown>
  content_sha256: string
  body_sha256: string
  record_sha256: string
  captured_by: EvidenceActor
  files_detail: EvidenceFile[]
  reports: EvidenceReport[]
  can_manage: boolean
}

export type VerifiedFile = {
  id: number
  position: number
  status: EvidenceFileStatus
  sha256: string | null
  size: number | null
  object_exists: boolean
  stored_size: number | null
  ok: boolean
}

export type VerifyResult = {
  ok: boolean
  content_ok: boolean
  body_ok: boolean
  record_ok: boolean
  custody_ok: boolean
  custody_entries: number
  custody_broken_at: number | null
  files_ok: boolean
  files: VerifiedFile[]
  checked_at: string
  status: EvidenceStatus
}

export type FileCheck = { file_id: number; match: boolean; expected: string; actual: string }

export type BundleFile = {
  position: number
  bucket: 'evidence'
  object_name: string
  status: EvidenceFileStatus
  sha256: string | null
  size: number | null
}

export type EvidenceBundle = {
  format: string
  manifest_sha256: string
  evidence: { id: string; code: string }
  files: BundleFile[]
  [key: string]: unknown
}

export type SignedLink = { object_name: string; url: string }

export const EVIDENCE_PAGE_SIZE = 50
export const EXPORT_LINK_SECONDS = 3600
export const VIEW_LINK_SECONDS = 120
