import { LoaderCircleIcon } from 'lucide-react'
import { useId, useState } from 'react'
import { useTranslation } from 'react-i18next'

import { Button } from '@/components/ui/button'
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
import { cn, lengthValid } from '@/lib/utils'

type ReasonDialogProps = {
  open: boolean
  title: string
  description?: string
  label: string
  action: string
  destructive?: boolean
  pending: boolean
  onSubmit: (reason: string) => void
  onClose: () => void
  min?: number
  max?: number
  optional?: boolean
  hint?: string
  children?: React.ReactNode
}

function ReasonForm({
  label,
  action,
  destructive,
  pending,
  onSubmit,
  onClose,
  min,
  max,
  optional,
  hint,
}: Omit<ReasonDialogProps, 'open' | 'title' | 'description' | 'children'> & { min: number; max: number }) {
  const { t } = useTranslation()
  const id = useId()
  const [reason, setReason] = useState('')
  const [touched, setTouched] = useState(false)
  const valid = lengthValid(reason, min, max, optional)
  return (
    <form
      className="flex flex-col gap-3"
      onSubmit={(event) => {
        event.preventDefault()
        setTouched(true)
        if (valid) onSubmit(reason.trim())
      }}
    >
      <div className="flex flex-col gap-1.5">
        <Label htmlFor={`${id}-reason`}>{label}</Label>
        <Textarea
          id={`${id}-reason`}
          autoFocus
          rows={3}
          maxLength={max}
          value={reason}
          aria-invalid={touched && !valid ? true : undefined}
          aria-describedby={`${id}-hint`}
          onChange={(event) => setReason(event.target.value)}
        />
        <p
          id={`${id}-hint`}
          className={cn('text-xs', touched && !valid ? 'text-destructive' : 'text-muted-foreground')}
        >
          {hint ?? t('community.reasonHint')}
        </p>
      </div>
      <DialogFooter>
        <Button type="button" variant="outline" disabled={pending} onClick={onClose}>
          {t('app.cancel')}
        </Button>
        <Button type="submit" variant={destructive ? 'destructive' : 'default'} disabled={pending}>
          {pending ? <LoaderCircleIcon className="animate-spin" /> : null}
          {action}
        </Button>
      </DialogFooter>
    </form>
  )
}

export function ReasonDialog({
  open,
  title,
  description,
  children,
  pending,
  onClose,
  min = 5,
  max = 500,
  ...form
}: ReasonDialogProps) {
  const { t } = useTranslation()
  return (
    <Dialog open={open} onOpenChange={(next) => !next && !pending && onClose()}>
      <DialogContent className="sm:max-w-md" closeLabel={t('app.close')}>
        <DialogHeader>
          <DialogTitle>{title}</DialogTitle>
          {description ? <DialogDescription>{description}</DialogDescription> : null}
        </DialogHeader>
        {children}
        <ReasonForm {...form} pending={pending} onClose={onClose} min={min} max={max} />
      </DialogContent>
    </Dialog>
  )
}
