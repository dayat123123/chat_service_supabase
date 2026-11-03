import { useState } from 'react'
import { useTranslation } from 'react-i18next'

import { DateRangePicker } from '@/components/date-range-picker'
import { MetricStrip } from '@/components/metric-strip'
import { SeriesChart } from '@/components/series-chart'
import { EmptyState, ErrorState } from '@/components/states'
import { ToggleGroup, ToggleGroupItem } from '@/components/ui/controls'
import { Skeleton } from '@/components/ui/primitives'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { rangeLabel } from '@/features/reports/range'
import type { DateRange } from '@/features/reports/types'
import { chartColors } from '@/lib/chart'
import { formatDay, formatNumber, formatPercent, stamp } from '@/lib/time'
import { cn } from '@/lib/utils'

import { useCommunityAnalytics } from '../hooks'
import {
  analyticsRange,
  contentSeries,
  countRows,
  dauSeries,
  isKnownEvent,
  retentionRows,
  retentionShade,
} from '../logic'
import {
  analyticsPresets,
  analyticsSources,
  MAX_ANALYTICS_DAYS,
  RETENTION_WEEKS,
  type AnalyticsPreset,
  type CommunityAnalytics,
} from '../types'

const percentText = (value: number | null) => (value === null ? '–' : formatPercent(value / 100))

function Section({
  id,
  title,
  hint,
  children,
}: {
  id: string
  title: string
  hint?: string
  children: React.ReactNode
}) {
  return (
    <section className="flex min-w-0 flex-col gap-3" aria-labelledby={id}>
      <div>
        <h2 id={id} className="text-panel font-semibold">
          {title}
        </h2>
        {hint ? <p className="text-row text-muted-foreground">{hint}</p> : null}
      </div>
      {children}
    </section>
  )
}

function Retention({ report }: { report: CommunityAnalytics }) {
  const { t } = useTranslation()
  const rows = retentionRows(report.retention)
  if (rows.length === 0) {
    return (
      <p className="border-y py-6 text-center text-row text-muted-foreground">
        {t('platform.analytics.noCohorts')}
      </p>
    )
  }
  return (
    <Table>
      <caption className="sr-only">{t('platform.analytics.retention')}</caption>
      <TableHeader>
        <TableRow>
          <TableHead>{t('platform.analytics.cohort')}</TableHead>
          <TableHead className="text-right">{t('platform.analytics.newUsers')}</TableHead>
          {Array.from({ length: RETENTION_WEEKS }, (_, week) => (
            <TableHead key={week} className="text-right">
              <abbr title={t('platform.analytics.weekLong', { week })} className="no-underline">
                {t('platform.analytics.weekShort', { week })}
              </abbr>
            </TableHead>
          ))}
        </TableRow>
      </TableHeader>
      <TableBody>
        {rows.map((row) => (
          <TableRow key={row.cohort}>
            <TableCell>
              {t('platform.analytics.weekOf', { date: formatDay(row.cohort, 'd MMM yyyy') })}
            </TableCell>
            <TableCell className="tabular text-right">{formatNumber(row.users)}</TableCell>
            {row.cells.map((cell, week) => (
              <TableCell
                key={week}
                className={cn(
                  'tabular text-right',
                  cell ? retentionShade(cell.pct) : 'text-muted-foreground',
                )}
                title={
                  cell
                    ? t('platform.analytics.cellTitle', {
                        active: formatNumber(cell.active),
                        users: formatNumber(row.users),
                        week,
                      })
                    : undefined
                }
              >
                {cell ? percentText(cell.pct) : '·'}
              </TableCell>
            ))}
          </TableRow>
        ))}
      </TableBody>
    </Table>
  )
}

function CountTable({
  caption,
  first,
  rows,
  label,
  empty,
}: {
  caption: string
  first: string
  rows: { name: string; count: number }[]
  label: (name: string) => string
  empty: string
}) {
  const { t } = useTranslation()
  if (rows.length === 0)
    return <p className="border-y py-6 text-center text-row text-muted-foreground">{empty}</p>
  return (
    <Table>
      <caption className="sr-only">{caption}</caption>
      <TableHeader>
        <TableRow>
          <TableHead>{first}</TableHead>
          <TableHead className="text-right">{t('platform.analytics.count')}</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {rows.map((row) => (
          <TableRow key={row.name}>
            <TableCell>{label(row.name)}</TableCell>
            <TableCell className="tabular text-right">{formatNumber(row.count)}</TableCell>
          </TableRow>
        ))}
      </TableBody>
    </Table>
  )
}

