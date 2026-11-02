import { describe, expect, it } from 'vitest'

import { csvCell, customersCsv, reportCsv, reportFileName, toCsv } from './csv'
import { emptyStats, type ReportSummary } from './types'

const label = (key: string) => key.toUpperCase()

const report: ReportSummary = {
  from: '2026-10-24',
  to: '2026-10-30',
  totals: { ...emptyStats, created: 12, resolved: 10, avg_rating: 4.5, ratings: 4 },
  daily: [{ ...emptyStats, day: '2026-10-30', created: 12, resolved: 10, avg_claim_minutes: 2.5 }],
  agents: [
    {
      id: 'a',
      display_name: '=HYPERLINK("x")',
      agent_code: 'CS01',
      handled: 5,
      resolved: 4,
      avg_first_response_minutes: null,
      avg_rating: 4.8,
      ratings: 3,
    },
  ],
  topics: [{ topic: 'order', name: 'Order, transaksi', count: 7 }],
}

describe('csvCell', () => {
  it('neutralises spreadsheet formulas', () => {
    expect(csvCell('=SUM(A1)')).toBe("'=SUM(A1)")
    expect(csvCell('+62812')).toBe("'+62812")
    expect(csvCell('-5')).toBe("'-5")
    expect(csvCell('@cmd')).toBe("'@cmd")
  })

  it('quotes separators and escapes quotes', () => {
    expect(csvCell('a,b')).toBe('"a,b"')
    expect(csvCell('say "hi"')).toBe('"say ""hi"""')
    expect(csvCell('line\nbreak')).toBe('"line\nbreak"')
  })

  it('keeps numbers as numbers and empties missing values', () => {
    expect(csvCell(-5)).toBe('-5')
    expect(csvCell(2.5)).toBe('2.5')
    expect(csvCell(Number.NaN)).toBe('')
    expect(csvCell(null)).toBe('')
    expect(csvCell(undefined)).toBe('')
  })
})

describe('report export', () => {
  it('starts with a byte order mark and ends every row with CRLF', () => {
    const csv = toCsv([['a', 1]])
    expect(csv.charCodeAt(0)).toBe(0xfeff)
    expect(csv.slice(1)).toBe('a,1\r\n')
  })

  it('exports daily rows with a total line', () => {
    const lines = reportCsv(report, 'daily', label).slice(1).split('\r\n')
    expect(lines[0]).toBe(
      'DATE,CREATED,RESOLVED,CLAIMMINUTES,FIRSTRESPONSEMINUTES,RESOLUTIONMINUTES,AVGRATING,RATINGS',
    )
    expect(lines[1]).toBe('2026-10-30,12,10,2.5,,,,0')
    expect(lines[2]).toBe('TOTAL,12,10,,,,4.5,4')
  })

  it('exports agents and topics safely', () => {
    const agents = reportCsv(report, 'agents', label).slice(1).split('\r\n')
    expect(agents[1]).toBe(`"'=HYPERLINK(""x"")",CS01,5,4,,4.8,3`)
    const topics = reportCsv(report, 'topics', label).slice(1).split('\r\n')
    expect(topics[1]).toBe('order,"Order, transaksi",7')
  })

  it('names files after the kind and range', () => {
    expect(reportFileName(report, 'agents')).toBe('laporan-cs-agents-2026-10-24-2026-10-30.csv')
  })
})

describe('customersCsv', () => {
  it('exports per-customer performance with neutralised names', () => {
    const csv = customersCsv(
      [
        {
          id: 'c1',
          display_name: '=Budi',
          username: 'budi',
          tickets: 3,
          resolved: 2,
          reopened: 1,
          complaints: 0,
          avg_first_response_minutes: 4.5,
          avg_resolution_minutes: null,
          avg_rating: 4.5,
          ratings: 2,
          closed_unrated: 1,
          last_ticket_at: '2026-11-02T03:00:00.000Z',
        },
      ],
      label,
    )
    expect(csv.slice(1).split('\r\n')).toEqual([
      'CUSTOMER,USERNAME,TICKETS,RESOLVED,REOPENED,COMPLAINTS,FIRSTRESPONSEMINUTES,RESOLUTIONMINUTES,AVGRATING,RATINGS,CLOSEDUNRATED,LASTTICKET',
      "'=Budi,budi,3,2,1,0,4.5,,4.5,2,1,2026-11-02T03:00:00.000Z",
      '',
    ])
    expect(reportFileName({ from: '2026-11-01', to: '2026-11-02' }, 'customers')).toBe(
      'laporan-cs-customers-2026-11-01-2026-11-02.csv',
    )
  })
})
