import { getRouteApi, Link } from '@tanstack/react-router'
import { DownloadIcon, LoaderCircleIcon, SearchIcon } from 'lucide-react'
import { useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { DateRangePicker } from '@/components/date-range-picker'
import { ErrorState, ListSkeleton } from '@/components/states'
import { Button } from '@/components/ui/button'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  ToggleGroup,
  ToggleGroupItem,
} from '@/components/ui/controls'
import { Input } from '@/components/ui/input'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { presetRange, rangeLabel } from '@/features/reports/range'
import type { DateRange, ReportPreset } from '@/features/reports/types'
import { useDebounced } from '@/hooks/use-now'
import { downloadText } from '@/lib/download'
import { errorText } from '@/lib/error-text'
import { format, formatNumber } from '@/lib/time'
import { cn } from '@/lib/utils'

import { complianceApi } from '../api'
import { useAuditLog } from '../hooks'
import { actionKey, auditCsv, detailsText } from '../logic'
import {
  AUDIT_EXPORT_LIMIT,
  MAX_AUDIT_DAYS,
  type AuditCursor,
  type AuditEntry,
  type AuditFilter,
} from '../types'

const route = getRouteApi('/compliance/audit')

const ALL = '__all__'

const shortStamp = (value: string) => format(value, 'd MMM yyyy, HH.mm')

function useActionLabel() {
  const { t } = useTranslation()
  return (action: string) => {
    const key = actionKey(action)
    return key ? t(key as 'compliance.actions.ticket_claim') : action
  }
}

function ActorCell({ entry }: { entry: AuditEntry }) {
  const { t } = useTranslation()
  const code = entry.actor?.agent_code ?? (entry.actor?.username ? `@${entry.actor.username}` : null)
  if (!entry.actor) {
    return (
      <span className="text-muted-foreground">
        {t(`compliance.actorTypes.${entry.actor_type as 'system'}`, { defaultValue: entry.actor_type })}
      </span>
    )
  }
  return (
    <span className="flex min-w-0 flex-col">
      <span className="truncate font-medium">{entry.actor.display_name ?? '–'}</span>
      <span className="truncate text-xs text-muted-foreground">
        {[
          code,
          entry.actor_roles
            .map((role) => t(`roles.${role as 'cs_agent'}`, { defaultValue: role }))
            .join(' · '),
        ]
          .filter(Boolean)
          .join(' · ')}
      </span>
    </span>
  )
}

function AuditTable({ rows }: { rows: AuditEntry[] }) {
  const { t } = useTranslation()
  const actionLabel = useActionLabel()
  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead>{t('compliance.audit.colTime')}</TableHead>
          <TableHead>{t('compliance.audit.colActor')}</TableHead>
          <TableHead>{t('compliance.audit.colAction')}</TableHead>
          <TableHead>{t('compliance.audit.colTicket')}</TableHead>
          <TableHead>{t('compliance.audit.colCustomer')}</TableHead>
          <TableHead>{t('compliance.audit.colDetails')}</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {rows.map((entry) => {
          const details = detailsText(entry.details, shortStamp)
          return (
            <TableRow key={entry.id} className="h-auto">
              <TableCell className="tabular py-2 align-top text-xs text-muted-foreground">
                {format(entry.created_at, 'd MMM yyyy, HH.mm.ss')}
              </TableCell>
              <TableCell className="max-w-56 py-2 align-top">
                <ActorCell entry={entry} />
              </TableCell>
              <TableCell className="py-2 align-top">
                <span className="flex flex-col">
                  <span
                    className={cn(
                      entry.action === 'message.secret_request_blocked' && 'font-medium text-danger',
                    )}
                  >
                    {actionLabel(entry.action)}
                  </span>
                  <span className="font-mono text-xs text-muted-foreground">{entry.action}</span>
                </span>
              </TableCell>
              <TableCell className="py-2 align-top">
                {entry.ticket ? (
                  entry.ticket.case ? (
                    <Link
                      to="/compliance/cases"
                      search={{ case: entry.ticket.id }}
                      className="font-mono text-xs underline underline-offset-2"
                      aria-label={t('compliance.cases.openCase', { number: entry.ticket.ticket_number })}
                    >
                      {entry.ticket.ticket_number}
                    </Link>
                  ) : (
                    <span className="font-mono text-xs">{entry.ticket.ticket_number}</span>
                  )
                ) : (
                  '–'
                )}
              </TableCell>
              <TableCell className="max-w-44 truncate py-2 align-top">
                {entry.customer?.display_name ?? entry.customer?.username ?? '–'}
              </TableCell>
              <TableCell className="max-w-80 py-2 align-top text-xs break-words whitespace-normal text-muted-foreground">
                {details || '–'}
              </TableCell>
            </TableRow>
          )
        })}
      </TableBody>
    </Table>
  )
}

