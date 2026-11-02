import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import type { AgentProfile } from '@/features/presence/types'
import { agentFixture, ticketFixture } from '@/test/fixtures'
import { renderWithProviders } from '@/test/render'
import { dismissToasts, findToast, Toaster } from '@/test/toast'

import type * as ApiModule from '../api'
import { ticketsApi } from '../api'
import type { TransferRequest } from '../types'
import { TransferInbox } from './transfer-inbox'

vi.mock('../api', async (importOriginal) => {
  const actual = await importOriginal<typeof ApiModule>()
  return { ...actual, ticketsApi: { ...actual.ticketsApi, respondTransfer: vi.fn() } }
})

const request: TransferRequest = {
  id: 'transfer-1',
  note: 'Mohon dilanjutkan',
  expires_at: null,
  from_name: 'Nadia',
  ticket: ticketFixture({ id: 'ticket-9', ticket_number: 'CS-000999' }),
}

function renderInbox(agent: AgentProfile) {
  return renderWithProviders(
    <>
      <TransferInbox incoming={[request]} outgoing={[]} />
      <Toaster />
    </>,
    agent,
  )
}

describe('TransferInbox', () => {
  beforeEach(() => vi.mocked(ticketsApi.respondTransfer).mockReset())
  afterEach(dismissToasts)

  it('asks offline agents to go Online before accepting a transfer', async () => {
    const user = userEvent.setup()
    renderInbox({ ...agentFixture, status: 'offline', active_tickets: 0 })

    await user.click(screen.getByRole('button', { name: 'Terima' }))

    const notice = await findToast('Status Anda Offline. Ubah ke Online dulu untuk menerima transfer.')
    expect(within(notice).getByRole('button', { name: 'Ubah ke Online' })).toBeInTheDocument()
    expect(ticketsApi.respondTransfer).not.toHaveBeenCalled()
  })

  it('accepts transfers while Online with a free slot', async () => {
    const user = userEvent.setup()
    vi.mocked(ticketsApi.respondTransfer).mockResolvedValue(request.ticket)
    renderInbox({ ...agentFixture, status: 'online', active_tickets: 0 })

    await user.click(screen.getByRole('button', { name: 'Terima' }))

    await waitFor(() =>
      expect(ticketsApi.respondTransfer).toHaveBeenCalledWith('transfer-1', true, undefined),
    )
  })
})
