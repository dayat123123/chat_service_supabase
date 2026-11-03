import { fitImage } from '@/features/conversation/clipboard'
import { imageSize } from '@/features/conversation/api'
import { MAX_FILE_BYTES } from '@/features/conversation/types'
import { toApiError } from '@/lib/errors'
import { appEnv, rpc, supabase } from '@/lib/supabase'
import { uuid } from '@/lib/utils'

import { avatarPath } from './avatar-crop'
import type {
  Appeal,
  AlertStatus,
  AppealStatus,
  Campaign,
  CampaignDraft,
  CommunityOverview,
  CommunityPost,
  CommunityUser,
  CommunityContent,
  CommunityUserRow,
  ContentMeta,
  ContentTarget,
  ContentType,
  EditVersion,
  HeldContent,
  HeldDecision,
  HeldTarget,
  ManipulationAlert,
  MediaPage,
  MediaStatus,
  OfficialAccount,
  PinScope,
  PostAttachment,
  PostDraft,
  ReportAction,
  ReportRow,
  ReportStatus,
  ReportTarget,
  RoomMessages,
  RoomState,
  ZeroToleranceResult,
} from './types'
import { MAX_AVATAR_BYTES } from './types'

const extension: Record<string, string> = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
  'image/gif': 'gif',
}

function room(raw: RoomState): RoomState {
  return { ...raw, open_alerts: raw.open_alerts ?? [] }
}

function post(raw: CommunityPost): CommunityPost {
  return { ...raw, attachments: raw.attachments ?? [] }
}

