import { describe, expect, it } from 'vitest'

import {
  canChangeStatus,
  csFormFromUser,
  csFormProblems,
  csUserPayload,
  generatePassword,
  incompleteFields,
  isServiceAccount,
  nasabahTabs,
  passwordOk,
  statusReasonOk,
} from './logic'
import type { CsUser } from './types'

const cs: CsUser = {
  LoginId: 'sinta  ',
  EmployeeId: 'E-01 ',
  Email: 'sinta@olt.test',
  Status: 1,
  Permissions: 5,
  Created: '2026-01-02 03:04:05',
  LastModified: '',
  LastLogin: '',
  CreatedBy: 'admin',
  ModifiedBy: '',
}

describe('csAdmin CS accounts and online user extras', () => {
  it('opens the users tab for quick status holders', () => {
    expect(nasabahTabs(['online_user.status'])).toEqual(['users'])
    expect(canChangeStatus(['online_user.status'])).toBe(true)
    expect(canChangeStatus(['online_user.manage'])).toBe(false)
  })

  it('recognises the gateway technical account regardless of case and padding', () => {
    expect(isServiceAccount(' GOMI ', 'gomi')).toBe(true)
    expect(isServiceAccount('sinta', 'gomi')).toBe(false)
    expect(isServiceAccount('gomi', undefined)).toBe(false)
  })

  it('validates CS account forms like the gateway does', () => {
    const form = csFormFromUser(cs)
    expect(form).toEqual({
      loginId: 'sinta',
      employeeId: 'E-01',
      email: 'sinta@olt.test',
      status: 1,
      permissions: 5,
    })
    expect(csFormProblems(form)).toEqual([])
    expect(
      csFormProblems({ ...form, loginId: 'si', employeeId: ' ', email: 'x@', permissions: 600 }),
    ).toEqual(['loginId', 'employeeId', 'email', 'permissions'])
    expect(csFormProblems({ ...form, loginId: 'a b c' })).toEqual(['loginId'])
  })

  it('builds create and update payloads without passwords', () => {
    const form = csFormFromUser(cs)
    expect(csUserPayload(form, true)).toEqual({
      LoginId: 'sinta',
      EmployeeId: 'E-01',
      Email: 'sinta@olt.test',
      Permissions: 5,
    })
    expect(csUserPayload({ ...form, status: 0 }, false)).toEqual({
      LoginId: 'sinta',
      EmployeeId: 'E-01',
      Email: 'sinta@olt.test',
      Permissions: 5,
      Status: 0,
    })
  })

  it('enforces the csAdmin password policy and generates compliant passwords', () => {
    expect(passwordOk('Rahasia9')).toBe(true)
    expect(passwordOk('rahasia9')).toBe(false)
    expect(passwordOk('Rah 9aa')).toBe(false)
    expect(passwordOk('Ab1')).toBe(false)
    expect(passwordOk('Abcdefghijklmnopqrstu')).toBe(false)
    const seen = new Set<string>()
    for (let i = 0; i < 50; i++) {
      const password = generatePassword()
      expect(passwordOk(password)).toBe(true)
      expect(password).toMatch(/\d/)
      expect(password).not.toMatch(/[0O1lI]/)
      seen.add(password)
    }
    expect(seen.size).toBe(50)
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
