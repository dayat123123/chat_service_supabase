import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import type { AgentProfile } from '@/features/presence/types'
import { ApiError } from '@/lib/errors'
import { agentFixture } from '@/test/fixtures'
import { renderWithProviders } from '@/test/render'
import { Toaster } from '@/test/toast'

import { communityApi } from '../api'
import type {
  Appeal,
  CommunityContent,
  CommunityUser,
  ContentTarget,
  HeldContent,
  ManipulationAlert,
  MediaReview,
  RoomMessage,
  RoomState,
} from '../types'
import { ModerationTab } from './moderation-tab'
import { RoomsTab } from './rooms-tab'

vi.mock('../api', () => ({
  communityApi: {
    reports: vi.fn(),
    resolveReport: vi.fn(),
    findUsers: vi.fn(),
    user: vi.fn(),
    held: vi.fn(),
    decideHeld: vi.fn(),
    editHistory: vi.fn(),
    media: vi.fn(),
    decideMedia: vi.fn(),
    mediaImage: vi.fn(),
    alerts: vi.fn(),
    reviewAlert: vi.fn(),
    appeals: vi.fn(),
    decideAppeal: vi.fn(),
    zeroTolerance: vi.fn(),
    roomState: vi.fn(),
    setSlowMode: vi.fn(),
    pinMessage: vi.fn(),
    roomMessages: vi.fn(),
    contentMeta: vi.fn(),
    content: vi.fn(),
  },
}))

const moderator: AgentProfile = {
  ...agentFixture,
  id: 'nadia',
  roles: ['community'],
  community_permissions: ['community.moderate', 'community.sanction'],
}

const heldPost: HeldContent = {
  target_type: 'post',
  target_id: 'post-7',
  excerpt: 'Gabung grup [tautan disensor] sekarang',
  attachments: 1,
  stock_code: null,
  created_at: '2026-11-03T02:00:00.000Z',
  categories: ['shortener'],
  source: 'policy',
  alert_id: null,
  author: { id: 'u-1', username: 'baru_123', display_name: 'Baru', trust_level: 0, new_account: true },
}

const review: MediaReview = {
  id: 41,
  bucket: 'attachments',
  path: 'posts/u-1/foto.jpg',
  status: 'pending',
  category: 'porn',
  score: 0.71,
  scores: { porn: 0.71, sexy: 0.2, neutral: 0.09 },
  model: 'nsfw-mobilenet-v2',
  thresholds_revision: 4,
  created_at: '2026-11-03T02:00:00.000Z',
  decided_at: null,
  decided_by: null,
  note: null,
  stripped: [],
  object_exists: true,
  uploader: { id: 'u-1', username: 'baru_123', display_name: 'Baru', deleted: false },
  used_in: [{ type: 'post', id: 'post-8', created_at: '2026-11-03T02:01:00.000Z', deleted: false }],
}

const appeal: Appeal = {
  id: 'appeal-1',
  status: 'pending',
  target_type: 'post',
  target_id: 'post-3',
  reason: 'Postingan saya analisis biasa, bukan promosi.',
  created_at: '2026-11-03T02:00:00.000Z',
  decided_at: null,
  decision_note: null,
  user: { id: 'u-2', username: 'sari_invest', display_name: 'Sari', avatar_url: null, banned: false },
  target: { state: 'hidden', excerpt: 'Analisis $BBCA minggu ini', decided_at: '2026-11-02T02:00:00.000Z' },
  original_decider: { id: 'nadia', name: 'Nadia' },
  decided_by: null,
  can_decide: false,
}

const profile: CommunityUser = {
  profile: {
    id: 'u-1',
    username: 'baru_123',
    display_name: 'Baru',
    avatar_url: null,
    is_verified: false,
    trust_level: 0,
    created_at: '2026-11-01T02:00:00.000Z',
    deleted: false,
    is_official: false,
    is_staff: false,
    banned: false,
    muted: false,
    bio: null,
  },
  counts: { posts: 3, comments: 1, reports_against: 2, reports_made: 0 },
  recent_posts: [
    {
      id: 'post-7',
      body: 'Gabung grup sekarang',
      moderation_status: 'held',
      created_at: '2026-11-03T02:00:00.000Z',
    },
  ],
  recent_comments: [],
  sanctions: [],
}

const room: RoomState = {
  room_id: 'room-bbca',
  stock_code: 'BBCA',
  slow_mode: { seconds: 0, until: null, source: null },
  wait_seconds: 0,
  pinned_message: null,
  pinned_at: null,
  override: null,
  open_alerts: [],
}

