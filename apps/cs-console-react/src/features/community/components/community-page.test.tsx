import type * as RouterModule from '@tanstack/react-router'
import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import type { AgentProfile } from '@/features/presence/types'
import { agentFixture, monitorFixture } from '@/test/fixtures'
import { renderWithProviders } from '@/test/render'
import { Toaster } from '@/test/toast'

import type * as ApiModule from '../api'
import { communityApi } from '../api'
import type { CommunityPost, CommunityTab, OfficialAccount, ReportRow } from '../types'
import { CommunityPage } from './community-page'
import { ModerationTab } from './moderation-tab'
import { StreamTab } from './stream-tab'

const route = vi.hoisted(() => {
  const search: { tab?: CommunityTab } = {}
  return { search, navigate: vi.fn() }
})

vi.mock('@tanstack/react-router', async (importOriginal) => {
  const actual = await importOriginal<typeof RouterModule>()
  return { ...actual, useSearch: () => route.search, useNavigate: () => route.navigate }
})

vi.mock('@/features/analytics/api', () => ({
  analyticsApi: { community: vi.fn(() => new Promise(() => undefined)) },
}))

vi.mock('../api', async (importOriginal) => {
  const actual = await importOriginal<typeof ApiModule>()
  return {
    ...actual,
    communityApi: {
      ...actual.communityApi,
      overview: vi.fn(),
      accounts: vi.fn(),
      posts: vi.fn(),
      savePost: vi.fn(),
      submitPost: vi.fn(),
      reviewPost: vi.fn(),
      reports: vi.fn(),
      resolveReport: vi.fn(),
      findUsers: vi.fn(),
    },
  }
})

const research: OfficialAccount = {
  id: 'acc-1',
  username: 'olt_research',
  display_name: 'OLT Research',
  avatar_url: null,
  bio: null,
  follower_count: 0,
  post_count: 0,
  created_at: '2026-11-01T02:00:00.000Z',
  created_by: 'Sinta',
  disabled_at: null,
}

function post(overrides: Partial<CommunityPost>): CommunityPost {
  return {
    id: 'post-1',
    account: research,
    kind: 'announcement',
    title: 'Libur Bursa',
    body: 'Bursa libur pada 25 Desember.',
    attachments: [],
    pin_scope: 'global',
    pin_stock: null,
    pin_until: null,
    pinned: false,
    notify: true,
    status: 'pending',
    publish_at: null,
    post_id: null,
    post: null,
    campaign: null,
    created_by: { id: 'maya', name: 'Maya' },
    created_at: '2026-11-02T02:00:00.000Z',
    updated_at: '2026-11-02T02:00:00.000Z',
    submitted_at: '2026-11-02T02:05:00.000Z',
    reviewed_by: null,
    reviewed_at: null,
    review_note: null,
    published_at: null,
    error: null,
    version: 2,
    ...overrides,
  }
}

const writer: AgentProfile = {
  ...agentFixture,
  id: 'maya',
  display_name: 'Maya',
  roles: ['community'],
  community_permissions: ['community.post'],
}

const publisher: AgentProfile = {
  ...agentFixture,
  id: 'kirana',
  display_name: 'Kirana',
  roles: ['compliance'],
  community_permissions: ['community.post', 'community.publish'],
}

beforeEach(() => {
  vi.clearAllMocks()
  route.search = {}
  vi.mocked(communityApi.accounts).mockResolvedValue([research])
  vi.mocked(communityApi.posts).mockResolvedValue([])
  vi.mocked(communityApi.overview).mockResolvedValue({
    pending_posts: 0,
    scheduled_posts: 0,
    pending_campaigns: 0,
    open_reports: 3,
    accounts: 1,
    four_eyes: true,
    push_ready: false,
    push_state: 'not_configured',
  })
})

function tabNames() {
  return within(screen.getByRole('tablist', { name: 'Menu komunitas' }))
    .getAllByRole('tab')
    .map((tab) => tab.textContent)
}

describe('CommunityPage', () => {
  it('opens Analitik as the only tab for a Super Admin without community permissions', async () => {
    renderWithProviders(<CommunityPage />, monitorFixture)

    expect(tabNames()).toEqual(['Analitik'])
    expect(screen.getByRole('tab', { name: 'Analitik' })).toHaveAttribute('aria-selected', 'true')
    expect(await screen.findByRole('radio', { name: '30 hari' })).toBeVisible()
    expect(screen.queryByText('Laporan terbuka')).not.toBeInTheDocument()
    expect(communityApi.overview).not.toHaveBeenCalled()
  })

  it('adds Analitik after the permitted tabs for a Super Admin with community permissions', async () => {
    route.search = { tab: 'analytics' }
    renderWithProviders(<CommunityPage />, {
      ...monitorFixture,
      community_permissions: ['community.post', 'community.accounts'],
    })

    expect(tabNames()).toEqual(['Stream', 'Notifikasi', 'Akun resmi', 'Analitik'])
    expect(screen.getByRole('tab', { name: 'Analitik' })).toHaveAttribute('aria-selected', 'true')
    expect(await screen.findByRole('radio', { name: '30 hari' })).toBeVisible()
  })

  it('keeps the tabs of community staff unchanged and ignores an analytics link', async () => {
    route.search = { tab: 'analytics' }
    renderWithProviders(<CommunityPage />, writer)

    expect(tabNames()).toEqual(['Stream', 'Notifikasi'])
    expect(screen.getByRole('tab', { name: 'Stream' })).toHaveAttribute('aria-selected', 'true')
    expect(await screen.findByText('Laporan terbuka')).toBeVisible()
    expect(screen.queryByRole('radio', { name: '30 hari' })).not.toBeInTheDocument()
  })
})

