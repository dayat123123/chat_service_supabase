import { LoaderCircleIcon, PowerIcon, ShieldAlertIcon } from 'lucide-react'
import { useId, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { Dot } from '@/components/badges'
import { Button } from '@/components/ui/button'
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
import { SettingsCard } from '@/features/settings/components/settings-ui'
import { FieldText } from '@/features/system/components/system-ui'
import { platformErrorText } from '@/lib/error-text'
import { stamp } from '@/lib/time'
import { cn } from '@/lib/utils'

import { useSetKillSwitch } from '../hooks'
import { collapseSpaces, killReasonValid, phraseMatches } from '../logic'
import { KILL_REASON_MAX, type KillSwitch } from '../types'

function SwitchForm({ enable, onClose }: { enable: boolean; onClose: () => void }) {
  const { t } = useTranslation()
  const id = useId()
  const save = useSetKillSwitch()
  const [reason, setReason] = useState('')
  const [typed, setTyped] = useState('')
  const [checked, setChecked] = useState(false)
  const phrase = enable ? t('platform.flags.kill.phraseOn') : t('platform.flags.kill.phraseOff')
  const reasonOk = killReasonValid(reason)
  const phraseOk = phraseMatches(typed, phrase)
  return (
    <form
      className="flex flex-col gap-4"
      noValidate
      onSubmit={(event) => {
        event.preventDefault()
        setChecked(true)
        if (!reasonOk || !phraseOk) return
        save
          .mutateAsync({ enabled: enable, reason: collapseSpaces(reason) })
          .then(() => {
            toast.success(enable ? t('platform.flags.kill.enabled') : t('platform.flags.kill.disabled'))
            onClose()
          })
          .catch((error: unknown) => toast.error(platformErrorText(error)))
      }}
    >
      <div className="flex flex-col gap-1.5">
        <Label htmlFor={`${id}-reason`}>{t('platform.flags.kill.reason')}</Label>
        <Textarea
          id={`${id}-reason`}
          autoFocus
          rows={3}
          maxLength={KILL_REASON_MAX}
          value={reason}
          aria-invalid={checked && !reasonOk ? true : undefined}
          aria-describedby={`${id}-reason-text`}
          onChange={(event) => setReason(event.target.value)}
        />
        <FieldText
          id={`${id}-reason-text`}
          error={checked && !reasonOk ? t('platform.flags.kill.reasonProblem') : undefined}
          hint={t('platform.flags.kill.reasonHint')}
        />
      </div>
      <div className="flex flex-col gap-1.5">
        <Label htmlFor={`${id}-phrase`}>{t('platform.flags.kill.phraseLabel', { phrase })}</Label>
        <Input
          id={`${id}-phrase`}
          autoComplete="off"
          spellCheck={false}
          value={typed}
          aria-invalid={checked && !phraseOk ? true : undefined}
          aria-describedby={`${id}-phrase-text`}
          onChange={(event) => setTyped(event.target.value)}
        />
        <FieldText
          id={`${id}-phrase-text`}
          error={checked && !phraseOk ? t('platform.flags.kill.phraseProblem', { phrase }) : undefined}
        />
      </div>
      <DialogFooter>
        <Button type="button" variant="outline" disabled={save.isPending} onClick={onClose}>
          {t('app.cancel')}
        </Button>
        <Button type="submit" variant={enable ? 'default' : 'destructive'} disabled={save.isPending}>
          {save.isPending ? <LoaderCircleIcon className="animate-spin" /> : <PowerIcon />}
          {enable ? t('platform.flags.kill.turnOn') : t('platform.flags.kill.turnOff')}
        </Button>
      </DialogFooter>
    </form>
  )
}

function SwitchDialog({ enable, open, onClose }: { enable: boolean; open: boolean; onClose: () => void }) {
  const { t } = useTranslation()
  return (
    <Dialog open={open} onOpenChange={(next) => !next && onClose()}>
      <DialogContent className="sm:max-w-lg" closeLabel={t('app.close')}>
        <DialogHeader>
          {enable ? null : <ShieldAlertIcon className="size-5 text-destructive" aria-hidden="true" />}
          <DialogTitle>
            {enable ? t('platform.flags.kill.onTitle') : t('platform.flags.kill.offTitle')}
          </DialogTitle>
          <DialogDescription>
            {enable ? t('platform.flags.kill.onBody') : t('platform.flags.kill.offBody')}
          </DialogDescription>
        </DialogHeader>
        {enable ? null : (
          <ul className="flex list-disc flex-col gap-1 pl-5 text-row">
            <li>{t('platform.flags.kill.effectWrites')}</li>
            <li>{t('platform.flags.kill.effectRead')}</li>
            <li>{t('platform.flags.kill.effectSupport')}</li>
            <li>{t('platform.flags.kill.effectStaff')}</li>
          </ul>
        )}
        <SwitchForm enable={enable} onClose={onClose} />
      </DialogContent>
    </Dialog>
  )
}

export function KillSwitchCard({ state }: { state: KillSwitch }) {
  const { t } = useTranslation()
  const [open, setOpen] = useState(false)
  const on = state.social_enabled
  return (
    <SettingsCard title={t('platform.flags.kill.title')} subtitle={t('platform.flags.kill.subtitle')}>
      <div
        role="status"
        className={cn(
          'flex flex-col gap-3 rounded-lg border p-4 sm:flex-row sm:items-center sm:justify-between',
          on ? 'border-border' : 'border-destructive/50 bg-destructive/5',
        )}
      >
        <div className="flex min-w-0 flex-col gap-1">
          <p
            className={cn(
              'flex items-center gap-2 text-panel font-semibold',
              on ? 'text-success' : 'text-destructive',
            )}
          >
            <Dot tone={on ? 'ok' : 'late'} />
            {on ? t('platform.flags.kill.stateOn') : t('platform.flags.kill.stateOff')}
          </p>
          <p className="text-row text-muted-foreground">
            {on ? t('platform.flags.kill.stateOnHint') : t('platform.flags.kill.stateOffHint')}
          </p>
          {state.changed_at ? (
            <p className="text-xs break-words text-muted-foreground">
              {t('platform.flags.kill.lastChange', {
                time: stamp(state.changed_at),
                name: state.changed_by?.name ?? '–',
                reason: state.reason ?? '–',
              })}
            </p>
          ) : null}
        </div>
        <Button
          variant={on ? 'destructive' : 'default'}
          className="self-start sm:self-center"
          onClick={() => setOpen(true)}
        >
          <PowerIcon />
          {on ? t('platform.flags.kill.turnOff') : t('platform.flags.kill.turnOn')}
        </Button>
      </div>
      {open ? <SwitchDialog enable={!on} open onClose={() => setOpen(false)} /> : null}
    </SettingsCard>
  )
}