function render(ui: React.ReactElement, agent: AgentProfile = moderator) {
  return renderWithProviders(
    <>
      {ui}
      <Toaster />
    </>,
    agent,
  )
}

const EDITED_AT = '2026-11-03T02:30:00.000Z'

const recent = (overrides: Partial<RoomMessage>): RoomMessage => ({
  id: 'msg-1',
  created_at: '2026-11-03T03:00:00.000Z',
  edited_at: null,
  body: 'BBCA kuat di 9.250',
  attachments: 0,
  moderation_status: 'visible',
  sender: { id: 'u-3', username: 'budi', display_name: 'Budi' },
  ...overrides,
})

const usedPost: CommunityContent = {
  type: 'post',
  id: 'post-8',
  body: 'Foto chart pagi ini',
  attachments: [{ path: 'posts/u-1/foto.jpg' }],
  created_at: '2026-11-03T02:01:00.000Z',
  edited_at: EDITED_AT,
  deleted_at: null,
  moderation_status: 'visible',
  like_count: 4,
  comment_count: 1,
  author: { id: 'u-1', username: 'baru_123', display_name: 'Baru' },
}

beforeEach(() => {
  vi.clearAllMocks()
  vi.mocked(communityApi.contentMeta).mockImplementation((targets: ContentTarget[]) =>
    Promise.resolve(
      targets.map((target) => ({
        ...target,
        edited_at: target.id === 'post-7' ? EDITED_AT : null,
        moderation_status: 'held',
        deleted: false,
      })),
    ),
  )
  vi.mocked(communityApi.roomMessages).mockResolvedValue({ room_id: 'room-bbca', items: [] })
  vi.mocked(communityApi.reports).mockResolvedValue([])
  vi.mocked(communityApi.findUsers).mockResolvedValue([])
  vi.mocked(communityApi.held).mockResolvedValue([heldPost])
  vi.mocked(communityApi.media).mockResolvedValue({ items: [review], next_cursor: null, pending: 1 })
  vi.mocked(communityApi.mediaImage).mockResolvedValue(new Blob(['x'], { type: 'image/jpeg' }))
  vi.mocked(communityApi.alerts).mockResolvedValue([])
  vi.mocked(communityApi.appeals).mockResolvedValue([appeal])
  vi.mocked(communityApi.user).mockResolvedValue(profile)
  vi.mocked(communityApi.editHistory).mockResolvedValue([])
})

