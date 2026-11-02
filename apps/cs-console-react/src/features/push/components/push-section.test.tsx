import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeAll, beforeEach, describe, expect, it, vi } from 'vitest'

import { useAuth } from '@/features/auth/hooks'
import { monitorFixture } from '@/test/fixtures'
import { renderWithProviders } from '@/test/render'
import { Toaster } from '@/test/toast'

import { pushApi } from '../api'
import type { PushStatus } from '../types'
import { PushSection } from './push-section'

vi.mock('../api', () => ({
  pushApi: {
    status: vi.fn(),
    findUsers: vi.fn(),
    test: vi.fn(),
    campaign: vi.fn(),
    setCredentials: vi.fn(),
    removeCredentials: vi.fn(),
  },
}))

const credentials = {
  revision: 3,
  project_id: 'olt-prod',
  client_email: 'firebase-adminsdk-x1@olt-prod.iam.gserviceaccount.com',
  key_id: 'a1b2c3d4e5f60718293a4b5c6d7e8f9012345678',
  updated_at: '2026-11-02T02:00:00.000Z',
  updated_by: 'Sinta',
}

function status(overrides: Partial<PushStatus> = {}): PushStatus {
  return {
    state: 'active',
    credentials,
    credentials_revision: 3,
    instances: [
      {
        instance: 'notifier-1',
        version: '0.2.0',
        configured: true,
        project_id: 'olt-prod',
        error: null,
        started_at: '2026-11-02T01:00:00.000Z',
        seen_at: '2026-11-02T03:00:00.000Z',
        credentials_revision: 3,
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

const notConfigured = () =>
  status({
    state: 'not_configured',
    credentials: null,
    credentials_revision: 0,
    instances: [{ ...status().instances[0]!, configured: false, project_id: null, credentials_revision: 0 }],
  })

let pem = ''

beforeAll(async () => {
  const pair = await crypto.subtle.generateKey(
    {
      name: 'RSASSA-PKCS1-v1_5',
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: 'SHA-256',
    },
    true,
    ['sign', 'verify'],
  )
  const der = new Uint8Array(await crypto.subtle.exportKey('pkcs8', pair.privateKey))
  pem = `-----BEGIN PRIVATE KEY-----\n${btoa(String.fromCharCode(...der))}\n-----END PRIVATE KEY-----\n`
})

function keyFile(projectId = 'olt-prod', name = 'olt-prod-firebase-adminsdk.json') {
  return new File(
    [
      JSON.stringify({
        type: 'service_account',
        project_id: projectId,
        private_key_id: 'f0e1d2c3b4a5968778695a4b3c2d1e0f12345678',
        private_key: pem,
        client_email: `firebase-adminsdk-x1@${projectId}.iam.gserviceaccount.com`,
        token_uri: 'https://oauth2.googleapis.com/token',
      }),
    ],
    name,
    { type: 'application/json' },
  )
}

function fileInput(container: HTMLElement) {
  return container.querySelector<HTMLInputElement>('input[type="file"]')!
}

beforeEach(() => {
  vi.clearAllMocks()
})

describe('PushSection', () => {
  it('guides the first Firebase key upload while push is not set up', async () => {
    vi.mocked(pushApi.status).mockResolvedValue(notConfigured())
    renderWithProviders(<PushSection />, monitorFixture)

    expect(await screen.findByText('Belum dipasang')).toBeInTheDocument()
    expect(screen.getByRole('status')).toHaveTextContent('kunci Firebase belum diunggah')
    expect(screen.getByText(/Generate new private key/)).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Pilih file JSON' })).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Hapus kunci' })).not.toBeInTheDocument()
    expect(screen.getByText('Push uji bisa dikirim setelah status layanan Aktif.')).toBeInTheDocument()
  })

  it('checks the chosen key file and saves it after review', async () => {
    const user = userEvent.setup()
    vi.mocked(pushApi.status).mockResolvedValue(notConfigured())
    vi.mocked(pushApi.setCredentials).mockResolvedValue(credentials)
    const { container } = renderWithProviders(
      <>
        <PushSection />
        <Toaster />
      </>,
      monitorFixture,
    )
    await screen.findByText('Belum dipasang')

    await user.upload(fileInput(container), keyFile())
    const review = await screen.findByRole('group', { name: 'Periksa sebelum menyimpan' })
    expect(within(review).getByText('olt-prod')).toBeInTheDocument()
    expect(within(review).getByText('f0e1d2c3b4…')).toBeInTheDocument()
    expect(pushApi.setCredentials).not.toHaveBeenCalled()

    await user.click(within(review).getByRole('button', { name: 'Simpan kunci' }))

    await waitFor(() => expect(pushApi.setCredentials).toHaveBeenCalledTimes(1))
    const [key, replaceProject] = vi.mocked(pushApi.setCredentials).mock.calls[0]!
    expect(replaceProject).toBe(false)
    expect(key).toEqual({
      type: 'service_account',
      project_id: 'olt-prod',
      client_email: 'firebase-adminsdk-x1@olt-prod.iam.gserviceaccount.com',
      private_key_id: 'f0e1d2c3b4a5968778695a4b3c2d1e0f12345678',
      private_key: pem,
    })
    expect(await screen.findByText(/Kunci Firebase disimpan/)).toBeInTheDocument()
  })

  it('names the common mistake of uploading google-services.json', async () => {
    const user = userEvent.setup()
    vi.mocked(pushApi.status).mockResolvedValue(notConfigured())
    const { container } = renderWithProviders(<PushSection />, monitorFixture)
    await screen.findByText('Belum dipasang')

    const androidConfig = new File(
      [JSON.stringify({ project_info: { project_id: 'olt-prod' }, client: [] })],
      'google-services.json',
      { type: 'application/json' },
    )
    await user.upload(fileInput(container), androidConfig)

    expect(await screen.findByRole('alert')).toHaveTextContent('Ini file google-services.json')
    expect(screen.queryByRole('group', { name: 'Periksa sebelum menyimpan' })).not.toBeInTheDocument()
  })

  it('asks for an explicit switch when the key belongs to another project', async () => {
    const user = userEvent.setup()
    vi.mocked(pushApi.status).mockResolvedValue(status())
    vi.mocked(pushApi.setCredentials).mockResolvedValue({
      ...credentials,
      project_id: 'olt-baru',
      revision: 4,
    })
    const { container } = renderWithProviders(<PushSection />, monitorFixture)
    expect(await screen.findByText('Dipakai notifier dan diterima Google.')).toBeInTheDocument()

    await user.upload(fileInput(container), keyFile('olt-baru'))
    const review = await screen.findByRole('group', { name: 'Periksa sebelum menyimpan' })
    expect(within(review).getByRole('alert')).toHaveTextContent('berbeda dari kunci sekarang (olt-prod)')
    await user.click(within(review).getByRole('button', { name: 'Ganti project dan simpan' }))

    await waitFor(() => expect(pushApi.setCredentials).toHaveBeenCalledWith(expect.anything(), true))
  })

  it('shows that the notifier is still loading a new key', async () => {
    vi.mocked(pushApi.status).mockResolvedValue(
      status({
        state: 'not_configured',
        instances: [
          { ...status().instances[0]!, configured: false, project_id: null, credentials_revision: 2 },
        ],
      }),
    )
    renderWithProviders(<PushSection />, monitorFixture)

    expect(await screen.findByRole('status')).toHaveTextContent('Notifier sedang memuatnya')
    expect(screen.getByText('Menunggu notifier memuat kunci ini…')).toBeInTheDocument()
  })

  it('waits for the notifier after a key is removed', async () => {
    vi.mocked(pushApi.status).mockResolvedValue(status({ credentials: null, credentials_revision: 4 }))
    renderWithProviders(<PushSection />, monitorFixture)

    expect(await screen.findByRole('status')).toHaveTextContent('Kunci dihapus. Menunggu notifier')
    expect(screen.getByRole('button', { name: 'Pilih file JSON' })).toBeInTheDocument()
  })

  it('ignores a stopped notifier that still looks alive once another one has the key', async () => {
    const stale = { ...status().instances[0]!, instance: 'notifier-old', credentials_revision: 2 }
    vi.mocked(pushApi.status).mockResolvedValue(status({ instances: [status().instances[0]!, stale] }))
    renderWithProviders(<PushSection />, monitorFixture)

    expect(await screen.findByText('Dipakai notifier dan diterima Google.')).toBeInTheDocument()
  })

  it('removes the key after confirmation', async () => {
    const user = userEvent.setup()
    vi.mocked(pushApi.status).mockResolvedValue(status())
    vi.mocked(pushApi.removeCredentials).mockResolvedValue({ removed: true })
    renderWithProviders(<PushSection />, monitorFixture)

    await user.click(await screen.findByRole('button', { name: 'Hapus kunci' }))
    const dialog = await screen.findByRole('alertdialog')
    expect(dialog).toHaveTextContent('dibatalkan setelah 24 jam')
    await user.click(within(dialog).getByRole('button', { name: 'Hapus kunci' }))

    await waitFor(() => expect(pushApi.removeCredentials).toHaveBeenCalledTimes(1))
  })

  it('updates the Push notification badge as soon as the status changes', async () => {
    vi.mocked(pushApi.status).mockResolvedValue(status())
    renderWithProviders(<PushSection />, {
      ...monitorFixture,
      settings: { ...monitorFixture.settings, community_push_ready: false },
    })

    await waitFor(() => {
      const phase = useAuth.getState().phase
      expect(phase.kind === 'ready' && phase.agent.settings.community_push_ready).toBe(true)
    })
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
    expect(screen.queryByText('Dipakai notifier dan diterima Google.')).not.toBeInTheDocument()
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
