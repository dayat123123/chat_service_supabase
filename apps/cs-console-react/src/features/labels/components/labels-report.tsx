import { useMemo } from 'react'
import { useTranslation } from 'react-i18next'

import { ErrorState } from '@/components/states'
import { Skeleton } from '@/components/ui/primitives'
import { SortableTable } from '@/features/reports/components/sortable-table'
import { reportColumns } from '@/features/reports/table'
import type { DateRange } from '@/features/reports/types'
import { formatNumber } from '@/lib/time'

import { useLabelReport } from '../hooks'
import { reportShares } from '../logic'
import type { LabelReportRow } from '../types'
import { LabelChip } from './label-chip'

type Row = LabelReportRow & { share: number | undefined }

export function LabelsReport({ range }: { range: DateRange }) {
  const { t } = useTranslation()
  const report = useLabelReport(range)
  const rows = useMemo<Row[]>(() => (report.data ? reportShares(report.data) : []), [report.data])
  const columns = useMemo(() => {
    const column = reportColumns<Row>()
    return column.columns([
      column.accessor('name', {
        header: t('labels.report.label'),
        sortFn: 'alphanumeric',
        cell: (info) => (
          <span className="inline-flex items-center gap-2">
            <LabelChip label={info.row.original} />
            {info.row.original.active ? null : (
              <span className="text-xs text-muted-foreground">{t('labels.report.inactive')}</span>
            )}
          </span>
        ),
      }),
      column.accessor('count', {
        header: t('labels.report.count'),
        sortFn: 'basic',
        meta: { numeric: true },
        cell: (info) => formatNumber(info.getValue()),
      }),
      column.accessor('share', {
        header: t('labels.report.share'),
        sortFn: 'basic',
        sortUndefined: 'last',
        meta: { numeric: true },
        cell: (info) => {
          const share = info.getValue()
          return share === undefined ? '–' : `${Math.round(share * 100)}%`
        },
      }),
    ])
  }, [t])
  return (
    <section className="flex flex-col gap-3" aria-labelledby="labels-report-title">
      <div className="flex flex-wrap items-baseline justify-between gap-2">
        <h2 id="labels-report-title" className="text-panel font-semibold">
          {t('labels.report.title')}
        </h2>
        {report.data ? (
          <p className="tabular text-row text-muted-foreground">
            {t('labels.report.summary', {
              labeled: formatNumber(report.data.total - report.data.unlabeled),
              total: formatNumber(report.data.total),
            })}
            {' · '}
            {t('labels.report.unlabeled')}: {formatNumber(report.data.unlabeled)}
          </p>
        ) : null}
      </div>
      {report.data ? (
        <SortableTable
          columns={columns}
          data={rows}
          caption={t('labels.report.title')}
          empty={t('labels.report.empty')}
        />
      ) : report.isError ? (
        <ErrorState error={report.error} onRetry={() => void report.refetch()} />
      ) : (
        <Skeleton className="h-2 w-2/3" />
      )}
    </section>
  )
}
