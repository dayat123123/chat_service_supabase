import { LoaderCircleIcon, PencilIcon, PlusIcon, SearchIcon, Trash2Icon } from 'lucide-react'
import { useId, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { Button } from '@/components/ui/button'
import {
  RadioGroup,
  RadioGroupItem,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/controls'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { Confirm } from '@/features/nasabah/components/confirm'
import { QueryContent } from '@/features/settings/components/settings-ui'
import { FieldText } from '@/features/system/components/system-ui'
import { policyErrorText } from '@/lib/error-text'
import { format } from '@/lib/time'

import {
  useContentRules,
  useDeleteAllowedDomain,
  useDeleteBlockedDomain,
  useSaveAllowedDomain,
  useSaveBlockedDomain,
} from '../hooks'
import { domainEntry, domainProblem } from '../logic'
import {
  contentActions,
  domainCategories,
  NOTE_MAX,
  type AllowedDomain,
  type BlockedDomain,
  type ContentAction,
  type ContentRules,
  type DomainCategory,
  type DomainMatch,
} from '../types'
import { ActionBadge, PolicyCard } from './policy-ui'

const INHERIT = '__inherit__'

function BlockedForm({
  editing,
  rules,
  onClose,
}: {
  editing: BlockedDomain | null
  rules: ContentRules
  onClose: () => void
}) {
  const { t } = useTranslation()
  const id = useId()
  const save = useSaveBlockedDomain()
  const [match, setMatch] = useState<DomainMatch>(editing?.match ?? 'domain')
  const [domain, setDomain] = useState(editing?.domain ?? '')
  const [category, setCategory] = useState<DomainCategory>(editing?.category ?? 'blocked')
  const [action, setAction] = useState<ContentAction | null>(editing?.action ?? null)
  const [note, setNote] = useState(editing?.note ?? '')
  const [checked, setChecked] = useState(false)
  const entry = domainEntry(domain, match)
  const problem = domainProblem(entry, match)
  const inherited = rules.categories.find((rule) => rule.category === category)?.action
  const duplicate =
    !editing && rules.blocked_domains.some((item) => item.domain === entry)
      ? t('policy.domains.exists')
      : undefined
  const domainText =
    checked && problem
      ? t(`policy.domains.problems.${match}.${problem}`)
      : checked && duplicate
        ? duplicate
        : undefined
  return (
    <form
      className="flex flex-col gap-4"
      noValidate
      onSubmit={(event) => {
        event.preventDefault()
        setChecked(true)
        if (problem || duplicate) return
        save
          .mutateAsync({ domain: entry, match, category, action, note: note.trim() || null })
          .then(() => {
            toast.success(t('policy.domains.saved', { domain: entry }))
            onClose()
          })
          .catch((error: unknown) => toast.error(policyErrorText(error)))
      }}
    >
      <RadioGroup
        value={match}
        onValueChange={(value) => setMatch(value as DomainMatch)}
        className="grid gap-2 sm:grid-cols-2"
        aria-label={t('policy.domains.match')}
        disabled={Boolean(editing)}
      >
        {(['domain', 'keyword'] as const).map((item) => (
          <label
            key={item}
            className="flex cursor-pointer items-start gap-3 rounded-lg border p-3 has-[[data-state=checked]]:border-primary/50 has-[[data-state=checked]]:bg-primary/5"
          >
            <RadioGroupItem value={item} className="mt-0.5" />
            <span>
              <span className="block text-sm font-medium">{t(`policy.domains.matches.${item}`)}</span>
              <span className="block text-xs text-muted-foreground">
                {t(`policy.domains.matchHints.${item}`)}
              </span>
            </span>
          </label>
        ))}
      </RadioGroup>
      <div className="flex flex-col gap-1.5">
        <Label htmlFor={`${id}-domain`}>
          {match === 'keyword' ? t('policy.domains.keyword') : t('policy.domains.domain')}
        </Label>
        <Input
          id={`${id}-domain`}
          autoFocus={!editing}
          readOnly={Boolean(editing)}
          autoComplete="off"
          spellCheck={false}
          maxLength={253}
          placeholder={match === 'keyword' ? 'slot88' : 'contoh-judi.com'}
          value={domain}
          aria-invalid={domainText ? true : undefined}
          aria-describedby={`${id}-domain-text`}
          onChange={(event) => setDomain(event.target.value)}
        />
        <FieldText
          id={`${id}-domain-text`}
          error={domainText}
          hint={
            editing
              ? t('policy.domains.domainLocked')
              : entry && entry !== domain.trim()
                ? t('policy.domains.cleaned', { value: entry })
                : t(`policy.domains.hints.${match}`)
          }
        />
      </div>
      <div className="grid gap-4 sm:grid-cols-2">
        <div className="flex flex-col gap-1.5">
          <Label htmlFor={`${id}-category`}>{t('policy.domains.category')}</Label>
          <Select value={category} onValueChange={(value) => setCategory(value as DomainCategory)}>
            <SelectTrigger id={`${id}-category`} className="w-full">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {domainCategories.map((item) => (
                <SelectItem key={item} value={item}>
                  {t(`policy.categories.${item}`)}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
        <div className="flex flex-col gap-1.5">
          <Label htmlFor={`${id}-action`}>{t('policy.domains.action')}</Label>
          <Select
            value={action ?? INHERIT}
            onValueChange={(value) => setAction(value === INHERIT ? null : (value as ContentAction))}
          >
            <SelectTrigger id={`${id}-action`} className="w-full" aria-describedby={`${id}-action-text`}>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value={INHERIT}>
                {t('policy.domains.inherit', { action: inherited ? t(`policy.actions.${inherited}`) : '–' })}
              </SelectItem>
              {contentActions.map((item) => (
                <SelectItem key={item} value={item}>
                  {t(`policy.actions.${item}`)}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
          <FieldText id={`${id}-action-text`} hint={t('policy.domains.actionHint')} />
        </div>
      </div>
      <div className="flex flex-col gap-1.5">
        <Label htmlFor={`${id}-note`}>{t('policy.domains.note')}</Label>
        <Input
          id={`${id}-note`}
          maxLength={NOTE_MAX}
          value={note}
          onChange={(event) => setNote(event.target.value)}
          aria-describedby={`${id}-note-text`}
        />
        <FieldText id={`${id}-note-text`} hint={t('policy.domains.noteHint', { max: NOTE_MAX })} />
      </div>
      <DialogFooter>
        <Button type="button" variant="outline" disabled={save.isPending} onClick={onClose}>
          {t('app.cancel')}
        </Button>
        <Button type="submit" disabled={save.isPending}>
          {save.isPending ? <LoaderCircleIcon className="animate-spin" /> : null}
          {t('app.save')}
        </Button>
      </DialogFooter>
    </form>
  )
}

function AllowedForm({ rules, onClose }: { rules: ContentRules; onClose: () => void }) {
  const { t } = useTranslation()
  const id = useId()
  const save = useSaveAllowedDomain()
  const [domain, setDomain] = useState('')
  const [note, setNote] = useState('')
  const [checked, setChecked] = useState(false)
  const entry = domainEntry(domain, 'domain')
  const problem = domainProblem(entry, 'domain')
  const duplicate = rules.allowed_domains.some((item) => item.domain === entry)
  const error =
    checked && problem
      ? t(`policy.domains.problems.domain.${problem}`)
      : checked && duplicate
        ? t('policy.domains.exists')
        : undefined
  return (
    <form
      className="flex flex-col gap-4"
      noValidate
      onSubmit={(event) => {
        event.preventDefault()
        setChecked(true)
        if (problem || duplicate) return
        save
          .mutateAsync({ domain: entry, note: note.trim() || null })
          .then(() => {
            toast.success(t('policy.allowed.saved', { domain: entry }))
            onClose()
          })
          .catch((caught: unknown) => toast.error(policyErrorText(caught)))
      }}
    >
      <div className="flex flex-col gap-1.5">
        <Label htmlFor={`${id}-domain`}>{t('policy.domains.domain')}</Label>
        <Input
          id={`${id}-domain`}
          autoFocus
          autoComplete="off"
          spellCheck={false}
          placeholder="idx.co.id"
          value={domain}
          aria-invalid={error ? true : undefined}
          aria-describedby={`${id}-domain-text`}
          onChange={(event) => setDomain(event.target.value)}
        />
        <FieldText
          id={`${id}-domain-text`}
          error={error}
          hint={
            entry && entry !== domain.trim()
              ? t('policy.domains.cleaned', { value: entry })
              : t('policy.allowed.hint')
          }
        />
      </div>
      <div className="flex flex-col gap-1.5">
        <Label htmlFor={`${id}-note`}>{t('policy.domains.note')}</Label>
        <Input
          id={`${id}-note`}
          maxLength={NOTE_MAX}
          value={note}
          onChange={(event) => setNote(event.target.value)}
        />
      </div>
      <DialogFooter>
        <Button type="button" variant="outline" disabled={save.isPending} onClick={onClose}>
          {t('app.cancel')}
        </Button>
        <Button type="submit" disabled={save.isPending}>
          {save.isPending ? <LoaderCircleIcon className="animate-spin" /> : null}
          {t('app.save')}
        </Button>
      </DialogFooter>
    </form>
  )
}

function FormDialog({
  title,
  description,
  onClose,
  children,
}: {
  title: string
  description?: string
  onClose: () => void
  children: React.ReactNode
}) {
  const { t } = useTranslation()
  return (
    <Dialog open onOpenChange={(next) => !next && onClose()}>
      <DialogContent className="sm:max-w-lg" closeLabel={t('app.close')}>
        <DialogHeader>
          <DialogTitle>{title}</DialogTitle>
          {description ? <DialogDescription>{description}</DialogDescription> : null}
        </DialogHeader>
        {children}
      </DialogContent>
    </Dialog>
  )
}

function BlockedCard({ rules }: { rules: ContentRules }) {
  const { t } = useTranslation()
  const remove = useDeleteBlockedDomain()
  const [query, setQuery] = useState('')
  const [category, setCategory] = useState<DomainCategory | 'all'>('all')
  const [editing, setEditing] = useState<BlockedDomain | 'new' | null>(null)
  const [removing, setRemoving] = useState<BlockedDomain | null>(null)
  const needle = query.trim().toLowerCase()
  const shown = rules.blocked_domains.filter(
    (item) =>
      (category === 'all' || item.category === category) &&
      (needle === '' || item.domain.includes(needle) || (item.note ?? '').toLowerCase().includes(needle)),
  )
  return (
    <PolicyCard
      title={t('policy.domains.title')}
      subtitle={t('policy.domains.subtitle')}
      action={
        <Button size="sm" onClick={() => setEditing('new')}>
          <PlusIcon />
          {t('policy.domains.add')}
        </Button>
      }
    >
      <div className="flex flex-wrap items-center gap-2">
        <div className="relative w-full sm:w-64">
          <SearchIcon className="pointer-events-none absolute top-2 left-2.5 size-4 text-muted-foreground" />
          <Input
            type="search"
            value={query}
            placeholder={t('policy.domains.search')}
            aria-label={t('policy.domains.search')}
            className="h-8 pl-8"
            onChange={(event) => setQuery(event.target.value)}
          />
        </div>
        <Select value={category} onValueChange={(value) => setCategory(value as DomainCategory | 'all')}>
          <SelectTrigger className="h-8 w-48" aria-label={t('policy.domains.filterCategory')}>
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="all">{t('policy.domains.allCategories')}</SelectItem>
            {domainCategories.map((item) => (
              <SelectItem key={item} value={item}>
                {t(`policy.categories.${item}`)}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
        <span className="tabular ml-auto text-xs text-muted-foreground">
          {t('policy.domains.count', { shown: shown.length, total: rules.blocked_domains.length })}
        </span>
      </div>
      {shown.length === 0 ? (
        <p className="border-y py-6 text-center text-row text-muted-foreground">
          {rules.blocked_domains.length === 0 ? t('policy.domains.empty') : t('policy.domains.noMatch')}
        </p>
      ) : (
        <Table>
          <caption className="sr-only">{t('policy.domains.title')}</caption>
          <TableHeader>
            <TableRow>
              <TableHead>{t('policy.domains.colDomain')}</TableHead>
              <TableHead>{t('policy.domains.category')}</TableHead>
              <TableHead>{t('policy.domains.action')}</TableHead>
              <TableHead>{t('policy.domains.note')}</TableHead>
              <TableHead>
                <span className="sr-only">{t('policy.domains.colActions')}</span>
              </TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {shown.map((item) => {
              const effective =
                item.action ??
                rules.categories.find((rule) => rule.category === item.category)?.action ??
                'block'
              return (
                <TableRow key={item.domain} className="align-top">
                  <TableCell className="py-2 whitespace-normal">
                    <p className="font-mono text-row break-all">{item.domain}</p>
                    <p className="text-xs text-muted-foreground">
                      {t(`policy.domains.matches.${item.match}`)} · {format(item.created_at, 'd MMM yyyy')}
                    </p>
                  </TableCell>
                  <TableCell className="py-2 text-row">{t(`policy.categories.${item.category}`)}</TableCell>
                  <TableCell className="py-2">
                    <ActionBadge action={effective} />
                    {item.action === null ? (
                      <span className="block pt-0.5 text-xs text-muted-foreground">
                        {t('policy.domains.followsCategory')}
                      </span>
                    ) : null}
                  </TableCell>
                  <TableCell className="max-w-64 py-2 text-xs break-words whitespace-normal text-muted-foreground">
                    {item.note ?? '–'}
                  </TableCell>
                  <TableCell className="py-2">
                    <div className="flex justify-end gap-1">
                      <Button
                        size="icon-xs"
                        variant="ghost"
                        aria-label={t('policy.domains.editLabel', { domain: item.domain })}
                        onClick={() => setEditing(item)}
                      >
                        <PencilIcon />
                      </Button>
                      <Button
                        size="icon-xs"
                        variant="ghost"
                        aria-label={t('policy.domains.deleteLabel', { domain: item.domain })}
                        onClick={() => setRemoving(item)}
                      >
                        <Trash2Icon />
                      </Button>
                    </div>
                  </TableCell>
                </TableRow>
              )
            })}
          </TableBody>
        </Table>
      )}
      {editing ? (
        <FormDialog
          title={
            editing === 'new'
              ? t('policy.domains.addTitle')
              : t('policy.domains.editTitle', { domain: editing.domain })
          }
          description={t('policy.domains.formHint')}
          onClose={() => setEditing(null)}
        >
          <BlockedForm
            editing={editing === 'new' ? null : editing}
            rules={rules}
            onClose={() => setEditing(null)}
          />
        </FormDialog>
      ) : null}
      <Confirm
        open={removing !== null}
        title={t('policy.domains.deleteTitle', { domain: removing?.domain ?? '' })}
        body={t('policy.domains.deleteBody')}
        action={t('app.delete')}
        destructive
        pending={remove.isPending}
        onClose={() => setRemoving(null)}
        onConfirm={() =>
          removing &&
          remove
            .mutateAsync(removing.domain)
            .then(() => {
              toast.success(t('policy.domains.deleted', { domain: removing.domain }))
              setRemoving(null)
            })
            .catch((error: unknown) => toast.error(policyErrorText(error)))
        }
      />
    </PolicyCard>
  )
}

function AllowedCard({ rules }: { rules: ContentRules }) {
  const { t } = useTranslation()
  const remove = useDeleteAllowedDomain()
  const [adding, setAdding] = useState(false)
  const [removing, setRemoving] = useState<AllowedDomain | null>(null)
  return (
    <PolicyCard
      title={t('policy.allowed.title')}
      subtitle={t('policy.allowed.subtitle')}
      action={
        <Button size="sm" variant="outline" onClick={() => setAdding(true)}>
          <PlusIcon />
          {t('policy.allowed.add')}
        </Button>
      }
    >
      {rules.allowed_domains.length === 0 ? (
        <p className="border-y py-6 text-center text-row text-muted-foreground">
          {t('policy.allowed.empty')}
        </p>
      ) : (
        <ul className="border-y">
          {rules.allowed_domains.map((item) => (
            <li
              key={item.domain}
              className="flex items-start justify-between gap-3 border-b py-2 last:border-b-0"
            >
              <div className="min-w-0">
                <p className="font-mono text-row break-all">{item.domain}</p>
                {item.note ? <p className="text-xs break-words text-muted-foreground">{item.note}</p> : null}
              </div>
              <Button
                size="icon-xs"
                variant="ghost"
                aria-label={t('policy.domains.deleteLabel', { domain: item.domain })}
                onClick={() => setRemoving(item)}
              >
                <Trash2Icon />
              </Button>
            </li>
          ))}
        </ul>
      )}
      {adding ? (
        <FormDialog
          title={t('policy.allowed.addTitle')}
          description={t('policy.allowed.subtitle')}
          onClose={() => setAdding(false)}
        >
          <AllowedForm rules={rules} onClose={() => setAdding(false)} />
        </FormDialog>
      ) : null}
      <Confirm
        open={removing !== null}
        title={t('policy.allowed.deleteTitle', { domain: removing?.domain ?? '' })}
        body={t('policy.allowed.deleteBody')}
        action={t('app.delete')}
        destructive
        pending={remove.isPending}
        onClose={() => setRemoving(null)}
        onConfirm={() =>
          removing &&
          remove
            .mutateAsync(removing.domain)
            .then(() => {
              toast.success(t('policy.domains.deleted', { domain: removing.domain }))
              setRemoving(null)
            })
            .catch((error: unknown) => toast.error(policyErrorText(error)))
        }
      />
    </PolicyCard>
  )
}

export function DomainsTab() {
  const rules = useContentRules()
  return (
    <QueryContent query={rules}>
      {(data) => (
        <div className="flex flex-col gap-6">
          <BlockedCard rules={data} />
          <AllowedCard rules={data} />
        </div>
      )}
    </QueryContent>
  )
}
