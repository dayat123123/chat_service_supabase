import { subDays } from 'date-fns'
import {
  CalendarRangeIcon,
  CheckCheckIcon,
  DownloadIcon,
  HandIcon,
  HourglassIcon,
  MessageSquareReplyIcon,
  StarIcon,
  TicketIcon,
} from 'lucide-react'
import { useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'

import { StatTile } from '@/components/stat-tile'
import { ErrorState } from '@/components/states'
import { Button } from '@/components/ui/button'
import { ToggleGroup, ToggleGroupItem } from '@/components/ui/controls'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
  Popover,
  PopoverContent,
  PopoverTrigger,
} from '@/components/ui/menu'
import { Skeleton } from '@/components/ui/primitives'
import { downloadText } from '@/lib/download'
import { formatDay, formatNumber, formatRating, isoDay, minutesLabel, todayInJakarta } from '@/lib/time'
import { cn } from '@/lib/utils'

import { reportCsv, reportFileName } from '../csv'
import { useReport } from '../hooks'
import { presetRange, rangeLabel, rangeProblem, type RangeProblem } from '../range'
import { reportColumns } from '../table'
import {
  MAX_REPORT_DAYS,
  type AgentReport,
  type DateRange,
  type ReportExport,
  type ReportPreset,
  type ReportStats,
  type ReportSummary,
  type TopicCount,
} from '../types'
import { DailyChart } from './daily-chart'
import { SortableTable } from './sortable-table'

type TopicRow = TopicCount & { share: number | undefined }

const problemKey: Record<
  RangeProblem,
  'reports.rangeInvalid' | 'reports.rangeOrder' | 'reports.rangeFuture' | 'reports.rangeTooLong'
> = {
  invalid: 'reports.rangeInvalid',
  order: 'reports.rangeOrder',
  future: 'reports.rangeFuture',
  tooLong: 'reports.rangeTooLong',
}

function CustomRange({
  range,
  active,
  onApply,
}: {
  range: DateRange
  active: boolean
  onApply: (range: DateRange) => void
}) {
  const { t } = useTranslation()
  const [open, setOpen] = useState(false)
  const [draft, setDraft] = useState(range)
  const [problem, setProblem] = useState<RangeProblem | null>(null)
  const today = todayInJakarta()
  const max = isoDay(today)
  const min = isoDay(subDays(today, 730))
  return (
    <Popover
      open={open}
      onOpenChange={(next) => {
        setOpen(next)
        if (next) {
          setDraft(range)
          setProblem(null)
        }
      }}
    >
      <PopoverTrigger asChild>
        <Button variant="outline" size="sm" className={cn(active && 'bg-accent text-accent-foreground')}>
          <CalendarRangeIcon />
          {t('reports.custom')}
        </Button>
      </PopoverTrigger>
      <PopoverContent align="end" className="w-72">
        <form
          className="flex flex-col gap-3"
          onSubmit={(event) => {
            event.preventDefault()
            const issue = rangeProblem(draft)
            setProblem(issue)
            if (issue) return
            onApply(draft)
            setOpen(false)
          }}
        >
          <div className="grid grid-cols-2 gap-2">
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="report-from">{t('reports.from')}</Label>
              <Input
                id="report-from"
                type="date"
                min={min}
                max={max}
                required
                value={draft.from}
                onChange={(event) => setDraft((current) => ({ ...current, from: event.target.value }))}
              />
            </div>
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="report-to">{t('reports.to')}</Label>
              <Input
                id="report-to"
                type="date"
                min={min}
                max={max}
                required
                value={draft.to}
                onChange={(event) => setDraft((current) => ({ ...current, to: event.target.value }))}
              />
            </div>
          </div>
          {problem ? (
            <p role="alert" className="text-xs text-destructive">
              {t(problemKey[problem], { days: MAX_REPORT_DAYS })}
            </p>
          ) : (
            <p className="text-xs text-muted-foreground">
              {t('reports.rangeTooLong', { days: MAX_REPORT_DAYS })}
            </p>
          )}
          <Button type="submit" size="sm" className="self-end">
            {t('reports.apply')}
          </Button>
        </form>
      </PopoverContent>
    </Popover>
  )
}

function ExportMenu({ report }: { report: ReportSummary | undefined }) {
  const { t } = useTranslation()
  const exportAs = (kind: ReportExport) => {
    if (!report) return
    const csv = reportCsv(report, kind, (key) => t(`reports.${key}`))
    downloadText(reportFileName(report, kind), csv, 'text/csv;charset=utf-8')
  }
  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button size="sm" disabled={!report}>
          <DownloadIcon />
          {t('reports.exportCsv')}
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end">
        <DropdownMenuItem onSelect={() => exportAs('daily')}>{t('reports.exportDaily')}</DropdownMenuItem>
        <DropdownMenuItem onSelect={() => exportAs('agents')}>{t('reports.exportAgents')}</DropdownMenuItem>
        <DropdownMenuItem onSelect={() => exportAs('topics')}>{t('reports.exportTopics')}</DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  )
}

