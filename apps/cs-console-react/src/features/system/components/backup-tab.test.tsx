import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { ApiError } from '@/lib/errors'
import { monitorFixture } from '@/test/fixtures'
import { renderWithProviders } from '@/test/render'
import { Toaster } from '@/test/toast'

import { systemApi } from '../api'
import type { BackupConfig, BackupOverview } from '../types'
import { BackupTab } from './backup-tab'

vi.mock('../api', () => ({
  systemApi: {
    backup: vi.fn(),
    setBackupTarget: vi.fn(),
    setBackupSchedule: vi.fn(),
    requestBackup: vi.fn(),
  },
}))

const PASSWORD = 'kata-sandi-backup-yang-panjang'
const SECRET = 's3-secret-yang-rahasia'

const emptyConfig: BackupConfig = {
  configured: false,
  revision: 0,
  endpoint: null,
  bucket: null,
  prefix: null,
  region: null,
  access_key_id: null,
  secret_set: false,
  password_set: false,
  password_set_at: null,
  configured_at: null,
  base_time: '02:00',
  offsite_minutes: 5,
  retention_daily: 7,
  retention_weekly: 4,
  retention_monthly: 6,
  wal_days: 7,
  restore_test: true,
  restore_test_weekday: 0,
  restore_test_time: '04:00',
  updated_at: '2026-11-01T00:00:00.000Z',
  updated_by: null,
}

const configured: BackupConfig = {
  ...emptyConfig,
  configured: true,
  revision: 3,
  endpoint: 'https://s3.example.co.id',
  bucket: 'olt-backup',
  prefix: 'prod',
  region: 'id-jkt-1',
  access_key_id: 'AKIA123',
  secret_set: true,
  password_set: true,
  password_set_at: '2026-10-01T03:00:00.000Z',
  configured_at: '2026-10-01T03:00:00.000Z',
  updated_by: 'Sinta',
}

function overview(overrides: Partial<BackupOverview> = {}): BackupOverview {
  return {
    config: emptyConfig,
    summary: {
      configured: false,
      target: null,
      live: false,
      state: null,
      last_base: null,
      last_files: null,
      last_restore_test: null,
    },
    requests: [],
    runs: [],
    ...overrides,
  }
}

const running = (): BackupOverview =>
  overview({
    config: configured,
    summary: {
      configured: true,
      target: 'https://s3.example.co.id/olt-backup/prod',
      live: true,
      state: {
        busy: 'check',
        repository_ready: true,
        wal: { streaming: true },
        offsite: { last_ok_at: '2026-11-03T02:55:00.000Z' },
        disk: { total_bytes: 200 * 1024 ** 3, avail_bytes: 150 * 1024 ** 3 },
      },
      last_base: {
        id: 1,
        kind: 'base',
        status: 'ok',
        started_at: '2026-11-03T19:00:00.000Z',
        finished_at: '2026-11-03T19:12:00.000Z',
        bytes: 5 * 1024 ** 3,
        snapshot_id: 'abc123def4567890',
      },
      last_files: null,
      last_restore_test: {
        id: 2,
        kind: 'restore_test',
        status: 'ok',
        started_at: '2026-11-02T21:00:00.000Z',
        finished_at: '2026-11-02T21:07:30.000Z',
        detail: { recovered_until: '2026-11-02T20:59:00.000Z' },
      },
    },
    runs: [
      {
        id: 3,
        kind: 'base',
        status: 'failed',
        started_at: '2026-11-01T19:00:00.000Z',
        finished_at: '2026-11-01T19:01:00.000Z',
        error: 'S3 403 AccessDenied',
      },
    ],
  })

beforeEach(() => {
  vi.clearAllMocks()
})

