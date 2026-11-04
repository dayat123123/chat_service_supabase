import { TriangleAlertIcon } from 'lucide-react'
import { useTranslation } from 'react-i18next'

import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { QueryContent, SettingsCard } from '@/features/settings/components/settings-ui'
import { useNow } from '@/hooks/use-now'
import { durationLabel, formatNumber, formatPercent, stamp } from '@/lib/time'
import { cn } from '@/lib/utils'

import { useHealerOverview } from '../hooks'
import { durationMs, healerOutcome, healerStatus, healerTone, outcomeTone } from '../logic'
import { healerReasons, type HealerEvent, type HealerOverview, type HealerState } from '../types'
import { ToneBadge } from './system-ui'

function Fact({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="flex min-w-0 flex-col gap-1 bg-background px-4 py-3">
      <dt className="text-xs text-muted-foreground">{label}</dt>
      <dd className="flex min-w-0 flex-col gap-1 text-row">{children}</dd>
    </div>
  )
}

function Muted({ children, className }: { children: React.ReactNode; className?: string }) {
  return <span className={cn('text-xs break-words text-muted-foreground', className)}>{children}</span>
}

function useReason() {
  const { t } = useTranslation()
  return (reason: string) =>
    (healerReasons as readonly string[]).includes(reason)
      ? t(`system.healer.reasons.${reason as (typeof healerReasons)[number]}`)
      : reason || '–'
}

function Summary({ overview }: { overview: HealerOverview }) {
  const { t } = useTranslation()
  const state = overview.state
  const status = healerStatus(state)
  const rules = state?.rules ?? {}
  const problem = state?.read_error ?? state?.error
  return (
    <dl className="grid grid-cols-1 gap-px overflow-hidden rounded-lg border bg-border sm:grid-cols-2 xl:grid-cols-4">
      <Fact label={t('system.healer.facts.status')}>
        <ToneBadge tone={healerTone(status)} className="self-start">
          {t(`system.healer.states.${status}`)}
        </ToneBadge>
        {status !== 'active' ? <Muted>{t(`system.healer.stateHints.${status}`)}</Muted> : null}
        {problem ? <Muted className="text-destructive">{problem}</Muted> : null}
        {state?.version ? (
          <Muted>
            {t('system.healer.version', { version: state.version, project: state.project ?? '–' })}
          </Muted>
        ) : null}
      </Fact>
      <Fact label={t('system.healer.facts.checked')}>
        <span className="tabular">{state?.checked_at ? stamp(state.checked_at) : '–'}</span>
      </Fact>
      <Fact label={t('system.healer.facts.watched')}>
        <span className="tabular">
          {t('system.healer.watchedCount', {
            count: state?.watched ?? 0,
            value: formatNumber(state?.watched ?? 0),
          })}
        </span>
      </Fact>
      <Fact label={t('system.healer.facts.restarts')}>
        <span className="tabular">
          {t('system.healer.restartCount', {
            restarts: formatNumber(overview.counts.restarts_24h),
            failed: formatNumber(overview.counts.failed_24h),
          })}
        </span>
      </Fact>
      {rules.unhealthy_seconds !== undefined ? (
        <div className="bg-background px-4 py-3 sm:col-span-2 xl:col-span-4">
          <dt className="text-xs text-muted-foreground">{t('system.healer.facts.rules')}</dt>
          <dd className="text-xs text-muted-foreground">
            {t('system.healer.rulesText', {
              unhealthy: rules.unhealthy_seconds,
              uptime: rules.min_uptime_seconds ?? '–',
              max: rules.max_restarts_per_hour ?? '–',
              cooldown: rules.global_cooldown_seconds ?? '–',
              fraction: formatPercent(rules.systemic_fraction ?? 0),
            })}
          </dd>
        </div>
      ) : null}
    </dl>
  )
}

const skipKeys = { db_unhealthy: true, pgbouncer_unhealthy: true, systemic: true } as const

function Skip({ state }: { state: HealerState }) {
  const { t } = useTranslation()
  const skip = state.skip
  if (!skip || !state.live) return null
  const reason = skip.reason as keyof typeof skipKeys
  return (
    <div role="status" className="flex gap-3 rounded-lg border border-warning/40 p-4">
      <TriangleAlertIcon className="size-5 shrink-0 text-warning" aria-hidden="true" />
      <div className="min-w-0">
        <p className="text-row font-medium">{t('system.healer.skipTitle')}</p>
        <p className="text-xs text-muted-foreground">
          {reason in skipKeys ? t(`system.healer.skipReason.${reason}`) : skip.reason}
        </p>
        <p className="text-xs text-muted-foreground">
          {t('system.healer.skipServices', {
            time: stamp(skip.since),
            services: (skip.services ?? []).join(', ') || '–',
          })}
        </p>
      </div>
    </div>
  )
}

