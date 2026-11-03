import { getRouteApi } from '@tanstack/react-router'
import { LoaderCircleIcon, SearchIcon } from 'lucide-react'
import { useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'

import { MetricStrip } from '@/components/metric-strip'
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
import { useDebounced } from '@/hooks/use-now'
import { format, formatNumber } from '@/lib/time'
import { cn } from '@/lib/utils'

import { useEvidenceList } from '../hooks'
import { normalizeQuery } from '../logic'
import {
  evidenceFilters,
  evidenceSources,
  type EvidenceFilter,
  type EvidenceListFilter,
  type EvidenceRow,
  type EvidenceSource,
  type EvidenceSummary,
} from '../types'
import { FilesSummary, RetentionText } from './evidence-badges'
import { EvidenceSheet } from './evidence-detail'

const route = getRouteApi('/compliance/evidence')

const ALL = '__all__'

const day = (value: string) => format(value, 'd MMM yyyy')

function Summary({ summary }: { summary: EvidenceSummary }) {
  const { t } = useTranslation()
  return (
    <MetricStrip
      metrics={[
        { label: t('evidence.summary.total'), value: formatNumber(summary.total) },
        { label: t('evidence.summary.held'), value: formatNumber(summary.held) },
        {
          label: t('evidence.summary.expiring'),
          value: formatNumber(summary.expiring),
          tone: summary.expiring > 0 ? 'warn' : undefined,
        },
        {
          label: t('evidence.summary.pendingFiles'),
          value: formatNumber(summary.pending_files),
          tone: summary.pending_files > 0 ? 'warn' : undefined,
        },
        {
          label: t('evidence.summary.problemFiles'),
          value: formatNumber(summary.problem_files),
          tone: summary.problem_files > 0 ? 'late' : undefined,
        },
        {
          label: t('evidence.summary.retention'),
          value: t('evidence.summary.retentionValue', { count: summary.retention_days }),
        },
      ]}
    />
  )
}

function EvidenceTable({ rows, onOpen }: { rows: EvidenceRow[]; onOpen: (id: string) => void }) {
  const { t } = useTranslation()
  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead>{t('evidence.columns.code')}</TableHead>
          <TableHead>{t('evidence.columns.source')}</TableHead>
          <TableHead>{t('evidence.columns.target')}</TableHead>
          <TableHead>{t('evidence.columns.author')}</TableHead>
          <TableHead>{t('evidence.columns.captured')}</TableHead>
          <TableHead>{t('evidence.columns.retainUntil')}</TableHead>
          <TableHead>{t('evidence.columns.files')}</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {rows.map((row) => (
          <TableRow key={row.id} className="h-auto cursor-pointer" onClick={() => onOpen(row.id)}>
            <TableCell className="py-2 align-top">
              <button
                type="button"
                className="font-mono text-xs underline underline-offset-2"
                aria-label={t('evidence.openEvidence', { code: row.code })}
                onClick={(event) => {
                  event.stopPropagation()
                  onOpen(row.id)
                }}
              >
                {row.code}
              </button>
            </TableCell>
            <TableCell className="py-2 align-top text-xs">
              {t(`evidence.sources.${row.source}`)}
              {row.links > 1 ? (
                <span className="block text-muted-foreground">
                  {t('evidence.linked', { count: row.links })}
                </span>
              ) : null}
            </TableCell>
            <TableCell className="max-w-48 py-2 align-top text-xs">
              {t(`evidence.targets.${row.target_type}`)}
              <span className="block truncate font-mono text-muted-foreground" title={row.target_id}>
                {row.target_id}
              </span>
            </TableCell>
            <TableCell className="max-w-44 py-2 align-top text-xs">
              <span className="block truncate">{row.author?.display_name ?? '–'}</span>
              {row.author?.username ? (
                <span className="block truncate text-muted-foreground">@{row.author.username}</span>
              ) : null}
            </TableCell>
            <TableCell className="tabular py-2 align-top text-xs text-muted-foreground">
              {format(row.captured_at, 'd MMM yyyy, HH.mm')}
            </TableCell>
            <TableCell className="py-2 align-top text-xs">
              <span className="tabular block">{day(row.retain_until)}</span>
              <RetentionText row={row} />
            </TableCell>
            <TableCell className="py-2 align-top">
              <FilesSummary row={row} />
            </TableCell>
          </TableRow>
        ))}
      </TableBody>
    </Table>
  )
}

