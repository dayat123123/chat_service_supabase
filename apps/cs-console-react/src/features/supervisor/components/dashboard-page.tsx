import {
  AlarmClockIcon,
  CheckCheckIcon,
  ChevronRightIcon,
  HeadsetIcon,
  InboxIcon,
  RefreshCwIcon,
  ShieldAlertIcon,
  TimerIcon,
  UserXIcon,
  UsersIcon,
  WifiOffIcon,
} from 'lucide-react'
import { useTranslation } from 'react-i18next'

import { PriorityBadge, StatusDot, WaitBadge } from '@/components/badges'
import { StatTile } from '@/components/stat-tile'
import { ErrorState } from '@/components/states'
import { Button } from '@/components/ui/button'
import { Tooltip } from '@/components/ui/menu'
import { Separator, Skeleton } from '@/components/ui/primitives'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { useAgent } from '@/features/auth/hooks'
import { useOpenTicket, useTicketLists, useTopicName } from '@/features/tickets/hooks'
import { customerName, ticketFlags, type Ticket } from '@/features/tickets/types'
import { useNow } from '@/hooks/use-now'
import { waitTone } from '@/lib/sla'
import { clock, formatNumber, minutesSince, stamp, waitLabel } from '@/lib/time'
import { cn } from '@/lib/utils'

import { useSupervisorOverview } from '../hooks'
import type { AgentLoad, SupervisorOverview } from '../types'
import { QueueChart } from './queue-chart'

const ATTENTION_LIMIT = 8

const accents = {
  late: { border: 'border-sla-late/50', icon: 'text-sla-late', pill: 'bg-sla-late/12 text-sla-late' },
  flag: {
    border: 'border-flag-complaint/50',
    icon: 'text-flag-complaint',
    pill: 'bg-flag-complaint/12 text-flag-complaint',
  },
  warn: { border: 'border-sla-warn/50', icon: 'text-sla-warn', pill: 'bg-sla-warn/14 text-sla-warn' },
}

function AttentionRow({
  ticket,
  showOwner,
  urgent,
  now,
  onOpen,
}: {
  ticket: Ticket
  showOwner: boolean
  urgent: boolean
  now: Date
  onOpen: (ticketId: string) => void
}) {
  const { t } = useTranslation()
  const agent = useAgent()
  const topicName = useTopicName()
  const since = showOwner ? (ticket.last_customer_message_at ?? ticket.claimed_at) : ticket.queued_at
  const meta = [
    topicName(ticket.topic),
    showOwner && ticket.owner ? t('dashboard.ownerOffline', { name: ticket.owner.display_name }) : null,
    ...ticket.flags.map((flag) =>
      (ticketFlags as readonly string[]).includes(flag) ? t(`tickets.flags.${flag as 'fraud'}`) : flag,
    ),
  ].filter(Boolean)
  return (
    <button
      type="button"
      onClick={() => onOpen(ticket.id)}
      className="flex w-full items-center gap-2.5 px-4 py-2 text-left transition-colors outline-none hover:bg-muted/50 focus-visible:bg-muted/60 focus-visible:ring-[3px] focus-visible:ring-ring/40 focus-visible:ring-inset compact:py-1.5"
    >
      <PriorityBadge priority={ticket.priority} />
      <span className="min-w-0 flex-1">
        <span className="block truncate text-sm font-medium">
          #{ticket.ticket_number} · {customerName(ticket)}
        </span>
        <span className="block truncate text-xs text-muted-foreground">{meta.join(' · ')}</span>
      </span>
      {since ? (
        <WaitBadge
          minutes={minutesSince(since, now)}
          warn={agent.settings.wait_warn_minutes}
          late={agent.settings.wait_late_minutes}
          urgent={urgent}
        />
      ) : null}
      <ChevronRightIcon className="size-4 shrink-0 text-muted-foreground" aria-hidden="true" />
    </button>
  )
}

