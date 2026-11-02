import { useTranslation } from 'react-i18next'

import { Dot } from '@/components/badges'
import { cn } from '@/lib/utils'

import type { PushState } from '../types'

const tones = { active: 'ok', not_configured: 'warn', error: 'late', offline: 'late' } as const

const borders: Record<PushState, string> = {
  active: 'border-success/40 text-success',
  not_configured: 'border-warning/40 text-warning',
  error: 'border-destructive/40 text-destructive',
  offline: 'border-destructive/40 text-destructive',
}

export function PushStateBadge({ state, className }: { state: PushState; className?: string }) {
  const { t } = useTranslation()
  return (
    <span
      className={cn(
        'inline-flex shrink-0 items-center gap-1.5 rounded-sm border px-1.5 py-px text-xs font-medium',
        borders[state],
        className,
      )}
    >
      <Dot tone={tones[state]} />
      {t(`push.states.${state}`)}
    </span>
  )
}

export function PushInactiveBadge() {
  const { t } = useTranslation()
  return (
    <span className="inline-flex shrink-0 items-center gap-1.5 rounded-sm border border-warning/40 px-1.5 py-px text-xs font-medium text-warning">
      <Dot tone="warn" />
      {t('push.navInactive')}
    </span>
  )
}
