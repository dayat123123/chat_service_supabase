import { subDays } from 'date-fns'

import type { DateRange } from '@/features/reports/types'
import { isoDay, todayInJakarta } from '@/lib/time'

import {
  analyticsEvents,
  RETENTION_WEEKS,
  type AnalyticsPreset,
  type CommunityAnalytics,
  type RetentionCohort,
  type RetentionWeek,
} from './types'

const presetDays: Record<Exclude<AnalyticsPreset, 'custom'>, number> = { week: 7, month: 30, quarter: 90 }

export function analyticsRange(
  preset: Exclude<AnalyticsPreset, 'custom'>,
  today: Date = todayInJakarta(),
): DateRange {
  return { from: isoDay(subDays(today, presetDays[preset] - 1)), to: isoDay(today) }
}

export function retentionRows(cohorts: RetentionCohort[]) {
  return cohorts.map((cohort) => {
    const byWeek = new Map(cohort.weeks.map((week) => [week.week, week]))
    const cells: (RetentionWeek | null)[] = Array.from(
      { length: RETENTION_WEEKS },
      (_, week) => byWeek.get(week) ?? null,
    )
    return { cohort: cohort.cohort_week, users: cohort.users, cells }
  })
}

export function retentionShade(pct: number) {
  if (pct <= 0) return 'bg-transparent'
  if (pct < 10) return 'bg-primary/5'
  if (pct < 25) return 'bg-primary/10'
  if (pct < 50) return 'bg-primary/20'
  if (pct < 75) return 'bg-primary/30'
  return 'bg-primary/40'
}

export function countRows(counts: Record<string, number>) {
  return Object.entries(counts)
    .map(([name, count]) => ({ name, count }))
    .sort((a, b) => b.count - a.count || a.name.localeCompare(b.name))
}

export const isKnownEvent = (name: string): name is (typeof analyticsEvents)[number] =>
  (analyticsEvents as readonly string[]).includes(name)

export function dauSeries(report: CommunityAnalytics) {
  return report.active_users.dau.map((row) => ({ day: row.date, users: row.users }))
}

export function contentSeries(report: CommunityAnalytics) {
  return report.content.daily.map((row) => ({ day: row.date, posts: row.posts, comments: row.comments }))
}
