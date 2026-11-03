import { describe, expect, it } from 'vitest'

import { ApiError } from '@/lib/errors'

import {
  actionState,
  canEditRoomModSettings,
  parseProblems,
  roomModErrorText,
  settingsChanges,
  settingsDraft,
  userLabel,
} from './logic'
import type { RoomModAction, RoomModSettings } from './types'

const settings: RoomModSettings = {
  'room_mods.min_trust_level': 2,
  'room_mods.sanction_free_days': 90,
  'room_mods.max_mute_hours': 24,
  'room_mods.max_per_room': 10,
  'room_mods.max_rooms_per_user': 3,
}

const base: RoomModAction = {
  id: 'a-1',
  room_id: 'r-1',
  stock_code: 'BBCA',
  action: 'hide',
  reason: 'spam',
  note: null,
  created_at: '2026-11-03T02:00:00.000Z',
  mute_until: null,
  mute_active: false,
  moderator: null,
  moderator_active: true,
  target: null,
  message: null,
  report: null,
  appeal: null,
  undone_at: null,
  undone_by: null,
  undo_note: null,
  can_undo: true,
}

describe('room moderator logic', () => {
  it('parses eligibility problems from the error detail', () => {
    expect(parseProblems('trust_level,recent_sanction,unknown')).toEqual(['trust_level', 'recent_sanction'])
    expect(parseProblems(undefined)).toEqual([])
    expect(roomModErrorText(new ApiError('not_eligible', 'trust_level', 400))).toBe(
      'Nasabah ini belum memenuhi syarat: trust level kurang.',
    )
    expect(roomModErrorText(new ApiError('already_moderator', 'x', 409))).toBe(
      'Nasabah ini sudah menjadi moderator room ini.',
    )
  })

  it('lets only Compliance or Super Admin edit the requirements', () => {
    expect(canEditRoomModSettings(['community'])).toBe(false)
    expect(canEditRoomModSettings(['community', 'compliance'])).toBe(true)
    expect(canEditRoomModSettings(['cs_super_admin'])).toBe(true)
  })

  it('validates settings and sends only changed values', () => {
    const draft = settingsDraft(settings)
    expect(settingsChanges(settings, draft)).toEqual({ changes: {}, invalid: [] })
    expect(
      settingsChanges(settings, {
        ...draft,
        'room_mods.min_trust_level': '3',
        'room_mods.max_mute_hours': '48',
      }),
    ).toEqual({ changes: { 'room_mods.min_trust_level': 3 }, invalid: ['room_mods.max_mute_hours'] })
    expect(settingsChanges(settings, { ...draft, 'room_mods.max_per_room': '2.5' }).invalid).toEqual([
      'room_mods.max_per_room',
    ])
  })

  it('describes the state of each action', () => {
    expect(actionState(base)).toBe('active')
    expect(actionState({ ...base, can_undo: false })).toBe('done')
    expect(actionState({ ...base, undone_at: '2026-11-03T03:00:00.000Z' })).toBe('undone')
    expect(actionState({ ...base, action: 'mute', mute_until: base.created_at, mute_active: false })).toBe(
      'expired',
    )
    expect(actionState({ ...base, action: 'escalate', can_undo: false })).toBe('done')
    expect(userLabel({ display_name: null, username: 'budi' })).toBe('@budi')
    expect(userLabel(null)).toBe('–')
  })
})
