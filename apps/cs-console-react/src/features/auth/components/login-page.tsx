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
import type { SignOutReason } from '../types'
import { AuthError, AuthFrame, FieldError, SubmitButton } from './auth-frame'

const schema = z.object({
  email: z.string().trim().min(1, 'auth.emailRequired'),
  password: z.string().min(1, 'auth.passwordRequired'),
})

type Values = z.infer<typeof schema>

export function LoginPage({ reason, idleMinutes }: { reason?: SignOutReason; idleMinutes: number }) {
  const { t } = useTranslation()
  const busy = useAuth((state) => state.busy)
  const error = useAuth((state) => state.error)
  const signIn = useAuth((state) => state.signIn)
  const [visible, setVisible] = useState(false)
  const form = useForm<Values>({ resolver: zodResolver(schema), defaultValues: { email: '', password: '' } })
  const { errors } = form.formState

  const notice =
    reason === 'idle'
      ? t('auth.signedOutIdle', { minutes: idleMinutes })
      : reason === 'expired'
        ? t('auth.signedOutExpired')
        : reason === 'notStaff'
          ? t('auth.signedOutNotStaff')
          : null

  return (
    <AuthFrame title={t('auth.loginTitle')} subtitle={t('auth.loginSubtitle')}>
      {error ? <AuthError message={errorText(error)} /> : notice ? <AuthError message={notice} /> : null}
      <form
        noValidate
        className="flex flex-col gap-4"
        onSubmit={form.handleSubmit((values) => signIn(values.email, values.password))}
      >
        <div className="flex flex-col gap-2">
          <Label htmlFor="email">{t('auth.email')}</Label>
          <Input
            id="email"
            type="email"
            autoComplete="username"
            autoFocus
            aria-invalid={errors.email ? true : undefined}
            aria-describedby={errors.email ? 'email-error' : undefined}
            {...form.register('email')}
          />
          <FieldError
            id="email-error"
            message={errors.email?.message && t(errors.email.message as 'auth.emailRequired')}
          />
        </div>
        <div className="flex flex-col gap-2">
          <Label htmlFor="password">{t('auth.password')}</Label>
          <div className="relative">
            <Input
              id="password"
              type={visible ? 'text' : 'password'}
              autoComplete="current-password"
              className="pr-10"
              aria-invalid={errors.password ? true : undefined}
              aria-describedby={errors.password ? 'password-error' : undefined}
              {...form.register('password')}
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
          <FieldError
            id="password-error"
            message={errors.password?.message && t(errors.password.message as 'auth.passwordRequired')}
          />
        </div>
        <SubmitButton busy={busy} label={t('auth.signIn')} busyLabel={t('auth.signingIn')} />
      </form>
    </AuthFrame>
  )
}
