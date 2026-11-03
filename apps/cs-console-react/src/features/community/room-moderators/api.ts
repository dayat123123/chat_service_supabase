import { rpc } from '@/lib/supabase'

import type {
  RoomModAction,
  RoomModActionCursor,
  RoomModActionPage,
  RoomModCandidate,
  RoomModerators,
  RoomModSettings,
} from './types'

export const ROOM_MOD_PAGE = 30

export const roomModeratorsApi = {
  list: (code: string) => rpc<RoomModerators>('community_room_moderators', { p_code: code }),
  candidates: (code: string, query: string) =>
    rpc<RoomModCandidate[]>('community_room_moderator_candidates', { p_code: code, p_query: query }),
  appoint: (code: string, userId: string, note: string | null) =>
    rpc<RoomModerators>('community_appoint_room_moderator', {
      p_code: code,
      p_user_id: userId,
      p_note: note,
    }),
  remove: (code: string, userId: string, reason: string) =>
    rpc<RoomModerators>('community_remove_room_moderator', {
      p_code: code,
      p_user_id: userId,
      p_reason: reason,
    }),
  actions: (code: string | null, before: RoomModActionCursor | null) =>
    rpc<RoomModActionPage>('community_room_moderator_actions', {
      p_code: code,
      p_limit: ROOM_MOD_PAGE,
      p_before: before?.created_at ?? null,
      p_before_id: before?.id ?? null,
    }),
  undo: (id: string, note: string) =>
    rpc<RoomModAction>('community_undo_room_moderator_action', { p_id: id, p_note: note }),
  settings: () => rpc<RoomModSettings>('community_room_moderator_settings'),
  saveSettings: (values: Partial<RoomModSettings>) =>
    rpc<RoomModSettings>('community_set_room_moderator_settings', { p_values: values }),
}
