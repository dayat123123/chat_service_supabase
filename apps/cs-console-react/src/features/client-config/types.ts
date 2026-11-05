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

export const bannerDisplays = ['strip', 'popup'] as const
export type BannerDisplay = (typeof bannerDisplays)[number]

export const bannerFrequencies = ['once', 'daily', 'every_open'] as const
export type BannerFrequency = (typeof bannerFrequencies)[number]

export const bannerAudiences = ['all', 'new_users'] as const
export type BannerAudience = (typeof bannerAudiences)[number]

export const bannerRatios = ['portrait', 'square'] as const
export type BannerRatio = (typeof bannerRatios)[number]

export type BannerStats = {
  impressions: number
  clicks: number
  dismissals: number
  unique_viewers: number
  ctr: number | null
}

export type BannerDayStats = {
  day: string
  impressions: number
  clicks: number
  dismissals: number
  ctr: number | null
}

export type BannerStatsDetail = BannerStats & { id: string; days: BannerDayStats[] }

export type BannerSettings = {
  deep_link_schemes: string[]
  forbidden_schemes: string[]
  max_schemes: number
  updated_at: string | null
  updated_by: StaffRef
}

export type AppBanner = {
  id: string
  title: string
  body: string
  link_url: string | null
  level: BannerLevel
  display: BannerDisplay
  image_path: string | null
  image_url: string | null
  cta_label: string | null
  frequency: BannerFrequency
  audience: BannerAudience
  audience_days: number
  starts_at: string
  ends_at: string | null
  platforms: AppPlatform[]
  min_app_version: string | null
  max_app_version: string | null
  dismissible: boolean
  priority: number
  status: BannerStatus
  stats: BannerStats
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
  display: BannerDisplay
  image_url: string | null
  cta_label: string | null
  frequency: BannerFrequency
  audience: BannerAudience
  audience_days: number
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
export const BANNER_CTA_MAX = 24
export const BANNER_AUDIENCE_DAYS_MAX = 90
export const BANNER_IMAGE_MAX_BYTES = 2 * 1024 * 1024
