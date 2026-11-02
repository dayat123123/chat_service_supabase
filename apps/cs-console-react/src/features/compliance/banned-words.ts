import type { BannedAction, BannedWord } from './types'

export const IMPORT_MAX_ROWS = 1000

const wordPattern = /^[a-z0-9]+( [a-z0-9]+)*$/

const headerWords = new Set(['kata', 'word', 'kata terlarang', 'kata atau frasa', 'frasa', 'banned word'])

const actionAliases: Record<string, BannedAction> = {
  mask: 'mask',
  sensor: 'mask',
  samarkan: 'mask',
  block: 'block',
  blokir: 'block',
  tolak: 'block',
}

export type WordProblem = 'length' | 'characters'

export type ImportProblem = WordProblem | 'action' | 'conflict'

export type ImportStatus = 'new' | 'update' | 'same' | 'duplicate' | 'invalid'

export type ImportRow = {
  line: number
  word: string
  action: BannedAction | null
  status: ImportStatus
  problem?: ImportProblem
  current?: BannedAction
}

export type ImportPreview = {
  rows: ImportRow[]
  counts: Record<ImportStatus, number>
  payload: { word: string; action: BannedAction }[]
  tooMany: boolean
  overLimit: boolean
}

export function normalizeWord(value: unknown) {
  const text = typeof value === 'string' || typeof value === 'number' ? String(value) : ''
  return text.trim().replace(/\s+/g, ' ').toLowerCase()
}

export function wordProblem(word: string): WordProblem | null {
  if (word.length < 2 || word.length > 50) return 'length'
  return wordPattern.test(word) ? null : 'characters'
}

export function parseAction(value: unknown): BannedAction | null {
  const text = normalizeWord(value)
  return text === '' ? 'mask' : (actionAliases[text] ?? null)
}

export function importPreview(table: unknown[][], existing: BannedWord[], limit: number): ImportPreview {
  const current = new Map(existing.map((entry) => [entry.word, entry.action]))
  const filled = table
    .map((cells, index) => ({ cells, line: index + 1 }))
    .filter(({ cells }) => normalizeWord(cells[0]) !== '' || normalizeWord(cells[1]) !== '')
  const body = headerWords.has(normalizeWord(filled[0]?.cells[0])) ? filled.slice(1) : filled
  const rows: ImportRow[] = body.map(({ cells, line }) => {
    const word = normalizeWord(cells[0])
    const action = parseAction(cells[1])
    const problem = wordProblem(word) ?? (action === null ? 'action' : undefined)
    return problem
      ? { line, word, action, status: 'invalid', problem }
      : { line, word, action, status: 'new' }
  })

  const actions = new Map<string, Set<BannedAction>>()
  for (const row of rows) {
    if (row.status === 'invalid' || row.action === null) continue
    actions.set(row.word, (actions.get(row.word) ?? new Set()).add(row.action))
  }
  const seen = new Set<string>()
  for (const row of rows) {
    if (row.status === 'invalid' || row.action === null) continue
    if ((actions.get(row.word)?.size ?? 0) > 1) {
      row.status = 'invalid'
      row.problem = 'conflict'
    } else if (seen.has(row.word)) {
      row.status = 'duplicate'
    } else {
      seen.add(row.word)
      const before = current.get(row.word)
      if (before === undefined) row.status = 'new'
      else if (before === row.action) row.status = 'same'
      else {
        row.status = 'update'
        row.current = before
      }
    }
  }

  const counts: Record<ImportStatus, number> = { new: 0, update: 0, same: 0, duplicate: 0, invalid: 0 }
  for (const row of rows) counts[row.status] += 1
  return {
    rows,
    counts,
    payload: rows
      .filter((row) => row.status === 'new' || row.status === 'update')
      .map((row) => ({ word: row.word, action: row.action as BannedAction })),
    tooMany: rows.length > IMPORT_MAX_ROWS,
    overLimit: existing.length + counts.new > limit,
  }
}

export function parseCsv(text: string): string[][] {
  const source = text.replace(/^\uFEFF/, '')
  const firstLine = source.split(/\r?\n/, 1)[0] ?? ''
  const delimiter = firstLine.includes(';') && !firstLine.includes(',') ? ';' : ','
  const rows: string[][] = []
  let row: string[] = []
  let cell = ''
  let quoted = false
  for (let index = 0; index < source.length; index += 1) {
    const char = source[index]
    if (quoted) {
      if (char === '"' && source[index + 1] === '"') {
        cell += '"'
        index += 1
      } else if (char === '"') quoted = false
      else cell += char
    } else if (char === '"') quoted = true
    else if (char === delimiter) {
      row.push(cell)
      cell = ''
    } else if (char === '\n' || char === '\r') {
      if (char === '\r' && source[index + 1] === '\n') index += 1
      row.push(cell)
      rows.push(row)
      row = []
      cell = ''
    } else cell += char
  }
  if (cell !== '' || row.length > 0) {
    row.push(cell)
    rows.push(row)
  }
  return rows
}

export function exportSheet(words: BannedWord[], label: (action: BannedAction) => string) {
  return [
    ['Kata', 'Aksi', 'Ditambahkan'],
    ...words.map((entry) => [entry.word, label(entry.action), new Date(entry.created_at)]),
  ]
}
