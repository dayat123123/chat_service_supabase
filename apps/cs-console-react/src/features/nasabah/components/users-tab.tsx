import { CircleAlertIcon, PlusIcon, SearchIcon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'

import { ErrorState, ListSkeleton } from '@/components/states'
import { Button } from '@/components/ui/button'
import { Switch } from '@/components/ui/controls'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { useAgent } from '@/features/auth/hooks'
import { useDebounced } from '@/hooks/use-now'
import { cn } from '@/lib/utils'

import { useOnlineUsers } from '../hooks'
import { legacyStamp, useNasabahLabels } from '../labels'
import { canEditUser, incompleteFields } from '../logic'
import type { OnlineUser } from '../types'
import { Pager } from './pager'
import { UserDialog } from './user-dialog'
import { UserPanel } from './user-panel'

const statusTone: Record<number, string> = {
  0: 'text-muted-foreground',
  1: 'text-success',
  2: 'text-warning',
  3: 'text-danger',
}

export function UsersTab({ initialQuery = '' }: { initialQuery?: string }) {
  const { t } = useTranslation()
  const agent = useAgent()
  const label = useNasabahLabels()
  const [query, setQuery] = useState(initialQuery)
  const [page, setPage] = useState(1)
  const [selected, setSelected] = useState<OnlineUser | null>(null)
  const [creating, setCreating] = useState(false)
  const [onlyIncomplete, setOnlyIncomplete] = useState(false)
  const debounced = useDebounced(query.trim(), 300)
  const users = useOnlineUsers(page, debounced)
  const all = users.data?.rows ?? []
  const rows = onlyIncomplete ? all.filter((user) => incompleteFields(user).length > 0) : all
  const current = selected ? (all.find((user) => user.LoginId === selected.LoginId) ?? selected) : null

  return (
    <div className="flex flex-col gap-3">
      <div className="flex flex-wrap items-center gap-2">
        <div className="relative w-full sm:w-80">
          <SearchIcon className="pointer-events-none absolute top-2 left-2.5 size-4 text-muted-foreground" />
          <Input
            type="search"
            value={query}
            placeholder={t('nasabah.users.searchPlaceholder')}
            aria-label={t('nasabah.users.searchPlaceholder')}
            className="h-8 pl-8"
            onChange={(event) => {
              setQuery(event.target.value)
              setPage(1)
            }}
          />
        </div>
        <div className="flex items-center gap-2">
          <Switch id="nasabah-only-incomplete" checked={onlyIncomplete} onCheckedChange={setOnlyIncomplete} />
          <Label htmlFor="nasabah-only-incomplete" className="text-row font-normal">
            {t('nasabah.incomplete.filter')}
          </Label>
        </div>
        {canEditUser(agent.nasabah_permissions, null) ? (
          <Button size="sm" className="ml-auto" onClick={() => setCreating(true)}>
            <PlusIcon />
            {t('nasabah.users.submitNew')}
          </Button>
        ) : null}
      </div>
      {users.data ? (
        <div
          className={cn('flex flex-col gap-3 transition-opacity', users.isPlaceholderData && 'opacity-60')}
        >
          {rows.length > 0 ? (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>{t('nasabah.users.colLoginId')}</TableHead>
                  <TableHead>{t('nasabah.users.colType')}</TableHead>
                  <TableHead>{t('nasabah.users.colEmail')}</TableHead>
                  <TableHead>{t('nasabah.users.colPhone')}</TableHead>
                  <TableHead>{t('nasabah.users.colStatus')}</TableHead>
                  <TableHead>{t('nasabah.users.colCreated')}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {rows.map((user) => {
                  const missing = incompleteFields(user)
                  const missingText = t('nasabah.incomplete.rowLabel', {
                    fields: missing.map(label.incomplete).join(', '),
                  })
                  return (
                    <TableRow key={user.LoginId} className="cursor-pointer" onClick={() => setSelected(user)}>
                      <TableCell>
                        <span className="flex items-center gap-1.5">
                          <button
                            type="button"
                            className="rounded-sm font-mono text-xs outline-none focus-visible:ring-2 focus-visible:ring-ring/50"
                            aria-label={t('nasabah.users.open', { loginId: user.LoginId })}
                            onClick={(event) => {
                              event.stopPropagation()
                              setSelected(user)
                            }}
                          >
                            {user.LoginId}
                          </button>
                          {missing.length > 0 ? (
                            <CircleAlertIcon
                              role="img"
                              aria-label={missingText}
                              className="size-3.5 shrink-0 text-warning"
                            >
                              <title>{missingText}</title>
                            </CircleAlertIcon>
                          ) : null}
                        </span>
                      </TableCell>
                      <TableCell>{label.loginType(user.LoginType)}</TableCell>
                      <TableCell className="max-w-64 truncate">{user.Email || '–'}</TableCell>
                      <TableCell>{user.PhoneNumber || '–'}</TableCell>
                      <TableCell className={cn('text-xs font-medium', statusTone[user.Status])}>
                        {label.status(user.Status)}
                      </TableCell>
                      <TableCell className="text-xs text-muted-foreground">
                        {legacyStamp(user.Created)}
                      </TableCell>
                    </TableRow>
                  )
                })}
              </TableBody>
            </Table>
          ) : (
            <p className="border-y py-6 text-center text-row text-muted-foreground">
              {t('nasabah.users.empty')}
            </p>
          )}
          {onlyIncomplete ? (
            <p className="text-xs text-muted-foreground">{t('nasabah.incomplete.pageNote')}</p>
          ) : null}
          <Pager
            page={users.data.page}
            totalPages={users.data.totalPages}
            summary={t('nasabah.users.count', { count: users.data.total })}
            onPage={setPage}
          />
        </div>
      ) : users.isError ? (
        <ErrorState error={users.error} onRetry={() => void users.refetch()} />
      ) : (
        <ListSkeleton rows={6} />
      )}
      <UserPanel user={current} onClose={() => setSelected(null)} />
      <UserDialog open={creating} user={null} links={[]} onClose={() => setCreating(false)} />
    </div>
  )
}
