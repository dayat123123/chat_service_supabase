import type { StaffRef } from '../types'

export const roomModProblems = [
  'user_not_found',
  'protected_account',
  'trust_level',
  'zero_tolerance',
  'recent_sanction',
] as const

export type RoomModProblem = (typeof roomModProblems)[number]

export const roomModSettingKeys = [
  'room_mods.min_trust_level',
  'room_mods.sanction_free_days',
  'room_mods.max_mute_hours',
  'room_mods.max_per_room',
  'room_mods.max_rooms_per_user',
] as const

export type RoomModSettingKey = (typeof roomModSettingKeys)[number]

export type RoomModSettings = Record<RoomModSettingKey, number>

export const roomModSettingRanges: Record<RoomModSettingKey, readonly [number, number]> = {
  'room_mods.min_trust_level': [1, 3],
  'room_mods.sanction_free_days': [0, 365],
  'room_mods.max_mute_hours': [1, 24],
  'room_mods.max_per_room': [1, 50],
  'room_mods.max_rooms_per_user': [1, 20],
}

export type RoomModUser = {
  id: string
  username: string | null
  display_name: string | null
  avatar_url: string | null
  trust_level: number
  is_verified?: boolean
  deleted: boolean
  is_official?: boolean
  is_staff?: boolean
  banned?: boolean
  muted?: boolean
}

export type RoomModerator = {
  id: string
  room_id: string
  user: RoomModUser
  note: string | null
  appointed_by: StaffRef
  appointed_at: string
  removed_at: string | null
  removed_by: StaffRef
  remove_reason: string | null
  problems: RoomModProblem[]
  actions_7d: number
  undone_7d: number
}

export type RoomModerators = {
  room_id: string | null
  stock_code: string
  moderators: RoomModerator[]
  removed: RoomModerator[]
  settings: RoomModSettings
}

export type RoomModCandidate = RoomModUser & {
  problems: RoomModProblem[]
  eligible: boolean
  is_moderator: boolean
  moderated_rooms: number
  member: boolean
}

export type RoomModActionKind = 'hide' | 'mute' | 'escalate'

export type RoomModAction = {
  id: string
  room_id: string
  stock_code: string | null
  action: RoomModActionKind
  reason: string
  note: string | null
  created_at: string
  mute_until: string | null
  mute_active: boolean
  moderator: RoomModUser | null
  moderator_active: boolean
  target: RoomModUser | null
  message: {
    id: string
    excerpt: string | null
    attachments: number
    moderation_status: string
    deleted: boolean
    created_at: string
  } | null
  report: { id: string; status: string } | null
  appeal: { id: string; status: string } | null
  undone_at: string | null
  undone_by: StaffRef
  undo_note: string | null
  can_undo: boolean
}

export type RoomModActionCursor = { created_at: string; id: string }

export type RoomModActionPage = { items: RoomModAction[] }
