import { describe, expect, it } from 'vitest'

import { canChangeStatus, canDecide, incompleteFields, nasabahTabs, statusReasonOk } from './logic'

describe('online user extras', () => {
  it('opens the users and approvals tabs for the new permissions', () => {
    expect(nasabahTabs(['online_user.status'])).toEqual(['users'])
    expect(nasabahTabs(['online_user.approve_own'])).toEqual(['users', 'approvals'])
    expect(canChangeStatus(['online_user.status'])).toBe(true)
    expect(canChangeStatus(['online_user.manage'])).toBe(false)
  })

  it('lets approve_own holders decide only their own submissions', () => {
    const own = { Status: 1, CreatedBy: ' cs-0045' }
    const other = { Status: 1, CreatedBy: 'CS-0046' }
    expect(canDecide(['online_user.approve_own'], own, 'CS-0045')).toBe(true)
    expect(canDecide(['online_user.approve_own'], other, 'CS-0045')).toBe(false)
    expect(canDecide(['online_user.approve', 'online_user.approve_own'], own, 'CS-0045')).toBe(true)
    expect(canDecide(['online_user.approve_own'], { ...own, Status: 2 }, 'CS-0045')).toBe(false)
  })

  it('requires a 10-200 character reason for a quick status change', () => {
    expect(statusReasonOk('  Laporan akses mencurigakan ')).toBe(true)
    expect(statusReasonOk('singkat')).toBe(false)
    expect(statusReasonOk('x'.repeat(201))).toBe(false)
  })

  it('lists missing customer data', () => {
    expect(incompleteFields({ Email: ' ', PhoneNumber: '0812', BirthDate: '1900-01-01' })).toEqual([
      'email',
      'birthDate',
    ])
    expect(incompleteFields({ Email: 'a@b.c', PhoneNumber: '', BirthDate: '1990-05-01 00:00:00' })).toEqual([
      'phone',
    ])
  })
})
