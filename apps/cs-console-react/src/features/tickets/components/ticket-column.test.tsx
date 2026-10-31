import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { hasCommand } from '@/features/command/bus'
import { agentFixture, monitorFixture, ticketFixture } from '@/test/fixtures'
import { renderWithProviders } from '@/test/render'

import type * as ApiModule from '../api'
import { useTicketUi } from '../hooks'
import { emptyLists } from '../types'
import { TicketColumn } from './ticket-column'

const openTicket = ticketFixture({
  id: 'open-1',
  ticket_number: 'CS-000124',
  status: 'open',
  owner: null,
  is_mine: false,
  customer: { id: 'c-open', display_name: 'Andi Pratama', username: 'andi' },
})
const activeTicket = ticketFixture({
  id: 'active-1',
  owner: { id: 'nadia', display_name: 'Nadia', agent_code: 'CS-0045', status: 'online' },
  is_mine: false,
})

vi.mock('../api', async (importOriginal) => {
  const actual = await importOriginal<typeof ApiModule>()
  return {
    ...actual,
    ticketsApi: {
      ...actual.ticketsApi,
      lists: vi.fn(() => Promise.resolve({ ...emptyLists, open: [openTicket], all_active: [activeTicket] })),
      topics: vi.fn(() =>
        Promise.resolve([{ code: 'order', name: 'Order & Transaksi', help_url: null, urgent: false }]),
      ),
    },
  }
})

function tabNames() {
  return screen.getAllByRole('tab').map((tab) => tab.textContent)
}

describe('TicketColumn', () => {
  beforeEach(() => {
    useTicketUi.getState().reset()
    vi.spyOn(Element.prototype, 'clientHeight', 'get').mockReturnValue(800)
    vi.spyOn(Element.prototype, 'clientWidth', 'get').mockReturnValue(340)
  })

  it('lets agents claim open tickets from their own tabs', async () => {
    renderWithProviders(<TicketColumn />, { ...agentFixture, status: 'offline', active_tickets: 0 })

    expect(await screen.findByRole('button', { name: 'Ambil CS-000124' })).toBeDisabled()
    expect(tabNames()).toEqual(['Terbuka1', 'Tiket saya0', 'Selesai hari ini'])
    expect(screen.getByRole('tab', { name: /^Terbuka/ })).toHaveAttribute('aria-selected', 'true')
    expect(screen.getByText('Status Anda Offline. Ubah ke Online untuk mengambil tiket.')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Ubah ke Online' })).toBeInTheDocument()
    expect(hasCommand('claim')).toBe(true)
  })

  it('opens Super Admins on all active tickets with no way to claim', async () => {
    const user = userEvent.setup()
    renderWithProviders(<TicketColumn />, monitorFixture)

    const active = await screen.findByRole('button', { name: /^CS-000123 · Budi Santoso/ })
    expect(active.closest('[data-ticket-id]')).toHaveTextContent('Ditangani: Nadia')
    expect(tabNames()).toEqual(['Semua aktif1', 'Terbuka1'])
    expect(screen.getByRole('tab', { name: /^Semua aktif/ })).toHaveAttribute('aria-selected', 'true')
    expect(screen.queryByRole('tab', { name: /^Tiket saya/ })).not.toBeInTheDocument()

    await user.click(screen.getByRole('tab', { name: /^Terbuka/ }))

    expect(await screen.findByRole('button', { name: /^CS-000124 · Andi Pratama/ })).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /^Ambil/ })).not.toBeInTheDocument()
    expect(screen.queryByText(/Ubah ke Online untuk mengambil tiket/)).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Ubah ke Online' })).not.toBeInTheDocument()
    expect(hasCommand('claim')).toBe(false)
  })
})
