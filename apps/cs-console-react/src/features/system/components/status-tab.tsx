import {
  CheckIcon,
  CircleCheckIcon,
  LoaderCircleIcon,
  OctagonAlertIcon,
  TriangleAlertIcon,
} from 'lucide-react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { MetricStrip } from '@/components/metric-strip'
import { UsageBar } from '@/components/usage-bar'
import { Button } from '@/components/ui/button'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { QueryContent, SettingsCard } from '@/features/settings/components/settings-ui'
import { useNow } from '@/hooks/use-now'
import { errorText } from '@/lib/error-text'
import { durationLabel, formatBytes, formatNumber, formatPercent, stamp } from '@/lib/time'
import { cn } from '@/lib/utils'

import { useAcknowledgeAlert, useSystemHealth } from '../hooks'
import {
  durationMs,
  evaluationStale,
  instanceState,
  instanceTone,
  sentinelLive,
  severityTone,
  usageTone,
} from '../logic'
import type { Disk, OpenAlert, Severity, SystemHealth } from '../types'
import { ToneBadge } from './system-ui'

const bannerClass = {
  ok: 'border-success/40',
  warning: 'border-warning/40',
  critical: 'border-destructive/40',
} as const

const bannerIcon = { ok: CircleCheckIcon, warning: TriangleAlertIcon, critical: OctagonAlertIcon } as const

const iconClass = { ok: 'text-success', warning: 'text-warning', critical: 'text-destructive' } as const

function SeverityBadge({ severity }: { severity: Severity }) {
  const { t } = useTranslation()
  return <ToneBadge tone={severityTone(severity)}>{t(`system.severity.${severity}`)}</ToneBadge>
}

function Banner({ health }: { health: SystemHealth }) {
  const { t } = useTranslation()
  const now = useNow(15_000)
  const Icon = bannerIcon[health.status]
  const stale = evaluationStale(health.evaluated_at, now)
  return (
    <div
      role="status"
      className={cn('flex flex-col gap-2 rounded-lg border p-4 sm:flex-row sm:items-center', bannerClass[health.status])}
    >
      <Icon className={cn('size-6 shrink-0', iconClass[health.status])} aria-hidden="true" />
      <div className="min-w-0 flex-1">
        <p className="text-panel font-semibold">{t(`system.status.overall.${health.status}`)}</p>
        <p className="text-xs text-muted-foreground">
          {health.evaluated_at
            ? t('system.status.evaluatedAt', { time: stamp(health.evaluated_at) })
            : t('system.status.neverEvaluated')}
        </p>
        {stale ? <p className="text-xs text-warning">{t('system.status.evaluationStale')}</p> : null}
      </div>
      <p className="tabular text-row text-muted-foreground">
        {t('system.status.summary', {
          checks: formatNumber(health.checks.length),
          alerts: formatNumber(health.alerts.open.length),
        })}
      </p>
    </div>
  )
}

function Problems({ health }: { health: SystemHealth }) {
  const { t } = useTranslation()
  const now = useNow(30_000)
  return (
    <SettingsCard title={t('system.status.problemsTitle')}>
      {health.checks.length === 0 ? (
        <p className="text-row text-muted-foreground">{t('system.status.noProblems')}</p>
      ) : (
        <ul className="flex flex-col border-t">
          {health.checks.map((check) => (
            <li key={check.key} className="flex flex-col gap-1 border-b py-2.5 sm:flex-row sm:items-start sm:gap-3">
              <SeverityBadge severity={check.severity} />
              <div className="min-w-0 flex-1">
                <p className="text-row font-medium break-words">{check.title}</p>
                {check.detail ? <p className="text-xs break-words text-muted-foreground">{check.detail}</p> : null}
              </div>
              <p className="tabular text-xs text-muted-foreground sm:text-right">
                {t('system.status.since', {
                  time: stamp(check.failing_since),
                  duration: durationLabel(durationMs(check.failing_since, now.toISOString())),
                })}
              </p>
            </li>
          ))}
        </ul>
      )}
    </SettingsCard>
  )
}

