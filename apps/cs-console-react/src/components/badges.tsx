import { useTranslation } from 'react-i18next'

import type { AgentStatus } from '@/features/presence/types'
import { waitTone, type WaitTone } from '@/lib/sla'
import { waitLabel } from '@/lib/time'
import { cn } from '@/lib/utils'

const priorityClass: Record<string, string> = {
  P1: 'text-danger',
  P2: 'text-warning',
}

export function PriorityText({ priority, className }: { priority: string; className?: string }) {
  const { t } = useTranslation()
  return (
    <span
      className={cn('tabular font-medium', priorityClass[priority] ?? 'text-muted-foreground', className)}
      aria-label={`${t('tickets.priority')} ${priority}`}
    >
      {priority}
    </span>
  )
}

const flagClass = {
  fraud: 'text-danger',
  complaint: 'text-info',
  vip: 'text-muted-foreground',
} as const

export function FlagText({ flag, className }: { flag: string; className?: string }) {
  const { t } = useTranslation()
  const tone = flagClass[flag as keyof typeof flagClass]
  if (!tone) return null
  return (
    <span className={cn('font-medium', tone, className)}>
      {t(`tickets.flags.${flag as keyof typeof flagClass}`)}
    </span>
  )
}

const dotClass: Record<WaitTone | 'neutral', string> = {
  ok: 'bg-signal-success',
  warn: 'bg-signal-warning',
  late: 'bg-signal-danger',
  neutral: 'bg-signal-neutral',
}

export function Dot({ tone, className }: { tone: WaitTone | 'neutral'; className?: string }) {
  return (
    <span
      aria-hidden="true"
      className={cn('inline-block size-2 shrink-0 rounded-full', dotClass[tone], className)}
    />
  )
}

export function WaitTime({
  minutes,
  warn,
  late,
  urgent,
  className,
}: {
  minutes: number
  warn: number
  late: number
  urgent?: boolean
  className?: string
}) {
  const tone = urgent ? 'late' : waitTone(minutes, warn, late)
  return (
    <span className={cn('tabular inline-flex items-center gap-1.5 text-xs text-muted-foreground', className)}>
      <Dot tone={tone} />
      {waitLabel(minutes)}
    </span>
  )
}

const statusTone: Record<AgentStatus, WaitTone | 'neutral'> = {
  online: 'ok',
  busy: 'late',
  break: 'warn',
  offline: 'neutral',
}

export function StatusDot({ status, className }: { status: AgentStatus; className?: string }) {
  return <Dot tone={statusTone[status]} className={className} />
}

export function TicketStatusText({ status, className }: { status: string; className?: string }) {
  const { t } = useTranslation()
  const known = ['open', 'claimed', 'waiting_customer', 'resolved', 'closed'].includes(status)
  return (
    <span className={cn('text-xs text-muted-foreground', className)}>
      {known ? t(`tickets.status.${status as 'open'}`) : status}
    </span>
  )
}

export function UnreadBadge({ count, label }: { count: number; label: string }) {
  return (
    <span
      className="tabular inline-flex h-[18px] min-w-[18px] shrink-0 items-center justify-center rounded-full bg-primary px-1 text-[11px] font-medium text-primary-foreground"
      aria-label={label}
    >
      {count}
    </span>
  )
}
