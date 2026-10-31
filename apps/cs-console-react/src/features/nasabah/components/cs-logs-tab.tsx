import { SearchIcon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'

import { ErrorState, ListSkeleton } from '@/components/states'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/controls'
import { Input } from '@/components/ui/input'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { useDebounced } from '@/hooks/use-now'
import { cn } from '@/lib/utils'

import { useCsLogs } from '../hooks'
import { legacyStamp, useNasabahLabels } from '../labels'
import { csLogTypes } from '../types'
import { Pager } from './pager'

const ALL = '-1'

export function CsLogsTab() {
  const { t } = useTranslation()
  const label = useNasabahLabels()
  const [page, setPage] = useState(1)
  const [logType, setLogType] = useState(-1)
  const [csLoginId, setCsLoginId] = useState('')
  const [loginId, setLoginId] = useState('')
  const filter = {
    logType,
    csLoginId: useDebounced(csLoginId.trim(), 300),
    loginId: useDebounced(loginId.trim(), 300),
  }
  const logs = useCsLogs(page, filter, true)
  const rows = logs.data?.rows ?? []

  return (
    <div className="flex flex-col gap-3">
      <div className="flex flex-wrap items-center gap-2">
        <Select
          value={String(logType)}
          onValueChange={(value) => {
            setLogType(Number(value))
            setPage(1)
          }}
        >
          <SelectTrigger className="h-8 w-full sm:w-64" aria-label={t('nasabah.csLogs.typeLabel')}>
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value={ALL}>{t('nasabah.csLogs.allTypes')}</SelectItem>
            {csLogTypes.map((_, value) => (
              <SelectItem key={value} value={String(value)}>
                {label.logType(value)}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
        <div className="relative w-full sm:w-48">
          <SearchIcon className="pointer-events-none absolute top-2 left-2.5 size-4 text-muted-foreground" />
          <Input
            type="search"
            value={csLoginId}
            placeholder={t('nasabah.csLogs.searchCs')}
            aria-label={t('nasabah.csLogs.searchCs')}
            className="h-8 pl-8"
            onChange={(event) => {
              setCsLoginId(event.target.value)
              setPage(1)
            }}
          />
        </div>
        <Input
          type="search"
          value={loginId}
          placeholder={t('nasabah.csLogs.searchLogin')}
          aria-label={t('nasabah.csLogs.searchLogin')}
          className="h-8 w-full sm:w-48"
          onChange={(event) => {
            setLoginId(event.target.value)
            setPage(1)
          }}
        />
      </div>
      {logs.data ? (
        <div className={cn('flex flex-col gap-3 transition-opacity', logs.isPlaceholderData && 'opacity-60')}>
          {rows.length > 0 ? (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>{t('nasabah.csLogs.colTime')}</TableHead>
                  <TableHead>{t('nasabah.csLogs.colCs')}</TableHead>
                  <TableHead>{t('nasabah.csLogs.colType')}</TableHead>
                  <TableHead>{t('nasabah.csLogs.colLogin')}</TableHead>
                  <TableHead>{t('nasabah.csLogs.colApproval')}</TableHead>
                  <TableHead>{t('nasabah.csLogs.colDesc')}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {rows.map((row, index) => {
                  const description = (row.LogDesc ?? '').trim()
                  return (
                    <TableRow key={row.LogId ?? `${row.LogTime}-${index}`}>
                      <TableCell className="tabular text-xs whitespace-nowrap text-muted-foreground">
                        {legacyStamp(row.LogTime, 'd MMM yyyy, HH.mm.ss')}
                      </TableCell>
                      <TableCell className="font-mono text-xs">
                        {(row.CSLoginId ?? '').trim() || '–'}
                      </TableCell>
                      <TableCell className="text-xs">{label.logType(row.LogType)}</TableCell>
                      <TableCell className="font-mono text-xs">{(row.LoginId ?? '').trim() || '–'}</TableCell>
                      <TableCell className="tabular text-xs">
                        {row.ApprovalId > 0 ? `#${row.ApprovalId}` : '–'}
                      </TableCell>
                      <TableCell className="max-w-80 truncate text-xs" title={description || undefined}>
                        {description || '–'}
                      </TableCell>
                    </TableRow>
                  )
                })}
              </TableBody>
            </Table>
          ) : (
            <p className="border-y py-6 text-center text-row text-muted-foreground">
              {t('nasabah.csLogs.empty')}
            </p>
          )}
          <Pager
            page={logs.data.page}
            totalPages={logs.data.totalPages}
            summary={t('nasabah.csLogs.count', { count: logs.data.total })}
            onPage={setPage}
          />
        </div>
      ) : logs.isError ? (
        <ErrorState error={logs.error} onRetry={() => void logs.refetch()} />
      ) : (
        <ListSkeleton rows={8} />
      )}
    </div>
  )
}
