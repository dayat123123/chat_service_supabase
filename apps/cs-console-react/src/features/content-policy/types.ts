import type { StaffRef } from '@/features/community/types'

export const policyTabs = [
  'rules',
  'domains',
  'terms',
  'images',
  'manipulation',
  'tester',
  'versions',
] as const
export type PolicyTab = (typeof policyTabs)[number]

export const contentCategories = [
  'gambling',
  'porn',
  'phishing',
  'blocked',
  'shortener',
  'messenger',
  'phone',
  'promotion',
  'other_link',
] as const
export type ContentCategory = (typeof contentCategories)[number]

export const domainCategories = ['gambling', 'porn', 'phishing', 'blocked', 'shortener', 'messenger'] as const
export type DomainCategory = (typeof domainCategories)[number]

export const contentActions = ['allow', 'censor', 'hold', 'block'] as const
export type ContentAction = (typeof contentActions)[number]

export const contentScopes = ['public', 'all'] as const
export type ContentScope = (typeof contentScopes)[number]

export type DomainMatch = 'domain' | 'keyword'

export type ContentRule = {
  category: ContentCategory
  action: ContentAction
  scope: ContentScope
  updated_at: string
  updated_by: StaffRef
}

export type BlockedDomain = {
  domain: string
  match: DomainMatch
  category: DomainCategory
  action: ContentAction | null
  note: string | null
  created_at: string
}

export type AllowedDomain = { domain: string; note: string | null; created_at: string }

export type ContentRules = {
  categories: ContentRule[]
  blocked_domains: BlockedDomain[]
  allowed_domains: AllowedDomain[]
  allowlist: { term: string; created_at: string }[]
  promo_phrases: { phrase: string; created_at: string }[]
  new_account_days: number
}

export type BlockedDraft = {
  domain: string
  match: DomainMatch
  category: DomainCategory
  action: ContentAction | null
  note: string | null
}

export const imageCategories = ['porn', 'hentai', 'sexy', 'drawings', 'neutral'] as const
export type ImageCategory = (typeof imageCategories)[number]

export type ImageLimits = { hold?: number; block?: number }

export type ImageThresholds = {
  revision: number
  thresholds: Partial<Record<ImageCategory, ImageLimits>>
  categories: string[]
  updated_at: string
  updated_by: string | null
}

export const testSurfaces = ['post', 'comment', 'stock', 'group', 'direct'] as const
export type TestSurface = (typeof testSurfaces)[number]

export type ContentTest = {
  action: ContentAction
  categories: string[]
  links: boolean
  body: string
  banned_words: 'allow' | 'censor' | 'block'
  normalized: string
}

export type ManipulationSettings = Record<string, unknown>

export const manipulationGroups = ['spike', 'newAccounts', 'coordinated', 'auto', 'busy'] as const
export type ManipulationGroup = (typeof manipulationGroups)[number]

export type NumberSettingId =
  | 'spikeFactor'
  | 'spikeMin'
  | 'baselineDays'
  | 'newShare'
  | 'newMin'
  | 'newAge'
  | 'similarity'
  | 'similarAuthors'
  | 'similarWindow'
  | 'autoSlowSeconds'
  | 'autoSlowMinutes'
  | 'busySlow'

export type NumberSetting = {
  key: string
  id: NumberSettingId
  group: ManipulationGroup
  min: number
  max: number
  integer: boolean
  percent?: boolean
}

export const numberSettings: NumberSetting[] = [
  { key: 'manipulation.spike_factor', id: 'spikeFactor', group: 'spike', min: 1.5, max: 100, integer: false },
  {
    key: 'manipulation.spike_min_mentions',
    id: 'spikeMin',
    group: 'spike',
    min: 1,
    max: 100000,
    integer: true,
  },
  { key: 'manipulation.baseline_days', id: 'baselineDays', group: 'spike', min: 1, max: 60, integer: true },
  {
    key: 'manipulation.new_account_share',
    id: 'newShare',
    group: 'newAccounts',
    min: 0.1,
    max: 1,
    integer: false,
    percent: true,
  },
  {
    key: 'manipulation.new_account_min_mentions',
    id: 'newMin',
    group: 'newAccounts',
    min: 1,
    max: 100000,
    integer: true,
  },
  {
    key: 'manipulation.new_account_age_days',
    id: 'newAge',
    group: 'newAccounts',
    min: 1,
    max: 90,
    integer: true,
  },
  {
    key: 'manipulation.similarity',
    id: 'similarity',
    group: 'coordinated',
    min: 0.3,
    max: 1,
    integer: false,
    percent: true,
  },
  {
    key: 'manipulation.similar_min_authors',
    id: 'similarAuthors',
    group: 'coordinated',
    min: 2,
    max: 1000,
    integer: true,
  },
  {
    key: 'manipulation.similar_window_minutes',
    id: 'similarWindow',
    group: 'coordinated',
    min: 5,
    max: 1440,
    integer: true,
  },
  {
    key: 'manipulation.auto_slow_mode_seconds',
    id: 'autoSlowSeconds',
    group: 'auto',
    min: 0,
    max: 3600,
    integer: true,
  },
  {
    key: 'manipulation.auto_slow_mode_minutes',
    id: 'autoSlowMinutes',
    group: 'auto',
    min: 1,
    max: 1440,
    integer: true,
  },
  { key: 'rooms.busy_slow_mode', id: 'busySlow', group: 'busy', min: 0, max: 300, integer: true },
]

export const booleanSettings = [
  { key: 'manipulation.auto_slow_mode', id: 'autoSlow' },
  { key: 'manipulation.auto_hold_similar', id: 'autoHold' },
] as const

export const BUSY_WINDOWS_KEY = 'rooms.busy_windows'
export const MAX_BUSY_WINDOWS = 6
export const NOTE_MAX = 200
export const TEST_TEXT_MAX = 4000
export const NEW_ACCOUNT_DAYS_MAX = 30
export const THRESHOLD_NOTE_MAX = 500