export function ComplianceAuditPage() {
  const { t } = useTranslation()
  const search = route.useSearch()
  const actionLabel = useActionLabel()
  const [preset, setPreset] = useState<ReportPreset>('week')
  const [range, setRange] = useState<DateRange>(() => presetRange('week'))
  const [action, setAction] = useState<string | null>(search.action ?? null)
  const [query, setQuery] = useState('')
  const debounced = useDebounced(query.trim(), 300)
  const filter: AuditFilter = useMemo(() => ({ range, action, query: debounced }), [range, action, debounced])
  const audit = useAuditLog(filter)
  const [exporting, setExporting] = useState(false)
  const rows = useMemo(() => audit.data?.pages.flatMap((page) => page.rows) ?? [], [audit.data])
  const actions = audit.data?.pages[0]?.actions ?? []
  const options =
    action && !actions.some((item) => item.action === action) ? [{ action, count: 0 }, ...actions] : actions

  const choosePreset = (value: string) => {
    if (value !== 'today' && value !== 'week' && value !== 'month') return
    setPreset(value)
    setRange(presetRange(value))
  }

  const exportCsv = async () => {
    setExporting(true)
    try {
      const entries: AuditEntry[] = []
      let cursor: AuditCursor | null = null
      do {
        const page = await complianceApi.audit(filter, cursor, 200)
        entries.push(...page.rows)
        cursor = page.next
      } while (cursor && entries.length < AUDIT_EXPORT_LIMIT)
      const limited = entries.slice(0, AUDIT_EXPORT_LIMIT)
      const csv = auditCsv(limited, {
        header: (column) => t(`compliance.csv.${column}`),
        action: actionLabel,
      })
      downloadText(`jejak-audit-${range.from}-${range.to}.csv`, csv, 'text/csv;charset=utf-8')
      if (cursor) toast.info(t('compliance.audit.exportLimited', { count: AUDIT_EXPORT_LIMIT }))
    } catch (error) {
      toast.error(errorText(error))
    } finally {
      setExporting(false)
    }
  }

  return (
    <div className="h-full overflow-y-auto">
      <div className="mx-auto flex max-w-[1440px] flex-col gap-4 px-4 py-5 lg:px-6">
        <header className="flex flex-wrap items-end justify-between gap-3">
          <div className="min-w-0">
            <h1 className="text-lg font-semibold">{t('compliance.audit.title')}</h1>
            <p className="text-row text-muted-foreground">{t('compliance.audit.subtitle')}</p>
          </div>
          <Button
            size="sm"
            variant="outline"
            disabled={exporting || rows.length === 0}
            onClick={() => void exportCsv()}
          >
            {exporting ? <LoaderCircleIcon className="animate-spin" /> : <DownloadIcon />}
            {exporting ? t('compliance.audit.exporting') : t('compliance.audit.exportCsv')}
          </Button>
        </header>
        <div className="flex flex-wrap items-center gap-2">
          <ToggleGroup
            type="single"
            value={preset === 'custom' ? '' : preset}
            onValueChange={choosePreset}
            aria-label={t('reports.rangeLabel')}
          >
            <ToggleGroupItem value="today">{t('compliance.audit.periods.today')}</ToggleGroupItem>
            <ToggleGroupItem value="week">{t('compliance.audit.periods.week')}</ToggleGroupItem>
            <ToggleGroupItem value="month">{t('compliance.audit.periods.month')}</ToggleGroupItem>
          </ToggleGroup>
          <DateRangePicker
            range={range}
            active={preset === 'custom'}
            maxDays={MAX_AUDIT_DAYS}
            onApply={(next) => {
              setPreset('custom')
              setRange(next)
            }}
          />
          <Select value={action ?? ALL} onValueChange={(value) => setAction(value === ALL ? null : value)}>
            <SelectTrigger className="h-8 w-64" aria-label={t('compliance.audit.actionLabel')}>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value={ALL}>{t('compliance.audit.allActions')}</SelectItem>
              {options.map((item) => (
                <SelectItem key={item.action} value={item.action}>
                  {actionLabel(item.action)} ({formatNumber(item.count)})
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
          <div className="relative ml-auto w-full sm:w-72">
            <SearchIcon className="pointer-events-none absolute top-2 left-2.5 size-4 text-muted-foreground" />
            <Input
              type="search"
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder={t('compliance.audit.searchPlaceholder')}
              aria-label={t('compliance.audit.searchPlaceholder')}
              className="h-8 pl-8"
            />
          </div>
        </div>
        <p className="text-xs text-muted-foreground">{rangeLabel(range)}</p>
        {audit.data ? (
          <div
            className={cn('flex flex-col gap-3 transition-opacity', audit.isPlaceholderData && 'opacity-60')}
            aria-busy={audit.isFetching}
          >
            {rows.length > 0 ? (
              <AuditTable rows={rows} />
            ) : (
              <p className="border-y py-6 text-center text-row text-muted-foreground">
                {t('compliance.audit.empty')}
              </p>
            )}
            <div className="flex flex-wrap items-center gap-3">
              <span className="tabular text-xs text-muted-foreground" role="status">
                {t('compliance.audit.shown', { count: rows.length })}
              </span>
              {audit.hasNextPage ? (
                <Button
                  size="sm"
                  variant="outline"
                  disabled={audit.isFetchingNextPage}
                  onClick={() => void audit.fetchNextPage()}
                >
                  {audit.isFetchingNextPage ? <LoaderCircleIcon className="animate-spin" /> : null}
                  {t('compliance.audit.loadMore')}
                </Button>
              ) : rows.length > 0 ? (
                <span className="text-xs text-muted-foreground">{t('compliance.audit.end')}</span>
              ) : null}
            </div>
          </div>
        ) : audit.isError ? (
          <ErrorState error={audit.error} onRetry={() => void audit.refetch()} />
        ) : (
          <ListSkeleton rows={6} />
        )}
      </div>
    </div>
  )
}
