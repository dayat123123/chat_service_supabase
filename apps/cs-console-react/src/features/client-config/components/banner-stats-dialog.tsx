import { useTranslation } from 'react-i18next'

import { ErrorState, ListSkeleton } from '@/components/states'
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { formatDay, formatNumber } from '@/lib/time'

import { useBannerStats } from '../hooks'
import { ctrText } from '../logic'
import type { AppBanner, BannerStats } from '../types'

function Totals({ stats }: { stats: BannerStats }) {
  const { t } = useTranslation()
  const items = [
    { key: 'impressions', value: formatNumber(stats.impressions) },
    { key: 'clicks', value: formatNumber(stats.clicks) },
    { key: 'dismissals', value: formatNumber(stats.dismissals) },
    { key: 'viewers', value: formatNumber(stats.unique_viewers) },
    { key: 'ctr', value: ctrText(stats.ctr) },
  ] as const
  return (
    <dl className="grid grid-cols-2 gap-3 sm:grid-cols-5">
      {items.map((item) => (
        <div key={item.key} className="rounded-lg border p-2.5">
          <dt className="text-xs text-muted-foreground">{t(`platform.banners.stats.${item.key}`)}</dt>
          <dd className="tabular text-lg font-semibold">{item.value}</dd>
        </div>
      ))}
    </dl>
  )
}

function StatsBody({ banner }: { banner: AppBanner }) {
  const { t } = useTranslation()
  const stats = useBannerStats(banner.id)
  if (stats.isError) return <ErrorState error={stats.error} onRetry={() => void stats.refetch()} />
  if (!stats.data) return <ListSkeleton rows={4} />
  return (
    <div className="flex flex-col gap-4">
      <Totals stats={stats.data} />
      <Table>
        <caption className="sr-only">{t('platform.banners.stats.days')}</caption>
        <TableHeader>
          <TableRow>
            <TableHead>{t('platform.banners.stats.day')}</TableHead>
            <TableHead className="text-right">{t('platform.banners.stats.impressions')}</TableHead>
            <TableHead className="text-right">{t('platform.banners.stats.clicks')}</TableHead>
            <TableHead className="text-right">{t('platform.banners.stats.dismissals')}</TableHead>
            <TableHead className="text-right">{t('platform.banners.stats.ctr')}</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {stats.data.days.map((day) => (
            <TableRow key={day.day}>
              <TableCell className="py-1.5 text-xs">{formatDay(day.day, 'EEE, d MMM')}</TableCell>
              <TableCell className="tabular py-1.5 text-right text-xs">
                {formatNumber(day.impressions)}
              </TableCell>
              <TableCell className="tabular py-1.5 text-right text-xs">{formatNumber(day.clicks)}</TableCell>
              <TableCell className="tabular py-1.5 text-right text-xs">
                {formatNumber(day.dismissals)}
              </TableCell>
              <TableCell className="tabular py-1.5 text-right text-xs">{ctrText(day.ctr)}</TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  )
}

export function BannerStatsDialog({ banner, onClose }: { banner: AppBanner; onClose: () => void }) {
  const { t } = useTranslation()
  return (
    <Dialog open onOpenChange={(next) => !next && onClose()}>
      <DialogContent className="max-h-[92vh] overflow-y-auto sm:max-w-2xl" closeLabel={t('app.close')}>
        <DialogHeader>
          <DialogTitle>{t('platform.banners.stats.title', { title: banner.title })}</DialogTitle>
          <DialogDescription>{t('platform.banners.stats.description')}</DialogDescription>
        </DialogHeader>
        <StatsBody banner={banner} />
      </DialogContent>
    </Dialog>
  )
}
