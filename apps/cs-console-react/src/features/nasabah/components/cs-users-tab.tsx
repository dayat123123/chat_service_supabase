import { PlusIcon, SearchIcon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { ErrorState, ListSkeleton } from '@/components/states'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { useDebounced } from '@/hooks/use-now'
import { cn } from '@/lib/utils'

import { useCsUsers, useGatewayInfo } from '../hooks'
import { legacyStamp, useNasabahLabels } from '../labels'
import { csFlagsOf, isServiceAccount } from '../logic'
import type { CreatedCsUser, CsUser } from '../types'
import { CsPasswordDialog, TemporaryPasswordDialog, type IssuedCsPassword } from './cs-password-dialog'
import { CsUserDialog } from './cs-user-dialog'
import { CsUserPanel, TechnicalBadge } from './cs-user-panel'
import { Pager } from './pager'

const sameLogin = (a: string, b: string) => a.trim().toLowerCase() === b.trim().toLowerCase()

export function CsUsersTab() {
  const { t } = useTranslation()
  const label = useNasabahLabels()
  const info = useGatewayInfo()
  const [loginId, setLoginId] = useState('')
  const [employeeId, setEmployeeId] = useState('')
  const [page, setPage] = useState(1)
  const [selected, setSelected] = useState<string | null>(null)
  const [snapshot, setSnapshot] = useState<CsUser | null>(null)
  const [editing, setEditing] = useState<CsUser | null | undefined>(undefined)
  const [passwordFor, setPasswordFor] = useState<string | null>(null)
  const [issued, setIssued] = useState<IssuedCsPassword | null>(null)
  const filter = {
    loginId: useDebounced(loginId.trim(), 300),
    employeeId: useDebounced(employeeId.trim(), 300),
  }
  const users = useCsUsers(page, filter, true)
  const rows = users.data?.rows ?? []
  const service = info.data?.service_login_id
  const current =
    selected === null ? null : (rows.find((row) => sameLogin(row.LoginId, selected)) ?? snapshot)

  const open = (user: CsUser) => {
    setSelected(user.LoginId)
    setSnapshot(user)
  }

  const created = (login: string, result: CreatedCsUser) => {
    if (result.TemporaryPassword) {
      setIssued({ loginId: login, password: result.TemporaryPassword })
      return
    }
    toast.warning(t('nasabah.csUsers.temporary.failed'))
    setPasswordFor(login)
  }

  return (
    <div className="flex flex-col gap-3">
      <div className="flex flex-wrap items-center gap-2">
        <div className="relative w-full sm:w-52">
          <SearchIcon className="pointer-events-none absolute top-2 left-2.5 size-4 text-muted-foreground" />
          <Input
            type="search"
            value={loginId}
            placeholder={t('nasabah.csUsers.searchLoginId')}
            aria-label={t('nasabah.csUsers.searchLoginId')}
            className="h-8 pl-8"
            onChange={(event) => {
              setLoginId(event.target.value)
              setPage(1)
            }}
          />
        </div>
        <Input
          type="search"
          value={employeeId}
          placeholder={t('nasabah.csUsers.searchEmployee')}
          aria-label={t('nasabah.csUsers.searchEmployee')}
          className="h-8 w-full sm:w-44"
          onChange={(event) => {
            setEmployeeId(event.target.value)
            setPage(1)
          }}
        />
        <Button size="sm" className="ml-auto" onClick={() => setEditing(null)}>
          <PlusIcon />
          {t('nasabah.csUsers.add')}
        </Button>
      </div>
      {users.data ? (
        <div
          className={cn('flex flex-col gap-3 transition-opacity', users.isPlaceholderData && 'opacity-60')}
        >
          {rows.length > 0 ? (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>{t('nasabah.csUsers.colLoginId')}</TableHead>
                  <TableHead>{t('nasabah.csUsers.colEmployee')}</TableHead>
                  <TableHead>{t('nasabah.csUsers.colEmail')}</TableHead>
                  <TableHead>{t('nasabah.csUsers.colFlags')}</TableHead>
                  <TableHead>{t('nasabah.csUsers.colStatus')}</TableHead>
                  <TableHead>{t('nasabah.csUsers.colLastLogin')}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {rows.map((user) => {
                  const login = (user.LoginId ?? '').trim()
                  return (
                    <TableRow key={login} className="cursor-pointer" onClick={() => open(user)}>
                      <TableCell>
                        <span className="flex flex-wrap items-center gap-2">
                          <button
                            type="button"
                            className="rounded-sm font-mono text-xs outline-none focus-visible:ring-2 focus-visible:ring-ring/50"
                            aria-label={t('nasabah.csUsers.open', { loginId: login })}
                            onClick={(event) => {
                              event.stopPropagation()
                              open(user)
                            }}
                          >
                            {login}
                          </button>
                          {isServiceAccount(login, service) ? <TechnicalBadge /> : null}
                        </span>
                      </TableCell>
                      <TableCell className="text-xs">{(user.EmployeeId ?? '').trim() || '–'}</TableCell>
                      <TableCell className="max-w-64 truncate">{(user.Email ?? '').trim() || '–'}</TableCell>
                      <TableCell className="tabular text-xs">
                        {t('nasabah.csUsers.flagsValue', { count: csFlagsOf(user.Permissions).length })}
                      </TableCell>
                      <TableCell
                        className={cn(
                          'text-xs font-medium',
                          user.Status === 1 ? 'text-success' : 'text-muted-foreground',
                        )}
                      >
                        {label.csStatus(user.Status)}
                      </TableCell>
                      <TableCell className="text-xs text-muted-foreground">
                        {(user.LastLogin ?? '').trim()
                          ? legacyStamp(user.LastLogin)
                          : t('nasabah.csUsers.never')}
                      </TableCell>
                    </TableRow>
                  )
                })}
              </TableBody>
            </Table>
          ) : (
            <p className="border-y py-6 text-center text-row text-muted-foreground">
              {t('nasabah.csUsers.empty')}
            </p>
          )}
          <Pager
            page={users.data.page}
            totalPages={users.data.totalPages}
            summary={t('nasabah.csUsers.count', { count: users.data.total })}
            onPage={setPage}
          />
        </div>
      ) : users.isError ? (
        <ErrorState error={users.error} onRetry={() => void users.refetch()} />
      ) : (
        <ListSkeleton rows={6} />
      )}
      <CsUserPanel
        user={current}
        technical={current !== null && isServiceAccount(current.LoginId, service)}
        actor={info.data?.actor}
        onEdit={() => setEditing(current)}
        onPassword={() => setPasswordFor(current ? current.LoginId.trim() : null)}
        onClose={() => setSelected(null)}
      />
      <CsUserDialog
        open={editing !== undefined}
        user={editing ?? null}
        onClose={() => setEditing(undefined)}
        onCreated={created}
      />
      <CsPasswordDialog loginId={passwordFor} onClose={() => setPasswordFor(null)} />
      <TemporaryPasswordDialog issued={issued} onClose={() => setIssued(null)} />
    </div>
  )
}