function Report({ report }: { report: CommunityAnalytics }) {
  const { t } = useTranslation()
  const active = report.active_users
  const taps = report.order_taps
  const eventLabel = (name: string) => (isKnownEvent(name) ? t(`platform.analytics.events.${name}`) : name)
  const sourceLabel = (name: string) =>
    (analyticsSources as readonly string[]).includes(name)
      ? t(`platform.analytics.sources.${name as (typeof analyticsSources)[number]}`)
      : name
  return (
    <>
      <MetricStrip
        className="md:grid-cols-4 xl:grid-cols-4"
        metrics={[
          { label: t('platform.analytics.avgDau'), value: formatNumber(active.avg_dau, 1) },
          { label: t('platform.analytics.wau'), value: formatNumber(active.wau) },
          { label: t('platform.analytics.mau'), value: formatNumber(active.mau) },
          {
            label: t('platform.analytics.stickiness'),
            value: percentText(active.stickiness_pct),
            caption: t('platform.analytics.stickinessHint'),
          },
        ]}
      />
      <Section id="analytics-dau" title={t('platform.analytics.dau')} hint={t('platform.analytics.dauHint')}>
        <SeriesChart
          data={dauSeries(report)}
          series={[{ key: 'users', label: t('platform.analytics.activeUsers'), color: chartColors.accent }]}
          label={t('platform.analytics.dau')}
        />
      </Section>
      <Section id="analytics-content" title={t('platform.analytics.content')}>
        <MetricStrip
          className="md:grid-cols-4 xl:grid-cols-4"
          metrics={[
            { label: t('platform.analytics.posts'), value: formatNumber(report.content.posts) },
            { label: t('platform.analytics.comments'), value: formatNumber(report.content.comments) },
            { label: t('platform.analytics.messages'), value: formatNumber(report.content.messages) },
            { label: t('platform.analytics.likes'), value: formatNumber(report.content.likes) },
          ]}
        />
        <SeriesChart
          data={contentSeries(report)}
          series={[
            { key: 'posts', label: t('platform.analytics.posts'), color: chartColors.accent },
            {
              key: 'comments',
              label: t('platform.analytics.comments'),
              color: chartColors.neutral,
              dash: '4 3',
            },
          ]}
          label={t('platform.analytics.content')}
        />
      </Section>
      <Section
        id="analytics-retention"
        title={t('platform.analytics.retention')}
        hint={t('platform.analytics.retentionHint')}
      >
        <Retention report={report} />
      </Section>
      <div className="grid items-start gap-6 xl:grid-cols-2">
        <Section
          id="analytics-stocks"
          title={t('platform.analytics.topStocks')}
          hint={t('platform.analytics.topStocksHint')}
        >
          {report.top_stocks.length === 0 ? (
            <p className="border-y py-6 text-center text-row text-muted-foreground">
              {t('platform.analytics.none')}
            </p>
          ) : (
            <Table>
              <caption className="sr-only">{t('platform.analytics.topStocks')}</caption>
              <TableHeader>
                <TableRow>
                  <TableHead>{t('platform.analytics.stock')}</TableHead>
                  <TableHead className="text-right">{t('platform.analytics.posts')}</TableHead>
                  <TableHead className="text-right">{t('platform.analytics.authors')}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {report.top_stocks.map((row) => (
                  <TableRow key={row.code}>
                    <TableCell className="font-mono font-medium">${row.code}</TableCell>
                    <TableCell className="tabular text-right">{formatNumber(row.posts)}</TableCell>
                    <TableCell className="tabular text-right">{formatNumber(row.authors)}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </Section>
        <Section
          id="analytics-events"
          title={t('platform.analytics.eventsTitle')}
          hint={t('platform.analytics.eventsHint')}
        >
          <CountTable
            caption={t('platform.analytics.eventsTitle')}
            first={t('platform.analytics.event')}
            rows={countRows(report.events)}
            label={eventLabel}
            empty={t('platform.analytics.none')}
          />
        </Section>
      </div>
      <Section
        id="analytics-orders"
        title={t('platform.analytics.orders')}
        hint={t('platform.analytics.ordersHint')}
      >
        <MetricStrip
          className="md:grid-cols-4 xl:grid-cols-4"
          metrics={[
            { label: t('platform.analytics.orderTaps'), value: formatNumber(taps.taps) },
            { label: t('platform.analytics.orderUsers'), value: formatNumber(taps.users) },
            { label: t('platform.analytics.stockTapUsers'), value: formatNumber(taps.stock_tap_users) },
            {
              label: t('platform.analytics.conversion'),
              value: percentText(taps.conversion_pct),
              caption: t('platform.analytics.conversionHint'),
            },
          ]}
        />
        <div className="grid items-start gap-6 xl:grid-cols-2">
          <CountTable
            caption={t('platform.analytics.bySource')}
            first={t('platform.analytics.source')}
            rows={countRows(taps.by_source)}
            label={sourceLabel}
            empty={t('platform.analytics.none')}
          />
          <CountTable
            caption={t('platform.analytics.orderStocks')}
            first={t('platform.analytics.stock')}
            rows={taps.top_stocks.map((row) => ({ name: row.code, count: row.taps }))}
            label={(code) => `$${code}`}
            empty={t('platform.analytics.none')}
          />
        </div>
      </Section>
      <p className="text-xs text-muted-foreground">
        {t('platform.analytics.generated', { time: stamp(report.generated_at) })}
      </p>
    </>
  )
}

export function AnalyticsPage() {
  const { t } = useTranslation()
  const [preset, setPreset] = useState<AnalyticsPreset>('month')
  const [range, setRange] = useState<DateRange>(() => analyticsRange('month'))
  const report = useCommunityAnalytics(range)
  return (
    <div className="h-full overflow-y-auto">
      <div className="mx-auto flex max-w-[1440px] flex-col gap-6 px-4 py-5 lg:px-6">
        <header className="flex flex-wrap items-end justify-between gap-3">
          <div>
            <h1 className="text-lg font-semibold">{t('platform.analytics.title')}</h1>
            <p className="text-row text-muted-foreground">{rangeLabel(range)}</p>
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <ToggleGroup
              type="single"
              value={preset === 'custom' ? '' : preset}
              aria-label={t('platform.analytics.rangeLabel')}
              onValueChange={(value) => {
                if (!(analyticsPresets as readonly string[]).includes(value)) return
                const next = value as Exclude<AnalyticsPreset, 'custom'>
                setPreset(next)
                setRange(analyticsRange(next))
              }}
            >
              {analyticsPresets.map((item) => (
                <ToggleGroupItem key={item} value={item}>
                  {t(`platform.analytics.presets.${item}`)}
                </ToggleGroupItem>
              ))}
            </ToggleGroup>
            <DateRangePicker
              range={range}
              active={preset === 'custom'}
              maxDays={MAX_ANALYTICS_DAYS}
              onApply={(next) => {
                setPreset('custom')
                setRange(next)
              }}
            />
          </div>
        </header>
        {report.data ? (
          <div
            className={cn('flex flex-col gap-6 transition-opacity', report.isPlaceholderData && 'opacity-60')}
            aria-busy={report.isFetching}
          >
            <Report report={report.data} />
          </div>
        ) : report.isError ? (
          <ErrorState error={report.error} onRetry={() => void report.refetch()} />
        ) : (
          <div className="flex flex-col gap-6" aria-busy="true">
            <div className="grid grid-cols-2 gap-6 border-y py-4 md:grid-cols-3 xl:grid-cols-6">
              {Array.from({ length: 6 }, (_, i) => (
                <div key={i} className="flex flex-col gap-2">
                  <Skeleton className="h-2 w-20" />
                  <Skeleton className="h-4 w-12" />
                </div>
              ))}
            </div>
            <EmptyState title={t('app.loading')} />
          </div>
        )}
      </div>
    </div>
  )
}
