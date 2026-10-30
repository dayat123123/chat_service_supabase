import { AlertCircleIcon, LoaderCircleIcon } from 'lucide-react'
import * as React from 'react'

import { Logo } from '@/components/logo'
import { Button } from '@/components/ui/button'

export function AuthFrame({
  title,
  subtitle,
  children,
}: {
  title: string
  subtitle?: string
  children: React.ReactNode
}) {
  return (
    <main className="flex min-h-full items-center justify-center bg-background p-6">
      <section
        aria-labelledby="auth-title"
        className="w-full max-w-[420px] rounded-2xl border bg-card p-7 shadow-sm"
      >
        <Logo />
        <h1 id="auth-title" className="mt-6 text-xl font-semibold tracking-tight">
          {title}
        </h1>
        {subtitle ? <p className="mt-1.5 text-sm text-muted-foreground">{subtitle}</p> : null}
        <div className="mt-5 flex flex-col gap-4">{children}</div>
      </section>
    </main>
  )
}

export function AuthError({ message }: { message: string }) {
  return (
    <div
      role="alert"
      className="flex items-start gap-2 rounded-md border border-destructive/30 bg-destructive/10 px-3 py-2 text-sm text-destructive"
    >
      <AlertCircleIcon className="mt-0.5 size-4 shrink-0" aria-hidden="true" />
      <span>{message}</span>
    </div>
  )
}

export function SubmitButton({
  busy,
  label,
  busyLabel,
}: {
  busy: boolean
  label: string
  busyLabel?: string
}) {
  return (
    <Button type="submit" size="lg" disabled={busy} className="w-full">
      {busy ? <LoaderCircleIcon className="animate-spin" aria-hidden="true" /> : null}
      {busy && busyLabel ? busyLabel : label}
    </Button>
  )
}

export function FieldError({ id, message }: { id: string; message?: string }) {
  if (!message) return null
  return (
    <p id={id} className="text-xs text-destructive">
      {message}
    </p>
  )
}
