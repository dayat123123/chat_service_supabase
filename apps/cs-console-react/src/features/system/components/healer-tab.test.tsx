import { screen, within } from '@testing-library/react'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { monitorFixture } from '@/test/fixtures'
import { renderWithProviders } from '@/test/render'

import { systemApi } from '../api'
import type { HealerOverview, HealerState } from '../types'
import { HealerTab } from './healer-tab'

vi.mock('../api', () => ({
  systemApi: { healer: vi.fn() },
}))

const state: HealerState = {
  reported_at: '2026-11-04T07:00:00.000Z',
  live: true,
  fresh: true,
  read_error: null,
  version: '0.1.0',
  project: 'olt-social',
  enabled: true,
  started_at: '2026-11-04T06:00:00.000Z',
  checked_at: '2026-11-04T06:59:55.000Z',
  rules: {
    unhealthy_seconds: 60,
    min_uptime_seconds: 120,
    max_restarts_per_hour: 3,
    global_cooldown_seconds: 30,
    systemic_fraction: 0.5,
    interval_seconds: 10,
  },
  watched: 19,
  unhealthy: [],
  skip: null,
  gave_up: [],
  error: null,
}

function overview(overrides: Partial<HealerOverview> = {}): HealerOverview {
  return {
    now: '2026-11-04T07:00:00.000Z',
    state,
    events: [],
    counts: { restarts_24h: 0, failed_24h: 0, gave_up_24h: 0, skipped_24h: 0 },
    ...overrides,
  }
}

beforeEach(() => {
  vi.clearAllMocks()
})

describe('HealerTab', () => {
  it('shows the active healer, its rules, and recent restarts', async () => {
    vi.mocked(systemApi.healer).mockResolvedValue(
      overview({
        counts: { restarts_24h: 2, failed_24h: 1, gave_up_24h: 0, skipped_24h: 0 },
        events: [
          {
            id: 'b',
            at: '2026-11-04T06:50:00.000Z',
            service: 'rest',
            label: 'API (PostgREST)',
            container: 'olt-social-rest-1',
            action: 'restart',
            reason: 'unhealthy',
            result: 'failed',
            detail: 'unhealthy 61s, uptime 300s: exit 1',
            error: 'docker restart: status 500',
          },
          {
            id: 'a',
            at: '2026-11-04T06:40:00.000Z',
            service: 'media',
            label: 'Upload media',
            container: 'olt-social-media-1',
            action: 'restart',
            reason: 'unhealthy',
            result: 'ok',
            detail: null,
            error: null,
          },
        ],
      }),
    )
    renderWithProviders(<HealerTab />, monitorFixture)

    expect(await screen.findByText('Aktif')).toBeInTheDocument()
    expect(screen.getByText('Versi 0.1.0 · proyek olt-social')).toBeInTheDocument()
    expect(screen.getByText('19 container')).toBeInTheDocument()
    expect(screen.getByText('2 restart, 1 gagal')).toBeInTheDocument()
    expect(
      screen.getByText(/Unhealthy ≥ 60 dtk dan berjalan ≥ 120 dtk · maks 3 restart\/jam/),
    ).toBeInTheDocument()
    expect(screen.getByText('Tidak ada layanan yang ditinggalkan.')).toBeInTheDocument()
    const table = screen.getByRole('table')
    expect(within(table).getByText('Waktu (WIB)')).toBeInTheDocument()
    expect(within(table).getByText('API (PostgREST)')).toBeInTheDocument()
    expect(within(table).getByText('Gagal')).toBeInTheDocument()
    expect(within(table).getByText('Di-restart')).toBeInTheDocument()
    expect(within(table).getByText('docker restart: status 500')).toBeInTheDocument()
    expect(within(table).getAllByText('Unhealthy')).toHaveLength(2)
  })

  it('lists services the healer gave up on and why restarts are held back', async () => {
    vi.mocked(systemApi.healer).mockResolvedValue(
      overview({
        state: {
          ...state,
          gave_up: [
            {
              service: 'rest',
              label: 'API (PostgREST)',
              since: '2026-11-04T06:55:00.000Z',
              until: '2026-11-04T07:30:00.000Z',
              restarts: 3,
            },
          ],
          skip: { reason: 'systemic', since: '2026-11-04T06:58:00.000Z', services: ['auth', 'kong'] },
          unhealthy: [{ service: 'auth', container: 'olt-social-auth-1', since: '2026-11-04T06:58:00.000Z' }],
        },
        events: [
          {
            id: 'c',
            at: '2026-11-04T06:58:00.000Z',
            service: '',
            label: '',
            container: '',
            action: 'skip',
            reason: 'systemic',
            result: 'skipped',
            detail: 'unhealthy: auth, kong',
            error: null,
          },
        ],
      }),
    )
    renderWithProviders(<HealerTab />, monitorFixture)

    expect(await screen.findByText('Restart sedang ditahan')).toBeInTheDocument()
    expect(screen.getByText(/Banyak layanan unhealthy bersamaan/)).toBeInTheDocument()
    expect(within(screen.getByRole('status')).getByText(/unhealthy: auth, kong$/)).toBeInTheDocument()
    expect(screen.getByText('Sedang unhealthy')).toBeInTheDocument()
    expect(screen.getByText('olt-social-auth-1')).toBeInTheDocument()
    expect(screen.getByText('API (PostgREST)')).toBeInTheDocument()
    expect(screen.getByText(/3 restart dalam 1 jam · dicoba lagi setelah/)).toBeInTheDocument()
    const table = screen.getByRole('table')
    expect(within(table).getByText('Semua layanan')).toBeInTheDocument()
    expect(within(table).getByText('Gangguan sistemik')).toBeInTheDocument()
    expect(within(table).getByText('Ditahan')).toBeInTheDocument()
  })

  it('explains report-only mode and a missing or broken healer', async () => {
    vi.mocked(systemApi.healer).mockResolvedValueOnce(overview({ state: { ...state, enabled: false } }))
    const { unmount } = renderWithProviders(<HealerTab />, monitorFixture)
    expect(await screen.findByText('Mode laporan saja')).toBeInTheDocument()
    expect(screen.getByText(/HEALER_ENABLED=false: healer hanya mencatat/)).toBeInTheDocument()
    expect(screen.getByText('Belum ada restart otomatis.')).toBeInTheDocument()
    unmount()

    vi.mocked(systemApi.healer).mockResolvedValueOnce(
      overview({
        state: { ...state, fresh: false, read_error: 'state file not found; is the healer running?' },
      }),
    )
    const second = renderWithProviders(<HealerTab />, monitorFixture)
    expect(await screen.findByText('Tidak berjalan')).toBeInTheDocument()
    expect(screen.getByText('state file not found; is the healer running?')).toBeInTheDocument()
    second.unmount()

    vi.mocked(systemApi.healer).mockResolvedValueOnce(overview({ state: null }))
    renderWithProviders(<HealerTab />, monitorFixture)
    expect(await screen.findByText('Belum ada data')).toBeInTheDocument()
    expect(screen.getByText(/profil cluster/)).toBeInTheDocument()
  })
})
