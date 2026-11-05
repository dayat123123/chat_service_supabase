import { fireEvent, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { ApiError } from '@/lib/errors'
import { monitorFixture } from '@/test/fixtures'
import { renderWithProviders } from '@/test/render'
import { Toaster } from '@/test/toast'

import { bannersApi } from '../api'
import type { AppBanner, BannerSettings } from '../types'
import { BannersSection } from './banners-section'

vi.mock('../api', () => ({
  bannersApi: {
    list: vi.fn(),
    save: vi.fn(),
    remove: vi.fn(),
    stats: vi.fn(),
    settings: vi.fn(),
    setLinkSchemes: vi.fn(),
    uploadImage: vi.fn(),
  },
}))

function banner(overrides: Partial<AppBanner> = {}): AppBanner {
  return {
    id: 'banner-1',
    title: 'Pemeliharaan sistem',
    body: 'Chat dipelihara pukul 22.00 WIB',
    link_url: 'https://olt.example/status',
    level: 'warning',
    display: 'strip',
    image_path: null,
    image_url: null,
    cta_label: null,
    frequency: 'once',
    audience: 'all',
    audience_days: 7,
    starts_at: '2026-11-03T03:00:00.000Z',
    ends_at: '2026-11-04T03:00:00.000Z',
    platforms: ['android', 'ios'],
    min_app_version: '2.4.0',
    max_app_version: null,
    dismissible: false,
    priority: 10,
    status: 'active',
    stats: { impressions: 1200, clicks: 84, dismissals: 300, unique_viewers: 950, ctr: 7 },
    created_by: { id: 'adi', name: 'Adi' },
    updated_by: { id: 'adi', name: 'Adi' },
    created_at: '2026-11-03T01:00:00.000Z',
    updated_at: '2026-11-03T01:00:00.000Z',
    ...overrides,
  }
}

const settings: BannerSettings = {
  deep_link_schemes: ['olt'],
  forbidden_schemes: ['http', 'https', 'javascript', 'data', 'file', 'intent', 'content'],
  max_schemes: 5,
  updated_at: null,
  updated_by: null,
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
    banner({
      id: 'banner-2',
      title: 'Promo akhir tahun',
      status: 'ended',
      level: 'info',
      platforms: [],
      display: 'popup',
      frequency: 'daily',
      audience: 'new_users',
      audience_days: 14,
      stats: { impressions: 0, clicks: 0, dismissals: 0, unique_viewers: 0, ctr: null },
    }),
  ])
  vi.mocked(bannersApi.settings).mockResolvedValue(settings)
})

