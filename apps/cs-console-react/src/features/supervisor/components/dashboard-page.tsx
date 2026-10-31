import { ChevronRightIcon, RefreshCwIcon, WifiOffIcon } from 'lucide-react'
import { useTranslation } from 'react-i18next'

import { PriorityText, StatusDot, WaitTime } from '@/components/badges'
import { MetricStrip } from '@/components/metric-strip'
import { ErrorState } from '@/components/states'
import { Button } from '@/components/ui/button'
import { Tooltip } from '@/components/ui/menu'
import { Skeleton } from '@/components/ui/primitives'
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
      className="flex w-full items-center gap-3 border-b px-4 py-(--row-py) text-left transition-colors outline-none last:border-b-0 hover:bg-muted focus-visible:ring-2 focus-visible:ring-ring/50 focus-visible:ring-inset"
    >
      <PriorityText priority={ticket.priority} className="w-5 text-xs" />
      <span className="min-w-0 flex-1">
        <span className="block truncate text-row font-medium">
          {customerName(ticket)} <span className="font-mono text-xs font-normal">{ticket.ticket_number}</span>
        </span>
        <span className="block truncate text-xs text-muted-foreground">{meta.join(' · ')}</span>
      </span>
      {since ? (
        <WaitTime
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

function AttentionList({
  title,
  empty,
  tickets,
  now,
  onOpen,
  showOwner = false,
  urgent = false,
}: {
  title: string
  empty: string
  tickets: Ticket[]
  now: Date
  onOpen: (ticketId: string) => void
  showOwner?: boolean
  urgent?: boolean
}) {
  const { t } = useTranslation()
  return (
    <section className="flex min-w-0 flex-col bg-background">
      <header className="flex items-center gap-2 border-b px-4 py-2.5">
        <h3 className="min-w-0 flex-1 truncate text-row font-medium">{title}</h3>
        <span
          className={cn(
            'tabular text-row',
            tickets.length > 0 ? 'font-medium text-danger' : 'text-muted-foreground',
          )}
        >
          {tickets.length}
        </span>
      </header>
      {tickets.length > 0 ? (
        <div className="flex flex-col">
          {tickets.slice(0, ATTENTION_LIMIT).map((ticket) => (
            <AttentionRow
              key={ticket.id}
              ticket={ticket}
              showOwner={showOwner}
              urgent={urgent}
              now={now}
              onOpen={onOpen}
            />
          ))}
        </div>
      ) : (
        <p className="px-4 py-3 text-row text-muted-foreground">{empty}</p>
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
        className="relative h-1.5 w-16 overflow-hidden rounded-full bg-muted"
      >
        <span
          className={cn(
            'absolute inset-y-0 left-0 rounded-full',
            full ? 'bg-signal-danger' : 'bg-foreground',
          )}
          style={{ width: `${max > 0 ? Math.min(100, (active / max) * 100) : 0}%` }}
        />
      </span>
      <span className="tabular">
        {active}/{max}
      </span>
      {full ? <span className="text-xs font-medium text-danger">{t('dashboard.full')}</span> : null}
    </span>
  )
}

function AgentsTable({ agents }: { agents: AgentLoad[] }) {
  const { t } = useTranslation()
  if (agents.length === 0) {
    return <p className="border-y py-3 text-row text-muted-foreground">{t('dashboard.noAgents')}</p>
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
              {agent.agent_code ? (
                <span className="font-normal text-muted-foreground"> ({agent.agent_code})</span>
              ) : null}
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
            <TableCell className="tabular text-muted-foreground">
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
    <div className="h-full overflow-y-auto">
      <div className="mx-auto flex max-w-[1440px] flex-col gap-6 px-4 py-5 lg:px-6">
        <header className="flex flex-wrap items-center gap-x-3 gap-y-1">
          <h1 className="flex-1 text-lg font-semibold">{t('dashboard.title')}</h1>
          {stale ? (
            <span role="status" className="text-xs text-destructive">
              {t('dashboard.stale')}
            </span>
          ) : null}
          <span className="tabular text-xs text-muted-foreground">
            {t('dashboard.updatedAt', { time: clock(overview.generated_at) })}
          </span>
          <Button
            variant="ghost"
            size="icon-sm"
            aria-label={t('app.refresh')}
            disabled={refreshing}
            onClick={onRefresh}
          >
            <RefreshCwIcon className={cn(refreshing && 'animate-spin')} />
          </Button>
        </header>
        <MetricStrip
          metrics={[
            { label: t('dashboard.statOpen'), value: formatNumber(overview.open_count) },
            {
              label: t('dashboard.statLongestWait'),
              value: oldest ? waitLabel(wait) : '–',
              caption: oldest
                ? t('dashboard.since', { time: stamp(oldest, now) })
                : t('dashboard.statNoQueue'),
              tone: oldest
                ? waitTone(wait, agent.settings.wait_warn_minutes, agent.settings.wait_late_minutes)
                : undefined,
            },
            { label: t('dashboard.statActive'), value: formatNumber(overview.active_count) },
            { label: t('dashboard.statResolvedToday'), value: formatNumber(overview.resolved_today) },
            { label: t('dashboard.statAgentsOnline'), value: `${online}/${overview.agents.length}` },
          ]}
        />
        <section className="flex flex-col gap-3" aria-labelledby="attention-title">
          <h2 id="attention-title" className="text-panel font-semibold">
            {t('dashboard.needsAttention')}
          </h2>
          <div className="grid items-start gap-px border-y bg-border lg:grid-cols-3">
            <AttentionList
              title={t('dashboard.overdueTitle', {
                minutes: limits.unclaimed_minutes,
                p1: limits.p1_unclaimed_minutes,
              })}
              empty={t('dashboard.overdueEmpty')}
              tickets={overview.overdue}
              now={now}
              onOpen={openTicket}
              urgent
            />
            <AttentionList
              title={t('dashboard.flaggedTitle')}
              empty={t('dashboard.flaggedEmpty')}
              tickets={overview.flagged_open}
              now={now}
              onOpen={openTicket}
            />
            <AttentionList
              title={t('dashboard.offlineOwnedTitle')}
              empty={t('dashboard.offlineOwnedEmpty')}
              tickets={overview.offline_owned}
              now={now}
              onOpen={openTicket}
              showOwner
            />
          </div>
        </section>
        <div className="grid items-start gap-8 xl:grid-cols-3">
          <QueueChart open={lists.data?.open} total={overview.open_count} />
          <section className="flex min-w-0 flex-col gap-3 xl:col-span-2" aria-labelledby="agents-title">
            <h2 id="agents-title" className="text-panel font-semibold">
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
      <Skeleton className="h-4 w-48" />
      <div className="grid grid-cols-2 gap-6 border-y py-4 md:grid-cols-3 xl:grid-cols-5">
        {Array.from({ length: 5 }, (_, i) => (
          <div key={i} className="flex flex-col gap-2">
            <Skeleton className="h-2 w-20" />
            <Skeleton className="h-4 w-12" />
          </div>
        ))}
      </div>
      <Skeleton className="h-2 w-2/3" />
    </div>
  )
}
