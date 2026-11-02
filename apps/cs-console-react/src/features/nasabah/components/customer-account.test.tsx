import type * as RouterModule from '@tanstack/react-router'
import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { Accordion } from '@/components/ui/controls'
import type { AgentProfile } from '@/features/presence/types'
import { ApiError } from '@/lib/errors'
import { agentFixture } from '@/test/fixtures'
import { renderWithProviders } from '@/test/render'

import type * as ApiModule from '../api'
import { nasabahApi } from '../api'
import type { OnlineUserProfile } from '../types'
import { CustomerAccount } from './customer-account'

vi.mock('@tanstack/react-router', async (importOriginal) => {
  const actual = await importOriginal<typeof RouterModule>()
  const { createElement } = await import('react')
  return {
    ...actual,
    Link: ({
      to,
      search,
      children,
    }: {
      to: string
      search?: Record<string, string>
      children: React.ReactNode
    }) =>
      createElement(
        'a',
        { href: `${to}${search ? `?${new URLSearchParams(search).toString()}` : ''}` },
        children,
      ),
  }
})

vi.mock('../api', async (importOriginal) => {
  const actual = await importOriginal<typeof ApiModule>()
  return { ...actual, nasabahApi: { ...actual.nasabahApi, ticketLogin: vi.fn(), onlineUser: vi.fn() } }
})

const viewer = { ...agentFixture, nasabah_permissions: ['online_user.view'] }

const render = (ticketId: string, agent: AgentProfile) =>
  renderWithProviders(
    <Accordion type="multiple" defaultValue={['account']}>
      <CustomerAccount ticketId={ticketId} />
    </Accordion>,
    agent,
  )

const profile = (accounts: number): OnlineUserProfile => ({
  LoginId: 'hidayat',
  LoginType: 1,
  Email: 'hidayat@contoh.test',
  Status: 1,
  ErrorPwdRetry: 0,
  ErrorPinRetry: 1,
  AccountExpired: '',
  SalesId: '',
  Permissions: 8,
  Created: '2025-03-07 15:20:00',
  BirthDate: '2000-07-10 00:00:00',
  PhoneNumber: '0812000000',
  IsPhoneNumberApproved: 0,
  PhoneNumberApprovedAt: '',
  IsEmailApproved: 1,
  EmailApprovedAt: '2025-03-08 10:00:00',
  Accounts: Array.from({ length: accounts }, (_, i) => ({
    AccountId: `A10${i}`,
    AccountName: `NASABAH ${i}`,
    Branch: 'JKT',
    RDNAccount: `45800${i}`,
    RDNBank: 'BCA',
    InvestorNo: `IDD00${i}`,
    KSEIId: '',
    Created: '2025-03-08 10:00:00',
    CreatedBy: 'admin',
  })),
})

describe('CustomerAccount', () => {
  beforeEach(() => {
    vi.mocked(nasabahApi.ticketLogin).mockReset().mockResolvedValue({ login_id: 'hidayat', source: 'olt' })
    vi.mocked(nasabahApi.onlineUser).mockReset().mockResolvedValue(profile(6))
  })

  it('shows the csAdmin profile and linked accounts of the ticket customer', async () => {
    const user = userEvent.setup()
    render('t-1', viewer)

    const card = await screen.findByRole('region', { name: 'Akun Nasabah hidayat' })
    expect(nasabahApi.ticketLogin).toHaveBeenCalledWith('t-1')
    expect(nasabahApi.onlineUser).toHaveBeenCalledWith('hidayat')
    expect(within(card).getByText('Aktif')).toBeInTheDocument()
    expect(within(card).getByText('hidayat@contoh.test')).toBeInTheDocument()
    expect(within(card).getByText('VIP')).toBeInTheDocument()
    expect(within(card).getByRole('link', { name: 'Buka di Akun Nasabah' })).toHaveAttribute(
      'href',
      '/nasabah?q=hidayat',
    )

    const linked = within(card).getByRole('list', { name: 'Rekening tertaut (6)' })
    expect(within(linked).getAllByRole('listitem')).toHaveLength(4)
    expect(within(linked).getByText('NASABAH 0')).toBeInTheDocument()
    expect(within(linked).getByText('RDN BCA 458000 · SID IDD000')).toBeInTheDocument()
    await user.click(within(card).getByRole('button', { name: 'Tampilkan semua (6)' }))
    expect(within(linked).getAllByRole('listitem')).toHaveLength(6)
  })

  it('labels customers without extra features as standard accounts', async () => {
    vi.mocked(nasabahApi.onlineUser).mockResolvedValue({ ...profile(0), Permissions: 0 })
    render('t-4', viewer)

    const card = await screen.findByRole('region', { name: 'Akun Nasabah hidayat' })
    expect(within(card).getByText('Fitur tambahan')).toBeInTheDocument()
    expect(within(card).getByText('Tidak ada (akun standar)')).toBeInTheDocument()
  })

  it('stays empty when the customer has no csAdmin login', async () => {
    vi.mocked(nasabahApi.ticketLogin).mockResolvedValue({ login_id: 'budi_s', source: 'profile' })
    vi.mocked(nasabahApi.onlineUser).mockRejectedValue(
      new ApiError('not_found', 'Online user not found.', 404),
    )
    render('t-2', viewer)

    await waitFor(() => expect(nasabahApi.onlineUser).toHaveBeenCalledWith('budi_s'))
    await waitFor(() =>
      expect(screen.queryByRole('button', { name: 'Akun Nasabah' })).not.toBeInTheDocument(),
    )
    expect(screen.queryByText(/tidak ditemukan/)).not.toBeInTheDocument()
  })

  it('stays hidden for accounts without customer account access', () => {
    render('t-3', {
      ...agentFixture,
      nasabah_permissions: ['opening_account.send'],
    })
    expect(screen.queryByRole('region', { name: /Akun Nasabah/ })).not.toBeInTheDocument()
    expect(nasabahApi.ticketLogin).not.toHaveBeenCalled()
  })
})
