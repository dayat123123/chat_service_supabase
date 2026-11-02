import { LoaderCircleIcon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { Button } from '@/components/ui/button'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/controls'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import { errorText } from '@/lib/error-text'

import { useChangeStatus } from '../hooks'
import { useNasabahLabels } from '../labels'
import { statusReasonOk } from '../logic'
import { userStatuses, type OnlineUser } from '../types'

function StatusForm({ user, onDone }: { user: OnlineUser; onDone: () => void }) {
  const { t } = useTranslation()
  const label = useNasabahLabels()
  const change = useChangeStatus()
  const options = userStatuses.filter((status) => status !== user.Status)
  const [status, setStatus] = useState<number>(options[0] ?? 1)
  const [reason, setReason] = useState('')
  const [checked, setChecked] = useState(false)
  const reasonInvalid = checked && !statusReasonOk(reason)

  return (
    <form
      className="flex flex-col gap-4"
      noValidate
      onSubmit={(event) => {
        event.preventDefault()
        setChecked(true)
        if (!statusReasonOk(reason) || status === user.Status) return
        change.mutate(
          { loginId: user.LoginId, status, reason },
          {
            onSuccess: () => {
              toast.success(
                t('nasabah.toast.statusChanged', { loginId: user.LoginId, status: label.status(status) }),
              )
              onDone()
            },
            onError: (error) => toast.error(errorText(error)),
          },
        )
      }}
    >
      <DialogDescription>{t('nasabah.status.hint')}</DialogDescription>
      <p className="text-row text-muted-foreground">
        {t('nasabah.status.current', { status: label.status(user.Status) })}
      </p>
      <div className="flex flex-col gap-1.5">
        <Label htmlFor="nasabah-next-status">{t('nasabah.status.next')}</Label>
        <Select value={String(status)} onValueChange={(value) => setStatus(Number(value))}>
          <SelectTrigger id="nasabah-next-status" className="w-full">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {options.map((option) => (
              <SelectItem key={option} value={String(option)}>
                {label.status(option)}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>
      <div className="flex flex-col gap-1.5">
        <Label htmlFor="nasabah-status-reason">{t('nasabah.status.reason')}</Label>
        <Textarea
          id="nasabah-status-reason"
          rows={3}
          maxLength={200}
          autoFocus
          aria-invalid={reasonInvalid ? true : undefined}
          aria-describedby="nasabah-status-reason-hint"
          value={reason}
          onChange={(event) => setReason(event.target.value)}
        />
        <p
          id="nasabah-status-reason-hint"
          role={reasonInvalid ? 'alert' : undefined}
          className={reasonInvalid ? 'text-xs text-destructive' : 'text-xs text-muted-foreground'}
        >
          {reasonInvalid ? t('nasabah.status.reasonProblem') : t('nasabah.status.reasonHint')}
        </p>
      </div>
      <DialogFooter>
        <Button type="button" variant="ghost" disabled={change.isPending} onClick={onDone}>
          {t('app.cancel')}
        </Button>
        <Button type="submit" variant={status === 1 ? 'default' : 'destructive'} disabled={change.isPending}>
          {change.isPending ? <LoaderCircleIcon className="animate-spin" /> : null}
          {t('nasabah.status.submit')}
        </Button>
      </DialogFooter>
    </form>
  )
}

export function StatusDialog({ user, onClose }: { user: OnlineUser | null; onClose: () => void }) {
  const { t } = useTranslation()
  return (
    <Dialog open={user !== null} onOpenChange={(next) => !next && onClose()}>
      <DialogContent className="sm:max-w-md" closeLabel={t('app.close')}>
        <DialogHeader>
          <DialogTitle>{t('nasabah.status.title', { loginId: user?.LoginId ?? '' })}</DialogTitle>
        </DialogHeader>
        {user ? <StatusForm key={user.LoginId} user={user} onDone={onClose} /> : null}
      </DialogContent>
    </Dialog>
  )
}
