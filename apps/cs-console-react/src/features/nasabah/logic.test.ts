import { describe, expect, it } from 'vitest'

import {
  approvalPayload,
  canDecide,
  canEditUser,
  canLinkAccounts,
  emptyForm,
  flagsOf,
  formFromUser,
  formProblems,
  nasabahTabs,
  salesOptions,
  toggleFlag,
  toList,
  toPage,
  userSearch,
  withLoginType,
} from './logic'
import type { CatalogAccount, OnlineUser, OnlineUserForm } from './types'

const user: OnlineUser = {
  LoginId: 'budi',
  LoginType: 1,
  Email: 'budi@olt.test',
  Status: 1,
  ErrorPwdRetry: 0,
  ErrorPinRetry: 2,
  AccountExpired: '',
  SalesId: '',
  Permissions: 9,
  Created: '2026-10-01 08:00:00',
  BirthDate: '1990-05-17 00:00:00',
  PhoneNumber: '0812',
  IsPhoneNumberApproved: 1,
  PhoneNumberApprovedAt: '',
  IsEmailApproved: 0,
  EmailApprovedAt: '',
}

describe('nasabah logic', () => {
  it('shows tabs and actions by console permission', () => {
    expect(nasabahTabs([])).toEqual([])
    expect(nasabahTabs(['online_user.view'])).toEqual(['users'])
    expect(nasabahTabs(['online_user.approve', 'opening_account.send'])).toEqual([
      'users',
      'approvals',
      'opening',
    ])
    expect(nasabahTabs(['cs_user.manage', 'cs_log.view'])).toEqual([])
    expect(canEditUser(['online_user.demo'], { LoginType: 0 })).toBe(true)
    expect(canEditUser(['online_user.demo'], { LoginType: 1 })).toBe(false)
    expect(canLinkAccounts(['online_user.manage'], { LoginType: 1 })).toBe(true)
    expect(canLinkAccounts(['online_user.manage'], { LoginType: 2 })).toBe(false)
  })

  it('never lets the submitter decide their own approval', () => {
    const approval = { Status: 1, CreatedBy: 'CS-0045 ' }
    expect(canDecide(['online_user.approve'], approval, 'cs-0045')).toBe(false)
    expect(canDecide(['online_user.approve'], approval, 'CS-0046')).toBe(true)
    expect(canDecide(['online_user.approve'], { ...approval, Status: 2 }, 'CS-0046')).toBe(false)
    expect(canDecide(['online_user.manage'], approval, 'CS-0046')).toBe(false)
  })

  it('searches by email only when the query looks like one', () => {
    expect(userSearch('  budi ')).toEqual({ loginId: 'budi' })
    expect(userSearch('budi@olt')).toEqual({ email: 'budi@olt' })
    expect(userSearch('  ')).toEqual({})
  })

  it('normalizes legacy paginated and empty responses', () => {
    expect(
      toPage(
        { data: [1, 2], pagination: { current_page: 2, per_page: 2, total_items: 5, total_pages: 3 } },
        2,
        2,
      ),
    ).toEqual({
      rows: [1, 2],
      total: 5,
      page: 2,
      perPage: 2,
      totalPages: 3,
    })
    expect(toPage({ message: 'No data available' } as never, 1, 30)).toEqual({
      rows: [],
      total: 0,
      page: 1,
      perPage: 30,
      totalPages: 0,
    })
    expect(toList({ data: null })).toEqual([])
  })

  it('maps the online user permission bits', () => {
    expect(flagsOf(9)).toEqual(['viewOnly', 'vip'])
    expect(toggleFlag(9, 8, false)).toBe(1)
    expect(toggleFlag(1, 32, true)).toBe(33)
  })

  const catalog: CatalogAccount[] = [
    { CustId: 'C1', Name: 'Budi', StaffId: 'S01', Branch: 'JKT' },
    { CustId: 'C2', Name: 'Citra', StaffId: 'S01', Branch: 'SBY' },
    { CustId: 'C3', Name: 'Dewi', StaffId: '', Branch: 'JKT' },
  ]
  const today = new Date(2026, 10, 1)
  const manager = ['online_user.manage']
  const fresh = { previous: null, previousLinks: [], catalog, today }
  const client: OnlineUserForm = {
    ...emptyForm(1),
    loginId: 'budi.s',
    email: 'Budi@olt.test',
    phone: '+6281234567',
    birthDate: '1990-05-17',
  }

  it('accepts a complete new client login', () => {
    expect(formProblems(client, manager, fresh)).toEqual([])
  })

  it('applies the csAdmin form rules to new logins', () => {
    expect(formProblems({ ...client, loginId: 'budi santoso', email: 'budi@olt' }, manager, fresh)).toEqual([
      'loginId',
      'email',
    ])
    expect(formProblems({ ...client, email: '' }, manager, fresh)).toEqual(['email'])
    expect(formProblems({ ...client, phone: '0812-34' }, manager, fresh)).toEqual(['phone'])
    expect(formProblems({ ...client, phone: '' }, manager, fresh)).toEqual(['phone'])
    expect(formProblems({ ...client, birthDate: '' }, manager, fresh)).toEqual(['birthDate'])
    expect(formProblems({ ...client, birthDate: '1946-10-31' }, manager, fresh)).toEqual(['birthDate'])
    expect(formProblems({ ...client, birthDate: '1946-11-01' }, manager, fresh)).toEqual([])
    expect(formProblems({ ...client, birthDate: '2026-11-02' }, manager, fresh)).toEqual(['birthDate'])
  })

  it('picks sales and branch codes from the account catalog', () => {
    expect(salesOptions(catalog, 2)).toEqual([{ id: 'S01', count: 2 }])
    expect(salesOptions(catalog, 3)).toEqual([
      { id: 'JKT', count: 2 },
      { id: 'SBY', count: 1 },
    ])
    expect(salesOptions(catalog, 1)).toEqual([])
    const sales = withLoginType(client, 2, [])
    expect(formProblems(sales, manager, fresh)).toEqual(['salesId'])
    expect(formProblems({ ...sales, salesId: 'S99' }, manager, fresh)).toEqual(['salesUnknown'])
    expect(formProblems({ ...sales, salesId: 'S01' }, manager, fresh)).toEqual([])
    expect(formProblems({ ...withLoginType(client, 5, []), salesId: 'SBY' }, manager, fresh)).toEqual([])
  })

  it('lets only demo logins expire, within the csAdmin date range', () => {
    const demo = withLoginType(client, 0, [])
    expect(demo).toMatchObject({ neverExpired: false, accountExpired: '', links: [] })
    expect(formProblems(demo, manager, fresh)).toEqual(['accountExpired'])
    expect(formProblems({ ...demo, accountExpired: '2026-10-31' }, manager, fresh)).toEqual([
      'accountExpired',
    ])
    expect(formProblems({ ...demo, accountExpired: '2029-01-02' }, manager, fresh)).toEqual([
      'accountExpired',
    ])
    expect(formProblems({ ...demo, accountExpired: '2029-01-01' }, manager, fresh)).toEqual([])
    expect(formProblems({ ...demo, neverExpired: true }, manager, fresh)).toEqual([])
    expect(withLoginType(demo, 1, ['C1'])).toMatchObject({ neverExpired: true, links: ['C1'] })
  })

  it('keeps unchanged values of existing logins', () => {
    const legacy = {
      ...user,
      LoginType: 0,
      PhoneNumber: '081234567',
      BirthDate: '1931-02-03 00:00:00',
      AccountExpired: '2025-01-01 23:59:00',
    }
    const edit = { previous: legacy, previousLinks: [], catalog, today }
    const form = formFromUser(legacy, [])
    expect(form).toMatchObject({ birthDate: '1931-02-03', accountExpired: '2025-01-01', neverExpired: false })
    expect(formProblems(form, manager, edit)).toEqual([])
    expect(formProblems({ ...form, email: 'baru@olt.test' }, manager, edit)).toEqual([])
    expect(formProblems({ ...form, accountExpired: '2025-06-01' }, manager, edit)).toEqual(['accountExpired'])
    const placeholder = formFromUser({ ...legacy, BirthDate: '1900-01-01 00:00:00' }, [])
    expect(formProblems(placeholder, manager, edit)).toEqual(['birthDate'])
  })

  it('limits linked accounts to what the csAdmin parameter can carry', () => {
    const ids = Array.from({ length: 29 }, (_, i) => `ACCT${String(i).padStart(4, '0')}`)
    expect(formProblems({ ...client, links: ids.slice(0, 28) }, manager, fresh)).toEqual([])
    expect(formProblems({ ...client, links: ids }, manager, fresh)).toEqual(['links'])
  })

  it('keeps demo-only accounts on demo logins', () => {
    expect(formProblems(client, ['online_user.demo'], fresh)).toEqual(['demoOnly'])
    expect(
      formProblems({ ...withLoginType(client, 0, []), neverExpired: true }, ['online_user.demo'], fresh),
    ).toEqual([])
  })

  it('builds approval payloads with link differences', () => {
    const form = { ...formFromUser(user, ['C1', 'C2']), links: ['C2', 'C3'] }
    expect(approvalPayload(2, form, ['C1', 'C2'])).toEqual({
      LoginId: 'budi',
      LoginType: 1,
      ActionType: 2,
      Permissions: 9,
      SalesId: '',
      Email: 'budi@olt.test',
      LoginStatus: 1,
      AccountExpired: '',
      ArrayAccountLink: ['C3'],
      ArrayAccountUnLink: ['C1'],
      BirthDate: '1990-05-17',
      HandphoneNo: '0812',
    })
    expect(approvalPayload(1, { ...client, links: ['C1', 'C3'] }, [])).toMatchObject({
      LoginId: 'budi.s',
      ActionType: 1,
      LoginStatus: 1,
      ArrayAccountLink: ['C1', 'C3'],
      ArrayAccountUnLink: [],
    })
    const removal = approvalPayload(3, formFromUser(user, ['C1']), ['C1'])
    expect(removal).toMatchObject({ ActionType: 3, ArrayAccountLink: [], ArrayAccountUnLink: ['C1'] })
    expect(removal).not.toHaveProperty('BirthDate')
    const toSales = { ...withLoginType(formFromUser(user, ['C1']), 2, ['C1']), salesId: 'S01' }
    expect(approvalPayload(2, toSales, ['C1'])).toMatchObject({
      ArrayAccountLink: [],
      ArrayAccountUnLink: [],
    })
    const demo = {
      ...withLoginType(client, 0, []),
      loginId: 'demo01',
      accountExpired: '2026-12-31',
      salesId: 'X',
    }
    expect(approvalPayload(1, demo, [])).toMatchObject({
      LoginType: 0,
      AccountExpired: '2026-12-31 00:00:00',
      SalesId: '',
    })
    const kept = formFromUser({ ...user, LoginType: 0, AccountExpired: '2026-12-31 23:59:00' }, [])
    expect(approvalPayload(2, kept, [])).toMatchObject({ AccountExpired: '2026-12-31 23:59:00' })
    expect(approvalPayload(2, { ...kept, neverExpired: true }, [])).toMatchObject({ AccountExpired: '' })
  })
})
