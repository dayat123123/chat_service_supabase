import { useState } from 'react'
import { useTranslation } from 'react-i18next'

import { MetricStrip } from '@/components/metric-strip'
import { SeriesChart, type ChartSeries } from '@/components/series-chart'
import { ErrorState, ListSkeleton } from '@/components/states'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  ToggleGroup,
  ToggleGroupItem,
} from '@/components/ui/controls'
import { Label } from '@/components/ui/label'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { SettingsCard } from '@/features/settings/components/settings-ui'
import { chartColors } from '@/lib/chart'
import { formatDay, formatNumber, formatPercent } from '@/lib/time'
import { cn } from '@/lib/utils'

import { useIntegrationStats, useKeyDaily } from '../hooks'
import { dailySeries, deliveryRatio, keyDailySeries } from '../logic'
import { statsWindows, type IntegrationStats, type KeyStats, type StatsWindow } from '../types'

type DailyKey = 'received' | 'queued' | 'no_recipient' | 'posts'

function totals(keys: KeyStats[]) {
  return keys.reduce(
    (sum, key) => ({
      received: sum.received + key.received,
      queued: sum.queued + key.queued,
      devices: sum.devices + key.devices,
      no_recipient: sum.no_recipient + key.no_recipient,
      duplicate: sum.duplicate + key.duplicate,
      invalid: sum.invalid + key.invalid,
      posts: sum.posts + key.posts,
      posts_rejected: sum.posts_rejected + key.posts_rejected,
      sent: sum.sent + key.push.sent,
      failed: sum.failed + key.push.failed,
      dead: sum.dead + key.push.invalid + key.push.expired,
      pending: sum.pending + key.push.pending,
    }),
    {
      received: 0,
      queued: 0,
      devices: 0,
      no_recipient: 0,
      duplicate: 0,
      invalid: 0,
      posts: 0,
      posts_rejected: 0,
      sent: 0,
      failed: 0,
      dead: 0,
      pending: 0,
    },
  )
}

const number = (value: number) => formatNumber(value)

const ALL_KEYS = '__all__'

