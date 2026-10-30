import { describe, expect, it } from 'vitest'

import { applyQuickReply, fillVariables, filterQuickReplies, slashToken } from './quick-replies'
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
