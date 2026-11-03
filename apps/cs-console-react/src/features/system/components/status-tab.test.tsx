import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { monitorFixture } from '@/test/fixtures'
import { renderWithProviders } from '@/test/render'

import { systemApi } from '../api'
import type { SystemHealth } from '../types'
import { StatusTab } from './status-tab'

vi.mock('../api', () => ({
  systemApi: { health: vi.fn(), acknowledge: vi.fn(), badge: vi.fn() },
}))

const now = new Date().toISOString()

function health(overrides: Partial<SystemHealth> = {}): SystemHealth {
  return {
    status: 'ok',
    now,
    evaluated_at: now,
    checks: [],
    alerts: { open: [], recent: [] },
    services: [
      {
        service: 'sentinel',
        label: 'Pemantau sistem',
        instances: [
          {
            instance: 'sentinel-a',
            version: '0.1.0',
            started_at: now,
            last_seen_at: now,
            status: 'ok',
            error: null,
            detail: {},
            live: true,
          },
        ],
      },
    ],
    probes: [
      {
        name: 'realtime',
        label: 'Realtime',
        target: 'http://realtime:4000/api/ping',
        ok: true,
        status: 200,
        latency_ms: 12,
        error: null,
        checked_at: now,
        last_ok_at: now,
        stale: false,
      },
    ],
    disks: [
      {
        name: 'data',
        total_bytes: 100 * 1024 ** 3,
        avail_bytes: 50 * 1024 ** 3,
        used_ratio: 0.5,
        checked_at: now,
      },
    ],
    database: { size_bytes: 3 * 1024 ** 3, connections: 40, max_connections: 100, slots: [] },
    queues: {
      push: { queued: 0, oldest_at: null },
      storage_cleanup: { pending: 0, failing: 0, oldest_at: null },
      alerts: { pending: 0, failed_24h: 0 },
    },
    cron: [
      {
        job: 'health-evaluate',
        schedule: '* * * * *',
        active: true,
        last_status: 'succeeded',
        last_start: now,
        last_message: '1 row',
      },
    ],
    ...overrides,
  }
}

beforeEach(() => {
  vi.clearAllMocks()
})

describe('StatusTab', () => {
  it('shows a healthy system', async () => {
    vi.mocked(systemApi.health).mockResolvedValue(health())
    renderWithProviders(<StatusTab />, monitorFixture)

    expect(await screen.findByRole('status')).toHaveTextContent('Semua sistem normal')
    expect(screen.getByText('Tidak ada masalah saat ini.')).toBeInTheDocument()
    expect(screen.getByRole('meter', { name: 'Pemakaian disk data' })).toHaveAttribute('aria-valuenow', '50')
    expect(screen.getByText('50% terpakai · sisa 50 GB dari 100 GB')).toBeInTheDocument()
    expect(screen.getByText('40 dari 100')).toBeInTheDocument()
    expect(screen.getByText('Berhasil')).toBeInTheDocument()
  })

  it('lists critical problems and lets Super Admin mark an open alert as handled', async () => {
    const user = userEvent.setup()
    vi.mocked(systemApi.acknowledge).mockResolvedValue(null)
    vi.mocked(systemApi.health).mockResolvedValue(
      health({
        status: 'critical',
        checks: [
          {
            key: 'probe:realtime',
            severity: 'critical',
            title: 'Realtime tidak merespons',
            detail: 'timeout',
            failing_since: now,
          },
        ],
        alerts: {
          open: [
            {
              id: 7,
              key: 'probe:realtime',
              severity: 'critical',
              title: 'Realtime tidak merespons',
              detail: 'timeout',
              opened_at: now,
              acknowledged_by: null,
              acknowledged_at: null,
            },
            {
              id: 8,
              key: 'disk:data',
              severity: 'warning',
              title: 'Disk data hampir penuh',
              detail: null,
              opened_at: now,
              acknowledged_by: 'Sinta',
              acknowledged_at: now,
            },
          ],
          recent: [],
        },
      }),
    )
    renderWithProviders(<StatusTab />, monitorFixture)

    expect(await screen.findByRole('status')).toHaveTextContent('Ada masalah kritis')
    expect(screen.getByRole('status')).toHaveTextContent('1 masalah · 2 alert terbuka')
    expect(screen.getAllByText('Realtime tidak merespons')).toHaveLength(2)
    expect(screen.getByText(/Ditangani Sinta/)).toBeInTheDocument()

    await user.click(screen.getByRole('button', { name: 'Tandai sudah ditangani: Realtime tidak merespons' }))
    await waitFor(() => expect(systemApi.acknowledge).toHaveBeenCalledWith(7))
    expect(screen.queryByRole('button', { name: /Disk data hampir penuh/ })).not.toBeInTheDocument()
  })

  it('says clearly when the sentinel has not reported anything', async () => {
    vi.mocked(systemApi.health).mockResolvedValue(health({ services: [], probes: [], disks: [] }))
    renderWithProviders(<StatusTab />, monitorFixture)

    await screen.findByRole('status')
    expect(screen.getAllByText(/Belum ada data dari pemantau/)).toHaveLength(2)
    expect(screen.getByText('Belum ada layanan yang mengirim heartbeat.')).toBeInTheDocument()
  })

  it('labels a nearly full disk as critical, not by color alone', async () => {
    vi.mocked(systemApi.health).mockResolvedValue(
      health({
        disks: [{ name: 'data', total_bytes: 1000, avail_bytes: 80, used_ratio: 0.92, checked_at: now }],
      }),
    )
    renderWithProviders(<StatusTab />, monitorFixture)

    const meter = await screen.findByRole('meter', { name: 'Pemakaian disk data' })
    const row = meter.closest('li')!
    expect(within(row).getByText('Kritis')).toBeInTheDocument()
    expect(meter.firstElementChild).toHaveClass('bg-signal-danger')
  })

  it('warns when alerts have not been evaluated recently', async () => {
    vi.mocked(systemApi.health).mockResolvedValue(
      health({ evaluated_at: new Date(Date.now() - 10 * 60_000).toISOString() }),
    )
    renderWithProviders(<StatusTab />, monitorFixture)

    expect(await screen.findByRole('status')).toHaveTextContent('pg_cron health-evaluate')
  })
})
