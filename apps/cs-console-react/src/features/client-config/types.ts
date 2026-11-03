import type { StaffRef } from '@/features/community/types'

export const appPlatforms = ['android', 'ios', 'web', 'windows', 'macos', 'linux'] as const
export type AppPlatform = (typeof appPlatforms)[number]

export type KillSwitch = {
  social_enabled: boolean
  reason: string | null
  changed_by: StaffRef
  changed_at: string | null
}

export type FeatureFlag = {
  key: string
  enabled: boolean
  percentage: number
  user_ids: string[]
  platforms: AppPlatform[]
  min_app_version: string | null
  description: string | null
  updated_by: StaffRef
  updated_at: string
}

export type MinVersion = {
  platform: AppPlatform
  min_version: string | null
  updated_by: StaffRef
  updated_at: string
}

export type ClientConfig = {
  kill_switch: KillSwitch
  flags: FeatureFlag[]
  min_versions: MinVersion[]
}

export type FlagDraft = {
  key: string
  enabled: boolean
  percentage: number
  user_ids: string[]
  platforms: AppPlatform[]
  min_app_version: string | null
  description: string | null
}

export const KILL_REASON_MIN = 10
export const KILL_REASON_MAX = 500
export const FLAG_DESCRIPTION_MAX = 300
export const FLAG_USERS_MAX = 1000
export const RESERVED_FLAG = 'social.enabled'
