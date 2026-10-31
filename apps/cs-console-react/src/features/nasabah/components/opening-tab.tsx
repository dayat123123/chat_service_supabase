import { MailIcon, SearchIcon, XIcon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { ErrorState, ListSkeleton } from '@/components/states'
import { Button } from '@/components/ui/button'
import { Checkbox } from '@/components/ui/controls'
import { Input } from '@/components/ui/input'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { useDebounced } from '@/hooks/use-now'
import { errorText } from '@/lib/error-text'
import { cn } from '@/lib/utils'

import { useOpenings, useSendOpeningEmail } from '../hooks'
import type { OpeningAccount } from '../types'
import { Confirm } from './confirm'
import { Pager } from './pager'

const rowKey = (row: OpeningAccount) => `${row.LoginId.trim()}|${row.CustId.trim()}`
const hasEmail = (row: OpeningAccount) => Boolean((row.Email ?? '').trim())

export function OpeningTab() {
  const { t } = useTranslation()
  const [page, setPage] = useState(1)
  const [loginId, setLoginId] = useState('')
  const [custId, setCustId] = useState('')
  const [target, setTarget] = useState<OpeningAccount | null>(null)
  const [picked, setPicked] = useState<string[]>([])
  const [confirmBatch, setConfirmBatch] = useState(false)
  const [progress, setProgress] = useState<{ done: number; total: number } | null>(null)
  const filter = { loginId: useDebounced(loginId.trim(), 300), custId: useDebounced(custId.trim(), 300) }
  const openings = useOpenings(page, filter, true)
  const send = useSendOpeningEmail()
  const rows = openings.data?.rows ?? []
  const eligible = rows.filter(hasEmail)
  const chosen = eligible.filter((row) => picked.includes(rowKey(row)))
  const allPicked = eligible.length > 0 && chosen.length === eligible.length

  const resetSelection = () => setPicked([])
  const toggle = (row: OpeningAccount, on: boolean) =>
    setPicked((current) => (on ? [...current, rowKey(row)] : current.filter((key) => key !== rowKey(row))))

  const sendBatch = async () => {
    const queue = [...chosen]
    let sent = 0
    const failures: string[] = []
    setProgress({ done: 0, total: queue.length })
    for (const row of queue) {
      try {
        await send.mutateAsync(row)
        sent++
      } catch (error) {
        failures.push(`${row.LoginId.trim()}: ${errorText(error)}`)
      }
      setProgress({ done: sent + failures.length, total: queue.length })
    }
    setProgress(null)
    setConfirmBatch(false)
    resetSelection()
    if (failures.length === 0) toast.success(t('nasabah.opening.batchDone', { count: sent }))
    else
      toast.warning(t('nasabah.opening.batchPartial', { sent, failed: failures.length, first: failures[0] }))
  }

  return (
    <div className="flex flex-col gap-3">
      <div className="flex flex-wrap items-center gap-2">
        <div className="relative w-full sm:w-52">
          <SearchIcon className="pointer-events-none absolute top-2 left-2.5 size-4 text-muted-foreground" />
          <Input
            type="search"
            value={loginId}
            placeholder={t('nasabah.opening.searchLoginId')}
            aria-label={t('nasabah.opening.searchLoginId')}
            className="h-8 pl-8"
            onChange={(event) => {
              setLoginId(event.target.value)
              setPage(1)
              resetSelection()
            }}
          />
        </div>
        <Input
          type="search"
          value={custId}
          placeholder={t('nasabah.opening.searchCustId')}
          aria-label={t('nasabah.opening.searchCustId')}
          className="h-8 w-full sm:w-44"
          onChange={(event) => {
            setCustId(event.target.value)
            setPage(1)
            resetSelection()
          }}
        />
        {chosen.length > 0 ? (
          <div className="ml-auto flex items-center gap-2">
            <span className="tabular text-xs text-muted-foreground" role="status">
              {t('nasabah.opening.selected', { count: chosen.length })}
            </span>
            <Button size="sm" variant="ghost" onClick={resetSelection}>
              <XIcon />
              {t('nasabah.opening.clear')}
            </Button>
            <Button size="sm" onClick={() => setConfirmBatch(true)}>
              <MailIcon />
              {t('nasabah.opening.sendSelected', { count: chosen.length })}
            </Button>
          </div>
        ) : null}
      </div>
      {openings.data ? (
        <div
          className={cn('flex flex-col gap-3 transition-opacity', openings.isPlaceholderData && 'opacity-60')}
        >
          {rows.length > 0 ? (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead className="w-8">
                    <Checkbox
                      checked={allPicked ? true : chosen.length > 0 ? 'indeterminate' : false}
                      disabled={eligible.length === 0}
                      aria-label={t('nasabah.opening.selectAll')}
                      onCheckedChange={(value) => setPicked(value === true ? eligible.map(rowKey) : [])}
                    />
                  </TableHead>
                  <TableHead>{t('nasabah.opening.colLoginId')}</TableHead>
                  <TableHead>{t('nasabah.opening.colCustId')}</TableHead>
                  <TableHead>{t('nasabah.opening.colName')}</TableHead>
                  <TableHead>{t('nasabah.opening.colRdn')}</TableHead>
                  <TableHead>{t('nasabah.opening.colBank')}</TableHead>
                  <TableHead>{t('nasabah.opening.colSid')}</TableHead>
                  <TableHead>{t('nasabah.opening.colEmail')}</TableHead>
                  <TableHead className="text-right">
                    <span className="sr-only">{t('nasabah.opening.send')}</span>
                  </TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {rows.map((row) => (
                  <TableRow
                    key={rowKey(row)}
                    data-state={picked.includes(rowKey(row)) ? 'selected' : undefined}
                  >
                    <TableCell>
                      <Checkbox
                        checked={picked.includes(rowKey(row))}
                        disabled={!hasEmail(row)}
                        aria-label={t('nasabah.opening.select', {
                          loginId: row.LoginId.trim(),
                          custId: row.CustId.trim(),
                        })}
                        onCheckedChange={(value) => toggle(row, value === true)}
                      />
                    </TableCell>
                    <TableCell className="font-mono text-xs">{row.LoginId}</TableCell>
                    <TableCell className="font-mono text-xs">{row.CustId.trim()}</TableCell>
                    <TableCell className="max-w-56 truncate">{row.Name || '–'}</TableCell>
                    <TableCell className="text-xs">{row.RDNAccount || '–'}</TableCell>
                    <TableCell className="text-xs">{row.RDNBank || '–'}</TableCell>
                    <TableCell className="text-xs">{row.InvestorNo || '–'}</TableCell>
                    <TableCell className="max-w-56 truncate">{row.Email || '–'}</TableCell>
                    <TableCell className="text-right">
                      <Button
                        size="sm"
                        variant="outline"
                        disabled={!hasEmail(row)}
                        aria-label={`${t('nasabah.opening.send')} ${row.LoginId} ${row.CustId.trim()}`}
                        onClick={() => setTarget(row)}
                      >
                        <MailIcon />
                        {t('nasabah.opening.send')}
                      </Button>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          ) : (
            <p className="border-y py-6 text-center text-row text-muted-foreground">
              {t('nasabah.opening.empty')}
            </p>
          )}
          <Pager
            page={openings.data.page}
            totalPages={openings.data.totalPages}
            summary={t('nasabah.opening.count', { count: openings.data.total })}
            onPage={(next) => {
              setPage(next)
              resetSelection()
            }}
          />
        </div>
      ) : openings.isError ? (
        <ErrorState error={openings.error} onRetry={() => void openings.refetch()} />
      ) : (
        <ListSkeleton rows={6} />
      )}
      <Confirm
        open={target !== null}
        title={t('nasabah.opening.sendTitle')}
        body={t('nasabah.opening.sendBody', {
          custId: target?.CustId.trim() ?? '',
          email: target?.Email.trim() ?? '',
        })}
        action={t('nasabah.opening.send')}
        pending={send.isPending}
        onConfirm={() => {
          if (!target) return
          send.mutate(target, {
            onSuccess: () => {
              toast.success(t('nasabah.toast.emailSent', { loginId: target.LoginId }))
              setTarget(null)
            },
            onError: (error) => {
              toast.error(errorText(error))
              setTarget(null)
            },
          })
        }}
        onClose={() => setTarget(null)}
      />
      <Confirm
        open={confirmBatch}
        title={t('nasabah.opening.batchTitle', { count: chosen.length })}
        body={t('nasabah.opening.batchBody')}
        action={
          progress
            ? t('nasabah.opening.batchProgress', { done: progress.done, total: progress.total })
            : t('nasabah.opening.sendSelected', { count: chosen.length })
        }
        pending={progress !== null}
        onConfirm={() => void sendBatch()}
        onClose={() => setConfirmBatch(false)}
      />
    </div>
  )
}
