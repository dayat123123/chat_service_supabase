import { KeyRoundIcon, LoaderCircleIcon, TriangleAlertIcon } from 'lucide-react'
import { useId, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { CopyButton } from '@/components/copy-button'
import { Button } from '@/components/ui/button'
import {
  Checkbox,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Switch,
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
import { Textarea } from '@/components/ui/textarea'
import type { AccountRef } from '@/features/community/types'
import { FieldText } from '@/features/system/components/system-ui'
import { platformErrorText } from '@/lib/error-text'

import { useCreateIntegrationKey, useUpdateIntegrationKey } from '../hooks'
import { draftFrom, invalidCidrs, keyProblems, parseCidrs, toggleScope } from '../logic'
import { keyScopes, KEY_NAME_MAX, MAX_CIDRS, type IntegrationKey, type KeyDraft } from '../types'

export type Revealed = { secret: string; key: IntegrationKey }

export function KeyDialog({
  open,
  editing,
  accounts,
  accountsFailed,
  onClose,
  onReveal,
}: {
  open: boolean
  editing: IntegrationKey | null
  accounts: AccountRef[] | null
  accountsFailed: boolean
  onClose: () => void
  onReveal: (revealed: Revealed) => void
}) {
  const { t } = useTranslation()
  return (
    <Dialog open={open} onOpenChange={(next) => !next && onClose()}>
      <DialogContent className="sm:max-w-lg" closeLabel={t('app.close')}>
        <DialogHeader>
          <DialogTitle>
            {editing ? t('platform.keys.editTitle', { name: editing.name }) : t('platform.keys.createTitle')}
          </DialogTitle>
          <DialogDescription>{t('platform.keys.formHint')}</DialogDescription>
        </DialogHeader>
        <KeyForm
          editing={editing}
          accounts={accounts}
          accountsFailed={accountsFailed}
          onClose={onClose}
          onReveal={onReveal}
        />
      </DialogContent>
    </Dialog>
  )
}

function KeyForm({
  editing,
  accounts,
  accountsFailed,
  onClose,
  onReveal,
}: {
  editing: IntegrationKey | null
  accounts: AccountRef[] | null
  accountsFailed: boolean
  onClose: () => void
  onReveal: (revealed: Revealed) => void
}) {
  const { t } = useTranslation()
  const id = useId()
  const initial = draftFrom(editing)
  const [draft, setDraft] = useState<KeyDraft>(initial)
  const [cidrText, setCidrText] = useState(initial.allowed_cidrs.join('\n'))
  const [rateText, setRateText] = useState(String(initial.rate_limit_per_minute))
  const [checked, setChecked] = useState(false)
  const create = useCreateIntegrationKey((secret, key) => onReveal({ secret, key }))
  const update = useUpdateIntegrationKey()
  const pending = create.isPending || update.isPending
  const current: KeyDraft = {
    ...draft,
    name: draft.name.trim(),
    allowed_cidrs: parseCidrs(cidrText),
    rate_limit_per_minute: Number(rateText.trim()),
    official_account_id: draft.scopes.includes('bot_post') ? draft.official_account_id : null,
  }
  const problems = keyProblems(current)
  const shown = checked ? problems : {}
  const active = accounts ?? []
  const keptOfficial =
    editing?.official_account && !active.some((account) => account.id === editing.official_account?.id)
      ? editing.official_account
      : null
  const problemText = {
    name: shown.name
      ? t(`platform.keys.problems.name.${shown.name === 'length' ? 'length' : 'required'}`)
      : undefined,
    scopes:
      shown.scopes === 'invalid'
        ? t('platform.keys.problems.scopesBroadcast')
        : shown.scopes
          ? t('platform.keys.problems.scopes')
          : undefined,
    official: shown.official ? t('platform.keys.problems.official') : undefined,
    rate: shown.rate ? t('platform.keys.problems.rate') : undefined,
    cidrs:
      shown.cidrs === 'tooMany'
        ? t('platform.keys.problems.cidrsTooMany', { max: MAX_CIDRS })
        : shown.cidrs
          ? t('platform.keys.problems.cidrsInvalid', {
              items: invalidCidrs(current.allowed_cidrs).join(', '),
            })
          : undefined,
  }

  return (
    <form
      className="flex flex-col gap-4"
      noValidate
      onSubmit={(event) => {
        event.preventDefault()
        setChecked(true)
        if (Object.keys(problems).length > 0) return
        if (editing) {
          update
            .mutateAsync({ id: editing.id, draft: current })
            .then(() => {
              toast.success(t('platform.keys.saved'))
              onClose()
            })
            .catch((error: unknown) => toast.error(platformErrorText(error)))
          return
        }
        create
          .mutateAsync(current)
          .then(() => onClose())
          .catch((error: unknown) => toast.error(platformErrorText(error)))
      }}
    >
      <div className="flex flex-col gap-1.5">
        <Label htmlFor={`${id}-name`}>{t('platform.keys.name')}</Label>
        <Input
          id={`${id}-name`}
          autoFocus
          autoComplete="off"
          maxLength={KEY_NAME_MAX}
          value={draft.name}
          aria-invalid={problemText.name ? true : undefined}
          aria-describedby={`${id}-name-text`}
          onChange={(event) => setDraft((value) => ({ ...value, name: event.target.value }))}
        />
        <FieldText id={`${id}-name-text`} error={problemText.name} hint={t('platform.keys.nameHint')} />
      </div>
      <fieldset className="flex flex-col gap-2" aria-describedby={`${id}-scopes-text`}>
        <legend className="mb-1 text-sm font-medium">{t('platform.keys.scopeLabel')}</legend>
        {keyScopes.map((scope) => (
          <label key={scope} className="flex items-start gap-2 text-row">
            <Checkbox
              className="mt-0.5"
              checked={draft.scopes.includes(scope)}
              onCheckedChange={(value) =>
                setDraft((current) => ({
                  ...current,
                  scopes: toggleScope(current.scopes, scope, value === true),
                }))
              }
            />
            <span>
              <span className="block">{t(`platform.keys.scopes.${scope}`)}</span>
              <span className="block text-xs text-muted-foreground">
                {t(`platform.keys.scopeHints.${scope}`)}
              </span>
            </span>
          </label>
        ))}
        {draft.scopes.includes('notify_broadcast') ? (
          <p className="flex items-start gap-2 rounded-md border border-warning/40 bg-warning/5 px-3 py-2 text-row text-warning">
            <TriangleAlertIcon className="mt-0.5 size-4 shrink-0" aria-hidden="true" />
            {t('platform.keys.broadcastWarning')}
          </p>
        ) : null}
        <FieldText id={`${id}-scopes-text`} error={problemText.scopes} />
      </fieldset>
      {draft.scopes.includes('bot_post') ? (
        <div className="flex flex-col gap-1.5">
          <Label htmlFor={`${id}-official`}>{t('platform.keys.official')}</Label>
          {accounts === null && !keptOfficial ? (
            <p className={accountsFailed ? 'text-xs text-destructive' : 'text-xs text-muted-foreground'}>
              {accountsFailed ? t('platform.keys.officialFailed') : t('platform.keys.officialLoading')}
            </p>
          ) : (
            <Select
              value={draft.official_account_id ?? ''}
              onValueChange={(value) => setDraft((current) => ({ ...current, official_account_id: value }))}
            >
              <SelectTrigger
                id={`${id}-official`}
                className="w-full"
                aria-invalid={problemText.official ? true : undefined}
                aria-describedby={`${id}-official-text`}
              >
                <SelectValue placeholder={t('platform.keys.officialNone')} />
              </SelectTrigger>
              <SelectContent>
                {keptOfficial ? (
                  <SelectItem value={keptOfficial.id}>
                    {keptOfficial.display_name ?? keptOfficial.username} (@{keptOfficial.username})
                  </SelectItem>
                ) : null}
                {active.map((account) => (
                  <SelectItem key={account.id} value={account.id}>
                    {account.display_name ?? account.username} (@{account.username})
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          )}
          <FieldText
            id={`${id}-official-text`}
            error={problemText.official}
            hint={
              accounts !== null && active.length === 0
                ? t('platform.keys.officialEmpty')
                : t('platform.keys.officialHint')
            }
          />
        </div>
      ) : null}
      <div className="flex flex-col gap-1.5">
        <Label htmlFor={`${id}-cidrs`}>{t('platform.keys.cidrs')}</Label>
        <Textarea
          id={`${id}-cidrs`}
          rows={3}
          spellCheck={false}
          className="font-mono text-row"
          placeholder={'10.20.0.0/16\n203.0.113.7'}
          value={cidrText}
          aria-invalid={problemText.cidrs ? true : undefined}
          aria-describedby={`${id}-cidrs-text`}
          onChange={(event) => setCidrText(event.target.value)}
        />
        <FieldText
          id={`${id}-cidrs-text`}
          error={problemText.cidrs}
          hint={t('platform.keys.cidrsHint', { max: MAX_CIDRS })}
        />
      </div>
      <div className="flex flex-col gap-1.5 sm:max-w-56">
        <Label htmlFor={`${id}-rate`}>{t('platform.keys.rate')}</Label>
        <Input
          id={`${id}-rate`}
          inputMode="numeric"
          value={rateText}
          aria-invalid={problemText.rate ? true : undefined}
          aria-describedby={`${id}-rate-text`}
          onChange={(event) => setRateText(event.target.value)}
        />
        <FieldText id={`${id}-rate-text`} error={problemText.rate} hint={t('platform.keys.rateHint')} />
      </div>
      {editing ? (
        <label className="flex items-start gap-2 text-row">
          <Switch
            className="mt-0.5"
            checked={draft.enabled}
            onCheckedChange={(value) => setDraft((current) => ({ ...current, enabled: value }))}
          />
          <span>
            <span className="block font-medium">{t('platform.keys.enabled')}</span>
            <span className="block text-xs text-muted-foreground">{t('platform.keys.enabledHint')}</span>
          </span>
        </label>
      ) : null}
      <DialogFooter>
        <Button type="button" variant="outline" disabled={pending} onClick={onClose}>
          {t('app.cancel')}
        </Button>
        <Button type="submit" disabled={pending}>
          {pending ? <LoaderCircleIcon className="animate-spin" /> : editing ? null : <KeyRoundIcon />}
          {editing ? t('app.save') : t('platform.keys.create')}
        </Button>
      </DialogFooter>
    </form>
  )
}

export function SecretDialog({ revealed, onClose }: { revealed: Revealed | null; onClose: () => void }) {
  return (
    <Dialog open={revealed !== null}>
      <DialogContent
        className="sm:max-w-lg"
        onInteractOutside={(event) => event.preventDefault()}
        onEscapeKeyDown={(event) => event.preventDefault()}
      >
        {revealed ? <SecretBody revealed={revealed} onClose={onClose} /> : null}
      </DialogContent>
    </Dialog>
  )
}

function SecretBody({ revealed, onClose }: { revealed: Revealed; onClose: () => void }) {
  const { t } = useTranslation()
  const id = useId()
  const [saved, setSaved] = useState(false)
  return (
    <>
      <DialogHeader>
        <KeyRoundIcon className="size-5 text-success" aria-hidden="true" />
        <DialogTitle>{t('platform.keys.secretTitle')}</DialogTitle>
        <DialogDescription>{t('platform.keys.secretBody', { name: revealed.key.name })}</DialogDescription>
      </DialogHeader>
      <p
        role="alert"
        className="flex items-start gap-2 rounded-md border border-warning/40 bg-warning/5 px-3 py-2 text-row text-warning"
      >
        <TriangleAlertIcon className="mt-0.5 size-4 shrink-0" aria-hidden="true" />
        {t('platform.keys.secretWarning')}
      </p>
      <div className="flex flex-col gap-1.5">
        <span id={`${id}-label`} className="text-xs font-medium text-muted-foreground">
          {t('platform.keys.secretLabel')}
        </span>
        <div className="flex flex-col gap-2 sm:flex-row sm:items-start">
          <code
            aria-labelledby={`${id}-label`}
            className="min-w-0 flex-1 rounded-md bg-muted px-2 py-1.5 font-mono text-row break-all select-all"
          >
            {revealed.secret}
          </code>
          <CopyButton text={revealed.secret} />
        </div>
      </div>
      <label className="flex items-start gap-2 text-row">
        <Checkbox className="mt-0.5" checked={saved} onCheckedChange={(value) => setSaved(value === true)} />
        {t('platform.keys.secretAck')}
      </label>
      <DialogFooter>
        <Button type="button" disabled={!saved} onClick={onClose}>
          {t('app.done')}
        </Button>
      </DialogFooter>
    </>
  )
}
