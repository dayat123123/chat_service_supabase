import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import type * as PresenceApiModule from '@/features/presence/api'
import { presenceApi } from '@/features/presence/api'
import { agentFixture, ticketFixture } from '@/test/fixtures'
import { renderWithProviders } from '@/test/render'

import { ReadOnlyBar } from './conversation-pane'

vi.mock('@/features/presence/api', async (importOriginal) => {
  const actual = await importOriginal<typeof PresenceApiModule>()
  return { ...actual, presenceApi: { ...actual.presenceApi, setStatus: vi.fn() } }
})

const openTicket = ticketFixture({ status: 'open', owner: null })

function renderBar(agent = agentFixture, ticket = openTicket) {
  return renderWithProviders(<ReadOnlyBar ticket={ticket} />, agent)
}

describe('ReadOnlyBar', () => {
  beforeEach(() => vi.mocked(presenceApi.setStatus).mockReset())

  it('menjelaskan kenapa tiket belum bisa diambil dan bisa langsung Online', async () => {
    const user = userEvent.setup()
    vi.mocked(presenceApi.setStatus).mockResolvedValue({
      ...agentFixture,
      status: 'online',
      active_tickets: 0,
    })
    renderBar({ ...agentFixture, status: 'offline', active_tickets: 0 })

    expect(screen.getByText('Status Anda Offline. Ubah ke Online untuk mengambil tiket.')).toBeVisible()
    expect(screen.getByRole('button', { name: 'Ambil tiket' })).toBeDisabled()

    await user.click(screen.getByRole('button', { name: 'Ubah ke Online' }))

    expect(presenceApi.setStatus).toHaveBeenCalledWith('online', undefined)
    expect(await screen.findByText('Ambil tiket ini untuk membalas')).toBeVisible()
    expect(screen.getByRole('button', { name: 'Ambil tiket' })).toBeEnabled()
    expect(screen.queryByRole('button', { name: 'Ubah ke Online' })).not.toBeInTheDocument()
  })

  it('status Istirahat disebut apa adanya', () => {
    renderBar({ ...agentFixture, status: 'break', active_tickets: 0 })

    expect(screen.getByText('Status Anda Istirahat. Ubah ke Online untuk mengambil tiket.')).toBeVisible()
    expect(screen.getByRole('button', { name: 'Ubah ke Online' })).toBeEnabled()
  })

  it('batas tiket penuh tidak menawarkan tombol Online', () => {
    renderBar({ ...agentFixture, status: 'online', active_tickets: 5 })

    expect(screen.getByText('Batas tiket aktif Anda sudah penuh.')).toBeVisible()
    expect(screen.getByRole('button', { name: 'Ambil tiket' })).toBeDisabled()
    expect(screen.queryByRole('button', { name: 'Ubah ke Online' })).not.toBeInTheDocument()
  })

  it('tiket milik CS lain hanya-baca tanpa tombol Gabung, juga bagi CS yang Super Admin', () => {
    renderBar(
      { ...agentFixture, roles: ['cs_agent', 'cs_super_admin'] },
      ticketFixture({
        owner: { id: 'bima', display_name: 'Bima', agent_code: 'CS-0046', status: 'online' },
        is_mine: false,
      }),
    )

    expect(screen.getByRole('status')).toHaveTextContent('Ditangani oleh Bima')
    expect(screen.queryByRole('button')).not.toBeInTheDocument()
  })
})
