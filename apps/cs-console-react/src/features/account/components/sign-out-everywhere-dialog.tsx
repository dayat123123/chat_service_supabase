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
import { AuthError } from '@/features/auth/components/auth-frame'

import { useSignOutEverywhere } from '../hooks'
import { accountErrorText } from '../logic'

export function SignOutEverywhereDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const { t } = useTranslation()
  const signOut = useSignOutEverywhere()
  const close = () => {
    if (signOut.isPending) return
    signOut.reset()
    onClose()
  }
  return (
    <AlertDialog open={open} onOpenChange={(next) => !next && close()}>
      <AlertDialogContent>
        <AlertDialogTitle>{t('account.signOutAll.title')}</AlertDialogTitle>
        <AlertDialogDescription>{t('account.signOutAll.body')}</AlertDialogDescription>
        {signOut.error ? <AuthError message={accountErrorText(signOut.error)} /> : null}
        <div className="flex justify-end gap-2">
          <AlertDialogCancel disabled={signOut.isPending}>{t('app.cancel')}</AlertDialogCancel>
          <Button variant="destructive" disabled={signOut.isPending} onClick={() => signOut.mutate()}>
            {signOut.isPending ? <LoaderCircleIcon className="animate-spin" aria-hidden="true" /> : null}
            {t('account.signOutAll.action')}
          </Button>
        </div>
      </AlertDialogContent>
    </AlertDialog>
  )
}
