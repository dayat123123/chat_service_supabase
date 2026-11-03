import { CircleCheckIcon, KeyRoundIcon } from 'lucide-react'
import { useTranslation } from 'react-i18next'

import { Dot } from '@/components/badges'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import type { WaitTone } from '@/lib/sla'
import { cn } from '@/lib/utils'

const toneBorders: Record<WaitTone | 'neutral', string> = {
  ok: 'border-success/40 text-success',
  warn: 'border-warning/40 text-warning',
  late: 'border-destructive/40 text-destructive',
  neutral: 'border-border text-muted-foreground',
}

export function ToneBadge({
  tone,
  children,
  className,
}: {
  tone: WaitTone | 'neutral'
  children: React.ReactNode
  className?: string
}) {
  return (
    <span
      className={cn(
        'inline-flex shrink-0 items-center gap-1.5 rounded-sm border px-1.5 py-px text-xs font-medium whitespace-nowrap',
        toneBorders[tone],
        className,
      )}
    >
      <Dot tone={tone} />
      {children}
    </span>
  )
}

export function FieldText({ id, error, hint }: { id: string; error?: string; hint?: React.ReactNode }) {
  if (!error && !hint) return null
  return (
    <p id={id} className={cn('text-xs', error ? 'text-destructive' : 'text-muted-foreground')}>
      {error ?? hint}
    </p>
  )
}

export function TextField({
  id,
  label,
  value,
  onChange,
  error,
  hint,
  className,
  ...props
}: Omit<React.ComponentProps<'input'>, 'onChange' | 'value'> & {
  id: string
  label: string
  value: string
  onChange: (value: string) => void
  error?: string
  hint?: React.ReactNode
}) {
  return (
    <div className={cn('flex min-w-0 flex-col gap-1.5', className)}>
      <Label htmlFor={id}>{label}</Label>
      <Input
        id={id}
        value={value}
        aria-invalid={error ? true : undefined}
        aria-describedby={error || hint ? `${id}-text` : undefined}
        onChange={(event) => onChange(event.target.value)}
        {...props}
      />
      <FieldText id={`${id}-text`} error={error} hint={hint} />
    </div>
  )
}

export function SecretField({
  id,
  label,
  stored,
  value,
  onChange,
  error,
  hint,
  disabled,
  className,
  autoComplete = 'new-password',
}: {
  id: string
  label: string
  stored: boolean
  value: string
  onChange: (value: string) => void
  error?: string
  hint?: React.ReactNode
  disabled?: boolean
  className?: string
  autoComplete?: string
}) {
  const { t } = useTranslation()
  return (
    <div className={cn('flex min-w-0 flex-col gap-1.5', className)}>
      <div className="flex flex-wrap items-center gap-2">
        <Label htmlFor={id}>{label}</Label>
        {stored ? (
          <span className="inline-flex items-center gap-1 text-xs text-success">
            <CircleCheckIcon className="size-3.5" aria-hidden="true" />
            {t('system.secret.stored')}
          </span>
        ) : null}
      </div>
      <div className="relative">
        <KeyRoundIcon
          className="pointer-events-none absolute top-1/2 left-2.5 size-4 -translate-y-1/2 text-muted-foreground"
          aria-hidden="true"
        />
        <Input
          id={id}
          type="password"
          value={value}
          disabled={disabled}
          autoComplete={autoComplete}
          spellCheck={false}
          placeholder={stored ? t('system.secret.keep') : undefined}
          className="pl-8"
          aria-invalid={error ? true : undefined}
          aria-describedby={`${id}-text`}
          onChange={(event) => onChange(event.target.value)}
        />
      </div>
      <FieldText
        id={`${id}-text`}
        error={error}
        hint={hint ?? (stored ? t('system.secret.storedHint') : t('system.secret.writeOnly'))}
      />
    </div>
  )
}
