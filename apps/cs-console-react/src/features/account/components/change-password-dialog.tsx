import { zodResolver } from '@hookform/resolvers/zod'
import { EyeIcon, EyeOffIcon, LoaderCircleIcon } from 'lucide-react'
import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

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
import { AuthError, FieldError } from '@/features/auth/components/auth-frame'

import { useChangeOwnPassword } from '../hooks'
import { accountErrorText, passwordSchema } from '../logic'
import type { PasswordValues } from '../types'

type MessageKey = 'auth.passwordTooShort'

export function ChangePasswordDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const { t } = useTranslation()
  const change = useChangeOwnPassword()
  const [visible, setVisible] = useState(false)
  const form = useForm<PasswordValues>({
    resolver: zodResolver(passwordSchema),
    defaultValues: { current: '', next: '', confirm: '' },
  })
  const { errors } = form.formState
  const close = () => {
    if (change.isPending) return
    form.reset()
    change.reset()
    setVisible(false)
    onClose()
  }
  const submit = form.handleSubmit((values) =>
    change.mutate(values, {
      onSuccess: (result) => {
        if (result.othersSignedOut) toast.success(t('account.password.success'))
        else toast.warning(t('account.password.successPartial'))
        form.reset()
        setVisible(false)
        onClose()
      },
      onError: () => form.setValue('current', ''),
    }),
  )
  const message = (value?: string) => (value ? t(value as MessageKey) : undefined)
  const type = visible ? 'text' : 'password'
  return (
    <Dialog open={open} onOpenChange={(next) => !next && close()}>
      <DialogContent closeLabel={t('app.close')}>
        <DialogHeader>
          <DialogTitle>{t('account.password.title')}</DialogTitle>
          <DialogDescription>{t('account.password.subtitle')}</DialogDescription>
        </DialogHeader>
        {change.error ? <AuthError message={accountErrorText(change.error)} /> : null}
        <form noValidate className="flex flex-col gap-4" onSubmit={(event) => void submit(event)}>
          <div className="flex flex-col gap-2">
            <Label htmlFor="current-password">{t('account.password.current')}</Label>
            <div className="relative">
              <Input
                id="current-password"
                type={type}
                autoComplete="current-password"
                autoFocus
                className="pr-10"
                aria-invalid={errors.current ? true : undefined}
                {...form.register('current')}
              />
              <Button
                type="button"
                variant="ghost"
                size="icon-sm"
                className="absolute top-0.5 right-0.5"
                aria-label={visible ? t('auth.hidePassword') : t('auth.showPassword')}
                aria-pressed={visible}
                onClick={() => setVisible((value) => !value)}
              >
                {visible ? <EyeOffIcon /> : <EyeIcon />}
              </Button>
            </div>
            <FieldError id="current-password-error" message={message(errors.current?.message)} />
          </div>
          <div className="flex flex-col gap-2">
            <Label htmlFor="own-new-password">{t('account.password.next')}</Label>
            <Input
              id="own-new-password"
              type={type}
              autoComplete="new-password"
              aria-invalid={errors.next ? true : undefined}
              aria-describedby="own-password-rules"
              {...form.register('next')}
            />
            <FieldError id="own-new-password-error" message={message(errors.next?.message)} />
          </div>
          <div className="flex flex-col gap-2">
            <Label htmlFor="own-confirm-password">{t('account.password.confirm')}</Label>
            <Input
              id="own-confirm-password"
              type={type}
              autoComplete="new-password"
              aria-invalid={errors.confirm ? true : undefined}
              {...form.register('confirm')}
            />
            <FieldError id="own-confirm-password-error" message={message(errors.confirm?.message)} />
          </div>
          <p id="own-password-rules" className="text-xs text-muted-foreground">
            {t('auth.passwordRules')}
          </p>
          <DialogFooter>
            <Button type="button" variant="outline" disabled={change.isPending} onClick={close}>
              {t('app.cancel')}
            </Button>
            <Button type="submit" disabled={change.isPending}>
              {change.isPending ? <LoaderCircleIcon className="animate-spin" aria-hidden="true" /> : null}
              {t('account.password.save')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}
