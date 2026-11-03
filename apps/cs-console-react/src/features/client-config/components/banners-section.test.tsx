import { fireEvent, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { ApiError } from '@/lib/errors'
import { monitorFixture } from '@/test/fixtures'
import { renderWithProviders } from '@/test/render'
import { Toaster } from '@/test/toast'

import { bannersApi } from '../api'
import type { AppBanner } from '../types'
import { BannersSection } from './banners-section'

vi.mock('../api', () => ({
  bannersApi: { list: vi.fn(), save: vi.fn(), remove: vi.fn() },
}))

function banner(overrides: Partial<AppBanner> = {}): AppBanner {
  return {
    id: 'banner-1',
    title: 'Pemeliharaan sistem',
    body: 'Chat dipelihara pukul 22.00 WIB',
    link_url: 'https://olt.example/status',
    level: 'warning',
    starts_at: '2026-11-03T03:00:00.000Z',
    ends_at: '2026-11-04T03:00:00.000Z',
    platforms: ['android', 'ios'],
    min_app_version: '2.4.0',
    max_app_version: null,
    dismissible: false,
    priority: 10,
    status: 'active',
    created_by: { id: 'adi', name: 'Adi' },
    updated_by: { id: 'adi', name: 'Adi' },
    created_at: '2026-11-03T01:00:00.000Z',
    updated_at: '2026-11-03T01:00:00.000Z',
    ...overrides,
  }
}

function renderSection() {
  return renderWithProviders(
    <>
      <BannersSection />
      <Toaster />
    </>,
    monitorFixture,
  )
}

beforeEach(() => {
  vi.clearAllMocks()
  vi.mocked(bannersApi.list).mockResolvedValue([
    banner(),
    banner({ id: 'banner-2', title: 'Promo akhir tahun', status: 'ended', level: 'info', platforms: [] }),
  ])
})

describe('BannersSection', () => {
  it('lists banners with status, schedule, and audience', async () => {
    renderSection()
    const table = await screen.findByRole('table', { name: 'Daftar banner' })
    const active = within(table).getByRole('row', { name: /Pemeliharaan sistem/ })
    expect(within(active).getByText('Aktif')).toBeVisible()
    expect(within(active).getByText('Peringatan · Tidak bisa ditutup')).toBeVisible()
    expect(within(active).getByText('Android, iOS')).toBeVisible()
    expect(within(active).getByText('Versi ≥ 2.4.0')).toBeVisible()
    const ended = within(table).getByRole('row', { name: /Promo akhir tahun/ })
    expect(within(ended).getByText('Berakhir')).toBeVisible()
    expect(within(ended).getByText('Semua platform')).toBeVisible()
  })

  it('validates the form and shows a live preview per level', async () => {
    const user = userEvent.setup()
    renderSection()
    await user.click(await screen.findByRole('button', { name: 'Tambah banner' }))
    const dialog = await screen.findByRole('dialog', { name: 'Tambah banner' })
    const preview = within(dialog).getByRole('figure', { name: 'Pratinjau' })
    expect(preview).toHaveTextContent('Judul banner')
    expect(within(preview).getByLabelText('Tutup banner')).toBeInTheDocument()

    await user.type(within(dialog).getByLabelText('Tautan (opsional)'), 'olt.example')
    await user.type(within(dialog).getByLabelText('Versi minimum'), '3.0')
    await user.type(within(dialog).getByLabelText('Versi maksimum'), '2.9.9')
    fireEvent.change(within(dialog).getByLabelText('Mulai (WIB)'), { target: { value: '2026-11-10T10:00' } })
    fireEvent.change(within(dialog).getByLabelText('Berakhir (WIB)'), {
      target: { value: '2026-11-10T09:00' },
    })
    const priority = within(dialog).getByLabelText('Prioritas (0–1000)')
    await user.clear(priority)
    await user.type(priority, '1001')
    await user.click(within(dialog).getByRole('button', { name: 'Simpan' }))

    expect(within(dialog).getByText('Judul wajib diisi.')).toBeVisible()
    expect(within(dialog).getByText('Tautan harus diawali http:// atau https:// tanpa spasi.')).toBeVisible()
    expect(
      within(dialog).getByText('Versi maksimum tidak boleh lebih rendah dari versi minimum.'),
    ).toBeVisible()
    expect(within(dialog).getByText('Waktu berakhir harus setelah waktu mulai.')).toBeVisible()
    expect(within(dialog).getByText('Isi bilangan bulat 0–1000.')).toBeVisible()
    expect(bannersApi.save).not.toHaveBeenCalled()

    await user.type(within(dialog).getByLabelText('Judul'), 'Gangguan login')
    expect(preview).toHaveTextContent('Gangguan login')
    expect(preview).toHaveTextContent('Buka tautan')
    expect(within(preview).getByText('Gangguan login').closest('[data-level]')).toHaveAttribute(
      'data-level',
      'info',
    )
    await user.click(within(dialog).getByRole('radio', { name: 'Kritis' }))
    expect(preview).toHaveTextContent('Tampilan di aplikasi, tingkat Kritis')
    expect(within(preview).getByText('Gangguan login').closest('[data-level]')).toHaveAttribute(
      'data-level',
      'critical',
    )
    await user.click(within(dialog).getByRole('switch', { name: /Boleh ditutup pengguna/ }))
    expect(within(preview).queryByLabelText('Tutup banner')).not.toBeInTheDocument()
  })

  it('saves a new banner with WIB times and maps server errors', async () => {
    const user = userEvent.setup()
    vi.mocked(bannersApi.save)
      .mockRejectedValueOnce(new ApiError('invalid_schedule', 'x', 400))
      .mockResolvedValueOnce(banner({ id: 'banner-3', title: 'Gangguan login' }))
    renderSection()
    await user.click(await screen.findByRole('button', { name: 'Tambah banner' }))
    const dialog = await screen.findByRole('dialog', { name: 'Tambah banner' })
    await user.type(within(dialog).getByLabelText('Judul'), '  Gangguan login ')
    await user.type(within(dialog).getByLabelText('Tautan (opsional)'), 'https://olt.example/status')
    fireEvent.change(within(dialog).getByLabelText('Berakhir (WIB)'), {
      target: { value: '2030-01-01T07:00' },
    })
    await user.click(within(dialog).getByRole('checkbox', { name: 'Android' }))
    await user.type(within(dialog).getByLabelText('Versi maksimum'), '3.1')
    await user.click(within(dialog).getByRole('button', { name: 'Simpan' }))

    expect(await screen.findByText('Waktu berakhir harus setelah waktu mulai.')).toBeVisible()
    await user.click(within(dialog).getByRole('button', { name: 'Simpan' }))
    await waitFor(() => expect(screen.queryByRole('dialog')).not.toBeInTheDocument())
    expect(bannersApi.save).toHaveBeenLastCalledWith(null, {
      title: 'Gangguan login',
      body: '',
      link_url: 'https://olt.example/status',
      level: 'info',
      starts_at: null,
      ends_at: '2030-01-01T00:00:00.000Z',
      platforms: ['android'],
      min_app_version: null,
      max_app_version: '3.1',
      dismissible: true,
      priority: 0,
    })
    expect(await screen.findByText('Banner disimpan')).toBeVisible()
  })

  it('deletes a banner after confirmation', async () => {
    const user = userEvent.setup()
    vi.mocked(bannersApi.remove).mockResolvedValue({ id: 'banner-1', deleted: true })
    renderSection()
    await user.click(await screen.findByRole('button', { name: 'Hapus banner Pemeliharaan sistem' }))
    const confirm = await screen.findByRole('alertdialog', { name: 'Hapus banner “Pemeliharaan sistem”?' })
    await user.click(within(confirm).getByRole('button', { name: 'Hapus' }))
    await waitFor(() => expect(bannersApi.remove).toHaveBeenCalledWith('banner-1'))
    expect(await screen.findByText('Banner dihapus')).toBeVisible()
  })
})
