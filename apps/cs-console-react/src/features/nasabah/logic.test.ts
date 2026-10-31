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
  inputToLegacyDateTime,
  legacyDateTimeInput,
  nasabahTabs,
  toggleFlag,
  toList,
  toPage,
  userSearch,
} from './logic'
import type { OnlineUser } from './types'

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

  it('converts legacy timestamps for date inputs and back', () => {
    expect(legacyDateTimeInput('2026-12-31 23:59:00')).toBe('2026-12-31T23:59')
    expect(legacyDateTimeInput('')).toBe('')
    expect(inputToLegacyDateTime('2026-12-31T23:59')).toBe('2026-12-31 23:59:00')
    expect(inputToLegacyDateTime('nope')).toBe('')
  })

  it('maps the online user permission bits', () => {
    expect(flagsOf(9)).toEqual(['viewOnly', 'vip'])
    expect(toggleFlag(9, 8, false)).toBe(1)
    expect(toggleFlag(1, 32, true)).toBe(33)
  })

  it('validates the form, including demo-only accounts', () => {
    expect(formProblems({ ...emptyForm(), loginId: 'ab' }, ['online_user.manage'])).toEqual(['loginId'])
    expect(formProblems({ ...emptyForm(2), loginId: 'sales01', email: 'x' }, ['online_user.manage'])).toEqual(
      ['email', 'salesId'],
    )
    expect(formProblems({ ...emptyForm(1), loginId: 'client01' }, ['online_user.demo'])).toEqual(['demoOnly'])
    expect(formProblems({ ...emptyForm(0), loginId: 'demo01' }, ['online_user.demo'])).toEqual([])
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
    const removal = approvalPayload(3, formFromUser(user, ['C1']), ['C1'])
    expect(removal).toMatchObject({ ActionType: 3, ArrayAccountLink: [], ArrayAccountUnLink: ['C1'] })
    expect(removal).not.toHaveProperty('BirthDate')
    const demo = approvalPayload(
      1,
      { ...emptyForm(0), loginId: 'demo01', accountExpired: '2026-12-31T23:59', salesId: 'X' },
      [],
    )
    expect(demo).toMatchObject({ LoginType: 0, AccountExpired: '2026-12-31 23:59:00', SalesId: '' })
  })
})