export const communityApi = {
  overview: () => rpc<CommunityOverview>('community_overview'),
  accounts: () => rpc<OfficialAccount[]>('community_accounts'),
  saveAccount: (
    id: string | null,
    values: { username: string; display_name: string; bio: string | null; avatar_url: string | null },
  ) =>
    rpc<OfficialAccount>('community_save_account', {
      p_id: id,
      p_username: values.username,
      p_display_name: values.display_name,
      p_bio: values.bio,
      p_avatar_url: values.avatar_url,
    }),
  setAccountDisabled: (id: string, disabled: boolean) =>
    rpc<OfficialAccount>('community_set_account_disabled', { p_id: id, p_disabled: disabled }),
  findUsers: (query: string) => rpc<CommunityUserRow[]>('community_find_users', { p_query: query }),
  setVerified: (id: string, verified: boolean, reason: string) =>
    rpc<CommunityUserRow>('community_set_verified', {
      p_user_id: id,
      p_verified: verified,
      p_reason: reason,
    }),

  posts: async () => (await rpc<CommunityPost[]>('community_posts', { p_status: null })).map(post),
  savePost: async (id: string | null, draft: PostDraft, version: number | null) =>
    post(
      await rpc<CommunityPost>('community_save_post', {
        p_id: id,
        p_account_id: draft.account_id,
        p_kind: draft.kind,
        p_title: draft.title,
        p_body: draft.body,
        p_attachments: draft.attachments,
        p_pin_scope: draft.pin_scope,
        p_pin_stock: draft.pin_stock,
        p_pin_until: draft.pin_until,
        p_notify: draft.notify,
        p_publish_at: draft.publish_at,
        p_version: version,
      }),
    ),
  submitPost: async (id: string, version: number) =>
    post(await rpc<CommunityPost>('community_submit_post', { p_id: id, p_version: version })),
  reviewPost: async (id: string, approve: boolean, note: string | null, version: number) =>
    post(
      await rpc<CommunityPost>('community_review_post', {
        p_id: id,
        p_approve: approve,
        p_note: note,
        p_version: version,
      }),
    ),
  cancelPost: async (id: string, version: number) =>
    post(await rpc<CommunityPost>('community_cancel_post', { p_id: id, p_version: version })),
  pinPost: async (id: string, scope: PinScope | null, stock: string | null, until: string | null) =>
    post(
      await rpc<CommunityPost>('community_pin_post', {
        p_id: id,
        p_scope: scope,
        p_stock: stock,
        p_until: until,
      }),
    ),
  deletePost: async (id: string, reason: string) =>
    post(await rpc<CommunityPost>('community_delete_post', { p_id: id, p_reason: reason })),

  campaigns: () => rpc<Campaign[]>('community_campaigns', { p_status: null }),
  audienceSize: (audience: string, stock: string | null) =>
    rpc<number>('community_audience_size', { p_audience: audience, p_stock: stock }),
  saveCampaign: (id: string | null, draft: CampaignDraft, version: number | null) =>
    rpc<Campaign>('community_save_campaign', {
      p_id: id,
      p_account_id: draft.account_id,
      p_title: draft.title,
      p_body: draft.body,
      p_link_post_id: draft.link_post_id,
      p_link_url: draft.link_url,
      p_audience: draft.audience,
      p_audience_stock: draft.audience_stock,
      p_send_at: draft.send_at,
      p_version: version,
    }),
  submitCampaign: (id: string, version: number) =>
    rpc<Campaign>('community_submit_campaign', { p_id: id, p_version: version }),
  reviewCampaign: (id: string, approve: boolean, note: string | null, version: number) =>
    rpc<Campaign>('community_review_campaign', {
      p_id: id,
      p_approve: approve,
      p_note: note,
      p_version: version,
    }),
  cancelCampaign: (id: string, version: number) =>
    rpc<Campaign>('community_cancel_campaign', { p_id: id, p_version: version }),

  reports: (status: ReportStatus) =>
    rpc<ReportRow[]>('community_reports', { p_status: status, p_limit: 200 }),
  resolveReport: (type: ReportTarget, id: string, action: ReportAction, reason: string) =>
    rpc<unknown>('community_resolve_report', {
      p_target_type: type,
      p_target_id: id,
      p_action: action,
      p_reason: reason,
    }),
  user: (id: string) => rpc<CommunityUser>('community_user', { p_user_id: id }),
  sanction: (id: string, reason: string, kind: string | null, hours: number | null) =>
    rpc<CommunityUser>('community_sanction_user', {
      p_user_id: id,
      p_reason: reason,
      p_kind: kind,
      p_duration_hours: hours,
    }),
  revokeSanction: (id: string, reason: string) =>
    rpc<CommunityUser>('community_revoke_sanction', { p_sanction_id: id, p_reason: reason }),
  revokeSessions: (id: string, reason: string) =>
    rpc<CommunityUser>('community_revoke_sessions', { p_user_id: id, p_reason: reason }),

  held: async () =>
    (await rpc<HeldContent[]>('community_held_content', { p_limit: 200 })).map((row) => ({
      ...row,
      categories: row.categories ?? [],
    })),
  decideHeld: (type: HeldTarget, id: string, action: HeldDecision, reason: string) =>
    rpc<unknown>('community_resolve_report', {
      p_target_type: type,
      p_target_id: id,
      p_action: action,
      p_reason: reason,
    }),
  editHistory: async (type: 'post' | 'comment', id: string) =>
    (await rpc<EditVersion[] | null>('community_edit_history', { p_target_type: type, p_target_id: id })) ??
    [],
  media: async (status: MediaStatus, cursor: number | null): Promise<MediaPage> => {
    const raw = await rpc<MediaPage>('community_media_reviews', {
      p_status: status,
      p_cursor: cursor,
      p_limit: 20,
    })
    return {
      ...raw,
      items: (raw.items ?? []).map((item) => ({
        ...item,
        used_in: item.used_in ?? [],
        stripped: item.stripped ?? [],
        scores: item.scores ?? {},
      })),
    }
  },
  decideMedia: (id: number, decision: 'approve' | 'remove', note: string | null) =>
    rpc<unknown>('community_media_review_decide', { p_id: id, p_decision: decision, p_note: note }),
  mediaImage: async (bucket: string, path: string) => {
    const { data, error } = await supabase().storage.from(bucket).download(path)
    if (error) throw toApiError(error)
    return data
  },
  alerts: (status: AlertStatus, stock: string | null) =>
    rpc<ManipulationAlert[]>('community_manipulation_alerts', {
      p_status: status,
      p_stock: stock,
      p_limit: 200,
    }),
  reviewAlert: (id: string, status: 'reviewed' | 'dismissed', note: string) =>
    rpc<ManipulationAlert>('community_manipulation_review', { p_id: id, p_status: status, p_note: note }),
  appeals: (status: AppealStatus) => rpc<Appeal[]>('community_appeals', { p_status: status, p_limit: 200 }),
  decideAppeal: (id: string, accept: boolean, note: string) =>
    rpc<Appeal>('community_appeal_decide', { p_id: id, p_accept: accept, p_note: note }),
  zeroTolerance: (id: string, reason: string) =>
    rpc<ZeroToleranceResult>('community_zero_tolerance', { p_user_id: id, p_reason: reason }),
  roomState: async (code: string) => room(await rpc<RoomState>('community_room_state', { p_code: code })),
  setSlowMode: async (code: string, seconds: number, until: string | null) =>
    room(
      await rpc<RoomState>('community_room_settings', {
        p_code: code,
        p_slow_mode_seconds: seconds,
        p_until: until,
      }),
    ),
  roomMessages: async (code: string, before: string | null): Promise<RoomMessages> => {
    const raw = await rpc<RoomMessages>('community_room_messages', {
      p_code: code,
      p_limit: 30,
      p_before: before,
    })
    return { ...raw, items: raw.items ?? [] }
  },
  contentMeta: async (targets: ContentTarget[]) =>
    (await rpc<ContentMeta[] | null>('community_content_meta', { p_targets: targets })) ?? [],
  content: (type: ContentType, id: string) =>
    rpc<CommunityContent>('community_content', { p_type: type, p_id: id }),
  pinMessage: async (roomId: string, messageId: string | null) =>
    room(await rpc<RoomState>('community_pin_message', { p_room: roomId, p_message: messageId })),

  uploadPostImage: async (accountId: string, original: File): Promise<PostAttachment> => {
    const file = await fitImage(original, MAX_FILE_BYTES)
    const path = `posts/${accountId}/${uuid()}.${extension[file.type] ?? 'jpg'}`
    const { error } = await supabase()
      .storage.from('attachments')
      .upload(path, file, { contentType: file.type })
    if (error) throw toApiError(error)
    const size = await imageSize(file)
    return { path, mime: file.type, width: size.width, height: size.height }
  },
  uploadAvatar: async (accountId: string, photo: Blob) => {
    const original = photo instanceof File ? photo : new File([photo], 'avatar.jpg', { type: photo.type })
    const file = await fitImage(original, MAX_AVATAR_BYTES)
    const path = `${accountId}/avatar-${Date.now()}.${extension[file.type] ?? 'jpg'}`
    const { error } = await supabase().storage.from('avatars').upload(path, file, { contentType: file.type })
    if (error) throw toApiError(error)
    return `${appEnv().publicApiUrl ?? appEnv().supabaseUrl}/storage/v1/object/public/avatars/${path}`
  },
  removeAvatar: async (accountId: string, url: string) => {
    const path = avatarPath(url, accountId)
    if (!path) return
    const { error } = await supabase().storage.from('avatars').remove([path])
    if (error) throw toApiError(error)
  },
}
