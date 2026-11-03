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

export const KILL_REASON_MIN = 10
export const KILL_REASON_MAX = 500

export const knownFlags = [
  'search',
  'trending',
  'bookmarks',
  'post_edit',
  'message_reactions',
  'share_post_to_chat',
  'notification_prefs',
  'analytics',
] as const
export type KnownFlag = (typeof knownFlags)[number]

export type FeatureRow = {
  key: KnownFlag
  enabled: boolean
  updated_by: StaffRef
  updated_at: string | null
}

export const bannerLevels = ['info', 'warning', 'critical'] as const
export type BannerLevel = (typeof bannerLevels)[number]

export const bannerStatuses = ['active', 'scheduled', 'ended'] as const
export type BannerStatus = (typeof bannerStatuses)[number]

export type AppBanner = {
  id: string
  title: string
  body: string
  link_url: string | null
  level: BannerLevel
  starts_at: string
  ends_at: string | null
  platforms: AppPlatform[]
  min_app_version: string | null
  max_app_version: string | null
  dismissible: boolean
  priority: number
  status: BannerStatus
  created_by: StaffRef
  updated_by: StaffRef
  created_at: string
  updated_at: string
}

export type BannerDraft = {
  title: string
  body: string
  link_url: string | null
  level: BannerLevel
  starts_at: string | null
  ends_at: string | null
  platforms: AppPlatform[]
  min_app_version: string | null
  max_app_version: string | null
  dismissible: boolean
  priority: number
}

export const BANNER_TITLE_MAX = 80
export const BANNER_BODY_MAX = 300
export const BANNER_LINK_MAX = 500
export const BANNER_PRIORITY_MAX = 1000
