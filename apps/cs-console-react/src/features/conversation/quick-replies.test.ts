import { describe, expect, it } from 'vitest'

import {
  applyQuickReply,
  fillVariables,
  filterQuickReplies,
  flattenGroups,
  groupQuickReplies,
  replyDraftProblems,
  slashToken,
} from './quick-replies'
import type { QuickReply } from './types'

const replies: QuickReply[] = [
  {
    id: '1',
    scope: 'global',
    shortcut: 'salam',
    title: 'Salam pembuka',
    body: 'Halo {nama}, saya {nama_cs}.',
  },
  {
    id: '2',
    scope: 'global',
    shortcut: 'tutup',
    title: 'Penutup',
    body: 'Terima kasih sudah menghubungi kami.',
  },
  { id: '3', scope: 'global', shortcut: 'dana', title: 'Cek dana', body: 'Dana sedang kami cek ke bank.' },
]

describe('slashToken', () => {
  it('detects a slash command at the caret', () => {
    expect(slashToken('/sal', 4)).toEqual({ start: 0, end: 4, query: 'sal' })
    expect(slashToken('Halo /tu', 8)).toEqual({ start: 5, end: 8, query: 'tu' })
  })

  it('ignores slashes inside words and text after the caret', () => {
    expect(slashToken('dan/atau', 8)).toBeNull()
    expect(slashToken('Halo', 4)).toBeNull()
    expect(slashToken('/salam lalu', 11)).toBeNull()
  })
})

describe('filterQuickReplies', () => {
  it('ranks shortcut prefix before title and body matches', () => {
    expect(filterQuickReplies(replies, 'dan').map((reply) => reply.shortcut)).toEqual(['dana'])
    expect(filterQuickReplies(replies, 'terima').map((reply) => reply.shortcut)).toEqual(['tutup'])
    expect(filterQuickReplies(replies, 'ka').map((reply) => reply.shortcut)).toEqual([
      'salam',
      'dana',
      'tutup',
    ])
  })

  it('returns everything for an empty query and nothing for unknown text', () => {
    expect(filterQuickReplies(replies, '')).toHaveLength(3)
    expect(filterQuickReplies(replies, 'zzz')).toHaveLength(0)
  })
})

describe('fillVariables and applyQuickReply', () => {
  it('fills every supported variable', () => {
    expect(
      fillVariables('Halo {nama}, tiket {nomor_tiket} ditangani {nama_cs}. {nama}', {
        customer: 'Budi',
        ticketNumber: 'CS-1',
        agent: 'Rina',
      }),
    ).toBe('Halo Budi, tiket CS-1 ditangani Rina. Budi')
  })

  it('replaces only the slash token and moves the caret to the end of the inserted text', () => {
    const token = slashToken('Baik /sal', 9)
    expect(token).not.toBeNull()
    const next = applyQuickReply('Baik /sal', token!, 'Halo Budi')
    expect(next).toEqual({ value: 'Baik Halo Budi', caret: 14 })
  })
})

describe('groupQuickReplies', () => {
  const mixed: QuickReply[] = [
    ...replies,
    { id: 'p1', scope: 'personal', shortcut: 'salam-pagi', title: 'Salam pagi saya', body: 'Pagi {nama}!' },
    { id: 'p2', scope: 'personal', shortcut: 'refund', title: 'Refund', body: 'Dana kembali 3 hari kerja.' },
  ]

  it('splits personal and shared replies and searches both', () => {
    const groups = groupQuickReplies(mixed, 'sal')
    expect(groups.personal.map((reply) => reply.id)).toEqual(['p1'])
    expect(groups.shared.map((reply) => reply.id)).toEqual(['1'])
    expect(flattenGroups(groups).map((reply) => reply.id)).toEqual(['p1', '1'])
  })

  it('matches body text in either group and keeps personal replies first', () => {
    const groups = groupQuickReplies(mixed, 'dana')
    expect(flattenGroups(groups).map((reply) => reply.id)).toEqual(['p2', '3'])
    expect(groupQuickReplies(mixed, '').personal).toHaveLength(2)
  })
})

describe('replyDraftProblems', () => {
  it('requires a title and a body within the shared limits and an optional valid shortcut', () => {
    expect(replyDraftProblems({ title: 'Salam', body: 'Halo', shortcut: '' })).toEqual({
      title: false,
      body: false,
      shortcut: false,
    })
    expect(replyDraftProblems({ title: ' ', body: 'a'.repeat(2001), shortcut: 'Bukan Valid' })).toEqual({
      title: true,
      body: true,
      shortcut: true,
    })
    expect(replyDraftProblems({ title: 'a'.repeat(81), body: 'ok', shortcut: 'ok-1' }).title).toBe(true)
  })
})
