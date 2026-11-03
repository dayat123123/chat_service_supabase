import { LoaderCircleIcon } from 'lucide-react'
import { useId, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { Button } from '@/components/ui/button'
import { Checkbox, Switch } from '@/components/ui/controls'
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
import { FieldText } from '@/features/system/components/system-ui'
import { platformErrorText } from '@/lib/error-text'

import { useSetFlag } from '../hooks'
import { flagDraft, flagProblems, normalizeFlagKey, parseUserIds } from '../logic'
import {
  appPlatforms,
  FLAG_DESCRIPTION_MAX,
  FLAG_USERS_MAX,
  type FeatureFlag,
  type FlagDraft,
} from '../types'

function FlagForm({
  editing,
  existing,
  onClose,
}: {
  editing: FeatureFlag | null
  existing: string[]
  onClose: () => void
}) {
  const { t } = useTranslation()
  const id = useId()
  const save = useSetFlag()
  const initial = flagDraft(editing)
  const [draft, setDraft] = useState<FlagDraft>(initial)
  const [percentText, setPercentText] = useState(String(initial.percentage))
  const [versionText, setVersionText] = useState(initial.min_app_version ?? '')
  const [usersText, setUsersText] = useState(initial.user_ids.join('\n'))
  const [checked, setChecked] = useState(false)
  const users = parseUserIds(usersText)
  const current: FlagDraft = {
    ...draft,
    key: normalizeFlagKey(draft.key),
    percentage: percentText.trim() === '' ? Number.NaN : Number(percentText.trim()),
    min_app_version: versionText.trim() === '' ? null : versionText.trim(),
    user_ids: users.ids,
    description: draft.description?.trim() ?? '',
  }
  const problems = flagProblems(current, { isNew: !editing, existing, invalidUsers: users.invalid })
  const shown = checked ? problems : {}
  const text = {
    key: shown.key ? t(`platform.flags.problems.key.${shown.key as 'required'}`) : undefined,
    percentage: shown.percentage ? t('platform.flags.problems.percentage') : undefined,
    users:
      shown.users === 'tooMany'
        ? t('platform.flags.problems.usersTooMany', { max: FLAG_USERS_MAX })
        : shown.users
          ? t('platform.flags.problems.usersInvalid', { items: users.invalid.slice(0, 3).join(', ') })
          : undefined,
    version: shown.version ? t('platform.flags.problems.version') : undefined,
    description: shown.description
      ? t('platform.flags.problems.description', { max: FLAG_DESCRIPTION_MAX })
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
        save
          .mutateAsync(current)
          .then(() => {
            toast.success(t('platform.flags.saved', { key: current.key }))
            onClose()
          })
          .catch((error: unknown) => toast.error(platformErrorText(error)))
      }}
    >
      <div className="flex flex-col gap-1.5">
        <Label htmlFor={`${id}-key`}>{t('platform.flags.key')}</Label>
        <Input
          id={`${id}-key`}
          autoFocus={!editing}
          readOnly={Boolean(editing)}
          autoComplete="off"
          spellCheck={false}
          maxLength={50}
          className="font-mono"
          value={draft.key}
          aria-invalid={text.key ? true : undefined}
          aria-describedby={`${id}-key-text`}
          onChange={(event) => setDraft((value) => ({ ...value, key: event.target.value }))}
        />
        <FieldText
          id={`${id}-key-text`}
          error={text.key}
          hint={editing ? t('platform.flags.keyLocked') : t('platform.flags.keyHint')}
        />
      </div>
      <div className="flex flex-col gap-1.5">
        <Label htmlFor={`${id}-description`}>{t('platform.flags.description')}</Label>
        <Input
          id={`${id}-description`}
          maxLength={FLAG_DESCRIPTION_MAX}
          value={draft.description ?? ''}
          aria-invalid={text.description ? true : undefined}
          aria-describedby={`${id}-description-text`}
          onChange={(event) => setDraft((value) => ({ ...value, description: event.target.value }))}
        />
        <FieldText id={`${id}-description-text`} error={text.description} />
      </div>
      <label className="flex items-start gap-2 text-row">
        <Switch
          className="mt-0.5"
          checked={draft.enabled}
          onCheckedChange={(value) => setDraft((current) => ({ ...current, enabled: value }))}
        />
        <span>
          <span className="block font-medium">{t('platform.flags.enabled')}</span>
          <span className="block text-xs text-muted-foreground">{t('platform.flags.enabledHint')}</span>
        </span>
      </label>
      <div className="grid gap-4 sm:grid-cols-2">
        <div className="flex flex-col gap-1.5">
          <Label htmlFor={`${id}-percent`}>{t('platform.flags.percentage')}</Label>
          <Input
            id={`${id}-percent`}
            inputMode="numeric"
            value={percentText}
            aria-invalid={text.percentage ? true : undefined}
            aria-describedby={`${id}-percent-text`}
            onChange={(event) => setPercentText(event.target.value)}
          />
          <FieldText
            id={`${id}-percent-text`}
            error={text.percentage}
            hint={t('platform.flags.percentageHint')}
          />
        </div>
        <div className="flex flex-col gap-1.5">
          <Label htmlFor={`${id}-version`}>{t('platform.flags.minVersion')}</Label>
          <Input
            id={`${id}-version`}
            inputMode="decimal"
            placeholder="2.4.0"
            value={versionText}
            aria-invalid={text.version ? true : undefined}
            aria-describedby={`${id}-version-text`}
            onChange={(event) => setVersionText(event.target.value)}
          />
          <FieldText
            id={`${id}-version-text`}
            error={text.version}
            hint={t('platform.flags.minVersionHint')}
          />
        </div>
      </div>
      <fieldset className="flex flex-col gap-2">
        <legend className="mb-1 text-sm font-medium">{t('platform.flags.platforms')}</legend>
        <div className="flex flex-wrap gap-x-5 gap-y-2">
          {appPlatforms.map((platform) => (
            <label key={platform} className="flex items-center gap-2 text-row">
              <Checkbox
                checked={draft.platforms.includes(platform)}
                onCheckedChange={(value) =>
                  setDraft((current) => ({
                    ...current,
                    platforms:
                      value === true
                        ? appPlatforms.filter((item) => item === platform || current.platforms.includes(item))
                        : current.platforms.filter((item) => item !== platform),
                  }))
                }
              />
              {t(`platform.platforms.${platform}`)}
            </label>
          ))}
        </div>
        <p className="text-xs text-muted-foreground">{t('platform.flags.platformsHint')}</p>
      </fieldset>
      <div className="flex flex-col gap-1.5">
        <Label htmlFor={`${id}-users`}>{t('platform.flags.users')}</Label>
        <Textarea
          id={`${id}-users`}
          rows={3}
          spellCheck={false}
          className="font-mono text-row"
          value={usersText}
          aria-invalid={text.users ? true : undefined}
          aria-describedby={`${id}-users-text`}
          onChange={(event) => setUsersText(event.target.value)}
        />
        <FieldText
          id={`${id}-users-text`}
          error={text.users}
          hint={t('platform.flags.usersHint', { count: users.ids.length, max: FLAG_USERS_MAX })}
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

export function FlagDialog({
  editing,
  existing,
  onClose,
}: {
  editing: FeatureFlag | null
  existing: string[]
  onClose: () => void
}) {
  const { t } = useTranslation()
  return (
    <Dialog open onOpenChange={(next) => !next && onClose()}>
      <DialogContent className="sm:max-w-lg" closeLabel={t('app.close')}>
        <DialogHeader>
          <DialogTitle>
            {editing ? t('platform.flags.editTitle', { key: editing.key }) : t('platform.flags.addTitle')}
          </DialogTitle>
          <DialogDescription>{t('platform.flags.formHint')}</DialogDescription>
        </DialogHeader>
        <FlagForm editing={editing} existing={existing} onClose={onClose} />
      </DialogContent>
    </Dialog>
  )
}