function AlertRow({ alert }: { alert: OpenAlert }) {
  const { t } = useTranslation()
  const acknowledge = useAcknowledgeAlert()
  return (
    <li className="flex flex-col gap-2 border-b py-2.5 sm:flex-row sm:items-start sm:gap-3">
      <SeverityBadge severity={alert.severity} />
      <div className="min-w-0 flex-1">
        <p className="text-row font-medium break-words">{alert.title}</p>
        {alert.detail ? <p className="text-xs break-words text-muted-foreground">{alert.detail}</p> : null}
        <p className="text-xs text-muted-foreground">{t('system.alerts.openedAt', { time: stamp(alert.opened_at) })}</p>
      </div>
      {alert.acknowledged_at ? (
        <p className="flex items-center gap-1.5 text-xs text-muted-foreground">
          <CheckIcon className="size-3.5 text-success" aria-hidden="true" />
          {t('system.alerts.acknowledgedBy', {
            name: alert.acknowledged_by ?? '–',
            time: stamp(alert.acknowledged_at),
          })}
        </p>
      ) : (
        <Button
          size="xs"
          variant="outline"
          className="self-start"
          disabled={acknowledge.isPending}
          aria-label={t('system.alerts.acknowledgeFor', { title: alert.title })}
          onClick={() =>
            void acknowledge
              .mutateAsync(alert.id)
              .then(() => toast.success(t('system.alerts.acknowledged')))
              .catch((error: unknown) => toast.error(errorText(error)))
          }
        >
          {acknowledge.isPending ? <LoaderCircleIcon className="animate-spin" /> : <CheckIcon />}
          {t('system.alerts.acknowledge')}
        </Button>
      )}
    </li>
  )
}

function OpenAlerts({ health }: { health: SystemHealth }) {
  const { t } = useTranslation()
  return (
    <SettingsCard title={t('system.alerts.openTitle')} subtitle={t('system.alerts.openHint')}>
      {health.alerts.open.length === 0 ? (
        <p className="text-row text-muted-foreground">{t('system.alerts.noneOpen')}</p>
      ) : (
        <ul className="flex flex-col border-t">
          {health.alerts.open.map((alert) => (
            <AlertRow key={alert.id} alert={alert} />
          ))}
        </ul>
      )}
    </SettingsCard>
  )
}

function Services({ health }: { health: SystemHealth }) {
  const { t } = useTranslation()
  return (
    <SettingsCard title={t('system.services.title')}>
      {health.services.length === 0 ? (
        <p className="text-row text-muted-foreground">{t('system.services.empty')}</p>
      ) : (
        <ul className="flex flex-col border-t">
          {health.services.map((group) => (
            <li key={group.service} className="flex flex-col gap-1.5 border-b py-2.5">
              <p className="text-row font-medium">
                {group.label} <span className="font-mono text-xs font-normal text-muted-foreground">{group.service}</span>
              </p>
              <ul className="flex flex-col gap-1.5">
                {group.instances.map((instance) => {
                  const state = instanceState(instance)
                  return (
                    <li key={instance.instance} className="flex flex-wrap items-center gap-x-3 gap-y-1 text-xs">
                      <ToneBadge tone={instanceTone(state)}>{t(`system.services.states.${state}`)}</ToneBadge>
                      <span className="min-w-0 font-mono break-all">{instance.instance}</span>
                      <span className="text-muted-foreground">
                        {t('system.services.meta', {
                          version: instance.version ?? '–',
                          time: stamp(instance.last_seen_at),
                        })}
                      </span>
                      {instance.error ? (
                        <span className="w-full break-words text-destructive">{instance.error}</span>
                      ) : null}
                    </li>
                  )
                })}
              </ul>
            </li>
          ))}
        </ul>
      )}
    </SettingsCard>
  )
}

function NoSentinel() {
  const { t } = useTranslation()
  return <p className="text-row text-muted-foreground">{t('system.noSentinel')}</p>
}

function Probes({ health, live }: { health: SystemHealth; live: boolean }) {
  const { t } = useTranslation()
  return (
    <SettingsCard title={t('system.probes.title')} subtitle={t('system.probes.hint')}>
      {health.probes.length === 0 ? (
        live ? (
          <p className="text-row text-muted-foreground">{t('system.probes.empty')}</p>
        ) : (
          <NoSentinel />
        )
      ) : (
        <ul className="flex flex-col border-t">
          {health.probes.map((probe) => {
            const tone = probe.stale ? 'neutral' : probe.ok ? 'ok' : 'late'
            return (
              <li key={probe.name} className="flex flex-wrap items-center gap-x-3 gap-y-1 border-b py-2">
                <ToneBadge tone={tone}>
                  {probe.stale
                    ? t('system.probes.stale')
                    : probe.ok
                      ? t('system.probes.ok')
                      : t('system.probes.failed')}
                </ToneBadge>
                <span className="text-row font-medium">{probe.label}</span>
                {probe.target ? (
                  <span className="min-w-0 font-mono text-xs break-all text-muted-foreground">{probe.target}</span>
                ) : null}
                <span className="tabular ml-auto text-xs text-muted-foreground">
                  {[
                    probe.latency_ms !== null ? t('system.probes.latency', { value: formatNumber(probe.latency_ms) }) : null,
                    probe.status !== null ? `HTTP ${probe.status}` : null,
                    stamp(probe.checked_at),
                  ]
                    .filter(Boolean)
                    .join(' · ')}
                </span>
                {probe.error ? <span className="w-full text-xs break-words text-destructive">{probe.error}</span> : null}
              </li>
            )
          })}
        </ul>
      )}
    </SettingsCard>
  )
}

