import { act, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import type * as TicketsApiModule from '@/features/tickets/api'
import { ticketsApi } from '@/features/tickets/api'
import { TicketColumn } from '@/features/tickets/components/ticket-column'
import { ticketKeys, useTicketUi } from '@/features/tickets/hooks'
import { noFilter } from '@/features/tickets/logic'
import { emptyLists, type Ticket } from '@/features/tickets/types'
import { ApiError } from '@/lib/errors'
import { monitorFixture, ticketFixture } from '@/test/fixtures'
import { renderWithProviders } from '@/test/render'
import { dismissToasts, findToast, Toaster } from '@/test/toast'

import type * as ApiModule from '../api'
import { labelsApi } from '../api'
import type { TicketLabel } from '../types'
import { TicketLabelMenu } from './ticket-label-menu'

const refund: TicketLabel = { id: 'refund', name: 'Refund', color: 'warning' }
const akun: TicketLabel = { id: 'akun', name: 'Akun terkunci', color: 'danger' }
const vip: TicketLabel = { id: 'vip', name: 'VIP', color: 'info' }
const extra = ['a', 'b', 'c', 'd'].map((id) => ({ id, name: `Label ${id}`, color: 'neutral' as const }))

vi.mock('../api', async (importOriginal) => {
  const actual = await importOriginal<typeof ApiModule>()
  return {
    ...actual,
    labelsApi: { ...actual.labelsApi, options: vi.fn(), add: vi.fn(), remove: vi.fn() },
  }
})

vi.mock('@/features/tickets/api', async (importOriginal) => {
  const actual = await importOriginal<typeof TicketsApiModule>()
  return {
    ...actual,
    ticketsApi: {
      ...actual.ticketsApi,
      lists: vi.fn(),
      detail: vi.fn(),
      topics: vi.fn(() =>
        Promise.resolve([{ code: 'order', name: 'Order & Transaksi', help_url: null, urgent: false }]),
      ),
    },
  }
})

function renderMenu(ticket: Ticket) {
  const user = userEvent.setup()
  const view = renderWithProviders(
    <>
      <TicketLabelMenu ticket={ticket} />
      <Toaster />
    </>,
  )
  view.client.setQueryData(ticketKeys.detail(ticket.id), ticket)
  return { user, ...view }
}

describe('ticket labels', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    useTicketUi.getState().reset()
    vi.mocked(labelsApi.options).mockResolvedValue([refund, akun, vip, ...extra])
    vi.mocked(ticketsApi.lists).mockResolvedValue({ ...emptyLists })
    vi.mocked(ticketsApi.detail).mockImplementation((id) => Promise.resolve(ticketFixture({ id })))
  })
  afterEach(dismissToasts)

  it('loads label options only when the menu opens and adds a label', async () => {
    vi.mocked(labelsApi.add).mockResolvedValue([refund])
    const ticket = ticketFixture()
    const { user, client } = renderMenu(ticket)
    expect(labelsApi.options).not.toHaveBeenCalled()
    await user.click(screen.getByRole('button', { name: 'Tambah label ke tiket CS-000123' }))
    const item = await screen.findByRole('menuitemcheckbox', { name: 'Refund' })
    expect(item).toHaveAttribute('aria-checked', 'false')
    await user.click(item)
    await waitFor(() => expect(labelsApi.add).toHaveBeenCalledWith(ticket.id, 'refund'))
    expect(await findToast('Label Refund ditambahkan')).toBeInTheDocument()
    expect(client.getQueryData<Ticket>(ticketKeys.detail(ticket.id))?.labels).toEqual([refund])
  })

  it('removes a label that is already on the ticket', async () => {
    vi.mocked(labelsApi.remove).mockResolvedValue([])
    const ticket = ticketFixture({ labels: [akun] })
    const { user } = renderMenu(ticket)
    await user.click(screen.getByRole('button', { name: 'Tambah label ke tiket CS-000123' }))
    const item = await screen.findByRole('menuitemcheckbox', { name: 'Akun terkunci' })
    expect(item).toHaveAttribute('aria-checked', 'true')
    expect(screen.getByText('1/5')).toBeInTheDocument()
    await user.click(item)
    await waitFor(() => expect(labelsApi.remove).toHaveBeenCalledWith(ticket.id, 'akun'))
    expect(await findToast('Label Akun terkunci dihapus')).toBeInTheDocument()
  })

  it('stops at five labels per ticket', async () => {
    const ticket = ticketFixture({ labels: [refund, ...extra] })
    const { user } = renderMenu(ticket)
    await user.click(screen.getByRole('button', { name: 'Tambah label ke tiket CS-000123' }))
    const menu = await screen.findByRole('menu')
    expect(await within(menu).findByRole('menuitemcheckbox', { name: 'VIP' })).toHaveAttribute(
      'aria-disabled',
      'true',
    )
    expect(within(menu).getByRole('menuitemcheckbox', { name: 'Refund' })).not.toHaveAttribute(
      'aria-disabled',
    )
    expect(within(menu).getByText('5/5')).toBeInTheDocument()
    expect(within(menu).getByText('Maksimal 5 label per tiket')).toBeInTheDocument()
  })

  it('explains server refusals', async () => {
    vi.mocked(labelsApi.add).mockRejectedValue(
      new ApiError('ticket_label_limit', 'Maksimal 5 label per tiket', 409),
    )
    const { user } = renderMenu(ticketFixture())
    await user.click(screen.getByRole('button', { name: 'Tambah label ke tiket CS-000123' }))
    await user.click(await screen.findByRole('menuitemcheckbox', { name: 'VIP' }))
    expect(await findToast('Maksimal 5 label per tiket.')).toBeInTheDocument()
  })

  it('shows labels in the ticket list and filters by label', async () => {
    const withRefund = ticketFixture({
      id: 't1',
      ticket_number: 'CS-000201',
      labels: [refund],
      customer: { id: 'c1', display_name: 'Andi Pratama', username: 'andi' },
    })
    const withVip = ticketFixture({
      id: 't2',
      ticket_number: 'CS-000202',
      labels: [vip],
      customer: { id: 'c2', display_name: 'Citra Lestari', username: 'citra' },
    })
    vi.mocked(ticketsApi.lists).mockResolvedValue({ ...emptyLists, all_active: [withRefund, withVip] })
    vi.spyOn(Element.prototype, 'clientHeight', 'get').mockReturnValue(800)
    vi.spyOn(Element.prototype, 'clientWidth', 'get').mockReturnValue(340)
    const user = userEvent.setup()
    renderWithProviders(<TicketColumn />, monitorFixture)
    expect(await screen.findByText('Andi Pratama')).toBeInTheDocument()
    expect(screen.getByText('Refund')).toBeInTheDocument()
    expect(screen.getByText('VIP')).toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: /Filter/ }))
    expect(await screen.findByRole('menuitem', { name: 'Label' })).toBeInTheDocument()
    await user.keyboard('{Escape}')
    act(() => useTicketUi.getState().setFilter({ ...noFilter, label: 'vip' }))
    await waitFor(() => expect(screen.queryByText('Andi Pratama')).not.toBeInTheDocument())
    expect(screen.getByText('Citra Lestari')).toBeInTheDocument()
    expect(screen.getByText('Label: VIP')).toBeInTheDocument()
    expect(labelsApi.options).not.toHaveBeenCalled()
  })
})
