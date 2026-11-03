import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { monitorFixture } from '@/test/fixtures'
import { renderWithProviders } from '@/test/render'
import { Toaster } from '@/test/toast'

import { systemApi } from '../api'
import type { AlertChannels } from '../types'
import { AlertsTab } from './alerts-tab'

vi.mock('../api', () => ({
  systemApi: {
    channels: vi.fn(),
    setOptions: vi.fn(),
    setTelegram: vi.fn(),
    setEmail: vi.fn(),
    sendTest: vi.fn(),
  },
}))

const TOKEN = '123456789:AAHdqTcvCH1vGWJxfSeofSAs0K5PALDsawQ'

function channels(overrides: Partial<AlertChannels> = {}): AlertChannels {
  return {
    revision: 4,
    label: 'OLT Social',
    console_url: null,
    updated_at: '2026-11-02T02:00:00.000Z',
    updated_by: 'Sinta',
    telegram: { enabled: false, token_set: false, chat_ids: [] },
    email: {
      enabled: true,
      host: 'smtp.example.co.id',
      port: 587,
      security: 'starttls',
      username: 'ops',
      password_set: true,
      from: 'alert@example.co.id',
      to: ['ops@example.co.id'],
    },
    last: { telegram: null, email: null },
    ...overrides,
  }
}

function card(name: string) {
  return screen.getByRole('heading', { name }).closest('section')!
}

beforeEach(() => {
  vi.clearAllMocks()
})

