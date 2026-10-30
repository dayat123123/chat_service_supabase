import { ClockIcon, ShieldAlertIcon, StarIcon, FlagIcon } from 'lucide-react'
import { useTranslation } from 'react-i18next'

import type { AgentStatus } from '@/features/presence/types'
import { waitTone } from '@/lib/sla'
import { waitLabel } from '@/lib/time'
import { cn } from '@/lib/utils'

const priorityClass: Record<string, string> = {
  P1: 'text-p1 bg-p1/10 border-p1/30',
  P2: 'text-p2 bg-p2/10 border-p2/30',
  P3: 'text-p3 bg-p3/10 border-p3/30',
  P4: 'text-p4 bg-p4/10 border-p4/30',
}

export function PriorityBadge({ priority, className }: { priority: string; className?: string }) {
  const { t } = useTranslation()
  return (
    <span
      className={cn(
        'tabular inline-flex h-5 items-center rounded-md border px-1.5 text-[11px] font-bold',
        priorityClass[priority] ?? priorityClass.P4,
        className,
      )}
      aria-label={`${t('tickets.priority')} ${priority}`}
    >
      {priority}
    </span>
  )
}

const flagStyle = {
  fraud: { className: 'text-flag-fraud border-flag-fraud/40', icon: ShieldAlertIcon },
  complaint: { className: 'text-flag-complaint border-flag-complaint/40', icon: FlagIcon },
  vip: { className: 'text-flag-vip border-flag-vip/40', icon: StarIcon },
} as const

export function FlagBadge({ flag }: { flag: string }) {
  const { t } = useTranslation()
  const style = flagStyle[flag as keyof typeof flagStyle]
  if (!style) return null
  const Icon = style.icon
  return (
    <span
      className={cn(
        'inline-flex h-5 items-center gap-1 rounded-md border px-1.5 text-[11px] font-medium',
        style.className,
      )}
    >
      <Icon className="size-3" aria-hidden="true" />
      {t(`tickets.flags.${flag as keyof typeof flagStyle}`)}
    </span>
  )
}

const toneClass = {
  ok: 'text-sla-ok bg-sla-ok/10',
  warn: 'text-sla-warn bg-sla-warn/12',
  late: 'text-sla-late bg-sla-late/10',
}

export function WaitBadge({
  minutes,
  warn,
  late,
  label,
  urgent,
}: {
  minutes: number
  warn: number
  late: number
  label?: string
  urgent?: boolean
}) {
  const tone = urgent ? 'late' : waitTone(minutes, warn, late)
  return (
    <span
      className={cn(
        'tabular inline-flex h-5 items-center gap-1 rounded-md px-1.5 text-[11px] font-semibold',
        toneClass[tone],
      )}
    >
      <ClockIcon className="size-3" aria-hidden="true" />
      {label ?? waitLabel(minutes)}
    </span>
  )
}

const statusDot: Record<AgentStatus, string> = {
  online: 'bg-status-online',
  busy: 'bg-status-busy',
  break: 'bg-status-break',
  offline: 'bg-status-offline',
}

export function StatusDot({ status, className }: { status: AgentStatus; className?: string }) {
  return (
    <span
      aria-hidden="true"
      className={cn('inline-block size-2.5 rounded-full', statusDot[status], className)}
    />
  )
}

const ticketStatusClass: Record<string, string> = {
  open: 'bg-accent text-accent-foreground',
  claimed: 'bg-primary/12 text-primary',
  waiting_customer: 'bg-sla-warn/12 text-sla-warn',
  resolved: 'bg-sla-ok/12 text-sla-ok',
  closed: 'bg-muted text-muted-foreground',
}

export function TicketStatusBadge({ status }: { status: string }) {
  const { t } = useTranslation()
  const known = status in ticketStatusClass
  return (
    <span
      className={cn(
        'inline-flex h-5 items-center rounded-md px-1.5 text-[11px] font-medium',
        known ? ticketStatusClass[status] : ticketStatusClass.closed,
      )}
    >
      {known ? t(`tickets.status.${status as 'open'}`) : status}
    </span>
  )
}
