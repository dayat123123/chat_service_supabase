export const communityPermissions = [
  'community.post',
  'community.publish',
  'community.moderate',
  'community.sanction',
  'community.accounts',
] as const
export type CommunityPermission = (typeof communityPermissions)[number]

export const communityTabs = ['stream', 'notifications', 'moderation', 'accounts'] as const
export type CommunityTab = (typeof communityTabs)[number]

export type AccountRef = {
  id: string
  username: string
  display_name: string | null
  avatar_url: string | null
}

export type StaffRef = { id: string; name: string | null } | null

export type OfficialAccount = AccountRef & {
  bio: string | null
  follower_count: number
  post_count: number
  created_at: string
  created_by: string | null
  disabled_at: string | null
}

export type PostAttachment = { path: string; mime?: string; width?: number | null; height?: number | null }

export const postStatuses = [
  'draft',
  'pending',
  'scheduled',
  'published',
  'rejected',
  'cancelled',
  'failed',
] as const
export type PostStatus = (typeof postStatuses)[number]

export type PostKind = 'post' | 'announcement'
export type PinScope = 'global' | 'stock'

export type CommunityPost = {
  id: string
  account: AccountRef
  kind: PostKind
  title: string | null
  body: string
  attachments: PostAttachment[]
  pin_scope: PinScope | null
  pin_stock: string | null
  pin_until: string | null
  pinned: boolean
  notify: boolean
  status: PostStatus
  publish_at: string | null
  post_id: string | null
  post: { like_count: number; comment_count: number; deleted: boolean; moderation_status: string } | null
  campaign: { id: string; status: CampaignStatus; recipients: number } | null
  created_by: StaffRef
  created_at: string
  updated_at: string
  submitted_at: string | null
  reviewed_by: StaffRef
  reviewed_at: string | null
  review_note: string | null
  published_at: string | null
  error: string | null
  version: number
}

export type PostDraft = {
  account_id: string
  kind: PostKind
  title: string | null
  body: string
  attachments: PostAttachment[]
  pin_scope: PinScope | null
  pin_stock: string | null
  pin_until: string | null
  notify: boolean
  publish_at: string | null
}

export const campaignStatuses = [
  'draft',
  'pending',
  'scheduled',
  'sending',
  'sent',
  'rejected',
  'cancelled',
] as const
export type CampaignStatus = (typeof campaignStatuses)[number]

export type Audience = 'all' | 'stock'

export type Campaign = {
  id: string
  account: AccountRef
  title: string
  body: string
  link_post: { id: string; title: string | null; body: string; post_id: string | null } | null
  link_url: string | null
  audience: Audience
  audience_stock: string | null
  status: CampaignStatus
  send_at: string | null
  created_by: StaffRef
  created_at: string
  updated_at: string
  submitted_at: string | null
  reviewed_by: StaffRef
  reviewed_at: string | null
  review_note: string | null
  started_at: string | null
  finished_at: string | null
  recipients: number
  version: number
}

export type CampaignDraft = {
  account_id: string
  title: string
  body: string
  link_post_id: string | null
  link_url: string | null
  audience: Audience
  audience_stock: string | null
  send_at: string | null
}

export const reportStatuses = ['open', 'resolved', 'dismissed'] as const
export type ReportStatus = (typeof reportStatuses)[number]

export type ReportTarget = 'post' | 'comment' | 'message' | 'user'
export type ReportAction = 'hide' | 'remove' | 'restore' | 'approve' | 'dismiss'

export type ReportRow = {
  target_type: ReportTarget
  target_id: string
  report_count: number
  reasons: string[]
  priority: number
  first_reported_at: string
  last_reported_at: string
  author_id: string | null
  author_username: string | null
  author_display_name: string | null
  author_is_official: boolean
  excerpt: string | null
  target_status: string
}

export type CommunityUserRow = {
  id: string
  username: string
  display_name: string | null
  avatar_url: string | null
  is_verified: boolean
  trust_level: number
  created_at: string
  deleted: boolean
  is_official: boolean
  is_staff: boolean
  banned: boolean
  muted: boolean
}

export type Sanction = {
  id: string
  kind: 'warning' | 'mute' | 'ban'
  category: string | null
  reason: string
  starts_at: string
  ends_at: string | null
  created_at: string
  created_by: string | null
  revoked_at: string | null
  revoke_reason: string | null
  active: boolean
}

export type CommunityUser = {
  profile: CommunityUserRow & { bio: string | null }
  counts: { posts: number; comments: number; reports_against: number; reports_made: number }
  recent_posts: { id: string; body: string; moderation_status: string; created_at: string }[]
  recent_comments: {
    id: string
    post_id: string
    body: string
    moderation_status: string
    created_at: string
  }[]
  sanctions: Sanction[]
}

export type CommunityOverview = {
  pending_posts: number
  scheduled_posts: number
  pending_campaigns: number
  open_reports: number
  accounts: number
  four_eyes: boolean
  push_ready: boolean
}

export const MAX_POST_BODY = 2000
export const MAX_POST_IMAGES = 4
export const MAX_AVATAR_BYTES = 2 * 1024 * 1024