function DiskRow({ disk }: { disk: Disk }) {
  const { t } = useTranslation()
  const ratio = disk.used_ratio ?? 0
  const tone = usageTone(ratio)
  const text = t('system.disks.usage', {
    percent: formatPercent(ratio),
    avail: formatBytes(disk.avail_bytes),
    total: formatBytes(disk.total_bytes),
  })
  return (
    <li className="flex flex-col gap-1.5 border-b py-2.5">
      <div className="flex flex-wrap items-center gap-2">
        <span className="font-mono text-row">{disk.name}</span>
        {tone !== 'ok' ? (
          <ToneBadge tone={tone}>{tone === 'late' ? t('system.severity.critical') : t('system.severity.warning')}</ToneBadge>
        ) : null}
        <span className="tabular ml-auto text-xs text-muted-foreground">{text}</span>
      </div>
      <UsageBar ratio={ratio} tone={tone === 'ok' ? 'accent' : tone} label={t('system.disks.label', { name: disk.name })} valueText={text} />
    </li>
  )
}

function Disks({ health, live }: { health: SystemHealth; live: boolean }) {
  const { t } = useTranslation()
  return (
    <SettingsCard title={t('system.disks.title')} subtitle={t('system.disks.hint')}>
      {health.disks.length === 0 ? (
        live ? (
          <p className="text-row text-muted-foreground">{t('system.disks.empty')}</p>
        ) : (
          <NoSentinel />
        )
      ) : (
        <ul className="flex flex-col border-t">
          {health.disks.map((disk) => (
            <DiskRow key={disk.name} disk={disk} />
          ))}
        </ul>
      )}
    </SettingsCard>
  )
}

function Database({ health }: { health: SystemHealth }) {
  const { t } = useTranslation()
  const db = health.database
  const ratio = db.max_connections > 0 ? db.connections / db.max_connections : 0
  const tone = usageTone(ratio)
  const text = t('system.database.connectionsValue', {
    used: formatNumber(db.connections),
    max: formatNumber(db.max_connections),
  })
  return (
    <SettingsCard title={t('system.database.title')}>
      <dl className="grid gap-3 sm:grid-cols-2">
        <div className="flex flex-col gap-0.5">
          <dt className="text-xs text-muted-foreground">{t('system.database.size')}</dt>
          <dd className="tabular text-metric font-medium">{formatBytes(db.size_bytes)}</dd>
        </div>
        <div className="flex flex-col gap-1">
          <dt className="text-xs text-muted-foreground">{t('system.database.connections')}</dt>
          <dd className="flex flex-col gap-1.5">
            <span className="tabular text-row">{text}</span>
            <UsageBar ratio={ratio} tone={tone === 'ok' ? 'accent' : tone} label={t('system.database.connections')} valueText={text} />
          </dd>
        </div>
      </dl>
      <div className="flex flex-col gap-1.5">
        <h3 className="text-xs font-medium text-muted-foreground">{t('system.database.slots')}</h3>
        {db.slots.length === 0 ? (
          <p className="text-row text-muted-foreground">{t('system.database.noSlots')}</p>
        ) : (
          <ul className="flex flex-col border-t">
            {db.slots.map((slot) => {
              const lost = slot.wal_status === 'lost'
              return (
                <li key={slot.name} className="flex flex-wrap items-center gap-x-3 gap-y-1 border-b py-2 text-xs">
                  <ToneBadge tone={lost ? 'late' : slot.active ? 'ok' : 'warn'}>
                    {lost
                      ? t('system.database.slotLost')
                      : slot.active
                        ? t('system.database.slotActive')
                        : t('system.database.slotInactive')}
                  </ToneBadge>
                  <span className="font-mono text-row">{slot.name}</span>
                  <span className="text-muted-foreground">
                    {[slot.type, slot.wal_status].filter(Boolean).join(' · ')}
                  </span>
                  <span className="tabular ml-auto text-muted-foreground">
                    {t('system.database.retained', { size: formatBytes(slot.retained_bytes) })}
                  </span>
                </li>
              )
            })}
          </ul>
        )}
      </div>
    </SettingsCard>
  )
}

