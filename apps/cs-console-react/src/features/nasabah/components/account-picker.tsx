import type { UseQueryResult } from '@tanstack/react-query'
import { LoaderCircleIcon, SearchIcon } from 'lucide-react'
import { useId, useMemo, useState, type ReactNode } from 'react'
import { useTranslation } from 'react-i18next'

import { ErrorState } from '@/components/states'
import { Checkbox } from '@/components/ui/controls'
import { Input } from '@/components/ui/input'
import { useDebounced } from '@/hooks/use-now'
import { cn } from '@/lib/utils'

import type { CatalogAccount } from '../types'

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

export function AccountPicker({
  catalog,
  linked,
  names = {},
  selected,
  onChange,
  showEmptyLinked = false,
  className,
}: {
  catalog: UseQueryResult<CatalogAccount[]>
  linked: string[]
  names?: Record<string, string>
  showEmptyLinked?: boolean
  selected: string[]
  onChange: (selected: string[]) => void
  className?: string
}) {
  const { t } = useTranslation()
  const [query, setQuery] = useState('')
  const debounced = useDebounced(query.trim(), 200)
  const byId = useMemo(
    () => new Map((catalog.data ?? []).map((a) => [a.CustId.trim(), { ...a, CustId: a.CustId.trim() }])),
    [catalog.data],
  )
  const added = selected.filter((id) => !linked.includes(id))
  const removed = linked.filter((id) => !selected.includes(id))
  const available = useMemo(() => {
    const rest = [...byId.values()].filter(
      (a) =>
        a.CustId &&
        !linked.includes(a.CustId) &&
        !selected.includes(a.CustId) &&
        (!debounced || matches(a, debounced)),
    )
    return { shown: rest.slice(0, LIMIT), total: rest.length }
  }, [byId, linked, selected, debounced])
  const toggle = (id: string, on: boolean) =>
    onChange(on ? [...selected, id] : selected.filter((item) => item !== id))

  return (
    <div className="flex min-h-0 flex-1 flex-col gap-2">
      {linked.length > 0 || added.length > 0 ? (
        <p className="tabular text-xs text-muted-foreground" role="status">
          {t('nasabah.link.summary', {
            total: linked.length - removed.length + added.length,
            added: added.length,
            removed: removed.length,
          })}
        </p>
      ) : null}
      <div className={cn('relative min-h-40 flex-1 overflow-y-auto rounded-md border', className)}>
        {catalog.isError ? (
          <ErrorState error={catalog.error} onRetry={() => void catalog.refetch()} />
        ) : !catalog.data ? (
          <p className="flex items-center gap-2 p-3 text-row text-muted-foreground">
            <LoaderCircleIcon className="size-4 animate-spin" />
            {t('nasabah.link.loading')}
          </p>
        ) : (
          <div className="flex flex-col">
            {linked.length > 0 || showEmptyLinked ? (
              <Section title={t('nasabah.link.linkedTitle', { count: linked.length })}>
                {linked.length === 0 ? (
                  <p className="px-3 py-2 text-row text-muted-foreground">{t('nasabah.link.linkedEmpty')}</p>
                ) : (
                  <ul className="flex flex-col">
                    {linked.map((id) => (
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
            ) : null}
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
    </div>
  )
}
