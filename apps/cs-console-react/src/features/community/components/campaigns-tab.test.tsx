import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import type { AgentProfile } from '@/features/presence/types'
import { pushApi } from '@/features/push/api'
import { agentFixture } from '@/test/fixtures'
import { renderWithProviders } from '@/test/render'
import { Toaster } from '@/test/toast'

import type * as ApiModule from '../api'
import { communityApi } from '../api'
import type { Campaign, OfficialAccount } from '../types'
import { CampaignsTab } from './campaigns-tab'

vi.mock('../api', async (importOriginal) => {
  const actual = await importOriginal<typeof ApiModule>()
  return {
    ...actual,
    communityApi: {
      ...actual.communityApi,
      overview: vi.fn(),
      accounts: vi.fn(),
      posts: vi.fn(),
      campaigns: vi.fn(),
      audienceSize: vi.fn(),
      saveCampaign: vi.fn(),
    },
  }
})

vi.mock('@/features/push/api', () => ({ pushApi: { campaign: vi.fn() } }))

const research: OfficialAccount = {
  id: 'acc-1',
  username: 'olt_research',
  display_name: 'OLT Research',
  avatar_url: null,
  bio: null,
  follower_count: 120,
  post_count: 4,
  created_at: '2026-11-01T02:00:00.000Z',
  created_by: 'Sinta',
  disabled_at: null,
}

const writer: AgentProfile = {
  ...agentFixture,
  id: 'kirana',
  display_name: 'Kirana',
  roles: ['compliance'],
  community_permissions: ['community.post'],
}

const publisher: AgentProfile = { ...writer, community_permissions: ['community.post', 'community.publish'] }

function campaign(overrides: Partial<Campaign> = {}): Campaign {
  return {
    id: 'camp-1',
    account: research,
    title: 'Riset mingguan',
    body: 'Ringkasan pasar pekan ini sudah terbit',
    link_post: null,
    link_url: null,
    audience: 'all',
    audience_stock: null,
    audience_days: null,
    audience_platform: null,
    audience_account: null,
    status: 'draft',
    send_at: null,
    created_by: { id: 'kirana', name: 'Kirana' },
    created_at: '2026-11-03T01:00:00.000Z',
    updated_at: '2026-11-03T01:00:00.000Z',
    submitted_at: null,
    reviewed_by: null,
    reviewed_at: null,
    review_note: null,
    started_at: null,
    finished_at: null,
    recipients: 0,
    opened: 0,
    tapped: 0,
    open_rate: null,
    tap_rate: null,
    version: 1,
    ...overrides,
  }
}

beforeEach(() => {
  vi.clearAllMocks()
  vi.mocked(communityApi.accounts).mockResolvedValue([research])
  vi.mocked(communityApi.posts).mockResolvedValue([])
  vi.mocked(communityApi.audienceSize).mockResolvedValue(1234)
  vi.mocked(communityApi.overview).mockResolvedValue({
    pending_posts: 0,
    scheduled_posts: 0,
    pending_campaigns: 0,
    open_reports: 0,
    accounts: 1,
    four_eyes: true,
    push_ready: true,
    push_state: 'active',
  })
  vi.mocked(pushApi.campaign).mockResolvedValue({
    state: 'active',
    sent: 900,
    queued: 0,
    failed: 0,
    invalid: 0,
    expired: 0,
    cancelled: 0,
  })
})

async function openComposer(user: ReturnType<typeof userEvent.setup>) {
  await user.click(await screen.findByRole('button', { name: /Riset mingguan/ }))
  await user.click(await screen.findByRole('button', { name: 'Ubah' }))
  return screen.findByRole('dialog', { name: 'Ubah notifikasi' })
}

