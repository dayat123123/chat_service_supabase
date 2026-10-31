import { useMemo } from 'react'
import { useTranslation } from 'react-i18next'
import { Bar, BarChart, Cell, LabelList, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts'

import { ChartTooltip } from '@/components/chart-tooltip'
import { Skeleton } from '@/components/ui/primitives'
import { ticketPriorities, type Ticket } from '@/features/tickets/types'
import { axisTick, chartColors } from '@/lib/chart'

export function QueueChart({ open, total }: { open: Ticket[] | undefined; total: number }) {
  const { t } = useTranslation()
  const data = useMemo(
    () =>
      ticketPriorities.map((priority) => ({
        priority,
        count: (open ?? []).filter((ticket) => ticket.priority === priority).length,
      })),
    [open],
  )
  const shown = open?.length ?? 0
  return (
    <section className="flex min-w-0 flex-col gap-3" aria-labelledby="queue-title">
      <header>
        <h2 id="queue-title" className="text-panel font-semibold">
          {t('dashboard.queueByPriority')}
        </h2>
        {open && total > shown ? (
          <p className="mt-0.5 text-xs text-muted-foreground">
            {t('dashboard.queueSample', { shown, total })}
          </p>
        ) : null}
      </header>
      {open === undefined ? (
        <Skeleton className="h-40" />
      ) : (
        <figure className="h-48 border-y py-3">
          <ResponsiveContainer width="100%" height="100%">
            <BarChart
              data={data}
              layout="vertical"
              margin={{ top: 0, right: 32, bottom: 0, left: 0 }}
              barCategoryGap="32%"
            >
              <XAxis type="number" hide allowDecimals={false} />
              <YAxis
                type="category"
                dataKey="priority"
                width={32}
                tickLine={false}
                axisLine={false}
                tick={{ ...axisTick, fontWeight: 500 }}
              />
              <Tooltip
                cursor={{ fill: chartColors.cursor }}
                content={({ active, payload, label }) => (
                  <ChartTooltip
                    active={active}
                    payload={payload}
                    title={`${t('tickets.priority')} ${String(label ?? '')}`}
                  />
                )}
              />
              <Bar
                dataKey="count"
                name={t('dashboard.tickets')}
                radius={[0, 4, 4, 0]}
                maxBarSize={14}
                isAnimationActive={false}
              >
                {data.map((item) => (
                  <Cell
                    key={item.priority}
                    fill={item.priority === 'P1' ? chartColors.accent : chartColors.neutral}
                  />
                ))}
                <LabelList
                  dataKey="count"
                  position="right"
                  offset={8}
                  fill={chartColors.label}
                  fontSize={12}
                />
              </Bar>
            </BarChart>
          </ResponsiveContainer>
          <figcaption className="sr-only">
            {data.map((item) => `${item.priority}: ${item.count}`).join(', ')}
          </figcaption>
        </figure>
      )}
    </section>
  )
}