function DailyChart({ stats }: { stats: IntegrationStats }) {
  const { t } = useTranslation()
  const [keyId, setKeyId] = useState<string>(ALL_KEYS)
  const chosen = stats.keys.find((key) => key.id === keyId) ?? null
  const perKey = useKeyDaily(stats.days, chosen?.id ?? null)
  const rows = chosen ? perKey.data?.find((row) => row.key_id === chosen.id) : undefined
  const series: ChartSeries<DailyKey>[] = [
    { key: 'received', label: t('platform.keys.stats.received'), color: chartColors.neutral, dash: '4 3' },
    { key: 'queued', label: t('platform.keys.stats.queued'), color: chartColors.accent },
    {
      key: 'no_recipient',
      label: t('platform.keys.stats.noRecipient'),
      color: chartColors.warning,
      dash: '1 3',
    },
    { key: 'posts', label: t('platform.keys.stats.posts'), color: chartColors.info },
  ]
  const data = chosen
    ? keyDailySeries(rows?.days ?? [], stats.from, stats.days)
    : dailySeries(stats.daily, stats.from, stats.days)
  return (
    <div className="flex flex-col gap-2">
      <div className="flex flex-wrap items-center gap-2">
        <Label htmlFor="key-chart-select" className="text-xs text-muted-foreground">
          {t('platform.keys.stats.chartFor')}
        </Label>
        <Select value={chosen ? chosen.id : ALL_KEYS} onValueChange={setKeyId}>
          <SelectTrigger id="key-chart-select" className="h-8 w-64 max-w-full">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value={ALL_KEYS}>{t('platform.keys.stats.allKeys')}</SelectItem>
            {stats.keys.map((key) => (
              <SelectItem key={key.id} value={key.id}>
                {key.name} (oik_{key.prefix}…)
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>
      {chosen && perKey.isError ? (
        <ErrorState error={perKey.error} onRetry={() => void perKey.refetch()} />
      ) : (
        <div className={cn('transition-opacity', chosen && !rows && 'opacity-60')}>
          <SeriesChart
            data={data}
            series={series}
            label={
              chosen
                ? t('platform.keys.stats.chartKey', { name: chosen.name })
                : t('platform.keys.stats.chart')
            }
          />
        </div>
      )}
    </div>
  )
}

function StatsBody({ stats }: { stats: IntegrationStats }) {
  const { t } = useTranslation()
  const sum = totals(stats.keys)
  const delivered = deliveryRatio(sum.sent, sum.failed)
  return (
    <>
      <MetricStrip
        metrics={[
          { label: t('platform.keys.stats.received'), value: number(sum.received) },
          {
            label: t('platform.keys.stats.queued'),
            value: number(sum.queued),
            caption: t('platform.keys.stats.devicesCaption', {
              count: sum.devices,
              value: number(sum.devices),
            }),
          },
          {
            label: t('platform.keys.stats.noRecipient'),
            value: number(sum.no_recipient),
            tone: sum.no_recipient > 0 ? 'warn' : undefined,
          },
          { label: t('platform.keys.stats.duplicate'), value: number(sum.duplicate) },
          {
            label: t('platform.keys.stats.invalid'),
            value: number(sum.invalid),
            tone: sum.invalid > 0 ? 'late' : undefined,
          },
          {
            label: t('platform.keys.stats.linked'),
            value: number(stats.linked.accounts),
            caption: t('platform.keys.stats.linkedCaption', { value: number(stats.linked.profiles) }),
          },
        ]}
      />
      <MetricStrip
        className="md:grid-cols-4 xl:grid-cols-4"
        metrics={[
          {
            label: t('platform.keys.stats.posts'),
            value: number(sum.posts),
            caption: t('platform.keys.stats.postsRejected', { value: number(sum.posts_rejected) }),
          },
          {
            label: t('platform.keys.stats.sent'),
            value: number(sum.sent),
            caption:
              delivered === null
                ? undefined
                : t('platform.keys.stats.deliveryRate', { percent: formatPercent(delivered) }),
          },
          {
            label: t('platform.keys.stats.failed'),
            value: number(sum.failed),
            tone: sum.failed > 0 ? 'late' : undefined,
            caption: t('platform.keys.stats.deadCaption', { value: number(sum.dead) }),
          },
          { label: t('platform.keys.stats.pending'), value: number(sum.pending) },
        ]}
      />
      {stats.days > 1 ? <DailyChart stats={stats} /> : null}
      {stats.keys.length === 0 ? (
        <p className="border-y py-6 text-center text-row text-muted-foreground">
          {t('platform.keys.stats.empty')}
        </p>
      ) : (
        <Table>
          <caption className="sr-only">{t('platform.keys.stats.perKey')}</caption>
          <TableHeader>
            <TableRow>
              <TableHead>{t('platform.keys.cols.name')}</TableHead>
              {(
                [
                  'received',
                  'queued',
                  'devices',
                  'noRecipient',
                  'duplicate',
                  'invalid',
                  'posts',
                  'sent',
                  'failed',
                  'pending',
                ] as const
              ).map((column) => (
                <TableHead key={column} className="text-right">
                  {t(`platform.keys.stats.${column}`)}
                </TableHead>
              ))}
            </TableRow>
          </TableHeader>
          <TableBody>
            {stats.keys.map((key) => (
              <TableRow key={key.id} className={cn(key.status === 'revoked' && 'text-muted-foreground')}>
                <TableCell>
                  <span className="font-medium">{key.name}</span>{' '}
                  <span className="font-mono text-xs text-muted-foreground">oik_{key.prefix}…</span>
                </TableCell>
                {[
                  key.received,
                  key.queued,
                  key.devices,
                  key.no_recipient,
                  key.duplicate,
                  key.invalid,
                  key.posts,
                  key.push.sent,
                  key.push.failed,
                  key.push.pending,
                ].map((value, index) => (
                  <TableCell key={index} className="tabular text-right">
                    {number(value)}
                  </TableCell>
                ))}
              </TableRow>
            ))}
          </TableBody>
        </Table>
      )}
    </>
  )
}

export function KeyStatsCard() {
  const { t } = useTranslation()
  const [days, setDays] = useState<StatsWindow>(7)
  const stats = useIntegrationStats(days)
  return (
    <SettingsCard
      title={t('platform.keys.stats.title')}
      subtitle={
        stats.data
          ? t('platform.keys.stats.subtitle', { from: formatDay(stats.data.from, 'd MMM yyyy') })
          : undefined
      }
    >
      <ToggleGroup
        type="single"
        value={String(days)}
        className="self-start"
        aria-label={t('platform.keys.stats.window')}
        onValueChange={(value) => {
          const next = Number(value)
          if ((statsWindows as readonly number[]).includes(next)) setDays(next as StatsWindow)
        }}
      >
        {statsWindows.map((item) => (
          <ToggleGroupItem key={item} value={String(item)}>
            {t('platform.keys.stats.days', { count: item })}
          </ToggleGroupItem>
        ))}
      </ToggleGroup>
      {stats.data ? (
        <div
          className={cn('flex flex-col gap-4 transition-opacity', stats.isPlaceholderData && 'opacity-60')}
        >
          <StatsBody stats={stats.data} />
        </div>
      ) : stats.isError ? (
        <ErrorState error={stats.error} onRetry={() => void stats.refetch()} />
      ) : (
        <ListSkeleton rows={3} />
      )}
    </SettingsCard>
  )
}