describe('moderation queues', () => {
  it('shows only the queues the staff member can act on', async () => {
    const user = userEvent.setup()
    const { unmount } = render(<ModerationTab />, {
      ...moderator,
      community_permissions: ['community.sanction'],
    })
    const tabs = screen.getByRole('tablist', { name: 'Antrean moderasi' })
    expect(
      within(tabs)
        .getAllByRole('tab')
        .map((tab) => tab.textContent),
    ).toEqual(['Laporan', 'Banding'])
    await user.click(within(tabs).getByRole('tab', { name: 'Banding' }))
    expect(await screen.findByText('Banding konten butuh izin Moderasi konten.')).toBeVisible()
    unmount()

    render(<ModerationTab />)
    expect(
      within(screen.getByRole('tablist', { name: 'Antrean moderasi' }))
        .getAllByRole('tab')
        .map((tab) => tab.textContent),
    ).toEqual(['Laporan', 'Konten ditahan', 'Gambar ditahan', 'Indikasi manipulasi', 'Banding'])
  })

  it('approves held content with a recorded reason through the report resolver', async () => {
    const user = userEvent.setup()
    vi.mocked(communityApi.decideHeld).mockResolvedValue({})
    render(<ModerationTab queue="held" />)

    expect(await screen.findByText('Gabung grup [tautan disensor] sekarang')).toBeVisible()
    expect(screen.getByText('Pemendek tautan')).toBeVisible()
    expect(screen.getByText('Akun baru')).toBeVisible()
    expect(await screen.findByText('· diedit')).toBeVisible()
    expect(communityApi.contentMeta).toHaveBeenCalledWith([{ type: 'post', id: 'post-7' }])
    expect(screen.getByRole('button', { name: 'Riwayat edit postingan' })).toBeVisible()
    await user.click(screen.getByRole('button', { name: 'Loloskan' }))
    const dialog = screen.getByRole('dialog', { name: 'Loloskan konten ini?' })
    await user.type(within(dialog).getByLabelText('Alasan'), 'Tautan resmi')
    await user.click(within(dialog).getByRole('button', { name: 'Loloskan' }))
    await waitFor(() =>
      expect(communityApi.decideHeld).toHaveBeenCalledWith('post', 'post-7', 'approve', 'Tautan resmi'),
    )
  })

  it('blurs held images until a moderator reveals them, and needs a reason to remove', async () => {
    const user = userEvent.setup()
    vi.mocked(communityApi.decideMedia).mockResolvedValue({})
    const { container } = render(<ModerationTab queue="media" />)

    const reveal = await screen.findByRole('button', { name: 'Tampilkan' })
    expect(communityApi.mediaImage).toHaveBeenCalledWith('attachments', 'posts/u-1/foto.jpg')
    const frame = container.querySelector('[data-slot="held-image"]')
    expect(frame).toHaveAttribute('data-state', 'blurred')
    expect(frame?.querySelector('img')).toHaveClass('blur-xl')
    await user.click(reveal)
    expect(frame).toHaveAttribute('data-state', 'revealed')
    expect(screen.getByRole('img', { name: 'Gambar yang sedang ditinjau' })).not.toHaveClass('blur-xl')
    await user.click(screen.getByRole('button', { name: 'Buramkan lagi' }))
    expect(frame).toHaveAttribute('data-state', 'blurred')

    expect(screen.getByText('Pornografi 71%')).toBeVisible()
    expect(screen.getByText('Postingan')).toBeVisible()
    await user.click(screen.getByRole('button', { name: 'Hapus gambar' }))
    const dialog = screen.getByRole('dialog', { name: 'Hapus gambar ini?' })
    await user.click(within(dialog).getByRole('button', { name: 'Hapus gambar' }))
    expect(communityApi.decideMedia).not.toHaveBeenCalled()
    await user.type(within(dialog).getByLabelText('Alasan'), 'Pornografi')
    await user.click(within(dialog).getByRole('button', { name: 'Hapus gambar' }))
    await waitFor(() => expect(communityApi.decideMedia).toHaveBeenCalledWith(41, 'remove', 'Pornografi'))
  })

  it('blocks the original decider from deciding an appeal and lets another moderator decide', async () => {
    const user = userEvent.setup()
    vi.mocked(communityApi.decideAppeal).mockResolvedValue({ ...appeal, status: 'accepted' })
    const { unmount } = render(<ModerationTab queue="appeals" />)
    expect(
      await screen.findByText('Anda pemberi keputusan awal, jadi banding ini harus ditinjau staf lain.'),
    ).toBeVisible()
    expect(screen.queryByRole('button', { name: 'Terima' })).not.toBeInTheDocument()
    unmount()

    vi.mocked(communityApi.appeals).mockResolvedValue([{ ...appeal, can_decide: true }])
    render(<ModerationTab queue="appeals" />, { ...moderator, id: 'bima' })
    await user.click(await screen.findByRole('button', { name: 'Terima' }))
    const dialog = screen.getByRole('dialog', { name: 'Terima banding ini?' })
    await user.type(within(dialog).getByLabelText('Catatan keputusan'), 'Analisis wajar, bukan promosi')
    await user.click(within(dialog).getByRole('button', { name: 'Terima' }))
    await waitFor(() =>
      expect(communityApi.decideAppeal).toHaveBeenCalledWith(
        'appeal-1',
        true,
        'Analisis wajar, bukan promosi',
      ),
    )
  })

  it('applies zero tolerance only after a reason, an acknowledgement, and the typed username', async () => {
    const user = userEvent.setup()
    vi.mocked(communityApi.zeroTolerance).mockResolvedValue({
      ...profile,
      hidden: { posts: 3, comments: 1, messages: 0 },
    })
    render(<ModerationTab queue="held" />)

    await user.click(await screen.findByRole('button', { name: /Baru/ }))
    const sheet = await screen.findByRole('dialog', { name: 'Detail pengguna' })
    expect(await within(sheet).findByRole('button', { name: 'Riwayat edit postingan' })).toBeVisible()
    await user.click(within(sheet).getByRole('button', { name: 'Toleransi nol' }))

    const first = screen.getByRole('dialog', { name: 'Toleransi nol untuk Baru?' })
    await user.type(within(first).getByLabelText('Alasan'), 'Materi CSAM di postingan')
    await user.click(within(first).getByRole('button', { name: 'Lanjutkan' }))
    expect(within(first).getByText('Centang untuk melanjutkan.')).toBeVisible()
    await user.click(within(first).getByRole('checkbox'))
    await user.click(within(first).getByRole('button', { name: 'Lanjutkan' }))

    const confirm = screen.getByRole('alertdialog', { name: 'Konfirmasi terakhir: toleransi nol untuk Baru' })
    const apply = within(confirm).getByRole('button', { name: 'Terapkan toleransi nol' })
    expect(apply).toBeDisabled()
    await user.type(within(confirm).getByLabelText('Ketik username @baru_123 untuk menerapkan'), '@baru_12')
    expect(apply).toBeDisabled()
    await user.type(within(confirm).getByLabelText('Ketik username @baru_123 untuk menerapkan'), '3')
    await user.click(apply)

    await waitFor(() =>
      expect(communityApi.zeroTolerance).toHaveBeenCalledWith('u-1', 'Materi CSAM di postingan'),
    )
    expect(await screen.findByText(/Disembunyikan: 3 postingan, 1 komentar, 0 pesan/)).toBeVisible()
  })
})

