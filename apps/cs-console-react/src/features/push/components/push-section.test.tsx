import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { monitorFixture } from '@/test/fixtures'
import { renderWithProviders } from '@/test/render'
import { Toaster } from '@/test/toast'

import { pushApi } from '../api'
import type { PushStatus } from '../types'
import { PushSection } from './push-section'

vi.mock('../api', () => ({
  pushApi: { status: vi.fn(), findUsers: vi.fn(), test: vi.fn(), campaign: vi.fn() },
}))

function status(overrides: Partial<PushStatus> = {}): PushStatus {
  return {
    state: 'active',
    instances: [
      {
        instance: 'notifier-1',
        version: '0.1.0',
        configured: true,
        project_id: 'olt-prod',
        error: null,
        started_at: '2026-11-02T01:00:00.000Z',
        seen_at: '2026-11-02T03:00:00.000Z',
        live: true,
      },
    ],
    devices: { total: 1250, users: 980, android: 1100, ios: 140, web: 10, active_30d: 900 },
    queue: { queued: 0, oldest_at: null },
    last_24h: { sent: 3400, failed: 2, invalid: 15, expired: 0 },
    last_sent_at: '2026-11-02T02:59:00.000Z',
    last_error: null,
    ttl_hours: 24,
    max_attempts: 6,
    ...overrides,
  }
}

beforeEach(() => {
  vi.clearAllMocks()
})

describe('PushSection', () => {
  it('explains how to install Firebase while push is not set up', async () => {
    vi.mocked(pushApi.status).mockResolvedValue(
      status({
        state: 'not_configured',
        instances: [{ ...status().instances[0]!, configured: false, project_id: null }],
      }),
    )
    renderWithProviders(<PushSection />, monitorFixture)

    expect(await screen.findByText('Belum dipasang')).toBeInTheDocument()
    expect(screen.getByRole('status')).toHaveTextContent('file kredensial Firebase belum dipasang')
    expect(screen.getByText('Cara memasang Firebase').closest('details')).toHaveAttribute('open')
    expect(screen.getByText('docker/secrets/firebase/')).toBeInTheDocument()
    expect(screen.getByText('Push uji bisa dikirim setelah status layanan Aktif.')).toBeInTheDocument()
  })

  it('shows the Firebase error the notifier reported', async () => {
    vi.mocked(pushApi.status).mockResolvedValue(
      status({
        state: 'error',
        instances: [{ ...status().instances[0]!, error: 'Firebase menolak kredensial: invalid_grant' }],
      }),
    )
    renderWithProviders(<PushSection />, monitorFixture)

    expect(await screen.findByText('Bermasalah')).toBeInTheDocument()
    expect(screen.getByRole('status')).toHaveTextContent('Firebase menolak kredensial: invalid_grant')
  })

  it('shows delivery numbers and sends a test push to a chosen user', async () => {
    const user = userEvent.setup()
    vi.mocked(pushApi.status).mockResolvedValue(status())
    vi.mocked(pushApi.findUsers).mockResolvedValue([
      {
        id: 'u-1',
        username: 'sari_invest',
        display_name: 'Sari',
        avatar_url: null,
        devices: [
          { platform: 'android', app_version: '2.4.1', last_seen_at: '2026-11-02T02:00:00.000Z' },
          { platform: 'ios', app_version: null, last_seen_at: '2026-11-01T02:00:00.000Z' },
        ],
      },
    ])
    vi.mocked(pushApi.test).mockResolvedValue({ queued: 2 })
    renderWithProviders(
      <>
        <PushSection />
        <Toaster />
      </>,
      monitorFixture,
    )

    expect(
      await screen.findByText('Aktif. Push dikirim lewat Firebase project olt-prod.'),
    ).toBeInTheDocument()
    expect(screen.getByText('Android 1.100 · iOS 140 · Web 10')).toBeInTheDocument()
    expect(screen.getByText('token mati 15 · kedaluwarsa 0')).toBeInTheDocument()
    expect(screen.getByText('Cara memasang Firebase').closest('details')).not.toHaveAttribute('open')

    await user.type(
      screen.getByRole('searchbox', { name: 'Cari pengguna dengan perangkat terdaftar' }),
      'sari',
    )
    await user.click(await screen.findByRole('button', { name: 'Kirim push uji ke Sari' }))

    await waitFor(() => expect(pushApi.test).toHaveBeenCalledWith('u-1'))
    expect(await screen.findByText('Push uji dikirim ke 2 perangkat.')).toBeInTheDocument()
    expect(pushApi.findUsers).toHaveBeenCalledWith('sari')
  })
})
