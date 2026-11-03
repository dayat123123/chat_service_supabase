import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { ApiError } from '@/lib/errors'
import { monitorFixture } from '@/test/fixtures'
import { renderWithProviders } from '@/test/render'
import { Toaster } from '@/test/toast'

import { clientConfigApi } from '../api'
import type { ClientConfig } from '../types'
import { FeaturesSection } from './features-section'

vi.mock('../api', () => ({
  clientConfigApi: {
    config: vi.fn(),
    toggleFlag: vi.fn(),
    setKillSwitch: vi.fn(),
    setMinVersion: vi.fn(),
  },
}))

function config(overrides: Partial<ClientConfig> = {}): ClientConfig {
  return {
    kill_switch: { social_enabled: true, reason: null, changed_by: null, changed_at: null },
    flags: [
      {
        key: 'search',
        enabled: true,
        percentage: 100,
        user_ids: [],
        platforms: [],
        min_app_version: null,
        description: 'Pencarian post, pengguna, saham, dan hashtag',
        updated_by: null,
        updated_at: '2026-11-03T01:00:00.000Z',
      },
    ],
    min_versions: [
      { platform: 'android', min_version: null, updated_by: null, updated_at: '2026-11-03T01:00:00.000Z' },
      { platform: 'ios', min_version: null, updated_by: null, updated_at: '2026-11-03T01:00:00.000Z' },
      { platform: 'web', min_version: null, updated_by: null, updated_at: '2026-11-03T01:00:00.000Z' },
      { platform: 'windows', min_version: null, updated_by: null, updated_at: '2026-11-03T01:00:00.000Z' },
      { platform: 'macos', min_version: null, updated_by: null, updated_at: '2026-11-03T01:00:00.000Z' },
      { platform: 'linux', min_version: null, updated_by: null, updated_at: '2026-11-03T01:00:00.000Z' },
    ],
    ...overrides,
  }
}

function renderSection() {
  return renderWithProviders(
    <>
      <FeaturesSection />
      <Toaster />
    </>,
    monitorFixture,
  )
}

beforeEach(() => {
  vi.clearAllMocks()
  vi.mocked(clientConfigApi.config).mockResolvedValue(config())
})

