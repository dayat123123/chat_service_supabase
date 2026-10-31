import type { UseQueryResult } from '@tanstack/react-query'
import { useTranslation } from 'react-i18next'

import { Dot } from '@/components/badges'
import { ErrorState, ListSkeleton } from '@/components/states'
import { errorText } from '@/lib/error-text'
import { stamp } from '@/lib/time'
import { cn } from '@/lib/utils'

import type { SettingEntry } from '../types'

export function SectionFrame({
  title,
  description,
  action,
  children,
}: {
  title: string
  description?: string
  action?: React.ReactNode
  children: React.ReactNode
}) {
  return (
    <div className="mx-auto flex max-w-6xl flex-col gap-4 px-4 py-5 lg:px-6">
      <header className="flex flex-wrap items-start gap-3">
        <div className="min-w-0 flex-1">
          <h1 className="text-lg font-semibold">{title}</h1>
          {description ? (
            <p className="mt-1 max-w-3xl text-row text-muted-foreground">{description}</p>
          ) : null}
        </div>
        {action}
      </header>
      {children}
    </div>
  )
}

export function SettingsCard({
  title,
  subtitle,
  children,
  className,
}: {
  title: string
  subtitle?: string
  children: React.ReactNode
  className?: string
}) {
  return (
    <section className={cn('flex flex-col gap-3 border-t pt-4', className)}>
      <div>
        <h2 className="text-panel font-semibold">{title}</h2>
        {subtitle ? <p className="mt-0.5 text-row text-muted-foreground">{subtitle}</p> : null}
      </div>
      {children}
    </section>
  )
}

export function QueryContent<T>({
  query,
  children,
}: {
  query: UseQueryResult<T>
  children: (data: T) => React.ReactNode
}) {
  if (query.data !== undefined) return <>{children(query.data)}</>
  if (query.isError) return <ErrorState error={query.error} onRetry={() => void query.refetch()} />
  return <ListSkeleton rows={4} className="border-t" />
}

export function ActiveBadge({ active, inactiveLabel }: { active: boolean; inactiveLabel?: string }) {
  const { t } = useTranslation()
  return (
    <span className="inline-flex items-center gap-1.5 text-xs text-muted-foreground">
      <Dot tone={active ? 'ok' : 'neutral'} />
      {active ? t('app.active') : (inactiveLabel ?? t('app.inactive'))}
    </span>
  )
}

export function ChangedBy({ entry }: { entry: SettingEntry | undefined }) {
  const { t } = useTranslation()
  if (!entry?.updated_at) return null
  return (
    <p className="text-xs text-muted-foreground">
      {entry.updated_by
        ? t('settings.lastChangedBy', { time: stamp(entry.updated_at), name: entry.updated_by })
        : t('settings.lastChanged', { time: stamp(entry.updated_at) })}
    </p>
  )
}

export function FormError({ error }: { error: unknown }) {
  if (!error) return null
  return (
    <p role="alert" className="text-row text-destructive">
      {errorText(error)}
    </p>
  )
}

export function FieldMessage({ error, hint }: { error?: string; hint?: string }) {
  if (error) return <p className="text-xs text-destructive">{error}</p>
  return hint ? <p className="text-xs text-muted-foreground">{hint}</p> : null
}