export function EvidencePage() {
  const { t } = useTranslation()
  const search = route.useSearch()
  const navigate = route.useNavigate()
  const [query, setQuery] = useState('')
  const [filter, setFilter] = useState<EvidenceFilter | null>(null)
  const [source, setSource] = useState<EvidenceSource | null>(null)
  const debounced = useDebounced(normalizeQuery(query), 300)
  const listFilter: EvidenceListFilter = useMemo(
    () => ({ query: debounced, filter, source }),
    [debounced, filter, source],
  )
  const list = useEvidenceList(listFilter)
  const rows = useMemo(() => list.data?.pages.flatMap((page) => page.rows) ?? [], [list.data])
  const first = list.data?.pages[0]
  const summary = first?.summary ?? null
  const open = (id: string | null) =>
    void navigate({ search: (previous) => ({ ...previous, id: id ?? undefined }), replace: id === null })

  return (
    <div className="h-full overflow-y-auto">
      <div className="mx-auto flex max-w-[1440px] flex-col gap-4 px-4 py-5 lg:px-6">
        <header className="min-w-0">
          <h1 className="text-lg font-semibold">{t('evidence.title')}</h1>
          <p className="max-w-3xl text-row text-muted-foreground">{t('evidence.subtitle')}</p>
          {first && !first.can_manage ? (
            <p className="mt-1 text-xs text-muted-foreground">{t('evidence.readOnly')}</p>
          ) : null}
        </header>
        {summary ? <Summary summary={summary} /> : null}
        <div className="flex flex-wrap items-center gap-2">
          <ToggleGroup
            type="single"
            value={filter ?? ALL}
            onValueChange={(value) =>
              setFilter(evidenceFilters.includes(value as EvidenceFilter) ? (value as EvidenceFilter) : null)
            }
            aria-label={t('evidence.filters.label')}
          >
            <ToggleGroupItem value={ALL}>{t('evidence.filters.all')}</ToggleGroupItem>
            {evidenceFilters.map((item) => (
              <ToggleGroupItem key={item} value={item}>
                {t(`evidence.filters.${item}`)}
              </ToggleGroupItem>
            ))}
          </ToggleGroup>
          <Select
            value={source ?? ALL}
            onValueChange={(value) => setSource(value === ALL ? null : (value as EvidenceSource))}
          >
            <SelectTrigger className="h-8 w-52" aria-label={t('evidence.sourceLabel')}>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value={ALL}>{t('evidence.allSources')}</SelectItem>
              {evidenceSources.map((item) => (
                <SelectItem key={item} value={item}>
                  {t(`evidence.sources.${item}`)}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
          <div className="relative ml-auto w-full sm:w-80">
            <SearchIcon className="pointer-events-none absolute top-2 left-2.5 size-4 text-muted-foreground" />
            <Input
              type="search"
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder={t('evidence.searchPlaceholder')}
              aria-label={t('evidence.searchPlaceholder')}
              className="h-8 pl-8"
            />
          </div>
        </div>
        {list.data ? (
          <div
            className={cn('flex flex-col gap-3 transition-opacity', list.isPlaceholderData && 'opacity-60')}
            aria-busy={list.isFetching}
          >
            {rows.length > 0 ? (
              <EvidenceTable rows={rows} onOpen={open} />
            ) : (
              <p className="border-y py-6 text-center text-row text-muted-foreground">
                {t('evidence.empty')}
              </p>
            )}
            <div className="flex flex-wrap items-center gap-3">
              <span className="tabular text-xs text-muted-foreground" role="status">
                {t('evidence.shown', { count: rows.length })}
              </span>
              {list.hasNextPage ? (
                <Button
                  size="sm"
                  variant="outline"
                  disabled={list.isFetchingNextPage}
                  onClick={() => void list.fetchNextPage()}
                >
                  {list.isFetchingNextPage ? <LoaderCircleIcon className="animate-spin" /> : null}
                  {t('evidence.loadMore')}
                </Button>
              ) : rows.length > 0 ? (
                <span className="text-xs text-muted-foreground">{t('evidence.end')}</span>
              ) : null}
            </div>
          </div>
        ) : list.isError ? (
          <ErrorState error={list.error} onRetry={() => void list.refetch()} />
        ) : (
          <ListSkeleton rows={6} />
        )}
      </div>
      <EvidenceSheet id={search.id ?? null} onClose={() => open(null)} />
    </div>
  )
}
