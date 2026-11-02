import { describe, expect, it } from 'vitest'

import { exportSheet, importPreview, normalizeWord, parseAction, parseCsv, wordProblem } from './banned-words'
import type { BannedWord } from './types'

const existing: BannedWord[] = [
  { word: 'jaminan profit', action: 'block', created_at: '2026-11-01T02:00:00.000Z' },
  { word: 'goblok', action: 'mask', created_at: '2026-11-01T02:00:00.000Z' },
]

describe('banned word rules', () => {
  it('normalizes case and spacing like the database', () => {
    expect(normalizeWord('  Jaminan   PROFIT ')).toBe('jaminan profit')
    expect(normalizeWord(123)).toBe('123')
    expect(normalizeWord(null)).toBe('')
  })

  it('accepts 2–50 letters, digits, and single spaces', () => {
    expect(wordProblem('jaminan profit')).toBeNull()
    expect(wordProblem('a')).toBe('length')
    expect(wordProblem('x'.repeat(51))).toBe('length')
    expect(wordProblem('anj*ng')).toBe('characters')
    expect(wordProblem('kata-kata')).toBe('characters')
  })

  it('reads actions in Indonesian or English and defaults to mask', () => {
    expect(parseAction('Sensor')).toBe('mask')
    expect(parseAction(' BLOKIR ')).toBe('block')
    expect(parseAction('block')).toBe('block')
    expect(parseAction('')).toBe('mask')
    expect(parseAction(undefined)).toBe('mask')
    expect(parseAction('hapus')).toBeNull()
  })
})

describe('import preview', () => {
  it('skips the header and blank rows and sorts rows into new, changed, and unchanged', () => {
    const preview = importPreview(
      [
        ['Kata', 'Aksi'],
        ['Penipu', 'blokir'],
        [null, null],
        ['Jaminan Profit', 'blokir'],
        ['GOBLOK', 'blokir'],
      ],
      existing,
      2000,
    )
    expect(preview.rows.map((row) => [row.line, row.word, row.status])).toEqual([
      [2, 'penipu', 'new'],
      [4, 'jaminan profit', 'same'],
      [5, 'goblok', 'update'],
    ])
    expect(preview.rows[2]?.current).toBe('mask')
    expect(preview.counts).toMatchObject({ new: 1, update: 1, same: 1, duplicate: 0, invalid: 0 })
    expect(preview.payload).toEqual([
      { word: 'penipu', action: 'block' },
      { word: 'goblok', action: 'block' },
    ])
  })

  it('flags invalid rows, repeats, and conflicting actions without sending them', () => {
    const preview = importPreview(
      [
        ['bodoh', 'sensor'],
        ['Bodoh', ''],
        ['tolol', 'sensor'],
        ['Tolol', 'blokir'],
        ['x', 'sensor'],
        ['anj*ng', 'sensor'],
        ['curang', 'hapus'],
      ],
      existing,
      2000,
    )
    expect(preview.rows.map((row) => [row.word, row.status, row.problem])).toEqual([
      ['bodoh', 'new', undefined],
      ['bodoh', 'duplicate', undefined],
      ['tolol', 'invalid', 'conflict'],
      ['tolol', 'invalid', 'conflict'],
      ['x', 'invalid', 'length'],
      ['anj*ng', 'invalid', 'characters'],
      ['curang', 'invalid', 'action'],
    ])
    expect(preview.payload).toEqual([{ word: 'bodoh', action: 'mask' }])
  })

  it('reports files that are too long or would pass the list limit', () => {
    const rows = Array.from({ length: 1001 }, (_, index) => [`kata ${index}`])
    expect(importPreview(rows, existing, 5000).tooMany).toBe(true)
    expect(importPreview(rows.slice(0, 10), existing, 11).overLimit).toBe(true)
    expect(importPreview(rows.slice(0, 9), existing, 11).overLimit).toBe(false)
  })
})

describe('files', () => {
  it('parses comma or semicolon CSV with quoted cells', () => {
    expect(parseCsv('Kata,Aksi\r\n"jaminan, profit",blokir\npenipu,\n')).toEqual([
      ['Kata', 'Aksi'],
      ['jaminan, profit', 'blokir'],
      ['penipu', ''],
    ])
    expect(parseCsv('﻿Kata;Aksi\n"kata ""lucu""";sensor')).toEqual([
      ['Kata', 'Aksi'],
      ['kata "lucu"', 'sensor'],
    ])
  })

  it('exports the list with readable actions that import back unchanged', () => {
    const sheet = exportSheet(existing, (action) => (action === 'block' ? 'blokir' : 'sensor'))
    expect(sheet[0]).toEqual(['Kata', 'Aksi', 'Ditambahkan'])
    expect(sheet[1]?.slice(0, 2)).toEqual(['jaminan profit', 'blokir'])
    expect(importPreview(sheet, existing, 2000).counts).toMatchObject({ same: 2, new: 0, update: 0 })
  })
})