function Unhealthy({ state }: { state: HealerState }) {
  const { t } = useTranslation()
  const now = useNow(15_000)
  const list = state.unhealthy ?? []
  if (!state.live || list.length === 0) return null
  return (
    <SettingsCard title={t('system.healer.unhealthyTitle')}>
      <ul className="flex flex-col border-t">
        {list.map((item) => (
          <li key={item.container} className="flex flex-wrap items-center gap-x-3 gap-y-1 border-b py-2">
            <ToneBadge tone="warn">{t('system.healer.reasons.unhealthy')}</ToneBadge>
            <span className="text-row font-medium">{item.service}</span>
            <span className="font-mono text-xs text-muted-foreground">{item.container}</span>
            <span className="tabular ml-auto text-xs text-muted-foreground">
              {t('system.healer.unhealthySince', {
                time: stamp(item.since),
                duration: durationLabel(durationMs(item.since, now.toISOString())),
              })}
            </span>
          </li>
        ))}
      </ul>
    </SettingsCard>
  )
}

function GaveUp({ state }: { state: HealerState | null }) {
  const { t } = useTranslation()
  const list = state?.live ? (state.gave_up ?? []) : []
  return (
    <SettingsCard title={t('system.healer.gaveUpTitle')} subtitle={t('system.healer.gaveUpHint')}>
      {list.length === 0 ? (
        <p className="text-row text-muted-foreground">{t('system.healer.gaveUpEmpty')}</p>
      ) : (
        <ul className="flex flex-col border-t">
          {list.map((item) => (
            <li key={item.service} className="flex flex-wrap items-center gap-x-3 gap-y-1 border-b py-2.5">
              <ToneBadge tone="late">{t('system.healer.outcomes.gaveUp')}</ToneBadge>
              <span className="text-row font-medium">{item.label ?? item.service}</span>
              <span className="font-mono text-xs text-muted-foreground">{item.service}</span>
              <span className="tabular ml-auto text-xs text-muted-foreground">
                {t('system.healer.gaveUpRow', {
                  restarts: formatNumber(item.restarts),
                  time: stamp(item.until),
                })}
              </span>
            </li>
          ))}
        </ul>
      )}
    </SettingsCard>
  )
}

function EventRow({ event }: { event: HealerEvent }) {
  const { t } = useTranslation()
  const reason = useReason()
  const outcome = healerOutcome(event)
  return (
    <TableRow>
      <TableCell className="tabular text-xs whitespace-nowrap text-muted-foreground">
        {stamp(event.at)}
      </TableCell>
      <TableCell>
        {event.service ? (
          <span className="flex flex-col">
            <span className="text-row">{event.label || event.service}</span>
            <span className="font-mono text-xs text-muted-foreground">
              {event.container || event.service}
            </span>
          </span>
        ) : (
          <Muted>{t('system.healer.allServices')}</Muted>
        )}
      </TableCell>
      <TableCell className="text-xs">{reason(event.reason)}</TableCell>
      <TableCell>
        <ToneBadge tone={outcomeTone(outcome)}>{t(`system.healer.outcomes.${outcome}`)}</ToneBadge>
      </TableCell>
      <TableCell className="max-w-96 text-xs">
        {event.error ? <span className="break-words text-destructive">{event.error}</span> : null}
        {event.detail ? (
          <span className="block break-words text-muted-foreground">{event.detail}</span>
        ) : null}
      </TableCell>
    </TableRow>
  )
}

function Events({ events }: { events: HealerEvent[] }) {
  const { t } = useTranslation()
  return (
    <SettingsCard title={t('system.healer.eventsTitle')} subtitle={t('system.healer.eventsHint')}>
      {events.length === 0 ? (
        <p className="text-row text-muted-foreground">{t('system.healer.eventsEmpty')}</p>
      ) : (
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>{t('system.healer.columns.time')}</TableHead>
              <TableHead>{t('system.healer.columns.service')}</TableHead>
              <TableHead>{t('system.healer.columns.reason')}</TableHead>
              <TableHead>{t('system.healer.columns.result')}</TableHead>
              <TableHead>{t('system.healer.columns.detail')}</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {events.map((event) => (
              <EventRow key={event.id} event={event} />
            ))}
          </TableBody>
        </Table>
      )}
    </SettingsCard>
  )
}

export function HealerTab() {
  const { t } = useTranslation()
  const overview = useHealerOverview()
  return (
    <QueryContent query={overview}>
      {(data) => (
        <div className="flex flex-col gap-5">
          <div>
            <h2 className="text-panel font-semibold">{t('system.healer.title')}</h2>
            <p className="max-w-3xl text-xs text-muted-foreground">{t('system.healer.subtitle')}</p>
          </div>
          <Summary overview={data} />
          {data.state ? <Skip state={data.state} /> : null}
          {data.state ? <Unhealthy state={data.state} /> : null}
          <GaveUp state={data.state} />
          <Events events={data.events} />
          <p className="text-xs text-muted-foreground">{t('system.healer.disableHint')}</p>
        </div>
      )}
    </QueryContent>
  )
}
