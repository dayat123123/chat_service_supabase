import { screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { clientConfigApi } from '@/features/client-config/api'
import type * as ClientConfigApiModule from '@/features/client-config/api'
import type * as SupabaseModule from '@/lib/supabase'
import { monitorFixture } from '@/test/fixtures'
import { renderWithProviders } from '@/test/render'

import { appIntegrationApi } from '../api'
import type { AppIntegrationOverview, BridgeInstance } from '../types'
import { AppIntegrationSection } from './app-integration-section'

const ANON_KEY = 'eyJhbGciOiJIUzI1NiJ9.eyJyb2xlIjoiYW5vbiJ9.c2lnbmF0dXJlLWFub24ta2V5'

vi.mock('@/lib/supabase', async (importOriginal) => ({
  ...(await importOriginal<typeof SupabaseModule>()),
  appEnv: () => ({
    supabaseUrl: 'http://localhost:8000',
    publicApiUrl: 'https://api.olt.test',
    anonKey: ANON_KEY,
    appEnv: 'development',
  }),
}))

vi.mock('../api', () => ({ appIntegrationApi: { overview: vi.fn() } }))

vi.mock('@/features/client-config/api', async (importOriginal) => {
  const actual = await importOriginal<typeof ClientConfigApiModule>()
  return { ...actual, clientConfigApi: { ...actual.clientConfigApi, config: vi.fn() } }
})

const recent = (minutes: number) => new Date(Date.now() - minutes * 60_000).toISOString()

const bridge = (patch: Partial<BridgeInstance> = {}): BridgeInstance => ({
  instance: 'b3a1c9-4f2e1a',
  version: '0.6.0',
  started_at: recent(120),
  last_seen_at: recent(0),
  status: 'ok',
  error: null,
  app_env: 'production',
  olt_mode: 'jwt',
  issuer: 'olt',
  audience: 'olt-social',
  max_ttl_seconds: 900,
  key_count: 1,
  keys: [{ kid: 'olt-2026-11', alg: 'EdDSA' }],
  ...patch,
})

const overview = (patch: Partial<AppIntegrationOverview> = {}): AppIntegrationOverview => ({
  now: new Date().toISOString(),
  status: 'active',
  warnings: [],
  instances: [bridge()],
  last_seen_at: recent(0),
  logins: { last_login_at: recent(5), users_24h: 1234 },
  ...patch,
})

beforeEach(() => {
  vi.clearAllMocks()
  vi.mocked(appIntegrationApi.overview).mockResolvedValue(overview())
  vi.mocked(clientConfigApi.config).mockResolvedValue({
    kill_switch: { social_enabled: true, reason: null, changed_by: null, changed_at: null },
    flags: [],
    min_versions: [
      { platform: 'android', min_version: '2.4.0', updated_by: null, updated_at: recent(60) },
      { platform: 'ios', min_version: null, updated_by: null, updated_at: recent(60) },
    ],
  })
})

describe('AppIntegrationSection', () => {
  it('shows the connection data with the anon key shortened until revealed', async () => {
    const user = userEvent.setup()
    renderWithProviders(<AppIntegrationSection />, monitorFixture)

    expect(screen.getByRole('heading', { name: 'Integrasi aplikasi' })).toBeVisible()
    expect(screen.getByText('https://api.olt.test')).toBeVisible()
    const key = screen.getByTestId('anon-key')
    expect(key.textContent).not.toBe(ANON_KEY)
    expect(key.textContent).toContain('…')
    await user.click(screen.getByRole('button', { name: 'Tampilkan' }))
    expect(key).toHaveTextContent(ANON_KEY)
    await user.click(screen.getByRole('button', { name: 'Sembunyikan' }))
    expect(key.textContent).not.toBe(ANON_KEY)

    expect(screen.getByText('rendezvous_community versi 1.7.0 atau lebih baru')).toBeVisible()
    expect(await screen.findByText('Android 2.4.0')).toBeVisible()
    expect(screen.getByRole('link', { name: /Panduan integrasi library/ })).toHaveAttribute(
      'href',
      'https://github.com/dayat123123/rendezvous_community/blob/main/doc/integration.md',
    )
    expect(JSON.parse(screen.getByLabelText('Contoh config/prod.json').textContent ?? '')).toEqual({
      SOCIAL_API_URL: 'https://api.olt.test',
      SOCIAL_ANON_KEY: ANON_KEY,
    })
  })

  it('copies the API URL, the anon key, and the config snippet', async () => {
    const user = userEvent.setup()
    renderWithProviders(<AppIntegrationSection />, monitorFixture)

    await user.click(screen.getByRole('button', { name: 'Salin: URL API (SOCIAL_API_URL)' }))
    expect(await navigator.clipboard.readText()).toBe('https://api.olt.test')
    await user.click(screen.getByRole('button', { name: 'Salin: Anon key (SOCIAL_ANON_KEY)' }))
    expect(await navigator.clipboard.readText()).toBe(ANON_KEY)
    await user.click(screen.getByRole('button', { name: 'Salin: Contoh config/prod.json' }))
    expect(JSON.parse(await navigator.clipboard.readText())).toEqual({
      SOCIAL_API_URL: 'https://api.olt.test',
      SOCIAL_ANON_KEY: ANON_KEY,
    })
    expect(screen.getByRole('button', { name: 'Disalin: Contoh config/prod.json' })).toBeVisible()
  })

  it('shows an active OLT login with mode, kid, issuer, audience, and customer logins', async () => {
    renderWithProviders(<AppIntegrationSection />, monitorFixture)

    expect(await screen.findByText('Aktif')).toBeVisible()
    expect(screen.getByText('jwt')).toBeVisible()
    expect(screen.getByText('olt-2026-11')).toBeVisible()
    expect(screen.getByText('olt')).toBeVisible()
    expect(screen.getByText('olt-social')).toBeVisible()
    expect(screen.getByText('900 dtk')).toBeVisible()
    expect(screen.getByText(/0\.6\.0 · terlihat baru saja/)).toBeVisible()
    expect(screen.getByText('(5 menit lalu)')).toBeVisible()
    expect(screen.getByText('1.234')).toBeVisible()
    expect(screen.getByText(/docker\/secrets\/olt_jwks lalu jalankan make up/)).toBeVisible()
    expect(screen.queryByRole('status')).not.toBeInTheDocument()
  })

  it('flags a dev key as a warning, not an error', async () => {
    vi.mocked(appIntegrationApi.overview).mockResolvedValue(
      overview({
        status: 'warning',
        warnings: ['dev_key'],
        instances: [bridge({ app_env: 'development', keys: [{ kid: 'dev-olt-1', alg: 'EdDSA' }] })],
      }),
    )
    renderWithProviders(<AppIntegrationSection />, monitorFixture)

    expect(await screen.findByText('Peringatan')).toBeVisible()
    const warnings = screen.getByRole('status')
    expect(within(warnings).getByText(/Kunci dev terpasang/)).toBeVisible()
    expect(screen.getByText('dev-olt-1')).toBeVisible()
    expect(screen.queryByText('Tidak ada heartbeat')).not.toBeInTheDocument()
  })

  it('reports a missing heartbeat with the last time auth-bridge was seen', async () => {
    vi.mocked(appIntegrationApi.overview).mockResolvedValue(
      overview({
        status: 'no_heartbeat',
        instances: [],
        last_seen_at: recent(180),
        logins: { last_login_at: null, users_24h: 0 },
      }),
    )
    renderWithProviders(<AppIntegrationSection />, monitorFixture)

    expect(await screen.findByText('Tidak ada heartbeat')).toBeVisible()
    expect(screen.getByText(/Heartbeat terakhir .* \(3 jam lalu\)/)).toBeVisible()
    expect(screen.getByText('Belum ada login nasabah.')).toBeVisible()
    expect(screen.queryByText('Kid terpasang')).not.toBeInTheDocument()
  })
})
