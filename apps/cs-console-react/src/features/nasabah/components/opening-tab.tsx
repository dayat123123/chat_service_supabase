import { ChevronRightIcon, MailIcon, SearchIcon, XIcon } from 'lucide-react'
import { useId, useState } from 'react'
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
import { groupOpenings, type OpeningGroup } from '../logic'
import type { OpeningAccount } from '../types'
import { Confirm } from './confirm'
import { Pager } from './pager'

const rowKey = (row: OpeningAccount) => `${row.LoginId.trim().toLowerCase()}|${row.CustId.trim()}`
const hasEmail = (row: OpeningAccount) => Boolean((row.Email ?? '').trim())

type Selection = {
  picked: Map<string, OpeningAccount>
  toggle: (rows: OpeningAccount[], on: boolean) => void
  send: (row: OpeningAccount) => void
}

function AccountsTable({
  loginId,
  rows,
  selection,
}: {
  loginId: string
  rows: OpeningAccount[]
  selection: Selection
}) {
  const { t } = useTranslation()
  const eligible = rows.filter(hasEmail)
  const chosen = eligible.filter((row) => selection.picked.has(rowKey(row)))
  return (
    <Table aria-label={t('nasabah.opening.accountsOf', { loginId })} className="bg-background">
      <TableHeader>
        <TableRow>
          <TableHead className="w-8">
            <Checkbox
              checked={
                eligible.length > 0 && chosen.length === eligible.length
                  ? true
                  : chosen.length > 0
                    ? 'indeterminate'
                    : false
              }
              disabled={eligible.length === 0}
              aria-label={t('nasabah.opening.selectGroup', { loginId })}
              onCheckedChange={(value) => selection.toggle(eligible, value === true)}
            />
          </TableHead>
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
          <TableRow key={rowKey(row)} data-state={selection.picked.has(rowKey(row)) ? 'selected' : undefined}>
            <TableCell>
              <Checkbox
                checked={selection.picked.has(rowKey(row))}
                disabled={!hasEmail(row)}
                aria-label={t('nasabah.opening.select', {
                  loginId: row.LoginId.trim(),
                  custId: row.CustId.trim(),
                })}
                onCheckedChange={(value) => selection.toggle([row], value === true)}
              />
            </TableCell>
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
                aria-label={`${t('nasabah.opening.send')} ${row.LoginId.trim()} ${row.CustId.trim()}`}
                onClick={() => selection.send(row)}
              >
                <MailIcon />
                {t('nasabah.opening.send')}
              </Button>
            </TableCell>
          </TableRow>
        ))}
      </TableBody>
    </Table>
  )
}

function GroupRow({
  group,
  continues,
  selection,
}: {
  group: OpeningGroup<OpeningAccount>
  continues: 'previous' | 'next' | null
  selection: Selection
}) {
  const { t } = useTranslation()
  const panelId = useId()
  const [open, setOpen] = useState(false)
  const rows = group.rows
  const picked = rows.filter((row) => selection.picked.has(rowKey(row))).length
  const preview = rows.slice(0, 3).map((row) => row.CustId.trim())
  const toggle = () => setOpen((value) => !value)

  return (
    <>
      <TableRow className={cn('cursor-pointer', open && 'bg-subtle')} onClick={toggle}>
        <TableCell>
          <button
            type="button"
            aria-expanded={open}
            aria-controls={open ? panelId : undefined}
            aria-label={t('nasabah.opening.toggle', { loginId: group.loginId })}
            className="inline-flex items-center gap-1.5 rounded-sm font-mono text-xs outline-none focus-visible:ring-2 focus-visible:ring-ring/50"
            onClick={(event) => {
              event.stopPropagation()
              toggle()
            }}
          >
            <ChevronRightIcon
              className={cn('size-4 transition-transform', open && 'rotate-90')}
              aria-hidden="true"
            />
            {group.loginId}
          </button>
        </TableCell>
        <TableCell className="max-w-64 truncate">
          {group.emails[0] ?? '–'}
          {group.emails.length > 1 ? (
            <span className="ml-1 text-xs text-muted-foreground">+{group.emails.length - 1}</span>
          ) : null}
        </TableCell>
        <TableCell className="tabular text-xs">
          {t('nasabah.opening.accounts', { count: rows.length })}
          {picked > 0 ? (
            <span className="ml-2 text-muted-foreground">
              {t('nasabah.opening.selected', { count: picked })}
            </span>
          ) : null}
        </TableCell>
        <TableCell className="max-w-72 truncate font-mono text-xs text-muted-foreground">
          {preview.join(', ')}
          {rows.length > preview.length ? ', …' : ''}
        </TableCell>
      </TableRow>
      {open ? (
        <TableRow id={panelId} className="hover:bg-transparent">
          <TableCell colSpan={4} className="bg-subtle p-3">
            <div className="flex flex-col gap-2">
              <AccountsTable loginId={group.loginId} rows={rows} selection={selection} />
              {continues ? (
                <p className="text-xs text-muted-foreground">
                  {continues === 'previous'
                    ? t('nasabah.opening.continuesPrevious', { loginId: group.loginId })
                    : t('nasabah.opening.continuesNext', { loginId: group.loginId })}
                </p>
              ) : null}
            </div>
          </TableCell>
        </TableRow>
      ) : null}
    </>
  )
}

