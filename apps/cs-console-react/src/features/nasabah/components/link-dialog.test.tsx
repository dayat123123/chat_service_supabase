import { screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { agentFixture } from '@/test/fixtures'
import { renderWithProviders } from '@/test/render'

import type * as ApiModule from '../api'
import { nasabahApi } from '../api'
import type { OnlineUser } from '../types'
import { LinkDialog } from './link-dialog'

vi.mock('../api', async (importOriginal) => {
  const actual = await importOriginal<typeof ApiModule>()
  return { ...actual, nasabahApi: { ...actual.nasabahApi, catalog: vi.fn(), submit: vi.fn() } }
})

const user = {
  LoginId: 'budi',
  LoginType: 1,
  Email: 'budi@olt.test',
  Status: 1,
  Permissions: 0,
  SalesId: '',
  BirthDate: '1990-01-01',
  PhoneNumber: '0812',
  AccountExpired: '',
} as OnlineUser

const manager = { ...agentFixture, nasabah_permissions: ['online_user.manage'] }

describe('LinkDialog', () => {
  beforeEach(() => {
    vi.mocked(nasabahApi.catalog)
      .mockReset()
      .mockResolvedValue([
        { CustId: 'C001 ', Name: 'Budi Santoso', StaffId: '', Branch: 'JKT' },
        { CustId: 'C002', Name: 'Budi Lain', StaffId: '', Branch: 'JKT' },
        { CustId: 'C003', Name: 'Citra', StaffId: '', Branch: 'SBY' },
      ])
    vi.mocked(nasabahApi.submit).mockReset().mockResolvedValue({ message: 'ok' })
  })

  it('separates linked accounts from the ones that can still be added', async () => {
    const actor = userEvent.setup()
    renderWithProviders(<LinkDialog open user={user} links={['C001']} onClose={() => undefined} />, manager)

    const linked = await screen.findByRole('region', { name: 'Sudah tertaut (1)' })
    const available = screen.getByRole('region', { name: 'Tambah rekening' })
    expect(within(linked).getByRole('checkbox', { name: /C001/ })).toBeChecked()
    expect(within(available).queryByRole('checkbox', { name: /C001/ })).not.toBeInTheDocument()
    expect(within(available).getByRole('checkbox', { name: /C002/ })).not.toBeChecked()
    expect(screen.queryByRole('region', { name: /Akan ditautkan/ })).not.toBeInTheDocument()

    await actor.click(within(available).getByRole('checkbox', { name: /C002/ }))
    const added = screen.getByRole('region', { name: 'Akan ditautkan (1)' })
    expect(within(added).getByRole('checkbox', { name: /C002/ })).toBeChecked()
    expect(within(available).queryByRole('checkbox', { name: /C002/ })).not.toBeInTheDocument()

    await actor.click(within(linked).getByRole('checkbox', { name: /C001/ }))
    expect(within(linked).getByText('akan dilepas')).toBeInTheDocument()
    expect(screen.getByRole('status')).toHaveTextContent('Setelah disetujui: 1 rekening tertaut (+1 / −1)')

    await actor.type(screen.getByRole('searchbox', { name: 'Cari kode atau nama rekening…' }), 'citra')
    expect(await within(available).findByRole('checkbox', { name: /C003/ })).toBeInTheDocument()

    await actor.click(screen.getByRole('button', { name: 'Ajukan perubahan tautan' }))
    expect(vi.mocked(nasabahApi.submit).mock.calls[0]?.[0]).toEqual(
      expect.objectContaining({ ArrayAccountLink: ['C002'], ArrayAccountUnLink: ['C001'] }),
    )
  })
})
