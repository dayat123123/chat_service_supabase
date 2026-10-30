import type { TooltipContentProps } from 'recharts'

import { formatNumber } from '@/lib/time'

export function ChartTooltip({
  active,
  payload,
  title,
}: Pick<TooltipContentProps<number, string>, 'active' | 'payload'> & { title: string }) {
  if (!active || payload.length === 0) return null
  return (
    <div className="min-w-36 rounded-lg border bg-popover px-3 py-2 text-xs text-popover-foreground shadow-md">
      <p className="mb-1.5 font-medium text-muted-foreground">{title}</p>
      <ul className="flex flex-col gap-1">
        {payload.map((entry) => (
          <li key={String(entry.dataKey)} className="flex items-center gap-2">
            <span
              aria-hidden="true"
              className="h-0.5 w-3 rounded-full"
              style={{ backgroundColor: entry.color }}
            />
            <span className="tabular text-sm font-semibold">{formatNumber(Number(entry.value ?? 0))}</span>
            <span className="text-muted-foreground">{entry.name}</span>
          </li>
        ))}
      </ul>
    </div>
  )
}