function AttentionPanel({
  title,
  empty,
  icon: Icon,
  accent,
  tickets,
  now,
  onOpen,
  showOwner = false,
  urgent = false,
}: {
  title: string
  empty: string
  icon: React.ComponentType<{ className?: string }>
  accent: keyof typeof accents
  tickets: Ticket[]
  now: Date
  onOpen: (ticketId: string) => void
  showOwner?: boolean
  urgent?: boolean
}) {
  const { t } = useTranslation()
  const style = accents[accent]
  const busy = tickets.length > 0
  return (
    <section className={cn('flex flex-col rounded-xl border bg-card shadow-xs', busy && style.border)}>
      <header className="flex items-center gap-2 px-4 pt-3 pb-2.5">
        <Icon
          className={cn('size-4 shrink-0', busy ? style.icon : 'text-muted-foreground')}
          aria-hidden="true"
        />
        <h3 className="flex-1 text-sm font-semibold">{title}</h3>
        {busy ? (
          <span
            className={cn(
              'tabular inline-flex h-5 min-w-5 items-center justify-center rounded-full px-1.5 text-xs font-bold',
              style.pill,
            )}
          >
            {tickets.length}
          </span>
        ) : null}
      </header>
      <Separator />
      {busy ? (
        <ul className="flex flex-col py-1">
          {tickets.slice(0, ATTENTION_LIMIT).map((ticket) => (
            <li key={ticket.id}>
              <AttentionRow ticket={ticket} showOwner={showOwner} urgent={urgent} now={now} onOpen={onOpen} />
            </li>
          ))}
        </ul>
      ) : (
        <p className="p-4 text-sm text-muted-foreground">{empty}</p>
      )}
      {tickets.length > ATTENTION_LIMIT ? (
        <p className="px-4 pb-3 text-xs text-muted-foreground">
          {t('dashboard.moreTickets', { count: tickets.length - ATTENTION_LIMIT })}
        </p>
      ) : null}
    </section>
  )
}

function LoadMeter({ active, max }: { active: number; max: number }) {
  const { t } = useTranslation()
  const full = active >= max
  return (
    <span className="inline-flex items-center gap-2">
      <span
        role="meter"
        aria-valuemin={0}
        aria-valuemax={max}
        aria-valuenow={active}
        aria-label={t('dashboard.colActiveTickets')}
        className="relative h-2 w-20 overflow-hidden rounded-full bg-chart-track"
      >
        <span
          className={cn('absolute inset-y-0 left-0 rounded-full', full ? 'bg-sla-late' : 'bg-chart-1')}
          style={{ width: `${max > 0 ? Math.min(100, (active / max) * 100) : 0}%` }}
        />
      </span>
      <span className="tabular">
        {active}/{max}
      </span>
      {full ? <span className="text-xs font-medium text-sla-late">{t('dashboard.full')}</span> : null}
    </span>
  )
}

function AgentsTable({ agents }: { agents: AgentLoad[] }) {
  const { t } = useTranslation()
  if (agents.length === 0) {
    return (
      <p className="rounded-xl border bg-card p-4 text-sm text-muted-foreground">{t('dashboard.noAgents')}</p>
    )
  }
  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead>{t('dashboard.colAgent')}</TableHead>
          <TableHead>{t('dashboard.colStatus')}</TableHead>
          <TableHead>{t('dashboard.colActiveTickets')}</TableHead>
          <TableHead className="text-right">{t('dashboard.colResolvedToday')}</TableHead>
          <TableHead>{t('dashboard.colStatusSince')}</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {agents.map((agent) => (
          <TableRow key={agent.id}>
            <TableCell className="font-medium">
              {agent.display_name}
              {agent.agent_code ? <span className="text-muted-foreground"> ({agent.agent_code})</span> : null}
            </TableCell>
            <TableCell>
              <span className="inline-flex items-center gap-1.5">
                <StatusDot status={agent.status} />
                {t(`presence.${agent.status}`)}
                {agent.status !== 'offline' && !agent.connected ? (
                  <Tooltip content={t('dashboard.connectionLost')}>
                    <span
                      className="inline-flex text-destructive"
                      role="img"
                      aria-label={t('dashboard.connectionLost')}
                    >
                      <WifiOffIcon className="size-3.5" />
                    </span>
                  </Tooltip>
                ) : null}
              </span>
            </TableCell>
            <TableCell>
              <LoadMeter active={agent.active_tickets} max={agent.max_active_tickets} />
            </TableCell>
            <TableCell className="tabular text-right">{formatNumber(agent.resolved_today)}</TableCell>
            <TableCell className="text-muted-foreground">
              {agent.status_changed_at ? stamp(agent.status_changed_at) : '–'}
            </TableCell>
          </TableRow>
        ))}
      </TableBody>
    </Table>
  )
}

