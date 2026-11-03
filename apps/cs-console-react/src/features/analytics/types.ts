export type DailyUsers = { date: string; users: number }

export type RetentionWeek = { week: number; active: number; pct: number }

export type RetentionCohort = { cohort_week: string; users: number; weeks: RetentionWeek[] }

export type DailyContent = { date: string; posts: number; comments: number }

export type StockMentions = { code: string; posts: number; authors: number }

export type OrderTaps = {
  taps: number
  users: number
  stock_tap_users: number
  conversion_pct: number | null
  by_source: Record<string, number>
  top_stocks: { code: string; taps: number }[]
}

export type CommunityAnalytics = {
  from: string
  to: string
  timezone: string
  generated_at: string
  active_users: {
    dau: DailyUsers[]
    avg_dau: number
    wau: number
    mau: number
    stickiness_pct: number | null
  }
  retention: RetentionCohort[]
  content: { posts: number; comments: number; messages: number; likes: number; daily: DailyContent[] }
  top_stocks: StockMentions[]
  events: Record<string, number>
  order_taps: OrderTaps
}

export const analyticsEvents = [
  'feed_open',
  'post_create',
  'comment_create',
  'message_send',
  'stock_tap',
  'order_tap',
  'search',
  'share_chart',
] as const
export type AnalyticsEvent = (typeof analyticsEvents)[number]

export const analyticsSources = [
  'feed',
  'post',
  'comment',
  'chat',
  'search',
  'profile',
  'notification',
  'stock',
  'hashtag',
  'trending',
  'push',
  'deep_link',
  'share',
  'other',
] as const
export type AnalyticsSource = (typeof analyticsSources)[number]

export const analyticsPresets = ['week', 'month', 'quarter'] as const
export type AnalyticsPreset = (typeof analyticsPresets)[number] | 'custom'

export const MAX_ANALYTICS_DAYS = 366
export const RETENTION_WEEKS = 8
