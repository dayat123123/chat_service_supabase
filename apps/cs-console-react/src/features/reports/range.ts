import { differenceInCalendarDays, parseISO, subDays } from 'date-fns'

import { formatDay, isoDay, todayInJakarta } from '@/lib/time'

import { MAX_REPORT_DAYS, type DateRange, type ReportPreset } from './types'

export type RangeProblem = 'invalid' | 'order' | 'future' | 'tooLong'

const isoPattern = /^\d{4}-\d{2}-\d{2}$/

export function presetRange(preset: ReportPreset, today: Date = todayInJakarta()): DateRange {
  const to = isoDay(today)
  if (preset === 'week') return { from: isoDay(subDays(today, 6)), to }
  if (preset === 'month') return { from: isoDay(subDays(today, 29)), to }
  return { from: to, to }
}

export function rangeDays(range: DateRange) {
  return differenceInCalendarDays(parseISO(range.to), parseISO(range.from)) + 1
}

export function rangeProblem(range: DateRange, today: Date = todayInJakarta()): RangeProblem | null {
  if (!isoPattern.test(range.from) || !isoPattern.test(range.to)) return 'invalid'
  if (Number.isNaN(parseISO(range.from).getTime()) || Number.isNaN(parseISO(range.to).getTime()))
    return 'invalid'
  if (range.to < range.from) return 'order'
  if (range.to > isoDay(today)) return 'future'
  if (rangeDays(range) > MAX_REPORT_DAYS) return 'tooLong'
  return null
}

export function rangeLabel(range: DateRange) {
  const pattern = 'd MMM yyyy'
  return range.from === range.to
    ? formatDay(range.from, pattern)
    : `${formatDay(range.from, pattern)} – ${formatDay(range.to, pattern)}`
}