describe('RoomsTab', () => {
  it('offers to create a missing room through slow mode', async () => {
    const user = userEvent.setup()
    vi.mocked(communityApi.roomState).mockRejectedValue(
      new ApiError('room_not_found', 'Room saham belum ada', 404),
    )
    vi.mocked(communityApi.setSlowMode).mockResolvedValue({ ...room, stock_code: 'GOTO' })
    render(<RoomsTab />)

    await user.type(screen.getByLabelText('Kode saham'), '$goto')
    await user.click(screen.getByRole('button', { name: 'Buka' }))
    expect(await screen.findByText(/Room \$GOTO belum ada/)).toBeVisible()
    await user.click(screen.getByRole('radio', { name: '30 dtk' }))
    await user.click(screen.getByRole('button', { name: 'Simpan slow mode' }))
    await waitFor(() => expect(communityApi.setSlowMode).toHaveBeenCalledWith('GOTO', 30, null))
  })

  it('validates slow mode, pins from recent messages, and keeps the id fallback', async () => {
    const user = userEvent.setup()
    vi.mocked(communityApi.roomState).mockResolvedValue({
      ...room,
      pinned_message: {
        id: 'msg-9',
        room_id: 'room-bbca',
        sender_id: 'u-9',
        sender_username: 'olt_official',
        sender_display_name: 'OLT',
        body: 'Pengumuman lama',
        created_at: '2026-11-02T03:00:00.000Z',
      },
      pinned_at: '2026-11-02T03:00:00.000Z',
    })
    vi.mocked(communityApi.roomMessages).mockResolvedValue({
      room_id: 'room-bbca',
      items: [
        recent({ edited_at: EDITED_AT }),
        recent({ id: 'msg-2', body: 'Ditahan karena tautan', moderation_status: 'held' }),
        recent({
          id: 'msg-9',
          body: 'Pengumuman lama',
          sender: { id: 'u-9', username: 'olt_official', display_name: 'OLT' },
        }),
      ],
    })
    vi.mocked(communityApi.pinMessage).mockResolvedValue(room)
    render(<RoomsTab stock="BBCA" />)

    expect(await screen.findByText('Slow mode tidak aktif')).toBeVisible()
    const seconds = screen.getByLabelText('Jeda antarpesan (detik)')
    await user.clear(seconds)
    await user.type(seconds, '4000')
    await user.click(screen.getByRole('button', { name: 'Simpan slow mode' }))
    expect(screen.getByText('Isi angka bulat 0–3600.')).toBeVisible()
    expect(communityApi.setSlowMode).not.toHaveBeenCalled()

    const list = await screen.findByRole('list', { name: 'Pilih dari pesan terbaru' })
    expect(communityApi.roomMessages).toHaveBeenCalledWith('BBCA', null)
    expect(within(list).getByText('· diedit')).toBeVisible()
    expect(within(list).getByText('Disematkan')).toBeVisible()
    const pinButtons = within(list).getAllByRole('button', { name: /^Sematkan pesan Budi/ })
    expect(pinButtons[1]).toBeDisabled()
    await user.click(pinButtons[0] as HTMLElement)
    const confirm = screen.getByRole('alertdialog', { name: 'Ganti pesan yang disematkan di $BBCA?' })
    expect(communityApi.pinMessage).not.toHaveBeenCalled()
    await user.click(within(confirm).getByRole('button', { name: 'Sematkan' }))
    await waitFor(() => expect(communityApi.pinMessage).toHaveBeenCalledWith('room-bbca', 'msg-1'))

    await user.click(screen.getByText('Sematkan dengan ID pesan'))
    const idInput = screen.getByLabelText('Sematkan pesan (ID pesan)')
    const fallback = idInput.closest('form')
    if (!fallback) throw new Error('form cadangan tidak ditemukan')
    await user.type(idInput, 'bukan-id')
    await user.click(within(fallback).getByRole('button', { name: 'Sematkan' }))
    expect(screen.getByText('ID pesan tidak valid.')).toBeVisible()
    await user.clear(idInput)
    await user.type(idInput, '7a6f1c2e-0b7d-4c55-9a51-2f1f0b6c9d10')
    await user.click(within(fallback).getByRole('button', { name: 'Sematkan' }))
    await waitFor(() =>
      expect(communityApi.pinMessage).toHaveBeenLastCalledWith(
        'room-bbca',
        '7a6f1c2e-0b7d-4c55-9a51-2f1f0b6c9d10',
      ),
    )
  })
})

