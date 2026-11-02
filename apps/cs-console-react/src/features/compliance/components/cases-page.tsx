import { getRouteApi } from '@tanstack/react-router'
import { DownloadIcon, SearchIcon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'

import { PriorityText, TicketStatusText } from '@/components/badges'
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
import { rangeLabel } from '@/features/reports/range'
import type { DateRange } from '@/features/reports/types'
import { customerName } from '@/features/tickets/types'
import { useDebounced, useNow } from '@/hooks/use-now'
import { downloadText } from '@/lib/download'
import { formatNumber, stamp } from '@/lib/time'
import { cn } from '@/lib/utils'

import { useCases } from '../hooks'
import { casePresetRange, casesCsv, rangeFileSuffix, type CasePreset } from '../logic'
import { caseKinds, caseStates, MAX_CASE_DAYS, type CaseKind, type CaseRow, type CaseState } from '../types'
import { useCaseKindLabel } from '../labels'
import { CaseKindText, DeadlineText, VerdictText } from './case-badges'
import { CasePanel } from './case-panel'

const route = getRouteApi('/compliance/cases')

function CaseTable({ rows, onOpen }: { rows: CaseRow[]; onOpen: (id: string) => void }) {
  const { t } = useTranslation()
  const now = useNow(60_000)
  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead>{t('compliance.cases.colTicket')}</TableHead>
          <TableHead>{t('compliance.cases.colCustomer')}</TableHead>
          <TableHead>{t('compliance.cases.colKind')}</TableHead>
          <TableHead>{t('compliance.cases.colStatus')}</TableHead>
          <TableHead>{t('compliance.cases.colAgent')}</TableHead>
          <TableHead>{t('compliance.cases.colReceived')}</TableHead>
          <TableHead>{t('compliance.cases.colDeadline')}</TableHead>
          <TableHead>{t('compliance.cases.colReview')}</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {rows.map((row) => (
          <TableRow key={row.id} className="cursor-pointer" onClick={() => onOpen(row.id)}>
            <TableCell>
              <span className="inline-flex items-center gap-2">
                <PriorityText priority={row.priority} />
                <button
                  type="button"
                  className="rounded-sm font-mono text-xs outline-none focus-visible:ring-2 focus-visible:ring-ring/50"
                  aria-label={t('compliance.cases.openCase', { number: row.ticket_number })}
                  onClick={(event) => {
                    event.stopPropagation()
                    onOpen(row.id)
                  }}
                >
                  {row.ticket_number}
                </button>
              </span>
            </TableCell>
            <TableCell className="max-w-48 truncate font-medium">{customerName(row)}</TableCell>
            <TableCell>
              <CaseKindText row={row} />
            </TableCell>
            <TableCell>
              <TicketStatusText status={row.status} />
            </TableCell>
            <TableCell className="max-w-40 truncate">{row.agent?.display_name ?? '–'}</TableCell>
            <TableCell className="tabular text-xs text-muted-foreground">
              {stamp(row.complaint_received_at ?? row.created_at, now)}
            </TableCell>
            <TableCell>
              <span className="flex items-center gap-2">
                <DeadlineText deadline={row.deadline} />
                {row.complaint_extended_at ? (
                  <span className="text-xs text-info">{t('compliance.cases.extended')}</span>
                ) : null}
              </span>
            </TableCell>
            <TableCell>
              <VerdictText verdict={row.review?.verdict} />
            </TableCell>
          </TableRow>
        ))}
      </TableBody>
    </Table>
  )
}