function QueueStrip({ health }: { health: SystemHealth }) {
  const { t } = useTranslation()
  const q = health.queues
  return (
    <SettingsCard title={t('system.queues.title')}>
      <MetricStrip
        className="md:grid-cols-3 xl:grid-cols-3"
        metrics={[
          {
            label: t('system.queues.push'),
            value: formatNumber(q.push.queued),
            caption: q.push.oldest_at
              ? t('system.queues.oldest', { time: stamp(q.push.oldest_at) })
              : t('system.queues.empty'),
          },
          {
            label: t('system.queues.storage'),
            value: formatNumber(q.storage_cleanup.pending),
            tone: q.storage_cleanup.failing > 0 ? 'warn' : undefined,
            caption: t('system.queues.failing', { count: q.storage_cleanup.failing, value: formatNumber(q.storage_cleanup.failing) }),
          },
          {
            label: t('system.queues.alerts'),
            value: formatNumber(q.alerts.pending),
            tone: q.alerts.failed_24h > 0 ? 'warn' : undefined,
            caption: t('system.queues.failed24h', { value: formatNumber(q.alerts.failed_24h) }),
          },
        ]}
      />
    </SettingsCard>
  )
}

const cronTones: Record<string, 'ok' | 'late' | 'warn' | 'neutral'> = {
  succeeded: 'ok',
  failed: 'late',
  running: 'warn',
  starting: 'warn',
}

function Cron({ health }: { health: SystemHealth }) {
  const { t } = useTranslation()
  if (health.cron.length === 0) return null
  return (
    <SettingsCard title={t('system.cron.title')}>
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>{t('system.cron.job')}</TableHead>
            <TableHead>{t('system.cron.schedule')}</TableHead>
            <TableHead>{t('system.cron.status')}</TableHead>
            <TableHead>{t('system.cron.lastRun')}</TableHead>
            <TableHead>{t('system.cron.message')}</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {health.cron.map((job) => (
            <TableRow key={job.job}>
              <TableCell className="font-mono text-xs">{job.job}</TableCell>
              <TableCell className="font-mono text-xs text-muted-foreground">{job.schedule}</TableCell>
              <TableCell>
                {!job.active ? (
                  <ToneBadge tone="neutral">{t('system.cron.inactive')}</ToneBadge>
                ) : job.last_status ? (
                  <ToneBadge tone={cronTones[job.last_status] ?? 'neutral'}>
                    {t(`system.cron.states.${job.last_status as 'succeeded'}`, { defaultValue: job.last_status })}
                  </ToneBadge>
                ) : (
                  <span className="text-xs text-muted-foreground">{t('system.cron.never')}</span>
                )}
              </TableCell>
              <TableCell className="tabular text-xs text-muted-foreground">
                {job.last_start ? stamp(job.last_start) : '–'}
              </TableCell>
              <TableCell className="max-w-80 truncate text-xs text-muted-foreground" title={job.last_message ?? undefined}>
                {job.last_message ?? '–'}
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </SettingsCard>
  )
}

function Recent({ health }: { health: SystemHealth }) {
  const { t } = useTranslation()
  return (
    <SettingsCard title={t('system.alerts.recentTitle')}>
      {health.alerts.recent.length === 0 ? (
        <p className="text-row text-muted-foreground">{t('system.alerts.noneRecent')}</p>
      ) : (
        <ul className="flex flex-col border-t">
          {health.alerts.recent.map((alert) => (
            <li key={alert.id} className="flex flex-col gap-1 border-b py-2 sm:flex-row sm:items-center sm:gap-3">
              <SeverityBadge severity={alert.severity} />
              <span className="min-w-0 flex-1 text-row break-words">{alert.title}</span>
              <span className="tabular text-xs text-muted-foreground">
                {t('system.alerts.resolvedMeta', {
                  opened: stamp(alert.opened_at),
                  resolved: stamp(alert.resolved_at),
                  duration: durationLabel(durationMs(alert.opened_at, alert.resolved_at)),
                })}
              </span>
            </li>
          ))}
        </ul>
      )}
    </SettingsCard>
  )
}

export function StatusTab() {
  const health = useSystemHealth()
  return (
    <QueryContent query={health}>
      {(data) => {
        const live = sentinelLive(data)
        return (
          <div className="flex flex-col gap-5">
            <Banner health={data} />
            <Problems health={data} />
            <OpenAlerts health={data} />
            <div className="grid gap-5 lg:grid-cols-2">
              <Probes health={data} live={live} />
              <Disks health={data} live={live} />
            </div>
            <Services health={data} />
            <Database health={data} />
            <QueueStrip health={data} />
            <Cron health={data} />
            <Recent health={data} />
          </div>
        )
      }}
    </QueryContent>
  )
}
