import { StarIcon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'

import { MetricStrip } from '@/components/metric-strip'
import { ErrorState, ListSkeleton } from '@/components/states'
import { ToggleGroup, ToggleGroupItem } from '@/components/ui/controls'
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { UsageBar } from '@/components/usage-bar'
import { rangeLabel } from '@/features/reports/range'
import { formatNumber, formatPercent, formatRating, minutesLabel } from '@/lib/time'

import { useMyStats } from '../hooks'
import { isStatsPeriod, ratingRows } from '../logic'
import { statsPeriods, type MyStats, type StatsPeriod } from '../types'

function Distribution({ stats }: { stats: MyStats }) {
  const { t } = useTranslation()
  if (stats.ratings === 0) {
    return <p className="text-row text-muted-foreground">{t('account.performance.noRatings')}</p>
  }
  return (
    <ul className="flex flex-col gap-2">
      {ratingRows(stats).map((row) => {
        const valueText = t('account.performance.starsValue', {
          count: row.count,
          percent: formatPercent(row.ratio),
        })
        return (
          <li key={row.rating} className="grid grid-cols-[72px_1fr_88px] items-center gap-3 text-row">
            <span className="inline-flex items-center gap-1 text-muted-foreground">
              <StarIcon className="size-3.5" aria-hidden="true" />
              {t('account.performance.stars', { count: row.rating })}
            </span>
            <UsageBar
              ratio={row.ratio}
              label={t('account.performance.stars', { count: row.rating })}
              valueText={valueText}
            />
            <span className="tabular text-right">{formatNumber(row.count)}</span>
          </li>
        )
      })}
    </ul>
  )
}

function StatsView({ stats }: { stats: MyStats }) {
  const { t } = useTranslation()
  return (
    <div className="flex flex-col gap-5">
      {stats.from && stats.to ? (
        <p className="text-xs text-muted-foreground">{rangeLabel({ from: stats.from, to: stats.to })}</p>
      ) : null}
      <MetricStrip
        className="-mx-5 xl:grid-cols-3"
        metrics={[
          {
            label: t('account.performance.resolved'),
            value: formatNumber(stats.resolved),
            caption: t('account.performance.resolvedCaption', { count: stats.handled }),
          },
          {
            label: t('account.performance.active'),
            value: formatNumber(stats.active_tickets),
            caption: t('account.performance.activeCaption'),
          },
          {
            label: t('account.performance.complaints'),
            value: formatNumber(stats.complaints),
            caption: t('account.performance.complaintsCaption'),
          },
          {
            label: t('account.performance.firstResponse'),
            value: minutesLabel(stats.avg_first_response_minutes),
            caption: t('account.performance.firstResponseCaption'),
          },
          {
            label: t('account.performance.resolution'),
            value: minutesLabel(stats.avg_resolution_minutes),
            caption: t('account.performance.resolutionCaption'),
          },
          {
            label: t('account.performance.rating'),
            value: stats.avg_rating === null ? '–' : `${formatRating(stats.avg_rating)}/5`,
            caption: t('account.performance.ratingCount', { count: stats.ratings }),
          },
        ]}
      />
      <section aria-labelledby="my-rating-distribution" className="flex flex-col gap-3">
        <h3 id="my-rating-distribution" className="text-row font-medium">
          {t('account.performance.distribution')}
        </h3>
        <Distribution stats={stats} />
      </section>
    </div>
  )
}

export function PerformanceDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const { t } = useTranslation()
  const [period, setPeriod] = useState<StatsPeriod>('today')
  const stats = useMyStats(period)
  return (
    <Dialog open={open} onOpenChange={(next) => !next && onClose()}>
      <DialogContent closeLabel={t('app.close')} className="sm:max-w-[640px]">
        <DialogHeader>
          <DialogTitle>{t('account.performance.title')}</DialogTitle>
          <DialogDescription>{t('account.performance.subtitle')}</DialogDescription>
        </DialogHeader>
        <ToggleGroup
          type="single"
          value={period}
          onValueChange={(value) => {
            if (isStatsPeriod(value)) setPeriod(value)
          }}
          aria-label={t('account.performance.periodLabel')}
          className="justify-self-start"
        >
          {statsPeriods.map((value) => (
            <ToggleGroupItem key={value} value={value}>
              {t(`account.performance.periods.${value}`)}
            </ToggleGroupItem>
          ))}
        </ToggleGroup>
        {stats.data ? (
          <StatsView stats={stats.data} />
        ) : stats.error ? (
          <ErrorState error={stats.error} onRetry={() => void stats.refetch()} />
        ) : (
          <ListSkeleton rows={4} />
        )}
      </DialogContent>
    </Dialog>
  )
}