describe('BackupTab', () => {
  it('summarises the running backup service', async () => {
    vi.mocked(systemApi.backup).mockResolvedValue(running())
    renderWithProviders(<BackupTab />, monitorFixture)

    expect(await screen.findByText('Berjalan')).toBeInTheDocument()
    expect(screen.getByText('Sedang: Pemeriksaan repositori')).toBeInTheDocument()
    expect(screen.getByText('Mengalir')).toBeInTheDocument()
    expect(screen.getByText(/5 GB · snapshot abc123def456/)).toBeInTheDocument()
    expect(screen.getByText(/pulih sampai .* · durasi 7 mnt 30 dtk/)).toBeInTheDocument()
    expect(screen.getByRole('meter', { name: 'Disk staging backup' })).toHaveAttribute('aria-valuenow', '25')
    const table = screen.getByRole('table')
    expect(within(table).getByText('S3 403 AccessDenied')).toBeInTheDocument()
    expect(within(table).getByText('Gagal')).toBeInTheDocument()
  })

  it('requires the encryption password, its confirmation, and the safe-keeping checkbox on first setup', async () => {
    const user = userEvent.setup()
    vi.mocked(systemApi.backup).mockResolvedValue(overview())
    vi.mocked(systemApi.setBackupTarget).mockResolvedValue({ ...configured, revision: 1 })
    const { client } = renderWithProviders(
      <>
        <BackupTab />
        <Toaster />
      </>,
      monitorFixture,
    )

    expect(await screen.findByText('Belum diatur')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Backup penuh sekarang' })).toBeDisabled()

    await user.type(screen.getByLabelText('Endpoint S3'), 'https://s3.example.co.id')
    await user.type(screen.getByLabelText('Bucket'), 'olt-backup')
    await user.type(screen.getByLabelText('Access key ID'), 'AKIA123')
    await user.click(screen.getByRole('button', { name: 'Simpan tujuan' }))
    expect(screen.getByText('Isi secret access key.')).toBeInTheDocument()
    expect(screen.getByText('Isi password enkripsi.')).toBeInTheDocument()
    expect(screen.getByText('Centang dulu setelah password tersimpan di tempat aman.')).toBeInTheDocument()

    await user.type(screen.getByLabelText('Secret access key'), SECRET)
    await user.type(screen.getByLabelText('Password enkripsi'), PASSWORD)
    await user.type(screen.getByLabelText('Ulangi password enkripsi'), `${PASSWORD}x`)
    await user.click(screen.getByRole('checkbox', { name: /Saya sudah menyimpan password ini/ }))
    await user.click(screen.getByRole('button', { name: 'Simpan tujuan' }))
    expect(screen.getByText('Password tidak sama.')).toBeInTheDocument()
    expect(systemApi.setBackupTarget).not.toHaveBeenCalled()

    await user.clear(screen.getByLabelText('Ulangi password enkripsi'))
    await user.type(screen.getByLabelText('Ulangi password enkripsi'), PASSWORD)
    await user.click(screen.getByRole('button', { name: 'Simpan tujuan' }))

    await waitFor(() =>
      expect(systemApi.setBackupTarget).toHaveBeenCalledWith({
        endpoint: 'https://s3.example.co.id',
        bucket: 'olt-backup',
        prefix: '',
        region: '',
        accessKeyId: 'AKIA123',
        secretAccessKey: SECRET,
        password: PASSWORD,
      }),
    )
    expect(await screen.findByText(/Tujuan backup disimpan/)).toBeInTheDocument()
    const cached = JSON.stringify(
      client
        .getQueryCache()
        .getAll()
        .map((query) => query.state.data),
    )
    expect(cached).not.toContain(SECRET)
    expect(cached).not.toContain(PASSWORD)
    await waitFor(() => {
      const mutations = JSON.stringify(
        client
          .getMutationCache()
          .getAll()
          .map((mutation) => mutation.state),
      )
      expect(mutations).not.toContain(PASSWORD)
      expect(mutations).not.toContain(SECRET)
    })
    for (const input of document.querySelectorAll<HTMLInputElement>('input[type="password"]')) {
      expect(input.value).toBe('')
    }
  })

  it('locks the password of an existing repository and asks for a new one when the folder changes', async () => {
    const user = userEvent.setup()
    vi.mocked(systemApi.backup).mockResolvedValue(running())
    vi.mocked(systemApi.setBackupTarget).mockResolvedValue({ ...configured, access_key_id: 'AKIA456' })
    renderWithProviders(<BackupTab />, monitorFixture)

    expect(await screen.findByText(/Password enkripsi repositori ini tersimpan sejak/)).toHaveTextContent(
      'Untuk memakai password baru, isi folder atau bucket baru.',
    )
    expect(screen.queryByLabelText('Password enkripsi')).not.toBeInTheDocument()
    expect(screen.getByText('Tersimpan', { selector: 'span' })).toBeInTheDocument()

    await user.clear(screen.getByLabelText('Folder (prefix)'))
    await user.type(screen.getByLabelText('Folder (prefix)'), 'prod-2')
    expect(screen.getByRole('note')).toHaveTextContent('repositori baru yang butuh password enkripsi baru')
    expect(screen.getByLabelText('Password enkripsi')).toBeInTheDocument()

    await user.clear(screen.getByLabelText('Folder (prefix)'))
    await user.type(screen.getByLabelText('Folder (prefix)'), 'prod')
    await user.clear(screen.getByLabelText('Access key ID'))
    await user.type(screen.getByLabelText('Access key ID'), 'AKIA456')
    await user.click(screen.getByRole('button', { name: 'Simpan tujuan' }))

    await waitFor(() =>
      expect(systemApi.setBackupTarget).toHaveBeenCalledWith(
        expect.objectContaining({ accessKeyId: 'AKIA456', secretAccessKey: '', password: '' }),
      ),
    )
  })

  it('explains a locked password reported by the server', async () => {
    const user = userEvent.setup()
    vi.mocked(systemApi.backup).mockResolvedValue(running())
    vi.mocked(systemApi.setBackupTarget).mockRejectedValue(new ApiError('backup_password_locked', 'x', 409))
    renderWithProviders(
      <>
        <BackupTab />
        <Toaster />
      </>,
      monitorFixture,
    )

    await user.click(await screen.findByRole('button', { name: 'Simpan tujuan' }))
    expect(await screen.findByText(/Pakai folder atau bucket baru\.$/)).toBeInTheDocument()
  })

  it('shows a pending full backup and still lets Super Admin request a restore test', async () => {
    const user = userEvent.setup()
    const data = {
      ...running(),
      requests: [{ kind: 'base' as const, requested_at: '2026-11-03T03:00:00.000Z', requested_by: 'Sinta' }],
    }
    const updated = {
      ...data,
      requests: [
        ...data.requests,
        { kind: 'restore_test' as const, requested_at: '2026-11-03T03:01:00.000Z', requested_by: 'Sinta' },
      ],
    }
    vi.mocked(systemApi.backup).mockResolvedValue(data)
    vi.mocked(systemApi.requestBackup).mockResolvedValue(updated)
    renderWithProviders(<BackupTab />, monitorFixture)

    expect(await screen.findByText(/Menunggu: Backup penuh, diminta Sinta/)).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Backup penuh sekarang' })).toBeDisabled()
    vi.mocked(systemApi.backup).mockResolvedValue(updated)
    await user.click(screen.getByRole('button', { name: 'Uji restore sekarang' }))

    await waitFor(() => expect(systemApi.requestBackup).toHaveBeenCalledWith('restore_test'))
    await waitFor(() => expect(screen.getByRole('button', { name: 'Uji restore sekarang' })).toBeDisabled())
  })

  it('saves the schedule with WIB times and the chosen weekday', async () => {
    const user = userEvent.setup()
    vi.mocked(systemApi.backup).mockResolvedValue(running())
    vi.mocked(systemApi.setBackupSchedule).mockResolvedValue(configured)
    renderWithProviders(<BackupTab />, monitorFixture)

    const days = await screen.findByLabelText('Simpan backup harian')
    await user.clear(days)
    await user.type(days, '61')
    await user.click(screen.getByRole('button', { name: 'Simpan jadwal' }))
    expect(days).toHaveAttribute('aria-invalid', 'true')
    expect(systemApi.setBackupSchedule).not.toHaveBeenCalled()

    await user.clear(days)
    await user.type(days, '14')
    await user.click(screen.getByRole('radio', { name: 'Sabtu' }))
    await user.click(screen.getByRole('button', { name: 'Simpan jadwal' }))

    await waitFor(() =>
      expect(systemApi.setBackupSchedule).toHaveBeenCalledWith({
        baseTime: '02:00',
        offsiteMinutes: 5,
        retentionDaily: 14,
        retentionWeekly: 4,
        retentionMonthly: 6,
        walDays: 7,
        restoreTest: true,
        restoreTestWeekday: 6,
        restoreTestTime: '04:00',
      }),
    )
  })
})
