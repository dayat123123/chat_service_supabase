import { LoaderCircleIcon, SearchIcon } from 'lucide-react'
import { useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { ErrorState } from '@/components/states'
import { Button } from '@/components/ui/button'
import { Checkbox } from '@/components/ui/controls'
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { useDebounced } from '@/hooks/use-now'
import { errorText } from '@/lib/error-text'

import { useAccountCatalog, useSubmitApproval } from '../hooks'
import { approvalPayload, formFromUser } from '../logic'
import type { CatalogAccount, OnlineUser } from '../types'

const LIMIT = 50

function matches(account: CatalogAccount, query: string) {
  const q = query.toLowerCase()
  return account.CustId.toLowerCase().includes(q) || account.Name.toLowerCase().includes(q)
}

function LinkForm({ user, links, onDone }: { user: OnlineUser; links: string[]; onDone: () => void }) {
  const { t } = useTranslation()
  const catalog = useAccountCatalog(true)
  const submit = useSubmitApproval()
  const [selected, setSelected] = useState<string[]>(links)
  const [query, setQuery] = useState('')
  const debounced = useDebounced(query.trim(), 200)
  const accounts = useMemo(() => {
    const all = (catalog.data ?? []).map((a) => ({ ...a, CustId: a.CustId.trim() })).filter((a) => a.CustId)
    const chosen = all.filter((a) => selected.includes(a.CustId))
    const rest = all.filter((a) => !selected.includes(a.CustId) && (!debounced || matches(a, debounced)))
    return { shown: [...chosen, ...rest.slice(0, LIMIT)], total: rest.length }
  }, [catalog.data, selected, debounced])
  const changed = selected.length !== links.length || selected.some((id) => !links.includes(id))

  return (
    <form
      className="flex min-h-0 flex-col gap-3"
      onSubmit={(event) => {
        event.preventDefault()
        if (!changed) return
        submit.mutate(approvalPayload(2, { ...formFromUser(user, links), links: selected }, links), {
          onSuccess: () => {
            toast.success(t('nasabah.toast.submitted'))
            onDone()
          },
          onError: (error) => toast.error(errorText(error)),
        })
      }}
    >
      <div className="relative">
        <SearchIcon className="pointer-events-none absolute top-2.5 left-2.5 size-4 text-muted-foreground" />
        <Input
          type="search"
          autoFocus
          value={query}
          placeholder={t('nasabah.link.search')}
          aria-label={t('nasabah.link.search')}
          className="pl-8"
          onChange={(event) => setQuery(event.target.value)}
        />
      </div>
      <p className="tabular text-xs text-muted-foreground" role="status">
        {t('nasabah.link.selected', { count: selected.length })}
      </p>
      <div className="max-h-[50vh] min-h-40 overflow-y-auto border-y">
        {catalog.isError ? (
          <ErrorState error={catalog.error} onRetry={() => void catalog.refetch()} />
        ) : !catalog.data ? (
          <p className="flex items-center gap-2 p-3 text-row text-muted-foreground">
            <LoaderCircleIcon className="size-4 animate-spin" />
            {t('nasabah.link.loading')}
          </p>
        ) : accounts.shown.length === 0 ? (
          <p className="p-3 text-row text-muted-foreground">{t('nasabah.link.empty')}</p>
        ) : (
          <ul className="flex flex-col">
            {accounts.shown.map((account) => (
              <li key={account.CustId} className="border-b last:border-b-0">
                <label className="flex cursor-pointer items-center gap-3 px-3 py-2 hover:bg-subtle">
                  <Checkbox
                    checked={selected.includes(account.CustId)}
                    onCheckedChange={(value) =>
                      setSelected((current) =>
                        value === true
                          ? [...current, account.CustId]
                          : current.filter((id) => id !== account.CustId),
                      )
                    }
                  />
                  <span className="font-mono text-xs">{account.CustId}</span>
                  <span className="min-w-0 flex-1 truncate text-row">{account.Name}</span>
                  <span className="text-xs text-muted-foreground">{account.Branch}</span>
                </label>
              </li>
            ))}
          </ul>
        )}
      </div>
      {accounts.total > LIMIT ? (
        <p className="text-xs text-muted-foreground">
          {t('nasabah.link.more', { shown: LIMIT, total: accounts.total })}
        </p>
      ) : null}
      <DialogFooter>
        <Button type="button" variant="ghost" disabled={submit.isPending} onClick={onDone}>
          {t('app.cancel')}
        </Button>
        <Button type="submit" disabled={!changed || submit.isPending}>
          {submit.isPending ? <LoaderCircleIcon className="animate-spin" /> : null}
          {t('nasabah.link.submit')}
        </Button>
      </DialogFooter>
    </form>
  )
}

export function LinkDialog({
  user,
  links,
  open,
  onClose,
}: {
  user: OnlineUser
  links: string[]
  open: boolean
  onClose: () => void
}) {
  const { t } = useTranslation()
  return (
    <Dialog open={open} onOpenChange={(next) => !next && onClose()}>
      <DialogContent className="sm:max-w-xl" closeLabel={t('app.close')} aria-describedby={undefined}>
        <DialogHeader>
          <DialogTitle>{t('nasabah.link.title', { loginId: user.LoginId })}</DialogTitle>
        </DialogHeader>
        {open ? <LinkForm user={user} links={links} onDone={onClose} /> : null}
      </DialogContent>
    </Dialog>
  )
}