describe('CampaignsTab segments', () => {
  it('previews the recipient count of a segment and saves its parameters', async () => {
    const user = userEvent.setup()
    vi.mocked(communityApi.campaigns).mockResolvedValue([campaign()])
    vi.mocked(communityApi.saveCampaign).mockResolvedValue(
      campaign({ audience: 'inactive', audience_days: 45, version: 2 }),
    )
    renderWithProviders(
      <>
        <CampaignsTab />
        <Toaster />
      </>,
      writer,
    )

    const dialog = await openComposer(user)
    const segments = within(dialog).getByRole('group', { name: 'Segmen penerima' })
    expect(await within(segments).findByText('Sekitar 1.234 penerima')).toBeVisible()
    expect(communityApi.audienceSize).toHaveBeenCalledWith({
      audience: 'all',
      stock: null,
      days: null,
      platform: null,
      account_id: null,
    })

    await user.click(within(segments).getByRole('radio', { name: 'Pengguna tidak aktif' }))
    const days = within(segments).getByRole('textbox', { name: 'Jumlah hari (1–365)' })
    await user.clear(days)
    await user.type(days, '0')
    await user.click(within(dialog).getByRole('button', { name: 'Simpan draf' }))
    expect(within(segments).getByText('Isi bilangan bulat 1–365.')).toBeVisible()
    expect(communityApi.saveCampaign).not.toHaveBeenCalled()

    vi.mocked(communityApi.audienceSize).mockResolvedValue(87)
    await user.clear(days)
    await user.type(days, '45')
    expect(await within(segments).findByText('Sekitar 87 penerima')).toBeVisible()
    expect(communityApi.audienceSize).toHaveBeenLastCalledWith({
      audience: 'inactive',
      stock: null,
      days: 45,
      platform: null,
      account_id: null,
    })

    await user.click(within(dialog).getByRole('button', { name: 'Simpan draf' }))
    await waitFor(() =>
      expect(communityApi.saveCampaign).toHaveBeenCalledWith(
        'camp-1',
        expect.objectContaining({
          audience: 'inactive',
          audience_stock: null,
          audience_days: 45,
          audience_platform: null,
          audience_account_id: null,
        }),
        1,
      ),
    )
  })

  it('keeps the follower segment of an existing campaign', async () => {
    const user = userEvent.setup()
    vi.mocked(communityApi.campaigns).mockResolvedValue([
      campaign({ audience: 'followers', audience_account: research }),
    ])
    vi.mocked(communityApi.saveCampaign).mockResolvedValue(campaign({ version: 2 }))
    renderWithProviders(<CampaignsTab />, writer)

    expect(await screen.findByText(/Pengikut OLT Research/)).toBeVisible()
    const dialog = await openComposer(user)
    const segments = within(dialog).getByRole('group', { name: 'Segmen penerima' })
    expect(within(segments).getByRole('radio', { name: 'Pengikut akun resmi' })).toBeChecked()
    expect(within(segments).getByRole('combobox', { name: 'Akun resmi' })).toHaveTextContent('OLT Research')
    await waitFor(() =>
      expect(communityApi.audienceSize).toHaveBeenCalledWith(
        expect.objectContaining({ audience: 'followers', account_id: 'acc-1' }),
      ),
    )

    await user.click(within(dialog).getByRole('button', { name: 'Simpan draf' }))
    await waitFor(() =>
      expect(communityApi.saveCampaign).toHaveBeenCalledWith(
        'camp-1',
        expect.objectContaining({ audience: 'followers', audience_account_id: 'acc-1' }),
        1,
      ),
    )
  })

  it('shows the segment and open/tap statistics of sent campaigns', async () => {
    const user = userEvent.setup()
    vi.mocked(communityApi.campaigns).mockResolvedValue([
      campaign({
        status: 'sent',
        audience: 'platform',
        audience_platform: 'ios',
        recipients: 1000,
        opened: 420,
        tapped: 155,
        open_rate: 42,
        tap_rate: 15.5,
        finished_at: '2026-11-03T03:00:00.000Z',
      }),
    ])
    renderWithProviders(<CampaignsTab />, publisher)

    await user.click(await screen.findByRole('radio', { name: 'Terkirim' }))
    const row = await screen.findByRole('button', { name: /Riset mingguan/ })
    expect(row).toHaveTextContent('Pengguna iOS')
    expect(row).toHaveTextContent('Dibuka 420 (42%) · diketuk 155 (15,5%)')

    await user.click(row)
    const detail = await screen.findByRole('dialog', { name: 'Detail notifikasi' })
    expect(within(detail).getByText('Pengguna iOS')).toBeVisible()
    expect(within(detail).getByText('Dibuka').nextElementSibling).toHaveTextContent('420 (42%)')
    expect(within(detail).getByText('Diketuk').nextElementSibling).toHaveTextContent('155 (15,5%)')
  })
})
