import { describe, expect, it } from 'vitest'

import {
  acceptanceRatio,
  draftActions,
  draftProblems,
  isoToWibInput,
  sortDrafts,
  toggleRequired,
  wibInputToIso,
} from './logic'
import type { LegalDraft } from './types'

const me = 'me'
const other = 'other'

const draft = (overrides: Partial<LegalDraft> = {}): LegalDraft => ({
  id: 'd-1',
  kind: 'terms',
  title: 'Syarat',
  body_length: 120,
  status: 'draft',
  created_by_id: other,
  created_at: '2026-11-01T02:00:00.000Z',
  updated_by_id: other,
  updated_at: '2026-11-01T02:00:00.000Z',
  ...overrides,
})

const body = 'Pasal 1. Pengguna wajib menjaga kerahasiaan akun dan kata sandinya. '

describe('WIB date-time input', () => {
  it('reads the effective date as Jakarta time', () => {
    expect(wibInputToIso('2026-12-01T09:30')).toBe('2026-12-01T02:30:00.000Z')
    expect(isoToWibInput('2026-12-01T02:30:00.000Z')).toBe('2026-12-01T09:30')
  })

  it('rejects malformed or impossible dates', () => {
    expect(wibInputToIso('2026-02-30T09:30')).toBeNull()
    expect(wibInputToIso('1 Des 2026')).toBeNull()
  })
})

describe('draftProblems', () => {
  const now = new Date('2026-11-03T03:00:00.000Z')
  const valid = { title: 'Syarat dan Ketentuan', body, changeSummary: '', effectiveInput: '' }

  it('accepts a complete draft that takes effect on approval', () => {
    expect(draftProblems(valid, now)).toEqual({})
  })

  it('checks title and body length after trimming, like the server', () => {
    expect(draftProblems({ ...valid, title: '  ab  ' }, now).title).toBe('length')
    expect(draftProblems({ ...valid, body: `   ${'x'.repeat(49)}   ` }, now).body).toBe('length')
    expect(draftProblems({ ...valid, changeSummary: 'x'.repeat(2001) }, now).changeSummary).toBe('length')
  })

  it('requires a future effective date when one is given', () => {
    expect(draftProblems({ ...valid, effectiveInput: '2026-11-03T09:59' }, now).effectiveAt).toBe('past')
    expect(draftProblems({ ...valid, effectiveInput: '2026-11-03T10:05' }, now).effectiveAt).toBeUndefined()
    expect(draftProblems({ ...valid, effectiveInput: '2026-13-01T10:00' }, now).effectiveAt).toBe('invalid')
  })
})

describe('draftActions and the four-eyes rule', () => {
  it('lets anyone edit, submit, or delete an open draft', () => {
    for (const status of ['draft', 'rejected'] as const) {
      expect(draftActions(draft({ status }), me, true)).toEqual({
        edit: true,
        submit: true,
        remove: true,
        withdraw: false,
        reject: false,
        approve: 'hidden',
      })
    }
  })

  it('lets another compliance officer approve or reject a pending draft', () => {
    expect(draftActions(draft({ status: 'pending' }), me, true)).toMatchObject({
      approve: 'allowed',
      reject: true,
      withdraw: true,
      edit: false,
    })
  })

  it('blocks the author, last editor, or submitter from approving while four eyes applies', () => {
    expect(draftActions(draft({ status: 'pending', created_by_id: me }), me, true).approve).toBe('blocked')
    expect(draftActions(draft({ status: 'pending', updated_by_id: me }), me, true).approve).toBe('blocked')
    expect(draftActions(draft({ status: 'pending', submitted_by_id: me }), me, true).approve).toBe('blocked')
    expect(draftActions(draft({ status: 'pending', created_by_id: me }), me, true).reject).toBe(false)
  })

  it('allows self-approval with a warning when only one compliance officer is active', () => {
    expect(draftActions(draft({ status: 'pending', created_by_id: me }), me, false).approve).toBe('self')
  })
})

describe('helpers', () => {
  it('builds the full required set in a stable order', () => {
    expect(toggleRequired(['terms', 'community_guidelines'], 'privacy', true)).toEqual([
      'terms',
      'community_guidelines',
      'privacy',
    ])
    expect(toggleRequired(['terms', 'community_guidelines'], 'terms', false)).toEqual([
      'community_guidelines',
    ])
  })

  it('computes acceptance against active users', () => {
    expect(acceptanceRatio(250, 1000)).toBe(0.25)
    expect(acceptanceRatio(5, 0)).toBeNull()
    expect(acceptanceRatio(12, 10)).toBe(1)
  })

  it('lists drafts awaiting approval first', () => {
    const sorted = sortDrafts([
      draft({ id: 'a', status: 'draft', updated_at: '2026-11-03T00:00:00.000Z' }),
      draft({ id: 'b', status: 'pending', updated_at: '2026-11-01T00:00:00.000Z' }),
      draft({ id: 'c', status: 'rejected', updated_at: '2026-11-02T00:00:00.000Z' }),
    ])
    expect(sorted.map((item) => item.id)).toEqual(['b', 'c', 'a'])
  })
})
