import { LoaderCircleIcon, SearchIcon } from 'lucide-react'
import { useId, useMemo, useState, type ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { ErrorState } from '@/components/states'
import { Button } from '@/components/ui/button'
import { Checkbox } from '@/components/ui/controls'
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { useDebounced } from '@/hooks/use-now'
import { errorText } from '@/lib/error-text'
import { cn } from '@/lib/utils'

import { useAccountCatalog, useSubmitApproval } from '../hooks'
import { approvalPayload, formFromUser } from '../logic'
import type { CatalogAccount, OnlineUser } from '../types'

const LIMIT = 50

function matches(account: CatalogAccount, query: string) {
  const q = query.toLowerCase()
  return account.CustId.toLowerCase().includes(q) || account.Name.toLowerCase().includes(q)
}

function Section({ title, children }: { title: string; children: ReactNode }) {
  const id = useId()
  return (
    <section aria-labelledby={id} className="flex flex-col border-t first:border-t-0">
      <h3
        id={id}
        className="sticky top-0 z-10 border-b bg-background px-3 py-1.5 text-xs font-medium text-muted-foreground"
      >
        {title}
      </h3>
      {children}
    </section>
  )
}

function AccountRow({
  id,
  account,
  name,
  checked,
  note,
  onChange,
}: {
  id: string
  account: CatalogAccount | undefined
  name?: string
  checked: boolean
  note?: string
  onChange: (checked: boolean) => void
}) {
  return (
    <li className="border-b last:border-b-0">
      <label className="flex cursor-pointer items-center gap-3 px-3 py-2 hover:bg-subtle">
        <Checkbox checked={checked} onCheckedChange={(value) => onChange(value === true)} />
        <span className={cn('font-mono text-xs', note && !checked && 'line-through')}>{id}</span>
        <span className={cn('min-w-0 flex-1 truncate text-row', note && !checked && 'text-muted-foreground')}>
          {account?.Name || name || '–'}
        </span>
        {note ? <span className="text-xs font-medium text-warning">{note}</span> : null}
        <span className="text-xs text-muted-foreground">{account?.Branch}</span>
      </label>
    </li>
  )
}

function LinkForm({
  user,
  links,
  names,
  onDone,
}: {
  user: OnlineUser
  links: string[]
  names: Record<string, string>
  onDone: () => void
}) {
  const { t } = useTranslation()
  const catalog = useAccountCatalog(true)
  const submit = useSubmitApproval()
  const [selected, setSelected] = useState<string[]>(links)
  const [query, setQuery] = useState('')
  const debounced = useDebounced(query.trim(), 200)
  const byId = useMemo(
    () => new Map((catalog.data ?? []).map((a) => [a.CustId.trim(), { ...a, CustId: a.CustId.trim() }])),
    [catalog.data],
  )
  const added = selected.filter((id) => !links.includes(id))
  const removed = links.filter((id) => !selected.includes(id))
  const available = useMemo(() => {
    const rest = [...byId.values()].filter(
      (a) =>
        a.CustId &&
        !links.includes(a.CustId) &&
        !selected.includes(a.CustId) &&
        (!debounced || matches(a, debounced)),
    )
    return { shown: rest.slice(0, LIMIT), total: rest.length }
  }, [byId, links, selected, debounced])
  const toggle = (id: string, on: boolean) =>
    setSelected((current) => (on ? [...current, id] : current.filter((item) => item !== id)))

  return (
    <form
      className="flex min-h-0 flex-col gap-3"
      onSubmit={(event) => {
        event.preventDefault()
        if (added.length === 0 && removed.length === 0) return
        submit.mutate(approvalPayload(2, { ...formFromUser(user, links), links: selected }, links), {
          onSuccess: () => {
            toast.success(t('nasabah.toast.submitted'))
            onDone()
          },
          onError: (error) => toast.error(errorText(error)),
        })
      }}
    >
      <p className="tabular text-xs text-muted-foreground" role="status">
        {t('nasabah.link.summary', {
          total: links.length - removed.length + added.length,
          added: added.length,
          removed: removed.length,
        })}
      </p>
      <div className="max-h-[60vh] min-h-40 overflow-y-auto border-y">
        {catalog.isError ? (
          <ErrorState error={catalog.error} onRetry={() => void catalog.refetch()} />
        ) : !catalog.data ? (
          <p className="flex items-center gap-2 p-3 text-row text-muted-foreground">
            <LoaderCircleIcon className="size-4 animate-spin" />
            {t('nasabah.link.loading')}
          </p>
        ) : (
          <div className="flex flex-col">
            <Section title={t('nasabah.link.linkedTitle', { count: links.length })}>
              {links.length === 0 ? (
                <p className="px-3 py-2 text-row text-muted-foreground">{t('nasabah.link.linkedEmpty')}</p>
              ) : (
                <ul className="flex flex-col">
                  {links.map((id) => (
                    <AccountRow
                      key={id}
                      id={id}
                      account={byId.get(id)}
                      name={names[id]}
                      checked={selected.includes(id)}
                      note={selected.includes(id) ? undefined : t('nasabah.link.willUnlink')}
                      onChange={(on) => toggle(id, on)}
                    />
                  ))}
                </ul>
              )}
            </Section>
            {added.length > 0 ? (
              <Section title={t('nasabah.link.addedTitle', { count: added.length })}>
                <ul className="flex flex-col">
                  {added.map((id) => (
                    <AccountRow
                      key={id}
                      id={id}
                      account={byId.get(id)}
                      checked
                      onChange={(on) => toggle(id, on)}
                    />
                  ))}
                </ul>
              </Section>
            ) : null}
            <Section title={t('nasabah.link.availableTitle')}>
              <div className="relative border-b p-2">
                <SearchIcon className="pointer-events-none absolute top-4 left-4.5 size-4 text-muted-foreground" />
                <Input
                  type="search"
                  value={query}
                  placeholder={t('nasabah.link.search')}
                  aria-label={t('nasabah.link.search')}
                  className="pl-8"
                  onChange={(event) => setQuery(event.target.value)}
                />
              </div>
              {available.shown.length === 0 ? (
                <p className="px-3 py-2 text-row text-muted-foreground">{t('nasabah.link.empty')}</p>
              ) : (
                <ul className="flex flex-col">
                  {available.shown.map((account) => (
                    <AccountRow
                      key={account.CustId}
                      id={account.CustId}
                      account={account}
                      checked={false}
                      onChange={(on) => toggle(account.CustId, on)}
                    />
                  ))}
                </ul>
              )}
              {available.total > LIMIT ? (
                <p className="border-t px-3 py-2 text-xs text-muted-foreground">
                  {t('nasabah.link.more', { shown: LIMIT, total: available.total })}
                </p>
              ) : null}
            </Section>
          </div>
        )}
      </div>
      <DialogFooter>
        <Button type="button" variant="ghost" disabled={submit.isPending} onClick={onDone}>
          {t('app.cancel')}
        </Button>
        <Button type="submit" disabled={(added.length === 0 && removed.length === 0) || submit.isPending}>
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
  names = {},
  open,
  onClose,
}: {
  user: OnlineUser
  links: string[]
  names?: Record<string, string>
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
        {open ? <LinkForm user={user} links={links} names={names} onDone={onClose} /> : null}
      </DialogContent>
    </Dialog>
  )
}
