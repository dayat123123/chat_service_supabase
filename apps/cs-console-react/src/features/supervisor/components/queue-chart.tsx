import { useMemo } from 'react'
import { useTranslation } from 'react-i18next'
import { Bar, BarChart, CartesianGrid, LabelList, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts'

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
    <section className="flex flex-col rounded-xl border bg-card shadow-xs" aria-labelledby="queue-title">
      <header className="px-4 pt-4">
        <h2 id="queue-title" className="text-sm font-semibold">
          {t('dashboard.queueByPriority')}
        </h2>
        {open && total > shown ? (
          <p className="mt-0.5 text-xs text-muted-foreground">
            {t('dashboard.queueSample', { shown, total })}
          </p>
        ) : null}
      </header>
      {open === undefined ? (
        <Skeleton className="m-4 h-40" />
      ) : (
        <figure className="h-52 px-2 pt-2 pb-3">
          <ResponsiveContainer width="100%" height="100%">
            <BarChart
              data={data}
              layout="vertical"
              margin={{ top: 4, right: 40, bottom: 0, left: 4 }}
              barCategoryGap="30%"
            >
              <CartesianGrid horizontal={false} stroke={chartColors.grid} />
              <XAxis type="number" allowDecimals={false} tickLine={false} axisLine={false} tick={axisTick} />
              <YAxis
                type="category"
                dataKey="priority"
                width={36}
                tickLine={false}
                axisLine={{ stroke: chartColors.grid }}
                tick={{ ...axisTick, fontSize: 12, fontWeight: 600 }}
              />
              <Tooltip
                cursor={{ fill: chartColors.cursor, opacity: 0.6 }}
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
                fill={chartColors.series1}
                radius={[0, 4, 4, 0]}
                maxBarSize={24}
                isAnimationActive={false}
              >
                <LabelList
                  dataKey="count"
                  position="right"
                  offset={8}
                  fill="var(--foreground)"
                  fontSize={12}
                  fontWeight={600}
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
