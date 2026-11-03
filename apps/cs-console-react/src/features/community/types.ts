import type { PushState } from '@/features/push/types'

export const communityPermissions = [
  'community.post',
  'community.publish',
  'community.moderate',
  'community.sanction',
  'community.accounts',
] as const
export type CommunityPermission = (typeof communityPermissions)[number]

export const communityTabs = ['stream', 'notifications', 'moderation', 'rooms', 'accounts'] as const
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
  push_state: PushState
}

export const MAX_POST_BODY = 2000
export const MAX_POST_IMAGES = 4
export const MAX_AVATAR_BYTES = 2 * 1024 * 1024

export const moderationQueues = ['reports', 'held', 'media', 'alerts', 'appeals'] as const
export type ModerationQueue = (typeof moderationQueues)[number]

export type HeldTarget = 'post' | 'comment' | 'message'
export type HeldDecision = 'approve' | 'hide' | 'remove'

export type HeldContent = {
  target_type: HeldTarget
  target_id: string
  excerpt: string | null
  attachments: number
  stock_code: string | null
  created_at: string
  categories: string[]
  source: 'policy' | 'manipulation' | 'staff'
  alert_id: string | null
  author: {
    id: string | null
    username: string | null
    display_name: string | null
    trust_level: number | null
    new_account: boolean
  }
}

export const mediaStatuses = ['pending', 'approved', 'removed'] as const
export type MediaStatus = (typeof mediaStatuses)[number]

export type MediaUse = {
  type: 'post' | 'message'
  id: string
  room_id?: string
  room_type?: string
  created_at: string
  deleted: boolean
}

export type MediaReview = {
  id: number
  bucket: string
  path: string
  status: MediaStatus
  category: string
  score: number
  scores: Record<string, number>
  model: string
  thresholds_revision: number | null
  created_at: string
  decided_at: string | null
  decided_by: string | null
  note: string | null
  stripped: { type: string; id: string; room_id?: string }[]
  object_exists: boolean
  uploader: { id: string; username: string | null; display_name: string | null; deleted: boolean }
  used_in: MediaUse[]
}

export type MediaPage = { items: MediaReview[]; next_cursor: number | null; pending: number }

export const alertStatuses = ['open', 'reviewed', 'dismissed'] as const
export type AlertStatus = (typeof alertStatuses)[number]
export type AlertKind = 'mention_spike' | 'new_account_concentration' | 'coordinated_posts'

export type ManipulationAlert = {
  id: string
  stock: string
  kind: AlertKind
  score: number
  evidence: Record<string, unknown>
  status: AlertStatus
  auto_actions: { slow_mode?: { seconds: number; until: string | null }; held_posts?: string[] }
  detected_at: string
  last_detected_at: string
  reviewed_by: StaffRef
  reviewed_at: string | null
  review_note: string | null
  released_posts?: number
}

export const appealStatuses = ['pending', 'accepted', 'rejected'] as const
export type AppealStatus = (typeof appealStatuses)[number]
export type AppealTarget = 'sanction' | 'post' | 'comment' | 'message'

export type AppealSanction = {
  kind: 'warning' | 'mute' | 'ban'
  category: string | null
  reason: string
  starts_at: string
  ends_at: string | null
  revoked_at: string | null
  active: boolean
}

export type AppealContent = { state: string; excerpt: string | null; decided_at: string | null }

export type Appeal = {
  id: string
  status: AppealStatus
  target_type: AppealTarget
  target_id: string
  reason: string
  created_at: string
  decided_at: string | null
  decision_note: string | null
  user: {
    id: string
    username: string
    display_name: string | null
    avatar_url: string | null
    banned: boolean
  }
  target: AppealSanction | AppealContent | null
  original_decider: { id: string; name: string } | null
  decided_by: StaffRef
  can_decide: boolean
}

export type SlowSource = 'manual' | 'alert' | 'schedule'

export type PinnedMessage = {
  id: string
  room_id: string
  sender_id: string | null
  sender_username: string | null
  sender_display_name: string | null
  body: string
  created_at: string
}

export type RoomState = {
  room_id: string
  stock_code: string
  slow_mode: { seconds: number; until: string | null; source: SlowSource | null }
  wait_seconds: number
  pinned_message: PinnedMessage | null
  pinned_at: string | null
  override: {
    seconds: number
    until: string | null
    source: SlowSource | null
    alert_id: string | null
    updated_by: StaffRef
    updated_at: string
    pinned_by: StaffRef
  } | null
  open_alerts: ManipulationAlert[]
}

export type EditVersion = { body: string; edited_at: string; edited_by: string | null }

export type RoomMessage = {
  id: string
  created_at: string
  edited_at: string | null
  body: string
  attachments: number
  moderation_status: string
  sender: { id: string; username: string | null; display_name: string | null }
}

export type RoomMessages = { room_id: string; items: RoomMessage[] }

export type RoomCursor = Pick<RoomMessage, 'created_at' | 'id'>

export type ContentType = 'post' | 'comment' | 'message'

export type ContentTarget = { type: ContentType; id: string }

export type ContentMeta = ContentTarget & {
  edited_at: string | null
  moderation_status: string
  deleted: boolean
}

export type ContentAuthor = { id: string; username: string | null; display_name: string | null }

export type CommunityContent = {
  type: ContentType
  id: string
  body: string
  attachments?: unknown[] | null
  sentiment?: string | null
  post_id?: string
  parent_id?: string | null
  created_at: string
  edited_at: string | null
  deleted_at: string | null
  moderation_status: string
  like_count?: number
  comment_count?: number
  room?: { id: string; type: string; name: string | null; stock_code: string | null }
  author: ContentAuthor
}

export type ZeroToleranceResult = CommunityUser & {
  hidden: { posts: number; comments: number; messages: number }
}

export const SLOW_MODE_MAX = 3600
export const APPEAL_NOTE_MAX = 1000
export const NOTE_MIN = 5
export const NOTE_MAX = 500
