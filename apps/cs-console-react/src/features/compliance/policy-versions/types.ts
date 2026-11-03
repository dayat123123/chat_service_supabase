import type { StaffRef } from '@/features/community/types'
import type { ContentAction, TestSurface } from '@/features/content-policy/types'

export const policySections = [
  'banned_words',
  'content_rules',
  'blocked_domains',
  'allowed_domains',
  'allowlist',
  'promo_phrases',
  'settings',
  'image_thresholds',
] as const
export type PolicySection = (typeof policySections)[number]

export type DiffOp = 'added' | 'removed' | 'changed'

export type DiffItem = { key: string; op: DiffOp; from?: unknown; to?: unknown }

export type SectionDiff = { added: number; removed: number; changed: number; items?: DiffItem[] }

export type PolicyDiff = { total: number; sections: Partial<Record<PolicySection, SectionDiff>> }

export const versionSources = ['baseline', 'direct', 'change', 'rollback', 'system'] as const
export type VersionSource = (typeof versionSources)[number]

export type PolicyVersion = {
  version: number
  source: VersionSource
  reason: string | null
  change_id: number | null
  restored_from: number | null
  created_by: StaffRef
  created_at: string
  summary: PolicyDiff
  current: boolean
}

export type VersionDetail = PolicyVersion & {
  diff: PolicyDiff
  restore: PolicyDiff
  sizes: Record<PolicySection, number>
}

export type VersionPage = { rows: PolicyVersion[]; next: number | null }

export type ChangeKind = 'edit' | 'rollback'
export type ChangeStatus = 'pending' | 'approved' | 'rejected' | 'withdrawn'

export type PolicyChange = {
  id: number
  kind: ChangeKind
  status: ChangeStatus
  base_version: number
  rollback_to: number | null
  reason: string
  created_by: StaffRef
  created_at: string
  updated_at: string
  submitted_at: string | null
  decided_by: StaffRef
  decided_at: string | null
  decision_note: string | null
  applied_version: number | null
  mine: boolean
  can_decide: boolean
  stale: boolean
  diff: PolicyDiff
  effective?: PolicyDiff | null
}

export type PolicyDraft = {
  id: number
  base_version: number
  created_at: string
  updated_at: string
  diff: PolicyDiff
}

export type PolicyState = {
  four_eyes: boolean
  current: PolicyVersion
  draft: PolicyDraft | null
  pending: number
  pending_mine: number
  pending_to_review: number
}

export type SimOutcome = { action: ContentAction; categories: string[] }

export type SimItem = {
  type: 'post' | 'comment' | 'message'
  id: string
  surface: TestSurface
  excerpt: string
  created_at: string
  current: SimOutcome
  draft: SimOutcome
}

export type ImageAction = 'allow' | 'hold' | 'block'

export type Simulation = {
  target: { kind: 'draft' | 'change' | 'version'; id: number; summary: PolicyDiff }
  sample: { surface: TestSurface; current: SimOutcome; draft: SimOutcome } | null
  content: {
    days: number
    limit: number
    scanned: number
    current: Record<ContentAction, number>
    draft: Record<ContentAction, number>
    changed: number
    stricter: number
    looser: number
    items: SimItem[]
  }
  images: {
    scanned: number
    current: Record<ImageAction, number>
    draft: Record<ImageAction, number>
    changed: number
  }
}

export type SimTarget =
  { kind: 'draft' } | { kind: 'change'; id: number } | { kind: 'version'; version: number }

export type SimInput = { target: SimTarget; text: string; surface: TestSurface; days: number }

export const simDays = [1, 3, 7, 14, 30] as const

export const REASON_MIN = 5
export const REASON_MAX = 500
export const VERSION_PAGE_SIZE = 20
