import { cn } from '@/lib/utils'

const toneClass = {
  neutral: 'bg-primary/10 text-primary',
  ok: 'bg-sla-ok/12 text-sla-ok',
  warn: 'bg-sla-warn/14 text-sla-warn',
  late: 'bg-sla-late/12 text-sla-late',
  rating: 'bg-flag-vip/14 text-flag-vip',
}

export type StatTone = keyof typeof toneClass

export function StatTile({
  label,
  value,
  caption,
  icon: Icon,
  tone = 'neutral',
  className,
}: {
  label: string
  value: string
  caption?: string
  icon: React.ComponentType<{ className?: string }>
  tone?: StatTone
  className?: string
}) {
  return (
    <div
      className={cn('flex items-start gap-3 rounded-xl border bg-card p-4 shadow-xs compact:p-3', className)}
    >
      <span
        className={cn('inline-flex size-9 shrink-0 items-center justify-center rounded-lg', toneClass[tone])}
      >
        <Icon className="size-[18px]" aria-hidden="true" />
      </span>
      <div className="min-w-0">
        <p className="truncate text-xs font-medium text-muted-foreground">{label}</p>
        <p className="mt-0.5 text-2xl leading-tight font-semibold">{value}</p>
        {caption ? <p className="mt-0.5 truncate text-xs text-muted-foreground">{caption}</p> : null}
      </div>
    </div>
  )
}
