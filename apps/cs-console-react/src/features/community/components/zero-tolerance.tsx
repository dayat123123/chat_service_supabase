import { LoaderCircleIcon, OctagonAlertIcon } from 'lucide-react'
import { useId, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { Button } from '@/components/ui/button'
import { Checkbox } from '@/components/ui/controls'
import {
  AlertDialog,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogTitle,
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
import { moderationErrorText } from '@/lib/error-text'
import { lengthValid } from '@/lib/utils'

import { useZeroTolerance } from '../hooks'
import { NOTE_MAX, NOTE_MIN } from '../types'

type Target = { id: string; username: string; name: string }

type Draft = { reason: string; understood: boolean }

function ReasonStep({
  target,
  draft,
  onDraft,
  onNext,
  onClose,
}: {
  target: Target
  draft: Draft
  onDraft: (draft: Draft) => void
  onNext: () => void
  onClose: () => void
}) {
  const { t } = useTranslation()
  const id = useId()
  const { reason, understood } = draft
  const [checked, setChecked] = useState(false)
  const valid = lengthValid(reason, NOTE_MIN, NOTE_MAX)
  return (
    <form
      className="flex flex-col gap-4"
      noValidate
      onSubmit={(event) => {
        event.preventDefault()
        setChecked(true)
        if (valid && understood) onNext()
      }}
    >
      <div className="flex flex-col gap-2 rounded-md border border-destructive/40 bg-destructive/5 p-3 text-row">
        <p className="flex items-center gap-2 font-medium text-destructive">
          <OctagonAlertIcon className="size-4 shrink-0" aria-hidden="true" />
          {t('moderation.zero.effectsTitle')}
        </p>
        <ul className="flex list-disc flex-col gap-1 pl-5">
          <li>{t('moderation.zero.effectBan')}</li>
          <li>{t('moderation.zero.effectSessions')}</li>
          <li>{t('moderation.zero.effectContent')}</li>
          <li>{t('moderation.zero.effectAppeal')}</li>
        </ul>
      </div>
      <div className="flex flex-col gap-1 text-xs text-muted-foreground">
        <p className="font-medium text-foreground">{t('moderation.zero.procedureTitle')}</p>
        <p>{t('moderation.zero.procedureEvidence')}</p>
        <p>{t('moderation.zero.procedureLegal')}</p>
      </div>
      <div className="flex flex-col gap-1.5">
        <Label htmlFor={`${id}-reason`}>{t('moderation.zero.reason')}</Label>
        <Textarea
          id={`${id}-reason`}
          autoFocus
          rows={3}
          maxLength={NOTE_MAX}
          value={reason}
          aria-invalid={checked && !valid ? true : undefined}
          aria-describedby={`${id}-reason-text`}
          onChange={(event) => onDraft({ ...draft, reason: event.target.value })}
        />
        <FieldText
          id={`${id}-reason-text`}
          error={checked && !valid ? t('moderation.reasonProblem') : undefined}
          hint={t('moderation.zero.reasonHint')}
        />
      </div>
      <label className="flex items-start gap-2 text-row">
        <Checkbox
          className="mt-0.5"
          checked={understood}
          aria-invalid={checked && !understood ? true : undefined}
          onCheckedChange={(value) => onDraft({ ...draft, understood: value === true })}
        />
        <span>
          {t('moderation.zero.understood', { username: target.username })}
          {checked && !understood ? (
            <span role="alert" className="block text-xs text-destructive">
              {t('moderation.zero.understoodRequired')}
            </span>
          ) : null}
        </span>
      </label>
      <DialogFooter>
        <Button type="button" variant="outline" onClick={onClose}>
          {t('app.cancel')}
        </Button>
        <Button type="submit" variant="destructive">
          {t('moderation.zero.continue')}
        </Button>
      </DialogFooter>
    </form>
  )
}

function ConfirmStep({
  target,
  reason,
  onBack,
  onDone,
}: {
  target: Target
  reason: string
  onBack: () => void
  onDone: () => void
}) {
  const { t } = useTranslation()
  const id = useId()
  const apply = useZeroTolerance()
  const [typed, setTyped] = useState('')
  const matches = typed.trim().replace(/^@/, '').toLowerCase() === target.username.toLowerCase()
  return (
    <AlertDialog open onOpenChange={(next) => !next && !apply.isPending && onBack()}>
      <AlertDialogContent>
        <AlertDialogTitle>{t('moderation.zero.confirmTitle', { name: target.name })}</AlertDialogTitle>
        <AlertDialogDescription>{t('moderation.zero.confirmBody')}</AlertDialogDescription>
        <div className="flex flex-col gap-1.5">
          <Label htmlFor={`${id}-confirm`}>
            {t('moderation.zero.typeUsername', { username: target.username })}
          </Label>
          <Input
            id={`${id}-confirm`}
            autoComplete="off"
            spellCheck={false}
            value={typed}
            onChange={(event) => setTyped(event.target.value)}
          />
        </div>
        <div className="flex justify-end gap-2">
          <AlertDialogCancel disabled={apply.isPending}>{t('moderation.zero.back')}</AlertDialogCancel>
          <Button
            variant="destructive"
            disabled={!matches || apply.isPending}
            onClick={() =>
              void apply
                .mutateAsync({ id: target.id, reason })
                .then((result) => {
                  toast.success(
                    t('moderation.zero.applied', {
                      posts: result.hidden.posts,
                      comments: result.hidden.comments,
                      messages: result.hidden.messages,
                    }),
                  )
                  onDone()
                })
                .catch((error: unknown) => toast.error(moderationErrorText(error)))
            }
          >
            {apply.isPending ? <LoaderCircleIcon className="animate-spin" /> : null}
            {t('moderation.zero.apply')}
          </Button>
        </div>
      </AlertDialogContent>
    </AlertDialog>
  )
}

export function ZeroToleranceDialog({ target, onClose }: { target: Target; onClose: () => void }) {
  const { t } = useTranslation()
  const [draft, setDraft] = useState<Draft>({ reason: '', understood: false })
  const [confirming, setConfirming] = useState(false)
  return (
    <>
      <Dialog open={!confirming} onOpenChange={(next) => !next && !confirming && onClose()}>
        <DialogContent className="sm:max-w-lg" closeLabel={t('app.close')}>
          <DialogHeader>
            <DialogTitle>{t('moderation.zero.title', { name: target.name })}</DialogTitle>
            <DialogDescription>{t('moderation.zero.subtitle')}</DialogDescription>
          </DialogHeader>
          <ReasonStep
            target={target}
            draft={draft}
            onDraft={setDraft}
            onNext={() => setConfirming(true)}
            onClose={onClose}
          />
        </DialogContent>
      </Dialog>
      {confirming ? (
        <ConfirmStep
          target={target}
          reason={draft.reason.trim()}
          onBack={() => setConfirming(false)}
          onDone={onClose}
        />
      ) : null}
    </>
  )
}