describe('StreamTab', () => {
  it('lets a writer draft an announcement and submit it for review', async () => {
    const user = userEvent.setup()
    vi.mocked(communityApi.savePost).mockResolvedValue(post({ status: 'draft', version: 1 }))
    vi.mocked(communityApi.submitPost).mockResolvedValue(post({}))
    renderWithProviders(
      <>
        <StreamTab />
        <Toaster />
      </>,
      writer,
    )

    await user.click(await screen.findByRole('button', { name: 'Buat postingan' }))
    const dialog = screen.getByRole('dialog', { name: 'Buat postingan' })
    await user.click(within(dialog).getByRole('button', { name: 'Simpan & ajukan' }))
    expect(within(dialog).getByText('Akun resmi wajib dipilih')).toBeVisible()
    expect(communityApi.savePost).not.toHaveBeenCalled()

    await user.click(within(dialog).getByRole('combobox', { name: 'Akun resmi' }))
    await user.click(await screen.findByRole('option', { name: 'OLT Research' }))
    await user.click(within(dialog).getByRole('radio', { name: 'Pengumuman' }))
    await user.type(within(dialog).getByLabelText('Judul pengumuman'), 'Libur Bursa')
    await user.type(within(dialog).getByLabelText('Isi'), 'Bursa libur pada 25 Desember.')
    await user.click(within(dialog).getByRole('switch', { name: 'Kirim notifikasi saat terbit' }))
    await user.click(within(dialog).getByRole('button', { name: 'Simpan & ajukan' }))

    await waitFor(() => expect(communityApi.submitPost).toHaveBeenCalledWith('post-1', 1))
    expect(communityApi.savePost).toHaveBeenCalledWith(
      null,
      {
        account_id: 'acc-1',
        kind: 'announcement',
        title: 'Libur Bursa',
        body: 'Bursa libur pada 25 Desember.',
        attachments: [],
        pin_scope: 'global',
        pin_stock: null,
        pin_until: null,
        notify: true,
        publish_at: null,
      },
      null,
    )
  })

  it('lets another publisher approve a pending post, but never its own', async () => {
    const user = userEvent.setup()
    vi.mocked(communityApi.posts).mockResolvedValue([
      post({}),
      post({
        id: 'post-2',
        title: 'Analisa pagi',
        kind: 'post',
        created_by: { id: 'kirana', name: 'Kirana' },
      }),
    ])
    vi.mocked(communityApi.reviewPost).mockResolvedValue(post({ status: 'published', post_id: 'p1' }))
    renderWithProviders(<StreamTab />, publisher)

    await user.click(await screen.findByRole('button', { name: /Libur Bursa/ }))
    const sheet = await screen.findByRole('dialog', { name: 'Detail postingan resmi' })
    await user.click(within(sheet).getByRole('button', { name: 'Setujui & terbitkan' }))
    await waitFor(() => expect(communityApi.reviewPost).toHaveBeenCalledWith('post-1', true, null, 2))
    await user.keyboard('{Escape}')

    await user.click(await screen.findByRole('button', { name: /Analisa pagi/ }))
    const own = await screen.findByRole('dialog', { name: 'Detail postingan resmi' })
    expect(
      within(own).getByText('Anda yang membuat ini, jadi persetujuannya harus dari staf lain.'),
    ).toBeVisible()
    expect(within(own).queryByRole('button', { name: 'Setujui & terbitkan' })).not.toBeInTheDocument()
  })
})

describe('ModerationTab', () => {
  it('hides reported content with a recorded reason', async () => {
    const user = userEvent.setup()
    const report: ReportRow = {
      target_type: 'post',
      target_id: 'p-9',
      report_count: 3,
      reasons: ['pump_and_dump'],
      priority: 4.5,
      first_reported_at: '2026-11-02T02:00:00.000Z',
      last_reported_at: '2026-11-02T03:00:00.000Z',
      author_id: 'sari',
      author_username: 'sari_invest',
      author_display_name: 'Sari',
      author_is_official: false,
      excerpt: 'Saham ini pasti naik 300%',
      target_status: 'visible',
    }
    vi.mocked(communityApi.reports).mockResolvedValue([report])
    vi.mocked(communityApi.resolveReport).mockResolvedValue({})
    renderWithProviders(<ModerationTab />, {
      ...agentFixture,
      roles: ['community'],
      community_permissions: ['community.moderate'],
    })

    expect(await screen.findByText('Saham ini pasti naik 300%')).toBeVisible()
    expect(screen.getByText(/Pom-pom saham/)).toBeVisible()
    await user.click(screen.getByRole('button', { name: 'Sembunyikan' }))
    const dialog = screen.getByRole('dialog', { name: 'Sembunyikan konten ini?' })
    await user.type(within(dialog).getByLabelText('Alasan'), 'Ajakan pom-pom saham')
    await user.click(within(dialog).getByRole('button', { name: 'Sembunyikan' }))
    await waitFor(() =>
      expect(communityApi.resolveReport).toHaveBeenCalledWith('post', 'p-9', 'hide', 'Ajakan pom-pom saham'),
    )
  })
})
