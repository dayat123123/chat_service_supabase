import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { monitorFixture } from '@/test/fixtures'
import { renderWithProviders } from '@/test/render'

import type * as ApiModule from '../api'
import { reportsApi } from '../api'
import type { CustomerReport, CustomerTrail } from '../types'
import { CustomersSection } from './customers-section'

vi.mock('../api', async (importOriginal) => {
  const actual = await importOriginal<typeof ApiModule>()
  return { ...actual, reportsApi: { ...actual.reportsApi, customers: vi.fn(), customerTrail: vi.fn() } }
})

const range = { from: '2026-11-01', to: '2026-11-02' }

const budi: CustomerReport = {
  id: 'budi',
  display_name: 'Budi Santoso',
  username: 'budi',
  tickets: 2,
  resolved: 2,
  reopened: 1,
  complaints: 0,
  avg_first_response_minutes: 3,
  avg_resolution_minutes: 42,
  avg_rating: 4.5,
  ratings: 2,
  closed_unrated: 1,
  last_ticket_at: '2026-11-02T03:00:00.000Z',
}

const trail: CustomerTrail = {
  customer: { id: 'budi', display_name: 'Budi Santoso', username: 'budi' },
  from: range.from,
  to: range.to,
  tickets: [
    {
      id: 't1',
      ticket_number: 'CS-20261102-0007',
      topic: 'account',
      topic_name: 'Akun & login',
      status: 'closed',
      priority: 'P3',
      flags: [],
      outcome: 'answered',
      close_reason: 'rated',
      agent: 'Rina',
      created_at: '2026-11-02T03:00:00.000Z',
      first_claimed_at: '2026-11-02T03:01:00.000Z',
      first_response_at: '2026-11-02T03:03:00.000Z',
      resolved_at: '2026-11-02T03:40:00.000Z',
      closed_at: '2026-11-02T03:45:00.000Z',
      claim_minutes: 1,
      first_response_minutes: 3,
      resolution_minutes: 40,
      rating: 5,
      rating_comment: 'Cepat sekali',
      rated_at: '2026-11-02T03:45:00.000Z',
      reopened: 0,
      transfers: 1,
      events: [
        {
          type: 'opened',
          actor_type: 'customer',
          actor_name: null,
          data: {},
          created_at: '2026-11-02T03:00:00.000Z',
        },
        {
          type: 'rated',
          actor_type: 'customer',
          actor_name: null,
          data: { rating: 5 },
          created_at: '2026-11-02T03:45:00.000Z',
        },
        {
          type: 'closed',
          actor_type: 'customer',
          actor_name: null,
          data: { reason: 'rated' },
          created_at: '2026-11-02T03:45:00.000Z',
        },
      ],
    },
  ],
}

beforeEach(() => {
  vi.clearAllMocks()
  vi.mocked(reportsApi.customers).mockResolvedValue([budi])
  vi.mocked(reportsApi.customerTrail).mockResolvedValue(trail)
})

describe('CustomersSection', () => {
  it('lists per-customer performance and searches by name', async () => {
    const user = userEvent.setup()
    renderWithProviders(<CustomersSection range={range} />, monitorFixture)

    const table = await screen.findByRole('table', { name: 'Per nasabah' })
    const row = within(table)
      .getByRole('button', { name: 'Lihat jejak layanan Budi Santoso' })
      .closest('tr') as HTMLElement
    expect(row).toHaveTextContent('@budi')
    expect(row).toHaveTextContent('4,5 (2)')
    expect(reportsApi.customers).toHaveBeenCalledWith(range, '')

    await user.type(screen.getByRole('searchbox', { name: 'Cari nama atau username' }), 'budi')
    await waitFor(() => expect(reportsApi.customers).toHaveBeenLastCalledWith(range, 'budi'))
  })

  it('opens the service trail with how each ticket closed', async () => {
    const user = userEvent.setup()
    renderWithProviders(<CustomersSection range={range} />, monitorFixture)

    await user.click(await screen.findByRole('button', { name: 'Lihat jejak layanan Budi Santoso' }))
    const sheet = await screen.findByRole('dialog', { name: 'Jejak layanan nasabah' })
    expect(reportsApi.customerTrail).toHaveBeenCalledWith('budi', range)
    expect(await within(sheet).findByText('Akses ke jejak layanan ini tercatat di audit log.')).toBeVisible()
    expect(within(sheet).getByText('Setelah dinilai nasabah', { selector: 'dd' })).toBeVisible()
    expect(within(sheet).getByText('“Cepat sekali”')).toBeVisible()
    expect(within(sheet).getByText('Dinilai nasabah')).toBeVisible()
    expect(within(sheet).getByText('Nasabah · Setelah dinilai nasabah')).toBeVisible()
  })

  it('says when no customer matches the search', async () => {
    vi.mocked(reportsApi.customers).mockResolvedValue([])
    const user = userEvent.setup()
    renderWithProviders(<CustomersSection range={range} />, monitorFixture)

    await user.type(await screen.findByRole('searchbox', { name: 'Cari nama atau username' }), 'zzz')
    expect(await screen.findByText('Tidak ada nasabah yang cocok pada rentang ini.')).toBeVisible()
  })
})
