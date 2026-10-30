import { useTable, type RowData, type SortingState, type TableOptions } from '@tanstack/react-table'
import { ArrowDownIcon, ArrowUpDownIcon, ArrowUpIcon } from 'lucide-react'
import { useTranslation } from 'react-i18next'

import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { cn } from '@/lib/utils'

import { reportTableFeatures, type ReportTableFeatures } from '../table'

export function SortableTable<T extends RowData>({
  columns,
  data,
  caption,
  empty,
  initialSorting = [],
}: {
  columns: TableOptions<ReportTableFeatures, T>['columns']
  data: T[]
  caption: string
  empty: string
  initialSorting?: SortingState
}) {
  const { t } = useTranslation()
  const table = useTable({
    features: reportTableFeatures,
    columns,
    data,
    initialState: { sorting: initialSorting },
  })
  if (data.length === 0) {
    return <p className="rounded-xl border bg-card p-4 text-sm text-muted-foreground">{empty}</p>
  }
  return (
    <Table>
      <caption className="sr-only">{caption}</caption>
      <TableHeader>
        {table.getHeaderGroups().map((group) => (
          <TableRow key={group.id}>
            {group.headers.map((header) => {
              const sorted = header.column.getIsSorted()
              const numeric = header.column.columnDef.meta?.numeric === true
              const title =
                typeof header.column.columnDef.header === 'string'
                  ? header.column.columnDef.header
                  : header.id
              const Icon =
                sorted === 'asc' ? ArrowUpIcon : sorted === 'desc' ? ArrowDownIcon : ArrowUpDownIcon
              return (
                <TableHead
                  key={header.id}
                  aria-sort={sorted === 'asc' ? 'ascending' : sorted === 'desc' ? 'descending' : undefined}
                  className={cn(numeric && 'text-right')}
                >
                  {header.column.getCanSort() ? (
                    <button
                      type="button"
                      onClick={header.column.getToggleSortingHandler()}
                      aria-label={t('reports.sortBy', { column: title })}
                      className={cn(
                        'inline-flex items-center gap-1 rounded-sm outline-none hover:text-foreground focus-visible:ring-[3px] focus-visible:ring-ring/50',
                        numeric && 'flex-row-reverse',
                        sorted && 'text-foreground',
                      )}
                    >
                      <table.FlexRender header={header} />
                      <Icon className={cn('size-3.5', !sorted && 'opacity-40')} aria-hidden="true" />
                    </button>
                  ) : (
                    <table.FlexRender header={header} />
                  )}
                </TableHead>
              )
            })}
          </TableRow>
        ))}
      </TableHeader>
      <TableBody>
        {table.getRowModel().rows.map((row) => (
          <TableRow key={row.id}>
            {row.getAllCells().map((cell) => (
              <TableCell
                key={cell.id}
                className={cn(cell.column.columnDef.meta?.numeric === true && 'tabular text-right')}
              >
                <table.FlexRender cell={cell} />
              </TableCell>
            ))}
          </TableRow>
        ))}
      </TableBody>
    </Table>
  )
}
