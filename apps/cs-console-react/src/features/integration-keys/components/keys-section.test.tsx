import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import type { AccountRef } from '@/features/community/types'
import { ApiError } from '@/lib/errors'
import type * as SupabaseModule from '@/lib/supabase'
import { monitorFixture } from '@/test/fixtures'
import { renderWithProviders } from '@/test/render'
import { Toaster } from '@/test/toast'

import { integrationKeysApi } from '../api'
import type { IntegrationKey, IntegrationStats } from '../types'
import { IntegrationKeysSection } from './keys-section'

vi.mock('../api', () => ({
  integrationKeysApi: {
    list: vi.fn(),
    create: vi.fn(),
    update: vi.fn(),
    revoke: vi.fn(),
    stats: vi.fn(),
    statsDaily: vi.fn(),
    officialAccounts: vi.fn(),
  },
}))

vi.mock('@/lib/supabase', async (importOriginal) => ({
  ...(await importOriginal<typeof SupabaseModule>()),
  appEnv: () => ({ supabaseUrl: 'http://localhost:8000', publicApiUrl: 'https://api.olt.test' }),
}))

const SECRET = 'oik_Zm9vYmFyYmF6cXV4cXV1eGNvcmdlZ3JhdWx0Z2FycGx5d2FsZG8'

const notifyKey: IntegrationKey = {
  id: 'key-1',
  name: 'notifEngine produksi',
  prefix: 'AbCdEfGh',
  hint: 'oik_AbCdEfGh…',
  scopes: ['notify'],
  official_account: null,
  allowed_cidrs: ['10.20.0.0/16'],
  rate_limit_per_minute: 600,
  status: 'active',
  created_by: { id: 'adi', name: 'Adi' },
  created_at: '2026-11-03T01:00:00.000Z',
  updated_at: '2026-11-03T01:00:00.000Z',
  disabled_at: null,
  revoked_at: null,
  revoked_by: null,
  revoke_reason: null,
  last_used_at: '2026-11-03T02:00:00.000Z',
  last_used_ip: '10.20.1.5',
}

const stats: IntegrationStats = {
  days: 7,
  from: '2026-10-28',
  keys: [
    {
      id: 'key-1',
      name: 'notifEngine produksi',
      prefix: 'AbCdEfGh',
      status: 'active',
      last_used_at: null,
      received: 120,
      queued: 100,
      devices: 180,
      no_recipient: 15,
      duplicate: 4,
      invalid: 1,
      posts: 0,
      posts_rejected: 0,
      push: { sent: 170, failed: 10, invalid: 2, expired: 1, pending: 0 },
    },
  ],
  daily: [{ day: '2026-11-03', received: 120, queued: 100, no_recipient: 15, posts: 0 }],
  linked: { accounts: 3, profiles: 2 },
}

const research: AccountRef = {
  id: 'acc-1',
  username: 'olt_research',
  display_name: 'OLT Research',
  avatar_url: null,
}

function renderSection(agent = monitorFixture) {
  return renderWithProviders(
    <>
      <IntegrationKeysSection />
      <Toaster />
    </>,
    agent,
  )
}

beforeEach(() => {
  vi.clearAllMocks()
  vi.mocked(integrationKeysApi.list).mockResolvedValue([notifyKey])
  vi.mocked(integrationKeysApi.stats).mockResolvedValue(stats)
  vi.mocked(integrationKeysApi.officialAccounts).mockResolvedValue([research])
  vi.mocked(integrationKeysApi.statsDaily).mockResolvedValue([])
})

