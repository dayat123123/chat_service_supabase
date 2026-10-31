import type { WaitTone } from '@/lib/sla'
import { cn } from '@/lib/utils'

import { Dot } from './badges'

export type Metric = { label: string; value: string; caption?: string; tone?: WaitTone }

const columns: Record<number, string> = {
  4: 'xl:grid-cols-4',
  5: 'xl:grid-cols-5',
  6: 'xl:grid-cols-6',
}

export function MetricStrip({ metrics, className }: { metrics: Metric[]; className?: string }) {
  return (
    <dl
      className={cn(
        'grid grid-cols-2 gap-px overflow-hidden border-y bg-border md:grid-cols-3',
        columns[metrics.length],
        className,
      )}
    >
      {metrics.map((metric) => (
        <div
          key={metric.label}
          className="flex min-w-0 flex-col gap-0.5 bg-background px-4 py-3 compact:py-2"
        >
          <dt className="truncate text-xs text-muted-foreground">{metric.label}</dt>
          <dd className="tabular flex items-center gap-2 text-metric font-medium">
            {metric.tone ? <Dot tone={metric.tone} /> : null}
            {metric.value}
          </dd>
          {metric.caption ? (
            <dd className="truncate text-xs text-muted-foreground">{metric.caption}</dd>
          ) : null}
        </div>
      ))}
    </dl>
  )
}