describe('opening content by id', () => {
  it('opens a held image use in a read-only sheet and goes on to the author', async () => {
    const user = userEvent.setup()
    vi.mocked(communityApi.content).mockResolvedValue(usedPost)
    render(<ModerationTab queue="media" />)

    await user.click(await screen.findByRole('button', { name: 'Buka' }))
    const sheet = await screen.findByRole('dialog', { name: 'Detail konten' })
    expect(communityApi.content).toHaveBeenCalledWith('post', 'post-8')
    expect(await within(sheet).findByText('Foto chart pagi ini')).toBeVisible()
    expect(within(sheet).getByText('· diedit')).toBeVisible()
    expect(within(sheet).getByRole('button', { name: 'Riwayat edit postingan' })).toBeVisible()
    await user.click(within(sheet).getByRole('button', { name: /Baru/ }))
    expect(await screen.findByRole('dialog', { name: 'Detail pengguna' })).toBeInTheDocument()
    expect(screen.queryByRole('dialog', { name: 'Detail konten' })).not.toBeInTheDocument()
  })

  it('explains why a private message cannot be opened', async () => {
    const user = userEvent.setup()
    vi.mocked(communityApi.media).mockResolvedValue({
      items: [
        {
          ...review,
          used_in: [
            {
              type: 'message',
              id: 'msg-dm',
              room_id: 'room-dm',
              room_type: 'direct',
              created_at: review.created_at,
              deleted: false,
            },
          ],
        },
      ],
      next_cursor: null,
      pending: 1,
    })
    vi.mocked(communityApi.content).mockRejectedValue(
      new ApiError('private_message_forbidden', 'Pesan pribadi hanya bisa dibuka bila dilaporkan', 403),
    )
    render(<ModerationTab queue="media" />)

    expect(await screen.findByText('Pesan di DM')).toBeVisible()
    await user.click(screen.getByRole('button', { name: 'Buka' }))
    const sheet = await screen.findByRole('dialog', { name: 'Detail konten' })
    expect(await within(sheet).findByRole('alert')).toHaveTextContent(
      'Pesan pribadi hanya bisa dibuka bila dilaporkan, ditandai sistem, atau tidak tampil.',
    )
  })

  it('opens the posts behind a coordinated posting alert', async () => {
    const user = userEvent.setup()
    const alert: ManipulationAlert = {
      id: 'alert-1',
      stock: 'BBCA',
      kind: 'coordinated_posts',
      score: 6,
      evidence: {
        post_ids: ['post-a', 'post-b'],
        authors: 6,
        sample: 'BBCA to the moon',
        window_minutes: 30,
      },
      status: 'open',
      auto_actions: { held_posts: ['post-a', 'post-b'] },
      detected_at: '2026-11-03T02:00:00.000Z',
      last_detected_at: '2026-11-03T02:10:00.000Z',
      reviewed_by: null,
      reviewed_at: null,
      review_note: null,
    }
    vi.mocked(communityApi.alerts).mockResolvedValue([alert])
    vi.mocked(communityApi.content).mockResolvedValue({ ...usedPost, id: 'post-b', body: 'Isi postingan B' })
    render(<ModerationTab queue="alerts" />)

    await user.click(await screen.findByRole('button', { name: 'Postingan 2' }))
    expect(communityApi.content).toHaveBeenCalledWith('post', 'post-b')
    const sheet = await screen.findByRole('dialog', { name: 'Detail konten' })
    expect(await within(sheet).findByText('Isi postingan B')).toBeVisible()
  })
})