describe('AlertsTab', () => {
  it('stores the Telegram bot token write-only and clears it after saving', async () => {
    const user = userEvent.setup()
    const saved = channels({ telegram: { enabled: true, token_set: true, chat_ids: ['-1001234567890'] } })
    vi.mocked(systemApi.channels).mockResolvedValue(channels())
    vi.mocked(systemApi.setTelegram).mockResolvedValue(saved)
    const { client } = renderWithProviders(
      <>
        <AlertsTab />
        <Toaster />
      </>,
      monitorFixture,
    )

    await screen.findByRole('heading', { name: 'Telegram' })
    const telegram = card('Telegram')
    expect(within(telegram).getByText(/@BotFather/)).toBeInTheDocument()
    await user.click(within(telegram).getByRole('switch', { name: 'Kirim alert ke Telegram' }))
    await user.click(within(telegram).getByRole('button', { name: 'Simpan' }))
    expect(within(telegram).getByText(/Isi token bot dan minimal satu chat ID/)).toBeInTheDocument()

    await user.type(within(telegram).getByLabelText('Token bot'), TOKEN)
    await user.type(within(telegram).getByLabelText('Chat ID'), '-1001234567890')
    await user.click(within(telegram).getByRole('button', { name: 'Simpan' }))

    await waitFor(() =>
      expect(systemApi.setTelegram).toHaveBeenCalledWith({
        enabled: true,
        chatIds: ['-1001234567890'],
        botToken: TOKEN,
      }),
    )
    expect(await screen.findByText('Pengaturan alert disimpan.')).toBeInTheDocument()
    const fresh = card('Telegram')
    expect(within(fresh).getByLabelText('Token bot')).toHaveValue('')
    expect(within(fresh).getByText('Tersimpan')).toBeInTheDocument()
    expect(
      JSON.stringify(
        client
          .getQueryCache()
          .getAll()
          .map((query) => query.state.data),
      ),
    ).not.toContain(TOKEN)
    await waitFor(() =>
      expect(
        JSON.stringify(
          client
            .getMutationCache()
            .getAll()
            .map((mutation) => mutation.state),
        ),
      ).not.toContain(TOKEN),
    )
  })

  it('keeps, replaces, or clears the SMTP password explicitly', async () => {
    const user = userEvent.setup()
    vi.mocked(systemApi.channels).mockResolvedValue(channels())
    vi.mocked(systemApi.setEmail).mockResolvedValue(channels())
    renderWithProviders(<AlertsTab />, monitorFixture)

    await screen.findByRole('heading', { name: 'Email' })
    const email = card('Email')
    expect(within(email).getByText('Tersimpan')).toBeInTheDocument()
    await user.clear(within(email).getByLabelText('Penerima'))
    await user.type(within(email).getByLabelText('Penerima'), 'ops@example.co.id{Enter}cto@example.co.id')
    await user.click(within(email).getByRole('button', { name: 'Simpan' }))
    await waitFor(() =>
      expect(systemApi.setEmail).toHaveBeenLastCalledWith(
        expect.objectContaining({ to: ['ops@example.co.id', 'cto@example.co.id'], password: null }),
      ),
    )

    await user.click(within(card('Email')).getByRole('button', { name: 'Hapus password' }))
    expect(within(card('Email')).getByText(/akan dihapus saat Anda menyimpan/)).toBeInTheDocument()
    await user.click(within(card('Email')).getByRole('button', { name: 'Simpan' }))
    await waitFor(() =>
      expect(systemApi.setEmail).toHaveBeenLastCalledWith(expect.objectContaining({ password: '' })),
    )
  })

  it('sends a test only for a saved channel and shows the delivery while it waits', async () => {
    const user = userEvent.setup()
    const pending = channels({
      last: {
        telegram: null,
        email: { kind: 'test', status: 'pending', at: '2026-11-03T03:00:00.000Z', error: null },
      },
    })
    vi.mocked(systemApi.channels).mockResolvedValue(channels())
    vi.mocked(systemApi.sendTest).mockResolvedValue(pending)
    renderWithProviders(<AlertsTab />, monitorFixture)

    await screen.findByRole('heading', { name: 'Email' })
    expect(within(card('Telegram')).getByRole('button', { name: 'Kirim uji Telegram' })).toBeDisabled()

    await user.type(within(card('Email')).getByLabelText('Username'), 'x')
    expect(within(card('Email')).getByRole('button', { name: 'Kirim uji email' })).toBeDisabled()
    expect(within(card('Email')).getByText('Simpan perubahan dulu sebelum mengirim uji.')).toBeInTheDocument()
    await user.clear(within(card('Email')).getByLabelText('Username'))
    await user.type(within(card('Email')).getByLabelText('Username'), 'ops')

    vi.mocked(systemApi.channels).mockResolvedValue(pending)
    await user.click(within(card('Email')).getByRole('button', { name: 'Kirim uji email' }))

    await waitFor(() => expect(systemApi.sendTest).toHaveBeenCalledWith('email'))
    expect(await within(card('Email')).findByText('Menunggu')).toBeInTheDocument()
    expect(within(card('Email')).getByRole('button', { name: 'Kirim uji email' })).toBeDisabled()
  })

  it('shows why the last delivery failed', async () => {
    vi.mocked(systemApi.channels).mockResolvedValue(
      channels({
        telegram: { enabled: true, token_set: true, chat_ids: ['-100123'] },
        last: {
          telegram: {
            kind: 'opened',
            status: 'failed',
            at: '2026-11-03T03:00:00.000Z',
            error: 'Forbidden: bot was kicked',
          },
          email: null,
        },
      }),
    )
    renderWithProviders(<AlertsTab />, monitorFixture)

    await screen.findByRole('heading', { name: 'Telegram' })
    expect(within(card('Telegram')).getByText('Forbidden: bot was kicked')).toBeInTheDocument()
    expect(within(card('Telegram')).getByText('Gagal')).toBeInTheDocument()
  })

  it('fills the web console address from the current page', async () => {
    const user = userEvent.setup()
    vi.mocked(systemApi.channels).mockResolvedValue(channels())
    vi.mocked(systemApi.setOptions).mockResolvedValue(channels({ console_url: window.location.origin }))
    renderWithProviders(<AlertsTab />, monitorFixture)

    await user.click(await screen.findByRole('button', { name: 'Pakai alamat web ini' }))
    expect(screen.getByLabelText('Alamat web CS')).toHaveValue(window.location.origin)
    await user.click(within(card('Label & tautan')).getByRole('button', { name: 'Simpan' }))

    await waitFor(() =>
      expect(systemApi.setOptions).toHaveBeenCalledWith('OLT Social', window.location.origin),
    )
  })
})
