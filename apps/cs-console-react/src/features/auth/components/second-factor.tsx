import { zodResolver } from '@hookform/resolvers/zod'
import { CheckIcon, CopyIcon, EyeIcon, EyeOffIcon } from 'lucide-react'
import { useState } from 'react'
import { useForm, useWatch } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod'

import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { errorText } from '@/lib/error-text'
import { cn } from '@/lib/utils'

import { useAuth } from '../hooks'
import { AuthError, AuthFrame, FieldError, SubmitButton } from './auth-frame'

const CODE_LENGTH = 6

const codeSchema = z.object({
  code: z
    .string()
    .trim()
    .regex(/^\d{6}$/, 'auth.codeInvalid'),
})

function CodeForm({ submitLabel }: { submitLabel: string }) {
  const { t } = useTranslation()
  const busy = useAuth((state) => state.busy)
  const verify = useAuth((state) => state.verify)
  const form = useForm<{ code: string }>({ resolver: zodResolver(codeSchema), defaultValues: { code: '' } })
  const code = useWatch({ control: form.control, name: 'code' })
  const [focused, setFocused] = useState(false)
  const { onBlur, ...field } = form.register('code')
  const error = form.formState.errors.code
  const active = Math.min(code.length, CODE_LENGTH - 1)
  return (
    <form
      noValidate
      className="flex flex-col gap-4"
      onSubmit={form.handleSubmit((values) => verify(values.code))}
    >
      <div className="flex flex-col gap-2">
        <Label htmlFor="code">{t('auth.code')}</Label>
        <div className="relative">
          <Input
            id="code"
            inputMode="numeric"
            autoComplete="one-time-code"
            autoFocus
            maxLength={CODE_LENGTH}
            className="absolute inset-0 h-full cursor-text caret-transparent opacity-0"
            aria-invalid={error ? true : undefined}
            aria-describedby={error ? 'code-error' : undefined}
            onFocus={() => setFocused(true)}
            onBlur={(event) => {
              setFocused(false)
              void onBlur(event)
            }}
            {...field}
          />
          <div aria-hidden="true" className="pointer-events-none grid grid-cols-6 gap-2">
            {Array.from({ length: CODE_LENGTH }, (_, index) => (
              <span
                key={index}
                className={cn(
                  'tabular flex h-11 items-center justify-center rounded-md border bg-background font-mono text-lg',
                  error && 'border-destructive',
                  focused && index === active && 'border-ring/60 ring-2 ring-ring/15',
                )}
              >
                {code[index] ?? ''}
              </span>
            ))}
          </div>
        </div>
        <FieldError id="code-error" message={error?.message && t(error.message as 'auth.codeInvalid')} />
      </div>
      <SubmitButton busy={busy} label={submitLabel} />
    </form>
  )
}

function OtherAccount() {
  const { t } = useTranslation()
  const signOut = useAuth((state) => state.signOut)
  return (
    <Button variant="link" className="self-center" onClick={() => void signOut('manual')}>
      {t('auth.useOtherAccount')}
    </Button>
  )
}

export function TotpPage() {
  const { t } = useTranslation()
  const error = useAuth((state) => state.error)
  return (
    <AuthFrame title={t('auth.totpTitle')} subtitle={t('auth.totpSubtitle')}>
      {error ? <AuthError message={errorText(error)} /> : null}
      <CodeForm submitLabel={t('auth.verify')} />
      <p className="text-xs text-muted-foreground">{t('auth.recoveryHint')}</p>
      <OtherAccount />
    </AuthFrame>
  )
}

export function EnrollPage({ secret, qr }: { secret: string; qr: string }) {
  const { t } = useTranslation()
  const error = useAuth((state) => state.error)
  const [copied, setCopied] = useState(false)
  const grouped = secret.replace(/(.{4})/g, '$1 ').trim()
  return (
    <AuthFrame title={t('auth.enrollTitle')} subtitle={t('auth.enrollSubtitle')}>
      {error ? <AuthError message={errorText(error)} /> : null}
      <div className="flex justify-center">
        <img
          src={qr}
          alt={t('auth.qrAlt')}
          width={184}
          height={184}
          className="rounded-lg border bg-qr p-2"
        />
      </div>
      <div className="flex items-center gap-2">
        <div className="flex-1">
          <p className="text-xs text-muted-foreground">{t('auth.manualKey')}</p>
          <p className="font-mono text-row break-all select-all">{grouped}</p>
        </div>
        <Button
          variant="ghost"
          size="icon-sm"
          aria-label={copied ? t('app.copied') : t('app.copy')}
          onClick={() => {
            void navigator.clipboard.writeText(secret).then(() => setCopied(true))
          }}
        >
          {copied ? <CheckIcon /> : <CopyIcon />}
        </Button>
      </div>
      <CodeForm submitLabel={t('auth.enrollActivate')} />
      <OtherAccount />
    </AuthFrame>
  )
}

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
      <OtherAccount />
    </AuthFrame>
  )
}
