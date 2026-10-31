import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import type * as CustomerApiModule from '@/features/customer/api'
import type * as PresenceApiModule from '@/features/presence/api'
import type * as TicketsApiModule from '@/features/tickets/api'
import { ticketsApi } from '@/features/tickets/api'
import type { Ticket } from '@/features/tickets/types'
import { realtime } from '@/lib/realtime'
import { agentFixture, monitorFixture, ticketFixture } from '@/test/fixtures'
import { renderWithProviders } from '@/test/render'

import type * as ApiModule from '../api'
import { ConversationPane } from './conversation-pane'

vi.mock('@/features/tickets/api', async (importOriginal) => {
  const actual = await importOriginal<typeof TicketsApiModule>()
  return {
    ...actual,
    ticketsApi: {
      ...actual.ticketsApi,
      detail: vi.fn(),
      reassign: vi.fn(),
      topics: vi.fn(() => Promise.resolve([])),
    },
  }
})

vi.mock('../api', async (importOriginal) => {
  const actual = await importOriginal<typeof ApiModule>()
  return {
    ...actual,
    conversationApi: {
      ...actual.conversationApi,
      page: vi.fn(() => Promise.resolve([])),
      members: vi.fn(() => Promise.resolve([])),
      quickReplies: vi.fn(() => Promise.resolve([])),
    },
  }
})

vi.mock('@/features/customer/api', async (importOriginal) => {
  const actual = await importOriginal<typeof CustomerApiModule>()
  return { ...actual, customerApi: { ...actual.customerApi, notes: vi.fn(() => Promise.resolve([])) } }
})

vi.mock('@/features/presence/api', async (importOriginal) => {
  const actual = await importOriginal<typeof PresenceApiModule>()
  return {
    ...actual,
    presenceApi: {
      ...actual.presenceApi,
      onlineAgents: vi.fn(() =>
        Promise.resolve([
          {
            id: 'bima',
            display_name: 'Bima',
            agent_code: 'CS-0046',
            roles: ['cs_agent'],
            status: 'online' as const,
            active_tickets: 1,
            max_active_tickets: 5,
            can_take: true,
          },
        ]),
      ),
    },
  }
})

const nadia = { id: 'nadia', display_name: 'Nadia', agent_code: 'CS-0045', status: 'online' as const }
const handled = ticketFixture({ owner: nadia, is_mine: false })
const open = ticketFixture({ status: 'open', owner: null, is_mine: false, claimed_at: null })

function renderPane(ticket: Ticket, agent = monitorFixture) {
  vi.mocked(ticketsApi.detail).mockResolvedValue(ticket)
  return renderWithProviders(
    <ConversationPane ticketId={ticket.id} infoOpen={false} onToggleInfo={vi.fn()} />,
    agent,
  )
}

describe('ConversationPane', () => {
  beforeEach(() => {
    vi.mocked(ticketsApi.detail).mockReset()
    vi.mocked(ticketsApi.reassign).mockReset()
    vi.spyOn(realtime, 'room').mockReturnValue({ sendTyping: vi.fn(), close: vi.fn() })
  })

  it('shows Super Admins a handled ticket read-only without composer, join or owner actions', async () => {
    renderPane(handled)

    const bar = (await screen.findByText('Mode pantau')).closest('p')
    expect(bar).toHaveTextContent('Mode pantau · Ditangani oleh Nadia')
    expect(screen.queryByRole('textbox', { name: 'Balas' })).not.toBeInTheDocument()
    for (const name of ['Gabung', 'Ambil tiket', 'Tunggu nasabah', 'Lepas', 'Transfer', 'Selesaikan']) {
      expect(screen.queryByRole('button', { name })).not.toBeInTheDocument()
    }
    expect(screen.getByRole('button', { name: 'Aksi lainnya' })).toBeInTheDocument()
  })

  it('lets Super Admins move a handled ticket to another agent', async () => {
    const user = userEvent.setup()
    vi.mocked(ticketsApi.reassign).mockResolvedValue({ ...handled, owner: { ...nadia, id: 'bima' } })
    renderPane(handled)

    await user.click(await screen.findByRole('button', { name: 'Pindahkan ke…' }))
    const dialog = await screen.findByRole('dialog', { name: 'Pindahkan tiket' })
    await user.click(within(dialog).getByRole('combobox', { name: 'CS tujuan' }))
    await user.click(await screen.findByRole('option', { name: /Bima/ }))
    await user.type(within(dialog).getByLabelText('Alasan'), 'Bima menangani dana hari ini')
    await user.click(within(dialog).getByRole('button', { name: 'Pindahkan ke…' }))

    await waitFor(() =>
      expect(ticketsApi.reassign).toHaveBeenCalledWith(handled.id, 'bima', 'Bima menangani dana hari ini'),
    )
  })

  it('shows Super Admins an open ticket without a way to claim it', async () => {
    renderPane(open)

    const bar = (await screen.findByText('Mode pantau')).closest('p')
    expect(bar).toHaveTextContent('Mode pantau · Belum diambil CS')
    for (const name of ['Ambil tiket', 'Ubah ke Online', 'Pindahkan ke…']) {
      expect(screen.queryByRole('button', { name })).not.toBeInTheDocument()
    }
  })

  it('still gives the owning agent the composer', async () => {
    renderPane(ticketFixture(), agentFixture)

    expect(await screen.findByRole('textbox', { name: 'Balas' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: /^Selesaikan/ })).toBeInTheDocument()
    expect(screen.queryByText('Mode pantau')).not.toBeInTheDocument()
  })
})