describe('BannersSection', () => {
  it('lists banners with type, status, schedule, audience, and stats', async () => {
    renderSection()
    const table = await screen.findByRole('table', { name: 'Daftar banner' })
    const active = within(table).getByRole('row', { name: /Pemeliharaan sistem/ })
    expect(within(active).getByText('Aktif')).toBeVisible()
    expect(within(active).getByText('Strip')).toBeVisible()
    expect(within(active).getByText('Peringatan · Tidak bisa ditutup')).toBeVisible()
    expect(within(active).getByText('Android, iOS')).toBeVisible()
    expect(within(active).getByText('Versi ≥ 2.4.0')).toBeVisible()
    expect(within(active).getByText('1.200 tayang · 84 klik')).toBeVisible()
    expect(within(active).getByText('CTR 7%')).toBeVisible()
    const ended = within(table).getByRole('row', { name: /Promo akhir tahun/ })
    expect(within(ended).getByText('Selesai')).toBeVisible()
    expect(within(ended).getByText('Popup')).toBeVisible()
    expect(within(ended).getByText('Info · Sekali sehari · Tidak bisa ditutup')).toBeVisible()
    expect(within(ended).getByText('Semua platform')).toBeVisible()
    expect(within(ended).getByText('Pengguna baru ≤ 14 hari')).toBeVisible()
    expect(within(ended).getByText('CTR –')).toBeVisible()
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
    expect(
      within(dialog).getByText(
        'Tautan harus diawali https:// atau skema deep link seperti olt://, tanpa spasi.',
      ),
    ).toBeVisible()
    expect(
      within(dialog).getByText('Versi maksimum tidak boleh lebih rendah dari versi minimum.'),
    ).toBeVisible()
    expect(within(dialog).getByText('Waktu berakhir harus setelah waktu mulai.')).toBeVisible()
    expect(within(dialog).getByText('Isi bilangan bulat 0–1000.')).toBeVisible()
    expect(bannersApi.save).not.toHaveBeenCalled()

    const link = within(dialog).getByLabelText('Tautan (opsional)')
    await user.clear(link)
    await user.type(link, 'mitra://order/BBCA')
    expect(
      within(dialog).getByText('Skema deep link ini belum diizinkan. Skema yang diizinkan: olt://.'),
    ).toBeVisible()

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

  it('saves a new strip banner with WIB times and maps server errors', async () => {
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
    expect(bannersApi.uploadImage).not.toHaveBeenCalled()
    expect(bannersApi.save).toHaveBeenLastCalledWith(null, {
      title: 'Gangguan login',
      body: '',
      link_url: 'https://olt.example/status',
      level: 'info',
      display: 'strip',
      image_url: null,
      cta_label: null,
      frequency: 'once',
      audience: 'all',
      audience_days: 7,
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

  it('builds a center popup with a phone preview, frequency, and new-user audience', async () => {
    const user = userEvent.setup()
    vi.mocked(bannersApi.save).mockResolvedValue(banner({ id: 'banner-4', display: 'popup' }))
    renderSection()
    await user.click(await screen.findByRole('button', { name: 'Tambah banner' }))
    const dialog = await screen.findByRole('dialog', { name: 'Tambah banner' })
    expect(within(dialog).queryByRole('radio', { name: 'Sekali sehari' })).not.toBeInTheDocument()
    await user.click(within(dialog).getByRole('radio', { name: 'Popup tengah' }))
    expect(within(dialog).getByRole('button', { name: 'Pilih gambar' })).toBeVisible()
    expect(within(dialog).getByRole('radio', { name: '4:5 (disarankan)' })).toBeChecked()

    await user.type(within(dialog).getByLabelText('Judul'), 'Promo akhir tahun')
    await user.type(within(dialog).getByLabelText('Isi (opsional)'), 'Diskon biaya transaksi')
    expect(within(dialog).getByLabelText('Label tombol (opsional)')).toBeDisabled()
    await user.type(within(dialog).getByLabelText('Tautan (opsional)'), 'olt://promo/akhir-tahun')
    await user.type(within(dialog).getByLabelText('Label tombol (opsional)'), 'Lihat promo')
    await user.click(within(dialog).getByRole('radio', { name: 'Sekali sehari' }))
    await user.click(within(dialog).getByRole('radio', { name: 'Pengguna baru ≤ N hari' }))
    const days = within(dialog).getByLabelText('Umur akun maksimal (hari)')
    await user.clear(days)
    await user.type(days, '14')

    const preview = within(dialog).getByRole('figure', { name: 'Pratinjau' })
    expect(preview).toHaveTextContent('Tampilan popup di ponsel')
    const card = within(preview).getByTestId('popup-card')
    expect(card).toHaveStyle({ borderRadius: '16px' })
    expect(card).toHaveTextContent('Promo akhir tahun')
    expect(card).toHaveTextContent('Diskon biaya transaksi')
    expect(within(card).getByText('Lihat promo')).toBeVisible()
    expect(within(card).getByLabelText('Tutup banner')).toBeInTheDocument()

    await user.click(within(dialog).getByRole('button', { name: 'Simpan' }))
    await waitFor(() => expect(bannersApi.save).toHaveBeenCalled())
    expect(bannersApi.save).toHaveBeenLastCalledWith(
      null,
      expect.objectContaining({
        display: 'popup',
        title: 'Promo akhir tahun',
        link_url: 'olt://promo/akhir-tahun',
        cta_label: 'Lihat promo',
        frequency: 'daily',
        audience: 'new_users',
        audience_days: 14,
        image_url: null,
      }),
    )
  })

  it('rejects an unsupported image before cropping', async () => {
    const user = userEvent.setup({ applyAccept: false })
    renderSection()
    await user.click(await screen.findByRole('button', { name: 'Tambah banner' }))
    const dialog = await screen.findByRole('dialog', { name: 'Tambah banner' })
    await user.click(within(dialog).getByRole('radio', { name: 'Popup tengah' }))
    await user.upload(
      within(dialog).getByTestId('banner-image-input'),
      new File(['gif'], 'promo.gif', { type: 'image/gif' }),
    )
    expect(await screen.findByText('Gambar harus JPEG, PNG, atau WebP.')).toBeVisible()
    await user.upload(
      within(dialog).getByTestId('banner-image-input'),
      new File(['jpg'], 'promo.jpg', { type: 'image/jpeg' }),
    )
    expect(await within(dialog).findByText('Potong gambar popup')).toBeVisible()
    expect(within(dialog).getByRole('button', { name: 'Pakai gambar' })).toBeDisabled()
    await user.click(within(dialog).getByRole('button', { name: 'Batal' }))
    expect(within(dialog).getByRole('button', { name: 'Pilih gambar' })).toBeVisible()
  })

  it('shows 7-day stats for a banner', async () => {
    const user = userEvent.setup()
    vi.mocked(bannersApi.stats).mockResolvedValue({
      id: 'banner-1',
      impressions: 1200,
      clicks: 84,
      dismissals: 300,
      unique_viewers: 950,
      ctr: 7,
      days: [
        '2026-10-30',
        '2026-10-31',
        '2026-11-01',
        '2026-11-02',
        '2026-11-03',
        '2026-11-04',
        '2026-11-05',
      ].map((day, index) => ({
        day,
        impressions: index * 10,
        clicks: index,
        dismissals: 0,
        ctr: index === 0 ? null : 10,
      })),
    })
    renderSection()
    await user.click(await screen.findByRole('button', { name: 'Statistik banner Pemeliharaan sistem' }))
    const dialog = await screen.findByRole('dialog', { name: 'Statistik “Pemeliharaan sistem”' })
    expect(await within(dialog).findByText('950')).toBeVisible()
    expect(within(dialog).getByText('Pengguna unik')).toBeVisible()
    const days = within(dialog).getByRole('table', { name: '7 hari terakhir' })
    expect(within(days).getAllByRole('row')).toHaveLength(8)
    expect(bannersApi.stats).toHaveBeenCalledWith('banner-1')
  })

  it('edits the allowed deep link schemes', async () => {
    const user = userEvent.setup()
    vi.mocked(bannersApi.setLinkSchemes).mockResolvedValue({
      ...settings,
      deep_link_schemes: ['mitra', 'olt'],
    })
    renderSection()
    const input = await screen.findByLabelText('Skema yang diizinkan')
    expect(input).toHaveValue('olt')
    await user.clear(input)
    await user.type(input, 'olt, https')
    await user.click(screen.getByRole('button', { name: 'Simpan skema' }))
    expect(
      screen.getByText('Skema http, https, javascript, data, file, intent, dan content tidak boleh dipakai.'),
    ).toBeVisible()
    expect(bannersApi.setLinkSchemes).not.toHaveBeenCalled()
    await user.clear(input)
    await user.type(input, 'olt, Mitra')
    await user.click(screen.getByRole('button', { name: 'Simpan skema' }))
    await waitFor(() => expect(bannersApi.setLinkSchemes).toHaveBeenCalledWith(['mitra', 'olt']))
    expect(await screen.findByText('Skema deep link disimpan')).toBeVisible()
    expect(input).toHaveValue('mitra, olt')
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
