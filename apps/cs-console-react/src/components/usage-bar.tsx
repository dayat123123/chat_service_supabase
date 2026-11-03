import type { WaitTone } from '@/lib/sla'
import { cn } from '@/lib/utils'

export type UsageTone = WaitTone | 'neutral' | 'accent'

const fills: Record<UsageTone, string> = {
  ok: 'bg-signal-success',
  warn: 'bg-signal-warning',
  late: 'bg-signal-danger',
  neutral: 'bg-chart-neutral',
  accent: 'bg-chart-accent',
}

export function UsageBar({
  ratio,
  tone = 'accent',
  label,
  valueText,
  className,
}: {
  ratio: number
  tone?: UsageTone
  label: string
  valueText: string
  className?: string
}) {
  const percent = Math.round(Math.min(1, Math.max(0, ratio)) * 1000) / 10
  return (
    <div
      role="meter"
      aria-label={label}
      aria-valuemin={0}
      aria-valuemax={100}
      aria-valuenow={percent}
      aria-valuetext={valueText}
      className={cn('h-1.5 w-full overflow-hidden rounded-full bg-muted', className)}
    >
      <div
        className={cn('h-full rounded-full transition-[width]', fills[tone])}
        style={{ width: `${percent}%` }}
      />
    </div>
  )
}