describe('FeaturesSection', () => {
  it('turns social features off only with a reason and the typed confirmation', async () => {
    const user = userEvent.setup()
    vi.mocked(clientConfigApi.setKillSwitch).mockResolvedValue(
      config({
        kill_switch: {
          social_enabled: false,
          reason: 'Spam masif dari bot',
          changed_by: { id: 'adi', name: 'Adi' },
          changed_at: '2026-11-03T03:00:00.000Z',
        },
      }),
    )
    renderSection()

    expect(await screen.findByText('Fitur sosial aktif')).toBeVisible()
    await user.click(screen.getByRole('button', { name: 'Matikan fitur sosial' }))
    const dialog = screen.getByRole('dialog', { name: 'Matikan fitur sosial untuk semua pengguna?' })
    expect(within(dialog).getByText(/Chat CS dengan nasabah tidak terpengaruh/)).toBeVisible()

    await user.type(within(dialog).getByLabelText('Alasan'), 'Spam')
    await user.type(within(dialog).getByLabelText('Ketik MATIKAN untuk konfirmasi'), 'matikan')
    await user.click(within(dialog).getByRole('button', { name: 'Matikan fitur sosial' }))
    expect(within(dialog).getByText('Alasan 10–500 karakter.')).toBeVisible()
    expect(clientConfigApi.setKillSwitch).not.toHaveBeenCalled()

    await user.type(within(dialog).getByLabelText('Alasan'), ' masif dari bot')
    await user.clear(within(dialog).getByLabelText('Ketik MATIKAN untuk konfirmasi'))
    await user.type(within(dialog).getByLabelText('Ketik MATIKAN untuk konfirmasi'), 'MATIKA')
    await user.click(within(dialog).getByRole('button', { name: 'Matikan fitur sosial' }))
    expect(within(dialog).getByText('Ketik MATIKAN persis untuk melanjutkan.')).toBeVisible()
    expect(clientConfigApi.setKillSwitch).not.toHaveBeenCalled()

    await user.type(within(dialog).getByLabelText('Ketik MATIKAN untuk konfirmasi'), 'N')
    await user.click(within(dialog).getByRole('button', { name: 'Matikan fitur sosial' }))
    await waitFor(() =>
      expect(clientConfigApi.setKillSwitch).toHaveBeenCalledWith(false, 'Spam masif dari bot'),
    )
    expect(await screen.findByText('Fitur sosial DIMATIKAN')).toBeVisible()
    expect(screen.getByText(/oleh Adi: Spam masif dari bot/)).toBeVisible()
    expect(screen.getByRole('button', { name: 'Nyalakan kembali' })).toBeVisible()
  })

  it('shows the fixed feature list with only an on/off switch', async () => {
    renderSection()

    expect(await screen.findByRole('switch', { name: 'Pencarian' })).toBeChecked()
    for (const label of [
      'Trending',
      'Simpan postingan',
      'Edit postingan',
      'Reaksi pesan',
      'Bagikan ke chat',
      'Pengaturan notifikasi',
      'Analitik aplikasi',
    ]) {
      expect(screen.getByRole('switch', { name: label })).not.toBeChecked()
    }
    expect(screen.getByText('Cari postingan, pengguna, saham, dan hashtag.')).toBeVisible()
    expect(screen.queryByRole('button', { name: /Tambah|Hapus|Ubah/ })).not.toBeInTheDocument()
  })

  it('turns a feature on right away', async () => {
    const user = userEvent.setup()
    vi.mocked(clientConfigApi.toggleFlag).mockResolvedValue(config())
    renderSection()

    await user.click(await screen.findByRole('switch', { name: 'Trending' }))
    await waitFor(() => expect(clientConfigApi.toggleFlag).toHaveBeenCalledWith('trending', true))
    expect(await screen.findByText('Trending dinyalakan')).toBeVisible()
  })

  it('confirms before turning a feature off', async () => {
    const user = userEvent.setup()
    vi.mocked(clientConfigApi.toggleFlag).mockResolvedValue(config())
    renderSection()

    await user.click(await screen.findByRole('switch', { name: 'Pencarian' }))
    const confirm = screen.getByRole('alertdialog', { name: 'Matikan Pencarian?' })
    expect(within(confirm).getByText(/tersembunyi untuk semua pengguna/)).toBeVisible()
    expect(clientConfigApi.toggleFlag).not.toHaveBeenCalled()
    await user.click(within(confirm).getByRole('button', { name: 'Matikan' }))
    await waitFor(() => expect(clientConfigApi.toggleFlag).toHaveBeenCalledWith('search', false))
  })

  it('explains a rejected toggle', async () => {
    const user = userEvent.setup()
    vi.mocked(clientConfigApi.toggleFlag).mockRejectedValue(new ApiError('unknown_flag', 'x', 400))
    renderSection()

    await user.click(await screen.findByRole('switch', { name: 'Trending' }))
    expect(await screen.findByText('Fitur ini tidak dikenal aplikasi. Daftar dimuat ulang.')).toBeVisible()
  })

  it('lists a minimum version for every app platform', async () => {
    renderSection()
    for (const platform of ['Android', 'iOS', 'Web', 'Windows', 'macOS', 'Linux']) {
      expect(await screen.findByLabelText(platform)).toBeInTheDocument()
    }
  })

  it('confirms before requiring a minimum app version', async () => {
    const user = userEvent.setup()
    vi.mocked(clientConfigApi.setMinVersion).mockResolvedValue(config())
    renderSection()

    const input = await screen.findByLabelText('Android')
    await user.type(input, '2.10.0')
    const row = input.closest('li')
    if (!row) throw new Error('baris versi tidak ditemukan')
    await user.click(within(row).getByRole('button', { name: 'Simpan' }))
    const confirm = screen.getByRole('alertdialog', {
      name: 'Wajibkan Android versi 2.10.0 atau lebih baru?',
    })
    expect(clientConfigApi.setMinVersion).not.toHaveBeenCalled()
    await user.click(within(confirm).getByRole('button', { name: 'Simpan' }))
    await waitFor(() => expect(clientConfigApi.setMinVersion).toHaveBeenCalledWith('android', '2.10.0'))
  })
})