export function OpeningTab() {
  const { t } = useTranslation()
  const [page, setPage] = useState(1)
  const [loginId, setLoginId] = useState('')
  const [custId, setCustId] = useState('')
  const [target, setTarget] = useState<OpeningAccount | null>(null)
  const [picked, setPicked] = useState<Map<string, OpeningAccount>>(() => new Map())
  const [confirmBatch, setConfirmBatch] = useState(false)
  const [progress, setProgress] = useState<{ done: number; total: number } | null>(null)
  const filter = { loginId: useDebounced(loginId.trim(), 300), custId: useDebounced(custId.trim(), 300) }
  const openings = useOpenings(page, filter, true)
  const send = useSendOpeningEmail()
  const groups = groupOpenings(openings.data?.rows ?? [])

  const resetSelection = () => setPicked(new Map())
  const selection: Selection = {
    picked,
    toggle: (rows, on) =>
      setPicked((current) => {
        const next = new Map(current)
        for (const row of rows) {
          if (on) next.set(rowKey(row), row)
          else next.delete(rowKey(row))
        }
        return next
      }),
    send: setTarget,
  }

  const sendBatch = async () => {
    const queue = [...picked.values()]
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
        {picked.size > 0 ? (
          <div className="ml-auto flex items-center gap-2">
            <span className="tabular text-xs text-muted-foreground" role="status">
              {t('nasabah.opening.selected', { count: picked.size })}
            </span>
            <Button size="sm" variant="ghost" onClick={resetSelection}>
              <XIcon />
              {t('nasabah.opening.clear')}
            </Button>
            <Button size="sm" onClick={() => setConfirmBatch(true)}>
              <MailIcon />
              {t('nasabah.opening.sendSelected', { count: picked.size })}
            </Button>
          </div>
        ) : null}
      </div>
      {openings.data ? (
        <div
          className={cn('flex flex-col gap-3 transition-opacity', openings.isPlaceholderData && 'opacity-60')}
        >
          {groups.length > 0 ? (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>{t('nasabah.opening.colLoginId')}</TableHead>
                  <TableHead>{t('nasabah.opening.colEmail')}</TableHead>
                  <TableHead>{t('nasabah.opening.colAccounts')}</TableHead>
                  <TableHead>{t('nasabah.opening.colPreview')}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {groups.map((group, index) => (
                  <GroupRow
                    key={group.key}
                    group={group}
                    continues={
                      index === 0 && openings.data.page > 1
                        ? 'previous'
                        : index === groups.length - 1 && openings.data.page < openings.data.totalPages
                          ? 'next'
                          : null
                    }
                    selection={selection}
                  />
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
            summary={t('nasabah.opening.groupCount', { logins: groups.length, count: openings.data.total })}
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
        title={t('nasabah.opening.batchTitle', { count: picked.size })}
        body={t('nasabah.opening.batchBody')}
        action={
          progress
            ? t('nasabah.opening.batchProgress', { done: progress.done, total: progress.total })
            : t('nasabah.opening.sendSelected', { count: picked.size })
        }
        pending={progress !== null}
        onConfirm={() => void sendBatch()}
        onClose={() => setConfirmBatch(false)}
      />
    </div>
  )
}
