import { screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import type * as PresenceApiModule from '@/features/presence/api'
import { presenceApi } from '@/features/presence/api'
import type * as TicketsApiModule from '@/features/tickets/api'
import { ticketsApi } from '@/features/tickets/api'
import { useTicketUi } from '@/features/tickets/hooks'
import { emptyLists } from '@/features/tickets/types'
import { agentFixture, ticketFixture } from '@/test/fixtures'
import { renderWithProviders } from '@/test/render'
import { dismissToasts, findToast, Toaster } from '@/test/toast'

import { ReadOnlyBar } from './conversation-pane'

vi.mock('@/features/presence/api', async (importOriginal) => {
  const actual = await importOriginal<typeof PresenceApiModule>()
  return { ...actual, presenceApi: { ...actual.presenceApi, setStatus: vi.fn() } }
})

vi.mock('@/features/tickets/api', async (importOriginal) => {
  const actual = await importOriginal<typeof TicketsApiModule>()
  return {
    ...actual,
    ticketsApi: { ...actual.ticketsApi, claim: vi.fn(), lists: vi.fn(() => Promise.resolve(emptyLists)) },
  }
})

const openTicket = ticketFixture({ status: 'open', owner: null })

function renderBar(agent = agentFixture, ticket = openTicket) {
  return renderWithProviders(
    <>
      <ReadOnlyBar ticket={ticket} />
      <Toaster />
    </>,
    agent,
  )
}

describe('ReadOnlyBar', () => {
  beforeEach(() => {
    vi.mocked(presenceApi.setStatus).mockReset()
    vi.mocked(ticketsApi.claim).mockReset()
  })
  afterEach(dismissToasts)

  it('menjelaskan kenapa tiket belum bisa diambil dan bisa langsung Online', async () => {
    const user = userEvent.setup()
    vi.mocked(presenceApi.setStatus).mockResolvedValue({
      ...agentFixture,
      status: 'online',
      active_tickets: 0,
    })
    renderBar({ ...agentFixture, status: 'offline', active_tickets: 0 })

    expect(screen.getByText('Status Anda Offline. Ubah ke Online untuk mengambil tiket.')).toBeVisible()
    expect(screen.getByRole('button', { name: 'Ambil tiket' })).toHaveAttribute('data-blocked', 'true')

    await user.click(screen.getByRole('button', { name: 'Ubah ke Online' }))

    expect(presenceApi.setStatus).toHaveBeenCalledWith('online', undefined)
    expect(await screen.findByText('Ambil tiket ini untuk membalas')).toBeVisible()
    expect(screen.getByRole('button', { name: 'Ambil tiket' })).not.toHaveAttribute('data-blocked')
    expect(screen.queryByRole('button', { name: 'Ubah ke Online' })).not.toBeInTheDocument()
  })

  it('menekan Ambil saat Offline memberi notifikasi untuk Online dulu, tanpa mengambil tiket', async () => {
    const user = userEvent.setup()
    vi.mocked(presenceApi.setStatus).mockResolvedValue({
      ...agentFixture,
      status: 'online',
      active_tickets: 0,
    })
    renderBar({ ...agentFixture, status: 'offline', active_tickets: 0 })

    await user.click(screen.getByRole('button', { name: 'Ambil tiket' }))

    const notice = await findToast('Status Anda Offline. Ubah ke Online dulu untuk mengambil tiket.')
    expect(ticketsApi.claim).not.toHaveBeenCalled()

    await user.click(within(notice).getByRole('button', { name: 'Ubah ke Online' }))

    expect(presenceApi.setStatus).toHaveBeenCalledWith('online', undefined)
  })

  it('status Istirahat disebut apa adanya', () => {
    renderBar({ ...agentFixture, status: 'break', active_tickets: 0 })

    expect(screen.getByText('Status Anda Istirahat. Ubah ke Online untuk mengambil tiket.')).toBeVisible()
    expect(screen.getByRole('button', { name: 'Ubah ke Online' })).toBeEnabled()
  })

  it('batas tiket penuh tidak menawarkan tombol Online', () => {
    renderBar({ ...agentFixture, status: 'online', active_tickets: 5 })

    expect(screen.getByText('Batas tiket aktif Anda sudah penuh.')).toBeVisible()
    expect(screen.getByRole('button', { name: 'Ambil tiket' })).toHaveAttribute('data-blocked', 'true')
    expect(screen.queryByRole('button', { name: 'Ubah ke Online' })).not.toBeInTheDocument()
  })

  it('menekan Ambil saat slot penuh memberi notifikasi tanpa tombol Online', async () => {
    const user = userEvent.setup()
    renderBar({ ...agentFixture, status: 'online', active_tickets: 5 })

    await user.click(screen.getByRole('button', { name: 'Ambil tiket' }))

    const notice = await findToast('Batas tiket aktif Anda sudah penuh. Selesaikan atau lepas tiket dulu.')
    expect(within(notice).queryByRole('button', { name: 'Ubah ke Online' })).not.toBeInTheDocument()
    expect(ticketsApi.claim).not.toHaveBeenCalled()
  })

  it('tiket yang sudah ditutup menunjuk ke tiket aktif nasabah yang sama', async () => {
    const user = userEvent.setup()
    const active = ticketFixture({ id: 'ticket-new', ticket_number: 'CS-000200', status: 'claimed' })
    vi.mocked(ticketsApi.lists).mockResolvedValue({ ...emptyLists, mine: [active] })
    renderBar(agentFixture, ticketFixture({ id: 'ticket-old', status: 'closed' }))

    expect(
      await screen.findByText('Tiket ini sudah ditutup. Nasabah punya tiket aktif #CS-000200.'),
    ).toBeVisible()
    await user.click(screen.getByRole('button', { name: 'Buka tiket aktif' }))

    expect(useTicketUi.getState().selectedId).toBe('ticket-new')
  })

  it('tiket ditutup tanpa tiket baru tetap memakai keterangan biasa', () => {
    renderBar(agentFixture, ticketFixture({ id: 'ticket-old', status: 'closed' }))

    expect(screen.getByRole('status')).toHaveTextContent(
      'Tiket ditutup dan tidak bisa dibalas lagi. Nasabah membuat tiket baru untuk chat lagi.',
    )
    expect(screen.queryByRole('button', { name: 'Buka tiket aktif' })).not.toBeInTheDocument()
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