function useReportColumns() {
  const { t } = useTranslation()
  return useMemo(() => {
    const day = reportColumns<ReportStats>()
    const agent = reportColumns<AgentReport>()
    const topic = reportColumns<TopicRow>()
    return {
      daily: day.columns([
        day.accessor((row) => row.day ?? '', {
          id: 'day',
          header: t('reports.date'),
          sortFn: 'alphanumeric',
          cell: (info) => (info.getValue() ? formatDay(info.getValue(), 'EEE, d MMM yyyy') : '–'),
        }),
        day.accessor('created', {
          header: t('reports.created'),
          sortFn: 'basic',
          meta: { numeric: true },
          cell: (info) => formatNumber(info.getValue()),
        }),
        day.accessor('resolved', {
          header: t('reports.resolved'),
          sortFn: 'basic',
          meta: { numeric: true },
          cell: (info) => formatNumber(info.getValue()),
        }),
        day.accessor((row) => row.avg_claim_minutes ?? undefined, {
          id: 'claim',
          header: t('reports.claimTime'),
          sortFn: 'basic',
          sortUndefined: 'last',
          meta: { numeric: true },
          cell: (info) => minutesLabel(info.getValue()),
        }),
        day.accessor((row) => row.avg_first_response_minutes ?? undefined, {
          id: 'firstResponse',
          header: t('reports.firstResponse'),
          sortFn: 'basic',
          sortUndefined: 'last',
          meta: { numeric: true },
          cell: (info) => minutesLabel(info.getValue()),
        }),
        day.accessor((row) => row.avg_resolution_minutes ?? undefined, {
          id: 'duration',
          header: t('reports.duration'),
          sortFn: 'basic',
          sortUndefined: 'last',
          meta: { numeric: true },
          cell: (info) => minutesLabel(info.getValue()),
        }),
        day.accessor((row) => row.avg_rating ?? undefined, {
          id: 'rating',
          header: t('reports.avgRating'),
          sortFn: 'basic',
          sortUndefined: 'last',
          meta: { numeric: true },
          cell: (info) => formatRating(info.getValue()),
        }),
      ]),
      agents: agent.columns([
        agent.accessor('display_name', {
          header: t('reports.agent'),
          sortFn: 'alphanumeric',
          cell: (info) => (
            <span className="font-medium">
              {info.getValue()}
              {info.row.original.agent_code ? (
                <span className="font-normal text-muted-foreground"> ({info.row.original.agent_code})</span>
              ) : null}
            </span>
          ),
        }),
        agent.accessor('handled', {
          header: t('reports.handled'),
          sortFn: 'basic',
          meta: { numeric: true },
          cell: (info) => formatNumber(info.getValue()),
        }),
        agent.accessor('resolved', {
          header: t('reports.resolved'),
          sortFn: 'basic',
          meta: { numeric: true },
          cell: (info) => formatNumber(info.getValue()),
        }),
        agent.accessor((row) => row.avg_first_response_minutes ?? undefined, {
          id: 'firstResponse',
          header: t('reports.firstResponse'),
          sortFn: 'basic',
          sortUndefined: 'last',
          meta: { numeric: true },
          cell: (info) => minutesLabel(info.getValue()),
        }),
        agent.accessor((row) => row.avg_rating ?? undefined, {
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
      ]),
      topics: topic.columns([
        topic.accessor('name', { header: t('reports.topic'), sortFn: 'alphanumeric' }),
        topic.accessor('count', {
          header: t('reports.count'),
          sortFn: 'basic',
          meta: { numeric: true },
          cell: (info) => formatNumber(info.getValue()),
        }),
        topic.accessor('share', {
          header: t('reports.share'),
          sortFn: 'basic',
          sortUndefined: 'last',
          meta: { numeric: true },
          cell: (info) => {
            const share = info.getValue()
            return share === undefined ? '–' : `${Math.round(share * 100)}%`
          },
        }),
      ]),
    }
  }, [t])
}

function ReportBody({ report }: { report: ReportSummary }) {
  const { t } = useTranslation()
  const columns = useReportColumns()
  const totals = report.totals
  const topics = useMemo<TopicRow[]>(() => {
    const total = report.topics.reduce((sum, item) => sum + item.count, 0)
    return report.topics.map((item) => ({ ...item, share: total === 0 ? undefined : item.count / total }))
  }, [report.topics])
  return (
    <>
      <section className="grid grid-cols-2 gap-3 md:grid-cols-3 2xl:grid-cols-6">
        <StatTile label={t('reports.created')} value={formatNumber(totals.created)} icon={TicketIcon} />
        <StatTile
          label={t('reports.resolved')}
          value={formatNumber(totals.resolved)}
          caption={
            totals.created === 0
              ? undefined
              : t('reports.percentOfTickets', {
                  percent: Math.round((totals.resolved * 100) / totals.created),
                })
          }
          icon={CheckCheckIcon}
        />
        <StatTile
          label={t('reports.claimTime')}
          value={minutesLabel(totals.avg_claim_minutes)}
          icon={HandIcon}
        />
        <StatTile
          label={t('reports.firstResponse')}
          value={minutesLabel(totals.avg_first_response_minutes)}
          icon={MessageSquareReplyIcon}
        />
        <StatTile
          label={t('reports.duration')}
          value={minutesLabel(totals.avg_resolution_minutes)}
          icon={HourglassIcon}
        />
        <StatTile
          label={t('reports.avgRating')}
          value={totals.avg_rating === null ? '–' : `${formatRating(totals.avg_rating)} ★`}
          caption={t('reports.ratingCount', { count: totals.ratings })}
          icon={StarIcon}
          tone="rating"
        />
      </section>
      <section className="flex flex-col gap-3" aria-labelledby="daily-title">
        <h2 id="daily-title" className="text-sm font-semibold">
          {t('reports.perDay')}
        </h2>
        {report.daily.length > 1 ? (
          <div className="rounded-xl border bg-card p-4 shadow-xs">
            <DailyChart daily={report.daily} />
          </div>
        ) : null}
        <SortableTable
          columns={columns.daily}
          data={report.daily}
          caption={t('reports.perDay')}
          empty={t('reports.empty')}
          initialSorting={[{ id: 'day', desc: false }]}
        />
      </section>
      <div className="grid items-start gap-6 xl:grid-cols-5">
        <section className="flex flex-col gap-3 xl:col-span-3" aria-labelledby="agents-report-title">
          <h2 id="agents-report-title" className="text-sm font-semibold">
            {t('reports.perAgent')}
          </h2>
          <SortableTable
            columns={columns.agents}
            data={report.agents}
            caption={t('reports.perAgent')}
            empty={t('reports.empty')}
          />
        </section>
        <section className="flex flex-col gap-3 xl:col-span-2" aria-labelledby="topics-report-title">
          <h2 id="topics-report-title" className="text-sm font-semibold">
            {t('reports.topTopics')}
          </h2>
          <SortableTable
            columns={columns.topics}
            data={topics}
            caption={t('reports.topTopics')}
            empty={t('reports.empty')}
          />
        </section>
      </div>
    </>
  )
}

export function ReportsPage() {
  const { t } = useTranslation()
  const [preset, setPreset] = useState<ReportPreset>('week')
  const [range, setRange] = useState<DateRange>(() => presetRange('week'))
  const report = useReport(range)
  const ready = report.data && !report.isPlaceholderData ? report.data : undefined

  const choosePreset = (value: string) => {
    if (value !== 'today' && value !== 'week' && value !== 'month') return
    setPreset(value)
    setRange(presetRange(value))
  }

  return (
    <div className="h-full scrollbar-thin overflow-y-auto">
      <div className="mx-auto flex max-w-[1440px] flex-col gap-6 px-4 py-5 lg:px-6">
        <header className="flex flex-wrap items-end justify-between gap-3">
          <div>
            <h1 className="text-xl font-semibold">{t('reports.title')}</h1>
            <p className="text-sm text-muted-foreground">{rangeLabel(range)}</p>
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <ToggleGroup
              type="single"
              value={preset === 'custom' ? '' : preset}
              onValueChange={choosePreset}
              aria-label={t('reports.rangeLabel')}
            >
              <ToggleGroupItem value="today">{t('reports.today')}</ToggleGroupItem>
              <ToggleGroupItem value="week">{t('reports.week')}</ToggleGroupItem>
              <ToggleGroupItem value="month">{t('reports.month')}</ToggleGroupItem>
            </ToggleGroup>
            <CustomRange
              range={range}
              active={preset === 'custom'}
              onApply={(next) => {
                setPreset('custom')
                setRange(next)
              }}
            />
            <ExportMenu report={ready} />
          </div>
        </header>
        {report.data ? (
          <div
            className={cn('flex flex-col gap-6 transition-opacity', report.isPlaceholderData && 'opacity-60')}
            aria-busy={report.isFetching}
          >
            <ReportBody report={report.data} />
          </div>
        ) : report.isError ? (
          <ErrorState error={report.error} onRetry={() => void report.refetch()} />
        ) : (
          <div className="flex flex-col gap-6" aria-busy="true">
            <div className="grid grid-cols-2 gap-3 md:grid-cols-3 2xl:grid-cols-6">
              {Array.from({ length: 6 }, (_, i) => (
                <Skeleton key={i} className="h-[86px] rounded-xl" />
              ))}
            </div>
            <Skeleton className="h-72 rounded-xl" />
          </div>
        )}
      </div>
    </div>
  )
}
