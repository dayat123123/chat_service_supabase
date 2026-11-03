import { useTranslation } from 'react-i18next'

import { ToneBadge } from '@/features/system/components/system-ui'

import type { ContentAction } from '../types'

const actionTones: Record<ContentAction, 'ok' | 'warn' | 'late' | 'neutral'> = {
  allow: 'ok',
  censor: 'neutral',
  hold: 'warn',
  block: 'late',
}

export function ActionBadge({ action }: { action: ContentAction }) {
  const { t } = useTranslation()
  return <ToneBadge tone={actionTones[action]}>{t(`policy.actions.${action}`)}</ToneBadge>
}

export function PolicyCard({
  title,
  subtitle,
  action,
  children,
}: {
  title: string
  subtitle?: string
  action?: React.ReactNode
  children: React.ReactNode
}) {
  return (
    <section className="flex flex-col gap-3 border-t pt-4">
      <div className="flex flex-wrap items-start justify-between gap-2">
        <div className="min-w-0 flex-1">
          <h2 className="text-panel font-semibold">{title}</h2>
          {subtitle ? <p className="mt-0.5 max-w-3xl text-row text-muted-foreground">{subtitle}</p> : null}
        </div>
        {action}
      </div>
      {children}
    </section>
  )
}
