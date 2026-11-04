import { XIcon } from 'lucide-react'
import { useTranslation } from 'react-i18next'

import { cn } from '@/lib/utils'

import type { LabelColor, TicketLabel } from '../types'

const dotClass: Record<LabelColor, string> = {
  neutral: 'bg-signal-neutral',
  info: 'bg-info',
  success: 'bg-signal-success',
  warning: 'bg-signal-warning',
  danger: 'bg-signal-danger',
}

export function LabelDot({ color, className }: { color: LabelColor; className?: string }) {
  return (
    <span
      aria-hidden="true"
      className={cn('inline-block size-2 shrink-0 rounded-full', dotClass[color], className)}
    />
  )
}

export function LabelChip({
  label,
  onRemove,
  disabled,
  className,
}: {
  label: TicketLabel
  onRemove?: () => void
  disabled?: boolean
  className?: string
}) {
  const { t } = useTranslation()
  return (
    <span
      className={cn(
        'inline-flex h-6 max-w-full items-center gap-1.5 rounded-md border bg-background pl-2 text-xs',
        onRemove ? 'pr-0.5' : 'pr-2',
        className,
      )}
    >
      <LabelDot color={label.color} />
      <span className="truncate">{label.name}</span>
      {onRemove ? (
        <button
          type="button"
          disabled={disabled}
          aria-label={t('labels.remove', { name: label.name })}
          onClick={onRemove}
          className="inline-flex size-5 shrink-0 items-center justify-center rounded-sm text-muted-foreground outline-none hover:bg-muted hover:text-foreground focus-visible:ring-2 focus-visible:ring-ring/50 disabled:pointer-events-none disabled:opacity-50"
        >
          <XIcon className="size-3" />
        </button>
      ) : null}
    </span>
  )
}

export function LabelNames({ labels, className }: { labels: TicketLabel[]; className?: string }) {
  if (labels.length === 0) return null
  return (
    <span className={cn('inline-flex min-w-0 items-center gap-2', className)}>
      {labels.map((label) => (
        <span key={label.id} className="inline-flex min-w-0 items-center gap-1">
          <LabelDot color={label.color} />
          <span className="truncate">{label.name}</span>
        </span>
      ))}
    </span>
  )
}
