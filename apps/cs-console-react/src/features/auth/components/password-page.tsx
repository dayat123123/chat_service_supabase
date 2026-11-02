import { zodResolver } from '@hookform/resolvers/zod'
import { EyeIcon, EyeOffIcon } from 'lucide-react'
import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod'

import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { errorText } from '@/lib/error-text'

import { useAuth } from '../hooks'
import { AuthError, AuthFrame, FieldError, SubmitButton } from './auth-frame'

const passwordSchema = z
  .object({
    password: z.string().min(12, 'auth.passwordTooShort'),
    confirm: z.string(),
  })
  .refine((values) => values.password === values.confirm, {
    path: ['confirm'],
    message: 'auth.passwordMismatch',
  })

type PasswordValues = z.infer<typeof passwordSchema>

export function PasswordPage() {
  const { t } = useTranslation()
  const busy = useAuth((state) => state.busy)
  const error = useAuth((state) => state.error)
  const changePassword = useAuth((state) => state.changePassword)
  const signOut = useAuth((state) => state.signOut)
  const [visible, setVisible] = useState(false)
  const form = useForm<PasswordValues>({
    resolver: zodResolver(passwordSchema),
    defaultValues: { password: '', confirm: '' },
  })
  const { errors } = form.formState
  const toggle = (
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
  )
  return (
    <AuthFrame title={t('auth.passwordTitle')} subtitle={t('auth.passwordSubtitle')}>
      {error ? <AuthError message={errorText(error)} /> : null}
      <form
        noValidate
        className="flex flex-col gap-4"
        onSubmit={form.handleSubmit((values) => changePassword(values.password))}
      >
        <div className="flex flex-col gap-2">
          <Label htmlFor="new-password">{t('auth.newPassword')}</Label>
          <div className="relative">
            <Input
              id="new-password"
              type={visible ? 'text' : 'password'}
              autoComplete="new-password"
              autoFocus
              className="pr-10"
              aria-invalid={errors.password ? true : undefined}
              aria-describedby="password-rules"
              {...form.register('password')}
            />
            {toggle}
          </div>
          <FieldError
            id="new-password-error"
            message={errors.password?.message && t(errors.password.message as 'auth.passwordTooShort')}
          />
        </div>
        <div className="flex flex-col gap-2">
          <Label htmlFor="confirm-password">{t('auth.confirmPassword')}</Label>
          <Input
            id="confirm-password"
            type={visible ? 'text' : 'password'}
            autoComplete="new-password"
            aria-invalid={errors.confirm ? true : undefined}
            {...form.register('confirm')}
          />
          <FieldError
            id="confirm-error"
            message={errors.confirm?.message && t(errors.confirm.message as 'auth.passwordMismatch')}
          />
        </div>
        <p id="password-rules" className="text-xs text-muted-foreground">
          {t('auth.passwordRules')}
        </p>
        <SubmitButton busy={busy} label={t('auth.savePassword')} />
      </form>
      <Button variant="link" className="self-center" onClick={() => void signOut('manual')}>
        {t('auth.useOtherAccount')}
      </Button>
    </AuthFrame>
  )
}
