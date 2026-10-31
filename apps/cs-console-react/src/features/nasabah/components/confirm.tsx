import { LoaderCircleIcon } from 'lucide-react'
import { useTranslation } from 'react-i18next'

import { Button } from '@/components/ui/button'
import {
  AlertDialog,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogTitle,
} from '@/components/ui/dialog'

export function Confirm({
  open,
  title,
  body,
  action,
  pending,
  destructive,
  onConfirm,
  onClose,
}: {
  open: boolean
  title: string
  body: string
  action: string
  pending: boolean
  destructive?: boolean
  onConfirm: () => void
  onClose: () => void
}) {
  const { t } = useTranslation()
  return (
    <AlertDialog open={open} onOpenChange={(next) => !next && !pending && onClose()}>
      <AlertDialogContent>
        <AlertDialogTitle>{title}</AlertDialogTitle>
        <AlertDialogDescription>{body}</AlertDialogDescription>
        <div className="flex justify-end gap-2">
          <AlertDialogCancel disabled={pending}>{t('app.cancel')}</AlertDialogCancel>
          <Button variant={destructive ? 'destructive' : 'default'} disabled={pending} onClick={onConfirm}>
            {pending ? <LoaderCircleIcon className="animate-spin" /> : null}
            {action}
          </Button>
        </div>
      </AlertDialogContent>
    </AlertDialog>
  )
}