function Dashboard({
  overview,
  stale,
  refreshing,
  onRefresh,
}: {
  overview: SupervisorOverview
  stale: boolean
  refreshing: boolean
  onRefresh: () => void
}) {
  const { t } = useTranslation()
  const agent = useAgent()
  const now = useNow(30_000)
  const openTicket = useOpenTicket()
  const lists = useTicketLists(true)
  const oldest = overview.oldest_open_at
  const wait = minutesSince(oldest, now)
  const online = overview.agents.filter((item) => item.status === 'online').length
  const limits = overview.thresholds
  return (
    <div className="h-full scrollbar-thin overflow-y-auto">
      <div className="mx-auto flex max-w-[1440px] flex-col gap-6 px-4 py-5 lg:px-6">
        <header className="flex flex-wrap items-center gap-x-3 gap-y-1">
          <h1 className="flex-1 text-xl font-semibold">{t('dashboard.title')}</h1>
          {stale ? (
            <span role="status" className="text-xs font-medium text-destructive">
              {t('dashboard.stale')}
            </span>
          ) : null}
          <span className="text-xs text-muted-foreground">
            {t('dashboard.updatedAt', { time: clock(overview.generated_at) })}
          </span>
          <Button
            variant="outline"
            size="icon-sm"
            aria-label={t('app.refresh')}
            disabled={refreshing}
            onClick={onRefresh}
          >
            <RefreshCwIcon className={cn(refreshing && 'animate-spin')} />
          </Button>
        </header>
        <section className="grid grid-cols-2 gap-3 md:grid-cols-3 xl:grid-cols-5">
          <StatTile
            label={t('dashboard.statOpen')}
            value={formatNumber(overview.open_count)}
            icon={InboxIcon}
          />
          <StatTile
            label={t('dashboard.statLongestWait')}
            value={oldest ? waitLabel(wait) : '–'}
            caption={oldest ? t('dashboard.since', { time: stamp(oldest, now) }) : t('dashboard.statNoQueue')}
            icon={TimerIcon}
            tone={
              oldest
                ? waitTone(wait, agent.settings.wait_warn_minutes, agent.settings.wait_late_minutes)
                : 'neutral'
            }
          />
          <StatTile
            label={t('dashboard.statActive')}
            value={formatNumber(overview.active_count)}
            icon={HeadsetIcon}
          />
          <StatTile
            label={t('dashboard.statResolvedToday')}
            value={formatNumber(overview.resolved_today)}
            icon={CheckCheckIcon}
          />
          <StatTile
            label={t('dashboard.statAgentsOnline')}
            value={`${online}/${overview.agents.length}`}
            icon={UsersIcon}
          />
        </section>
        <section className="flex flex-col gap-3" aria-labelledby="attention-title">
          <h2 id="attention-title" className="text-sm font-semibold">
            {t('dashboard.needsAttention')}
          </h2>
          <div className="grid items-start gap-3 lg:grid-cols-3">
            <AttentionPanel
              title={t('dashboard.overdueTitle', {
                minutes: limits.unclaimed_minutes,
                p1: limits.p1_unclaimed_minutes,
              })}
              empty={t('dashboard.overdueEmpty')}
              icon={AlarmClockIcon}
              accent="late"
              tickets={overview.overdue}
              now={now}
              onOpen={openTicket}
              urgent
            />
            <AttentionPanel
              title={t('dashboard.flaggedTitle')}
              empty={t('dashboard.flaggedEmpty')}
              icon={ShieldAlertIcon}
              accent="flag"
              tickets={overview.flagged_open}
              now={now}
              onOpen={openTicket}
            />
            <AttentionPanel
              title={t('dashboard.offlineOwnedTitle')}
              empty={t('dashboard.offlineOwnedEmpty')}
              icon={UserXIcon}
              accent="warn"
              tickets={overview.offline_owned}
              now={now}
              onOpen={openTicket}
              showOwner
            />
          </div>
        </section>
        <div className="grid items-start gap-6 xl:grid-cols-3">
          <QueueChart open={lists.data?.open} total={overview.open_count} />
          <section className="flex flex-col gap-3 xl:col-span-2" aria-labelledby="agents-title">
            <h2 id="agents-title" className="text-sm font-semibold">
              {t('dashboard.agentsToday')}
            </h2>
            <AgentsTable agents={overview.agents} />
          </section>
        </div>
      </div>
    </div>
  )
}

export function DashboardPage() {
  const overview = useSupervisorOverview(true)
  if (overview.data) {
    return (
      <Dashboard
        overview={overview.data}
        stale={overview.isError}
        refreshing={overview.isFetching}
        onRefresh={() => void overview.refetch()}
      />
    )
  }
  if (overview.isError)
    return <ErrorState className="h-full" error={overview.error} onRetry={() => void overview.refetch()} />
  return (
    <div className="mx-auto flex max-w-[1440px] flex-col gap-6 px-4 py-5 lg:px-6" aria-busy="true">
      <Skeleton className="h-7 w-64" />
      <div className="grid grid-cols-2 gap-3 md:grid-cols-3 xl:grid-cols-5">
        {Array.from({ length: 5 }, (_, i) => (
          <Skeleton key={i} className="h-[86px] rounded-xl" />
        ))}
      </div>
      <div className="grid gap-3 lg:grid-cols-3">
        {Array.from({ length: 3 }, (_, i) => (
          <Skeleton key={i} className="h-36 rounded-xl" />
        ))}
      </div>
    </div>
  )
}
