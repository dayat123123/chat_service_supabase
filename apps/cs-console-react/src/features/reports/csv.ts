import type { CustomerReport, DateRange, ReportExport, ReportStats, ReportSummary } from './types'

export type CsvLabel =
  | 'date'
  | 'created'
  | 'resolved'
  | 'claimMinutes'
  | 'firstResponseMinutes'
  | 'resolutionMinutes'
  | 'avgRating'
  | 'ratings'
  | 'total'
  | 'agent'
  | 'agentCode'
  | 'handled'
  | 'topicCode'
  | 'topic'
  | 'count'
  | 'customer'
  | 'username'
  | 'tickets'
  | 'reopened'
  | 'complaints'
  | 'closedUnrated'
  | 'lastTicket'

type CsvValue = string | number | null | undefined

const formula = /^[=+\-@\t\r]/
const needsQuotes = /[",\r\n]/
const byteOrderMark = String.fromCharCode(0xfeff)

export function csvCell(value: CsvValue): string {
  if (value === null || value === undefined) return ''
  if (typeof value === 'number') return Number.isFinite(value) ? String(value) : ''
  const text = formula.test(value) ? `'${value}` : value
  return needsQuotes.test(text) ? `"${text.replaceAll('"', '""')}"` : text
}

export function toCsv(rows: CsvValue[][]) {
  return `${byteOrderMark}${rows.map((row) => `${row.map(csvCell).join(',')}\r\n`).join('')}`
}

function stats(row: ReportStats): CsvValue[] {
  return [
    row.created,
    row.resolved,
    row.avg_claim_minutes,
    row.avg_first_response_minutes,
    row.avg_resolution_minutes,
    row.avg_rating,
    row.ratings,
  ]
}

export function reportCsv(report: ReportSummary, kind: ReportExport, label: (key: CsvLabel) => string) {
  if (kind === 'daily') {
    return toCsv([
      [
        'date',
        'created',
        'resolved',
        'claimMinutes',
        'firstResponseMinutes',
        'resolutionMinutes',
        'avgRating',
        'ratings',
      ].map((key) => label(key as CsvLabel)),
      ...report.daily.map((day) => [day.day ?? null, ...stats(day)]),
      [label('total'), ...stats(report.totals)],
    ])
  }
  if (kind === 'agents') {
    return toCsv([
      ['agent', 'agentCode', 'handled', 'resolved', 'firstResponseMinutes', 'avgRating', 'ratings'].map(
        (key) => label(key as CsvLabel),
      ),
      ...report.agents.map((agent) => [
        agent.display_name,
        agent.agent_code,
        agent.handled,
        agent.resolved,
        agent.avg_first_response_minutes,
        agent.avg_rating,
        agent.ratings,
      ]),
    ])
  }
  return toCsv([
    [label('topicCode'), label('topic'), label('count')],
    ...report.topics.map((topic) => [topic.topic, topic.name, topic.count]),
  ])
}

export function customersCsv(rows: CustomerReport[], label: (key: CsvLabel) => string) {
  return toCsv([
    (
      [
        'customer',
        'username',
        'tickets',
        'resolved',
        'reopened',
        'complaints',
        'firstResponseMinutes',
        'resolutionMinutes',
        'avgRating',
        'ratings',
        'closedUnrated',
        'lastTicket',
      ] as const
    ).map((key) => label(key)),
    ...rows.map((row) => [
      row.display_name,
      row.username,
      row.tickets,
      row.resolved,
      row.reopened,
      row.complaints,
      row.avg_first_response_minutes,
      row.avg_resolution_minutes,
      row.avg_rating,
      row.ratings,
      row.closed_unrated,
      row.last_ticket_at,
    ]),
  ])
}

export function reportFileName(report: Pick<DateRange, 'from' | 'to'>, kind: ReportExport | 'customers') {
  return `laporan-cs-${kind}-${report.from}-${report.to}.csv`
}
