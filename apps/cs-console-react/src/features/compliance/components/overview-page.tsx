import { Link, useNavigate } from '@tanstack/react-router'
import { ChevronRightIcon, RefreshCwIcon, ShieldAlertIcon } from 'lucide-react'
import { useTranslation } from 'react-i18next'

import { MetricStrip } from '@/components/metric-strip'
import { ErrorState } from '@/components/states'
import { Button, buttonVariants } from '@/components/ui/button'
import { Skeleton } from '@/components/ui/primitives'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { customerName } from '@/features/tickets/types'
import { useNow } from '@/hooks/use-now'
import { clock, formatNumber, stamp } from '@/lib/time'
import { cn } from '@/lib/utils'

import { useComplianceOverview } from '../hooks'
import { finishedAt, onTimePercent } from '../logic'
import type { CaseRow, CaseState, ComplianceOverview, SecretAgent } from '../types'
import { CaseKindText, DeadlineText } from './case-badges'

const SECRET_ACTION = 'message.secret_request_blocked'

function CaseLine({
  row,
  meta,
  now,
}: {
  row: CaseRow
  meta: 'deadline' | 'created' | 'finished'
  now: Date
}) {
  const at = meta === 'finished' ? finishedAt(row) : row.created_at
  return (
    <Link
      to="/compliance/cases"
      search={{ case: row.id }}
      className="flex w-full items-center gap-3 border-b px-4 py-(--row-py) text-left transition-colors outline-none last:border-b-0 hover:bg-muted focus-visible:ring-2 focus-visible:ring-ring/50 focus-visible:ring-inset"
    >
      <span className="min-w-0 flex-1">
        <span className="block truncate text-row font-medium">
          {customerName(row)} <span className="font-mono text-xs font-normal">{row.ticket_number}</span>
        </span>
        <span className="flex min-w-0 items-center gap-2 truncate text-xs text-muted-foreground">
          <CaseKindText row={row} />
          {row.agent ? <span className="truncate">· {row.agent.display_name}</span> : null}
        </span>
      </span>
      {meta === 'deadline' ? (
        <DeadlineText deadline={row.deadline} className="shrink-0" />
      ) : (
        <span className="tabular shrink-0 text-xs text-muted-foreground">{at ? stamp(at, now) : '–'}</span>
      )}
      <ChevronRightIcon className="size-4 shrink-0 text-muted-foreground" aria-hidden="true" />
    </Link>
  )
}

function CaseList({
  title,
  empty,
  rows,
  total,
  meta,
  state,
  now,
}: {
  title: string
  empty: string
  rows: CaseRow[]
  total: number
  meta: 'deadline' | 'created' | 'finished'
  state: CaseState
  now: Date
}) {
  const { t } = useTranslation()
  return (
    <section className="flex min-w-0 flex-col bg-background">
      <header className="flex items-center gap-2 border-b px-4 py-2.5">
        <h3 className="min-w-0 flex-1 truncate text-row font-medium">{title}</h3>
        <span
          className={cn(
            'tabular text-row',
            total > 0 ? 'font-medium text-foreground' : 'text-muted-foreground',
          )}
        >
          {formatNumber(total)}
        </span>
      </header>
      {rows.length > 0 ? (
        <div className="flex flex-col">
          {rows.map((row) => (
            <CaseLine key={row.id} row={row} meta={meta} now={now} />
          ))}
        </div>
      ) : (
        <p className="px-4 py-3 text-row text-muted-foreground">{empty}</p>
      )}
      {total > rows.length ? (
        <Link
          to="/compliance/cases"
          search={{ state }}
          className="px-4 py-2.5 text-xs text-muted-foreground underline-offset-2 hover:text-foreground hover:underline"
        >
          {t('compliance.overview.seeAll')}
        </Link>
      ) : null}
    </section>
  )
}

function SecretAgents({ agents, now }: { agents: SecretAgent[]; now: Date }) {
  const { t } = useTranslation()
  if (agents.length === 0) {
    return (
      <p className="border-y py-3 text-row text-muted-foreground">
        {t('compliance.overview.secretAgentsEmpty')}
      </p>
    )
  }
  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead>{t('compliance.overview.colAgent')}</TableHead>
          <TableHead className="text-right">{t('compliance.overview.colAttempts')}</TableHead>
          <TableHead>{t('compliance.overview.colLastAttempt')}</TableHead>
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
            <TableCell className="tabular text-right font-medium text-danger">
              {formatNumber(agent.count)}
            </TableCell>
            <TableCell className="tabular text-muted-foreground">{stamp(agent.last_at, now)}</TableCell>
          </TableRow>
        ))}
      </TableBody>
    </Table>
  )
}