export function ComplianceCasesPage() {
  const { t } = useTranslation()
  const search = route.useSearch()
  const navigate = route.useNavigate()
  const kindLabel = useCaseKindLabel()
  const [kind, setKind] = useState<CaseKind>('all')
  const [state, setState] = useState<CaseState>(search.state ?? 'all')
  const [preset, setPreset] = useState<CasePreset>('all')
  const [range, setRange] = useState<DateRange | null>(null)
  const [query, setQuery] = useState('')
  const debounced = useDebounced(query.trim(), 300)
  const cases = useCases({ kind, state, range, query: debounced })
  const rows = cases.data?.rows ?? []

  const choosePreset = (value: string) => {
    if (value !== 'all' && value !== 'month' && value !== 'quarter' && value !== 'year') return
    setPreset(value)
    setRange(casePresetRange(value))
  }

  const exportCsv = () => {
    const csv = casesCsv(rows, {
      header: (column) => t(`compliance.csv.${column}`),
      kind: kindLabel,
      status: (status) => t(`tickets.status.${status as 'open'}`),
      deadline: (value) => t(`compliance.deadlineState.${value}`),
      verdict: (value) => t(`compliance.verdict.${value}`),
      yes: t('compliance.csv.yes'),
    })
    downloadText(
      `register-kasus-${kind}-${state}-${rangeFileSuffix(range)}.csv`,
      csv,
      'text/csv;charset=utf-8',
    )
  }

  return (
    <div className="h-full overflow-y-auto">
      <div className="mx-auto flex max-w-[1440px] flex-col gap-4 px-4 py-5 lg:px-6">
        <header className="flex flex-wrap items-end justify-between gap-3">
          <div>
            <h1 className="text-lg font-semibold">{t('compliance.cases.title')}</h1>
            <p className="text-row text-muted-foreground">
              {t('compliance.cases.subtitle')}
              {range ? ` · ${rangeLabel(range)}` : ''}
            </p>
          </div>
          <Button size="sm" variant="outline" disabled={rows.length === 0} onClick={exportCsv}>
            <DownloadIcon />
            {t('compliance.cases.exportCsv')}
          </Button>
        </header>
        <div className="flex flex-wrap items-center gap-2">
          <ToggleGroup
            type="single"
            value={kind}
            onValueChange={(value) => value && setKind(value as CaseKind)}
            aria-label={t('compliance.cases.kindLabel')}
          >
            {caseKinds.map((item) => (
              <ToggleGroupItem key={item} value={item}>
                {t(`compliance.cases.kinds.${item}`)}
              </ToggleGroupItem>
            ))}
          </ToggleGroup>
          <Select value={state} onValueChange={(value) => setState(value as CaseState)}>
            <SelectTrigger className="h-8 w-44" aria-label={t('compliance.cases.stateLabel')}>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {caseStates.map((item) => (
                <SelectItem key={item} value={item}>
                  {t(`compliance.cases.states.${item}`)}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
          <ToggleGroup
            type="single"
            value={preset === 'custom' ? '' : preset}
            onValueChange={choosePreset}
            aria-label={t('compliance.cases.periodLabel')}
          >
            <ToggleGroupItem value="all">{t('compliance.cases.periods.all')}</ToggleGroupItem>
            <ToggleGroupItem value="month">{t('compliance.cases.periods.month')}</ToggleGroupItem>
            <ToggleGroupItem value="quarter">{t('compliance.cases.periods.quarter')}</ToggleGroupItem>
            <ToggleGroupItem value="year">{t('compliance.cases.periods.year')}</ToggleGroupItem>
          </ToggleGroup>
          <DateRangePicker
            range={range ?? casePresetRange('month') ?? { from: '', to: '' }}
            active={preset === 'custom'}
            maxDays={MAX_CASE_DAYS}
            onApply={(next) => {
              setPreset('custom')
              setRange(next)
            }}
          />
          <div className="relative ml-auto w-full sm:w-72">
            <SearchIcon className="pointer-events-none absolute top-2 left-2.5 size-4 text-muted-foreground" />
            <Input
              type="search"
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder={t('compliance.cases.searchPlaceholder')}
              aria-label={t('compliance.cases.searchPlaceholder')}
              className="h-8 pl-8"
            />
          </div>
        </div>
        {cases.data ? (
          <div
            className={cn('flex flex-col gap-2 transition-opacity', cases.isPlaceholderData && 'opacity-60')}
          >
            <p className="tabular text-xs text-muted-foreground" role="status">
              {t('compliance.cases.count', { count: cases.data.total })}
            </p>
            {cases.data.truncated ? (
              <p className="text-xs text-warning">
                {t('compliance.cases.truncated', { total: formatNumber(cases.data.total) })}
              </p>
            ) : null}
            {rows.length > 0 ? (
              <CaseTable
                rows={rows}
                onOpen={(id) => void navigate({ search: (current) => ({ ...current, case: id }) })}
              />
            ) : (
              <p className="border-y py-6 text-center text-row text-muted-foreground">
                {t('compliance.cases.empty')}
              </p>
            )}
          </div>
        ) : cases.isError ? (
          <ErrorState error={cases.error} onRetry={() => void cases.refetch()} />
        ) : (
          <ListSkeleton rows={6} />
        )}
      </div>
      <CasePanel
        ticketId={search.case}
        onClose={() => void navigate({ search: (current) => ({ ...current, case: undefined }) })}
      />
    </div>
  )
}
