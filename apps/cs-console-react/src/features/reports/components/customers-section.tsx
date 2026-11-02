import { DownloadIcon, SearchIcon } from 'lucide-react'
import { useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'

import { ErrorState, ListSkeleton } from '@/components/states'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { useDebounced } from '@/hooks/use-now'
import { downloadText } from '@/lib/download'
import { formatNumber, formatRating, minutesLabel, shortDate } from '@/lib/time'
import { cn } from '@/lib/utils'

import { customersCsv, reportFileName } from '../csv'
import { useCustomerReport } from '../hooks'
import { reportColumns } from '../table'
import { customerLabel } from '../trail'
import { MAX_CUSTOMER_ROWS, type CustomerReport, type DateRange } from '../types'
import { CustomerTrailSheet } from './customer-trail'
import { SortableTable } from './sortable-table'

function useCustomerColumns(onOpen: (row: CustomerReport) => void) {
  const { t } = useTranslation()
  return useMemo(() => {
    const column = reportColumns<CustomerReport>()
    return column.columns([
      column.accessor((row) => customerLabel(row), {
        id: 'customer',
        header: t('reports.customer'),
        sortFn: 'alphanumeric',
        cell: (info) => (
          <button
            type="button"
            onClick={() => onOpen(info.row.original)}
            aria-label={t('reports.openTrail', { name: info.getValue() })}
            className="flex flex-col items-start rounded-sm text-left outline-none hover:underline focus-visible:ring-2 focus-visible:ring-ring/50"
          >
            <span className="font-medium">{info.getValue()}</span>
            {info.row.original.username ? (
              <span className="font-mono text-xs text-muted-foreground">@{info.row.original.username}</span>
            ) : null}
          </button>
        ),
      }),
      column.accessor('tickets', {
        header: t('reports.tickets'),
        sortFn: 'basic',
        meta: { numeric: true },
        cell: (info) => formatNumber(info.getValue()),
      }),
      column.accessor('resolved', {
        header: t('reports.resolved'),
        sortFn: 'basic',
        meta: { numeric: true },
        cell: (info) => formatNumber(info.getValue()),
      }),
      column.accessor('reopened', {
        header: t('reports.reopened'),
        sortFn: 'basic',
        meta: { numeric: true },
        cell: (info) => formatNumber(info.getValue()),
      }),
      column.accessor((row) => row.avg_first_response_minutes ?? undefined, {
        id: 'firstResponse',
        header: t('reports.firstResponse'),
        sortFn: 'basic',
        sortUndefined: 'last',
        meta: { numeric: true },
        cell: (info) => minutesLabel(info.getValue()),
      }),
      column.accessor((row) => row.avg_resolution_minutes ?? undefined, {
        id: 'duration',
        header: t('reports.duration'),
        sortFn: 'basic',
        sortUndefined: 'last',
        meta: { numeric: true },
        cell: (info) => minutesLabel(info.getValue()),
      }),
      column.accessor((row) => row.avg_rating ?? undefined, {
        id: 'rating',
        header: t('reports.avgRating'),
        sortFn: 'basic',
        sortUndefined: 'last',
        meta: { numeric: true },
        cell: (info) =>
          info.getValue() === undefined
            ? '–'
            : `${formatRating(info.getValue())} (${formatNumber(info.row.original.ratings)})`,
      }),
      column.accessor('closed_unrated', {
        header: t('reports.closedUnrated'),
        sortFn: 'basic',
        meta: { numeric: true },
        cell: (info) => formatNumber(info.getValue()),
      }),
      column.accessor('complaints', {
        header: t('reports.complaints'),
        sortFn: 'basic',
        meta: { numeric: true },
        cell: (info) => formatNumber(info.getValue()),
      }),
      column.accessor('last_ticket_at', {
        header: t('reports.lastTicket'),
        sortFn: 'alphanumeric',
        cell: (info) => shortDate(info.getValue()),
      }),
    ])
  }, [t, onOpen])
}

export function CustomersSection({ range }: { range: DateRange }) {
  const { t } = useTranslation()
  const [query, setQuery] = useState('')
  const [open, setOpen] = useState<CustomerReport | null>(null)
  const search = useDebounced(query.trim(), 300)
  const customers = useCustomerReport(range, search)
  const columns = useCustomerColumns(setOpen)
  const rows = customers.data ?? []
  const ready = customers.data && !customers.isPlaceholderData ? customers.data : undefined

  return (
    <section className="flex flex-col gap-3" aria-labelledby="customers-report-title">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h2 id="customers-report-title" className="text-panel font-semibold">
            {t('reports.perCustomer')}
          </h2>
          <p className="text-xs text-muted-foreground">{t('reports.perCustomerHint')}</p>
        </div>
        <div className="flex w-full flex-wrap items-center gap-2 sm:w-auto">
          <div className="relative w-full sm:w-64">
            <SearchIcon className="pointer-events-none absolute top-2 left-2.5 size-4 text-muted-foreground" />
            <Input
              type="search"
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder={t('reports.searchCustomer')}
              aria-label={t('reports.searchCustomer')}
              maxLength={100}
              className="h-8 pl-8"
            />
          </div>
          <Button
            size="sm"
            variant="outline"
            disabled={!ready || ready.length === 0}
            onClick={() => {
              if (!ready) return
              const csv = customersCsv(ready, (key) => t(`reports.${key}`))
              downloadText(reportFileName(range, 'customers'), csv, 'text/csv;charset=utf-8')
            }}
          >
            <DownloadIcon />
            {t('reports.exportCsv')}
          </Button>
        </div>
      </div>
      {customers.data ? (
        <div
          className={cn(
            'flex flex-col gap-2 transition-opacity',
            customers.isPlaceholderData && 'opacity-60',
          )}
        >
          <SortableTable
            columns={columns}
            data={rows}
            caption={t('reports.perCustomer')}
            empty={search ? t('reports.customerNotFound') : t('reports.empty')}
          />
          {rows.length >= MAX_CUSTOMER_ROWS ? (
            <p className="text-xs text-muted-foreground">
              {t('reports.customerLimit', { count: MAX_CUSTOMER_ROWS })}
            </p>
          ) : null}
        </div>
      ) : customers.isError ? (
        <ErrorState error={customers.error} onRetry={() => void customers.refetch()} />
      ) : (
        <ListSkeleton rows={4} />
      )}
      <CustomerTrailSheet customer={open} range={range} onClose={() => setOpen(null)} />
    </section>
  )
}
