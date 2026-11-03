import { screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import type { AgentProfile } from '@/features/presence/types'
import { agentFixture } from '@/test/fixtures'
import { renderWithProviders } from '@/test/render'
import { Toaster } from '@/test/toast'

import { roomModeratorsApi } from './api'
import { RoomModeratorsSection } from './room-moderators-section'
import type { RoomModAction, RoomModCandidate, RoomModerator, RoomModerators } from './types'

vi.mock('./api', () => ({
  ROOM_MOD_PAGE: 30,
  roomModeratorsApi: {
    list: vi.fn(),
    candidates: vi.fn(),
    appoint: vi.fn(),
    remove: vi.fn(),
    actions: vi.fn(),
    undo: vi.fn(),
    settings: vi.fn(),
    saveSettings: vi.fn(),
  },
}))

const staff: AgentProfile = {
  ...agentFixture,
  id: 'dodi',
  roles: ['community'],
  community_permissions: ['community.moderate'],
}

const moderator: RoomModerator = {
  id: 'rm-1',
  room_id: 'room-1',
  user: {
    id: 'u-mod',
    username: 'mod_bbca',
    display_name: 'Mod BBCA',
    avatar_url: null,
    trust_level: 2,
    deleted: false,
  },
  note: 'Aktif dan sopan',
  appointed_by: { id: 'dodi', name: 'Dodi' },
  appointed_at: '2026-11-03T01:00:00.000Z',
  removed_at: null,
  removed_by: null,
  remove_reason: null,
  problems: [],
  actions_7d: 2,
  undone_7d: 0,
}

const list: RoomModerators = {
  room_id: 'room-1',
  stock_code: 'BBCA',
  moderators: [moderator],
  removed: [],
  settings: {
    'room_mods.min_trust_level': 2,
    'room_mods.sanction_free_days': 90,
    'room_mods.max_mute_hours': 24,
    'room_mods.max_per_room': 10,
    'room_mods.max_rooms_per_user': 3,
  },
}

const hide: RoomModAction = {
  id: 'act-1',
  room_id: 'room-1',
  stock_code: 'BBCA',
  action: 'hide',
  reason: 'spam',
  note: 'Promosi grup',
  created_at: '2026-11-03T02:00:00.000Z',
  mute_until: null,
  mute_active: false,
  moderator: moderator.user,
  moderator_active: true,
  target: {
    id: 'u-1',
    username: 'budi',
    display_name: 'Budi',
    avatar_url: null,
    trust_level: 1,
    deleted: false,
  },
  message: {
    id: 'm-1',
    excerpt: 'Gabung grup sinyal sekarang',
    attachments: 0,
    moderation_status: 'hidden',
    deleted: false,
    created_at: '2026-11-03T01:59:00.000Z',
  },
  report: null,
  appeal: { id: 'ap-1', status: 'pending' },
  undone_at: null,
  undone_by: null,
  undo_note: null,
  can_undo: true,
}

const candidate = (overrides: Partial<RoomModCandidate>): RoomModCandidate => ({
  id: 'u-2',
  username: 'sari',
  display_name: 'Sari',
  avatar_url: null,
  trust_level: 2,
  deleted: false,
  problems: [],
  eligible: true,
  is_moderator: false,
  moderated_rooms: 0,
  member: true,
  ...overrides,
})

function render() {
  return renderWithProviders(
    <>
      <RoomModeratorsSection code="BBCA" />
      <Toaster />
    </>,
    staff,
  )
}

describe('RoomModeratorsSection', () => {
  beforeEach(() => {
    vi.mocked(roomModeratorsApi.list).mockResolvedValue(list)
    vi.mocked(roomModeratorsApi.actions).mockResolvedValue({ items: [hide] })
  })

  it('lists moderators, appoints an eligible customer, and blocks ineligible ones', async () => {
    const user = userEvent.setup()
    vi.mocked(roomModeratorsApi.candidates).mockResolvedValue([
      candidate({}),
      candidate({
        id: 'u-3',
        username: 'baru',
        display_name: 'Baru',
        eligible: false,
        problems: ['trust_level'],
      }),
    ])
    vi.mocked(roomModeratorsApi.appoint).mockResolvedValue(list)
    render()

    const active = await screen.findByRole('list', { name: 'Moderator aktif' })
    expect(within(active).getByText('Mod BBCA')).toBeVisible()
    expect(screen.getByText(/trust level minimal 2/)).toBeVisible()

    await user.type(screen.getByLabelText('Tunjuk moderator baru'), 'sa')
    const results = await screen.findByRole('list', { name: 'Hasil pencarian nasabah' })
    expect(within(results).getByText('Belum memenuhi syarat: trust level kurang')).toBeVisible()
    expect(within(results).getByRole('button', { name: 'Tunjuk Baru' })).toBeDisabled()

    await user.click(within(results).getByRole('button', { name: 'Tunjuk Sari' }))
    const dialog = await screen.findByRole('dialog')
    await user.type(within(dialog).getByLabelText('Catatan (opsional)'), 'Rajin membantu')
    await user.click(within(dialog).getByRole('button', { name: 'Tunjuk' }))
    expect(roomModeratorsApi.appoint).toHaveBeenCalledWith('BBCA', 'u-2', 'Rajin membantu')
    expect(await screen.findByText('Sari ditunjuk sebagai moderator $BBCA')).toBeVisible()
  })

  it('removes a moderator with a reason and undoes a hidden message', async () => {
    const user = userEvent.setup()
    vi.mocked(roomModeratorsApi.remove).mockResolvedValue({ ...list, moderators: [] })
    vi.mocked(roomModeratorsApi.undo).mockResolvedValue({ ...hide, undone_at: '2026-11-03T03:00:00.000Z' })
    render()

    await user.click(await screen.findByRole('button', { name: 'Copot Mod BBCA' }))
    let dialog = await screen.findByRole('dialog')
    await user.type(within(dialog).getByLabelText('Alasan pencopotan'), 'Rotasi moderator')
    await user.click(within(dialog).getByRole('button', { name: 'Copot' }))
    expect(roomModeratorsApi.remove).toHaveBeenCalledWith('BBCA', 'u-mod', 'Rotasi moderator')

    const log = await screen.findByRole('list', { name: 'Log aksi moderator' })
    expect(within(log).getByText('Gabung grup sinyal sekarang')).toBeVisible()
    expect(within(log).getByText(/Banding: menunggu/)).toBeVisible()
    await user.click(within(log).getByRole('button', { name: /^Batalkan Sembunyikan pesan/ }))
    dialog = await screen.findByRole('dialog')
    await user.type(within(dialog).getByLabelText('Catatan pembatalan'), 'Bukan promosi')
    await user.click(within(dialog).getByRole('button', { name: 'Batalkan' }))
    expect(roomModeratorsApi.undo).toHaveBeenCalledWith('act-1', 'Bukan promosi')
    expect(await screen.findByText('Aksi moderator dibatalkan')).toBeVisible()
  })

  it('switches the log to all rooms', async () => {
    const user = userEvent.setup()
    render()
    await screen.findByRole('list', { name: 'Log aksi moderator' })
    await user.click(screen.getByRole('radio', { name: 'Semua room' }))
    expect(roomModeratorsApi.actions).toHaveBeenLastCalledWith(null, null)
  })
})
