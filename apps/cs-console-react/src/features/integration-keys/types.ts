import type { AccountRef, StaffRef } from '@/features/community/types'

export const keyScopes = ['notify', 'bot_post'] as const
export type KeyScope = (typeof keyScopes)[number]

export type KeyStatus = 'active' | 'disabled' | 'revoked'

export type IntegrationKey = {
  id: string
  name: string
  prefix: string
  hint: string
  scopes: KeyScope[]
  official_account: AccountRef | null
  allowed_cidrs: string[]
  rate_limit_per_minute: number
  status: KeyStatus
  created_by: StaffRef
  created_at: string
  updated_at: string
  disabled_at: string | null
  revoked_at: string | null
  revoked_by: StaffRef
  revoke_reason: string | null
  last_used_at: string | null
  last_used_ip: string | null
}

export type KeyDraft = {
  name: string
  scopes: KeyScope[]
  official_account_id: string | null
  allowed_cidrs: string[]
  rate_limit_per_minute: number
  enabled: boolean
}

export type CreatedKey = { key: IntegrationKey; secret: string }

export type PushOutcome = { sent: number; failed: number; invalid: number; expired: number; pending: number }

export type KeyStats = {
  id: string
  name: string
  prefix: string
  status: KeyStatus
  last_used_at: string | null
  received: number
  queued: number
  devices: number
  no_recipient: number
  duplicate: number
  invalid: number
  posts: number
  posts_rejected: number
  push: PushOutcome
}

export type DailyIntegration = {
  day: string
  received: number
  queued: number
  no_recipient: number
  posts: number
}

export type KeyDailyRow = {
  day: string
  received: number
  queued: number
  devices: number
  no_recipient: number
  duplicate: number
  invalid: number
  posts: number
  posts_rejected: number
}

export type KeyDaily = { key_id: string; name: string; prefix: string; days: KeyDailyRow[] }

export type IntegrationStats = {
  days: number
  from: string
  keys: KeyStats[]
  daily: DailyIntegration[]
  linked: { accounts: number; profiles: number }
}

export const statsWindows = [7, 30, 90] as const
export type StatsWindow = (typeof statsWindows)[number]

export const KEY_NAME_MIN = 3
export const KEY_NAME_MAX = 80
export const RATE_LIMIT_MAX = 100_000
export const DEFAULT_RATE_LIMIT = 600
export const MAX_CIDRS = 20
export const REVOKE_REASON_MIN = 5
export const REVOKE_REASON_MAX = 500