describe('IntegrationKeysSection', () => {
  it('lists keys with scopes, allowed IPs, status, and per-key statistics', async () => {
    renderSection()

    const list = await screen.findByRole('table', { name: 'API key' })
    const row = within(list).getByRole('row', { name: /notifEngine produksi/ })
    expect(within(row).getByText('oik_AbCdEfGh…')).toBeInTheDocument()
    expect(within(row).getByText('Notifikasi transaksi')).toBeInTheDocument()
    expect(within(row).getByText('10.20.0.0/16')).toBeInTheDocument()
    expect(within(row).getByText('Aktif')).toBeInTheDocument()
    expect(within(row).getByText('10.20.1.5')).toBeInTheDocument()

    const perKey = await screen.findByRole('table', { name: 'Statistik per API key' })
    expect(within(perKey).getByText('180')).toBeInTheDocument()
    expect(screen.getByText('94% berhasil')).toBeInTheDocument()
    expect(screen.getByText(/integration\/v1\/notify\/messages/)).toBeInTheDocument()
    expect(screen.getByText(/https:\/\/api\.olt\.test/)).toBeInTheDocument()
  })

  it('validates the form, then shows the new key only once and never caches it', async () => {
    const user = userEvent.setup()
    vi.mocked(integrationKeysApi.create).mockResolvedValue({
      key: { ...notifyKey, id: 'key-2', name: 'notifEngine baru' },
      secret: SECRET,
    })
    const { client } = renderSection()

    await user.click(screen.getByRole('button', { name: 'Buat API key' }))
    const dialog = await screen.findByRole('dialog', { name: 'Buat API key' })
    await user.clear(within(dialog).getByLabelText('Batas request per menit'))
    await user.type(within(dialog).getByLabelText('Batas request per menit'), '0')
    await user.type(within(dialog).getByLabelText('IP atau CIDR yang diizinkan'), '10.0.0.0/40')
    await user.click(within(dialog).getByRole('button', { name: 'Buat API key' }))

    expect(within(dialog).getByText('Isi nama key.')).toBeVisible()
    expect(within(dialog).getByText('Isi angka bulat 1–100.000.')).toBeVisible()
    expect(within(dialog).getByText('Alamat tidak valid: 10.0.0.0/40')).toBeVisible()
    expect(integrationKeysApi.create).not.toHaveBeenCalled()

    await user.type(within(dialog).getByLabelText('Nama key'), 'notifEngine baru')
    await user.clear(within(dialog).getByLabelText('Batas request per menit'))
    await user.type(within(dialog).getByLabelText('Batas request per menit'), '1200')
    await user.clear(within(dialog).getByLabelText('IP atau CIDR yang diizinkan'))
    await user.type(within(dialog).getByLabelText('IP atau CIDR yang diizinkan'), '203.0.113.7')
    await user.click(within(dialog).getByRole('button', { name: 'Buat API key' }))

    await waitFor(() =>
      expect(integrationKeysApi.create).toHaveBeenCalledWith({
        name: 'notifEngine baru',
        scopes: ['notify'],
        official_account_id: null,
        allowed_cidrs: ['203.0.113.7'],
        rate_limit_per_minute: 1200,
        enabled: true,
      }),
    )
    const secret = await screen.findByRole('dialog', { name: 'API key dibuat' })
    expect(within(secret).getByText(SECRET)).toBeInTheDocument()
    expect(within(secret).getByRole('alert')).toHaveTextContent('Jangan tempel di kode')
    const done = within(secret).getByRole('button', { name: 'Selesai' })
    expect(done).toBeDisabled()

    await user.keyboard('{Escape}')
    expect(screen.getByRole('dialog', { name: 'API key dibuat' })).toBeInTheDocument()

    await user.click(within(secret).getByRole('button', { name: 'Salin' }))
    expect(await navigator.clipboard.readText()).toBe(SECRET)
    await user.click(within(secret).getByRole('checkbox', { name: /sudah menyimpan key/ }))
    await user.click(done)

    await waitFor(() => expect(screen.queryByText(SECRET)).not.toBeInTheDocument())
    const cached = JSON.stringify([
      client
        .getQueryCache()
        .getAll()
        .map((query) => query.state.data),
      client
        .getMutationCache()
        .getAll()
        .map((mutation) => mutation.state.data),
    ])
    expect(cached).not.toContain(SECRET)
  })

  it('requires an official account for bot posts, listed without any community permission', async () => {
    const user = userEvent.setup()
    vi.mocked(integrationKeysApi.create).mockResolvedValue({ key: notifyKey, secret: SECRET })
    renderSection()

    await user.click(screen.getByRole('button', { name: 'Buat API key' }))
    const dialog = await screen.findByRole('dialog', { name: 'Buat API key' })
    await user.type(within(dialog).getByLabelText('Nama key'), 'Bot berita')
    await user.click(within(dialog).getByRole('checkbox', { name: /Notifikasi transaksi/ }))
    await user.click(within(dialog).getByRole('checkbox', { name: /Postingan bot/ }))
    await user.click(within(dialog).getByRole('button', { name: 'Buat API key' }))
    expect(within(dialog).getByText('Pilih akun resmi untuk izin Postingan bot.')).toBeVisible()

    await user.click(within(dialog).getByRole('combobox', { name: 'Akun resmi untuk bot' }))
    await user.click(await screen.findByRole('option', { name: /OLT Research/ }))
    await user.click(within(dialog).getByRole('button', { name: 'Buat API key' }))

    await waitFor(() =>
      expect(integrationKeysApi.create).toHaveBeenCalledWith(
        expect.objectContaining({ scopes: ['bot_post'], official_account_id: 'acc-1' }),
      ),
    )
  })

  it('explains when the official accounts cannot be loaded', async () => {
    const user = userEvent.setup()
    vi.mocked(integrationKeysApi.officialAccounts).mockRejectedValue(
      new ApiError('unavailable', undefined, 503),
    )
    renderSection()

    await user.click(screen.getByRole('button', { name: 'Buat API key' }))
    const dialog = await screen.findByRole('dialog', { name: 'Buat API key' })
    await user.click(within(dialog).getByRole('checkbox', { name: /Postingan bot/ }))
    expect(await within(dialog).findByText(/Daftar akun resmi gagal dimuat/)).toBeVisible()
  })

  it('charts the daily series of a single key', async () => {
    const user = userEvent.setup()
    vi.mocked(integrationKeysApi.statsDaily).mockResolvedValue([
      {
        key_id: 'key-1',
        name: 'notifEngine produksi',
        prefix: 'AbCdEfGh',
        days: [
          {
            day: '2026-11-03',
            received: 120,
            queued: 100,
            devices: 180,
            no_recipient: 15,
            duplicate: 4,
            invalid: 1,
            posts: 0,
            posts_rejected: 0,
          },
        ],
      },
    ])
    renderSection()

    const chooser = await screen.findByRole('combobox', { name: 'Grafik untuk' })
    expect(chooser).toHaveTextContent('Semua key')
    expect(integrationKeysApi.statsDaily).not.toHaveBeenCalled()
    await user.click(chooser)
    await user.click(await screen.findByRole('option', { name: /notifEngine produksi/ }))
    await waitFor(() => expect(integrationKeysApi.statsDaily).toHaveBeenCalledWith(7, 'key-1'))
    expect(
      screen.getByRole('figure', { name: 'Pesan dan postingan bot per hari untuk notifEngine produksi' }),
    ).toBeInTheDocument()
  })

  it('revokes a key only with a reason and maps server errors', async () => {
    const user = userEvent.setup()
    vi.mocked(integrationKeysApi.revoke)
      .mockRejectedValueOnce(new ApiError('key_revoked', 'API key yang sudah dicabut tidak bisa diubah', 409))
      .mockResolvedValueOnce({ ...notifyKey, status: 'revoked' })
    renderSection()

    await user.click(await screen.findByRole('button', { name: 'Cabut notifEngine produksi' }))
    const dialog = screen.getByRole('dialog', { name: 'Cabut API key notifEngine produksi?' })
    await user.type(within(dialog).getByLabelText('Alasan pencabutan'), 'abc')
    await user.click(within(dialog).getByRole('button', { name: 'Cabut' }))
    expect(integrationKeysApi.revoke).not.toHaveBeenCalled()

    await user.type(within(dialog).getByLabelText('Alasan pencabutan'), ' rotasi key')
    await user.click(within(dialog).getByRole('button', { name: 'Cabut' }))
    expect(await screen.findByText('API key yang sudah dicabut tidak bisa diubah.')).toBeVisible()

    await user.click(within(dialog).getByRole('button', { name: 'Cabut' }))
    await waitFor(() => expect(integrationKeysApi.revoke).toHaveBeenLastCalledWith('key-1', 'abc rotasi key'))
  })
})
