import i18n from '@/i18n'
import { moderationErrorText } from '@/lib/error-text'
import { toApiError } from '@/lib/errors'

import {
  roomModProblems,
  roomModSettingKeys,
  roomModSettingRanges,
  type RoomModAction,
  type RoomModProblem,
  type RoomModSettingKey,
  type RoomModSettings,
} from './types'

const roomModCodes = [
  'not_eligible',
  'already_moderator',
  'room_moderator_limit',
  'user_moderator_limit',
  'moderator_not_found',
  'action_not_found',
  'action_undone',
  'nothing_to_undo',
  'undo_not_supported',
  'role_forbidden',
] as const

type RoomModCode = (typeof roomModCodes)[number]

const isRoomModCode = (code: string): code is RoomModCode =>
  (roomModCodes as readonly string[]).includes(code)

export function roomModErrorText(error: unknown): string {
  const e = toApiError(error)
  if (e.code === 'not_eligible') {
    const problems = parseProblems(e.detail)
    if (problems.length > 0) {
      return i18n.t('moderation.roomMods.errors.not_eligible_with', {
        reasons: problems.map((problem) => i18n.t(`moderation.roomMods.problems.${problem}`)).join(', '),
      })
    }
  }
  return isRoomModCode(e.code) ? i18n.t(`moderation.roomMods.errors.${e.code}`) : moderationErrorText(error)
}

export function parseProblems(detail: string | null | undefined): RoomModProblem[] {
  return (detail ?? '')
    .split(',')
    .map((part) => part.trim())
    .filter((part): part is RoomModProblem => (roomModProblems as readonly string[]).includes(part))
}

export function canEditRoomModSettings(roles: readonly string[]): boolean {
  return roles.includes('compliance') || roles.includes('cs_super_admin')
}

export function settingsDraft(settings: RoomModSettings): Record<RoomModSettingKey, string> {
  return Object.fromEntries(roomModSettingKeys.map((key) => [key, String(settings[key] ?? '')])) as Record<
    RoomModSettingKey,
    string
  >
}

export function settingsChanges(
  settings: RoomModSettings,
  draft: Record<RoomModSettingKey, string>,
): { changes: Partial<RoomModSettings>; invalid: RoomModSettingKey[] } {
  const changes: Partial<RoomModSettings> = {}
  const invalid: RoomModSettingKey[] = []
  for (const key of roomModSettingKeys) {
    const text = draft[key].trim()
    const value = /^\d+$/.test(text) ? Number(text) : Number.NaN
    const [min, max] = roomModSettingRanges[key]
    if (!Number.isInteger(value) || value < min || value > max) invalid.push(key)
    else if (value !== Number(settings[key])) changes[key] = value
  }
  return { changes, invalid }
}

export function userLabel(user: { display_name: string | null; username: string | null } | null): string {
  if (!user) return '–'
  return user.display_name ?? (user.username ? `@${user.username}` : '–')
}

export type ActionState = 'undone' | 'active' | 'expired' | 'done'

export function actionState(action: RoomModAction): ActionState {
  if (action.undone_at) return 'undone'
  if (action.action === 'mute') return action.mute_active ? 'active' : 'expired'
  if (action.action === 'hide') return action.can_undo ? 'active' : 'done'
  return 'done'
}