function Overview({
  overview,
  stale,
  refreshing,
  onRefresh,
}: {
  overview: ComplianceOverview
  stale: boolean
  refreshing: boolean
  onRefresh: () => void
}) {
  const { t } = useTranslation()
  const now = useNow(60_000)
  const navigate = useNavigate()
  const percent = onTimePercent(overview.on_time)
  return (
    <div className="h-full overflow-y-auto">
      <div className="mx-auto flex max-w-[1440px] flex-col gap-6 px-4 py-5 lg:px-6">
        <header className="flex flex-wrap items-center gap-x-3 gap-y-1">
          <h1 className="flex-1 text-lg font-semibold">{t('compliance.overview.title')}</h1>
          {stale ? (
            <span role="status" className="text-xs text-destructive">
              {t('compliance.overview.stale')}
            </span>
          ) : null}
          <span className="tabular text-xs text-muted-foreground">
            {t('compliance.overview.updatedAt', { time: clock(overview.generated_at) })}
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
        {overview.policies_unconfirmed > 0 ? (
          <div
            role="status"
            className="flex flex-wrap items-center gap-3 border-y border-l-2 border-l-signal-warning bg-subtle px-4 py-3"
          >
            <ShieldAlertIcon className="size-4 shrink-0 text-warning" aria-hidden="true" />
            <p className="min-w-0 flex-1 text-row">
              {t('compliance.overview.policyBanner', { count: overview.policies_unconfirmed })}
            </p>
            <Link to="/compliance/policy" className={buttonVariants({ variant: 'outline', size: 'sm' })}>
              {t('compliance.overview.openPolicy')}
            </Link>
          </div>
        ) : null}
        <MetricStrip
          metrics={[
            {
              label: t('compliance.overview.activeComplaints'),
              value: formatNumber(overview.active_complaints),
            },
            {
              label: t('compliance.overview.dueSoon'),
              value: formatNumber(overview.due_soon),
              tone: overview.due_soon > 0 ? 'warn' : undefined,
            },
            {
              label: t('compliance.overview.overdue'),
              value: formatNumber(overview.overdue),
              tone: overview.overdue > 0 ? 'late' : undefined,
            },
            {
              label: t('compliance.overview.onTime'),
              value: percent === null ? '–' : `${percent}%`,
              caption:
                overview.on_time.total === 0
                  ? t('compliance.overview.onTimeEmpty')
                  : t('compliance.overview.onTimeCaption', overview.on_time),
              tone: percent === null ? undefined : percent < 100 ? 'warn' : 'ok',
            },
            { label: t('compliance.overview.activeFraud'), value: formatNumber(overview.active_fraud) },
            {
              label: t('compliance.overview.unreviewed'),
              value: formatNumber(overview.unreviewed),
              caption: t('compliance.overview.unreviewedCaption'),
            },
          ]}
        />
        <section className="flex flex-col gap-3" aria-labelledby="compliance-attention-title">
          <h2 id="compliance-attention-title" className="text-panel font-semibold">
            {t('compliance.overview.needsAttention')}
          </h2>
          <div className="grid gap-px border-y bg-border lg:grid-cols-3">
            <CaseList
              title={t('compliance.overview.deadlinesTitle')}
              empty={t('compliance.overview.deadlinesEmpty')}
              rows={overview.deadlines}
              total={overview.active_complaints}
              meta="deadline"
              state="active"
              now={now}
            />
            <CaseList
              title={t('compliance.overview.fraudTitle')}
              empty={t('compliance.overview.fraudEmpty')}
              rows={overview.fraud}
              total={overview.active_fraud}
              meta="created"
              state="active"
              now={now}
            />
            <CaseList
              title={t('compliance.overview.toReviewTitle')}
              empty={t('compliance.overview.toReviewEmpty')}
              rows={overview.to_review}
              total={overview.unreviewed}
              meta="finished"
              state="unreviewed"
              now={now}
            />
          </div>
        </section>
        <section className="flex flex-col gap-3" aria-labelledby="compliance-security-title">
          <div className="flex flex-wrap items-center gap-x-3 gap-y-1">
            <h2 id="compliance-security-title" className="flex-1 text-panel font-semibold">
              {t('compliance.overview.securityTitle')}
            </h2>
            <Button
              variant="outline"
              size="sm"
              onClick={() => void navigate({ to: '/compliance/audit', search: { action: SECRET_ACTION } })}
            >
              {t('compliance.overview.openAudit')}
            </Button>
          </div>
          <div className="grid items-start gap-6 xl:grid-cols-3">
            <MetricStrip
              className="grid-cols-2 md:grid-cols-2 xl:grid-cols-1"
              metrics={[
                {
                  label: t('compliance.overview.fakeCsReports'),
                  value: formatNumber(overview.fake_cs_reports),
                  tone: overview.fake_cs_reports > 0 ? 'late' : undefined,
                },
                {
                  label: t('compliance.overview.secretBlocked'),
                  value: formatNumber(overview.secret_blocked),
                  caption: t('compliance.overview.secretBlockedHint'),
                  tone: overview.secret_blocked > 0 ? 'late' : undefined,
                },
              ]}
            />
            <div className="min-w-0 xl:col-span-2">
              <SecretAgents agents={overview.secret_agents} now={now} />
            </div>
          </div>
        </section>
      </div>
    </div>
  )
}

export function ComplianceOverviewPage() {
  const overview = useComplianceOverview(true)
  if (overview.data) {
    return (
      <Overview
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
      <div className="grid grid-cols-2 gap-6 border-y py-4 md:grid-cols-3 xl:grid-cols-6">
        {Array.from({ length: 6 }, (_, i) => (
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
