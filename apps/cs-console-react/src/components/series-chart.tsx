import { CartesianGrid, Line, LineChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts'

import { ChartTooltip } from '@/components/chart-tooltip'
import { axisTick, chartColors } from '@/lib/chart'
import { formatDay } from '@/lib/time'

export type ChartSeries<K extends string> = { key: K; label: string; color: string; dash?: string }

export function SeriesLegend<K extends string>({ series }: { series: ChartSeries<K>[] }) {
  return (
    <ul className="flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-muted-foreground">
      {series.map((item) => (
        <li key={item.key} className="inline-flex items-center gap-1.5">
          <svg aria-hidden="true" width="16" height="2" className="shrink-0">
            <line
              x1="0"
              y1="1"
              x2="16"
              y2="1"
              stroke={item.color}
              strokeWidth="2"
              strokeDasharray={item.dash}
            />
          </svg>
          {item.label}
        </li>
      ))}
    </ul>
  )
}

export function SeriesChart<K extends string>({
  data,
  series,
  label,
  height = 'h-56',
}: {
  data: ({ day: string } & Record<K, number>)[]
  series: ChartSeries<K>[]
  label: string
  height?: string
}) {
  const dots = data.length <= 31
  return (
    <figure className="flex flex-col gap-2" aria-label={label}>
      <SeriesLegend series={series} />
      <div className={height}>
        <ResponsiveContainer width="100%" height="100%">
          <LineChart data={data} margin={{ top: 8, right: 16, bottom: 0, left: 0 }}>
            <CartesianGrid vertical={false} stroke={chartColors.grid} strokeDasharray="2 4" />
            <XAxis
              dataKey="day"
              tickLine={false}
              axisLine={{ stroke: chartColors.grid }}
              tick={axisTick}
              minTickGap={24}
              tickFormatter={(day: string) => formatDay(day, 'd MMM')}
            />
            <YAxis allowDecimals={false} tickLine={false} axisLine={false} width={36} tick={axisTick} />
            <Tooltip
              cursor={{ stroke: chartColors.axis, strokeWidth: 1 }}
              content={({ active, payload, label: day }) => (
                <ChartTooltip
                  active={active}
                  payload={payload}
                  title={typeof day === 'string' ? formatDay(day, 'EEEE, d MMM yyyy') : ''}
                />
              )}
            />
            {series.map((item) => (
              <Line
                key={item.key}
                type="linear"
                dataKey={item.key}
                name={item.label}
                stroke={item.color}
                strokeWidth={2}
                strokeDasharray={item.dash}
                strokeLinecap="round"
                strokeLinejoin="round"
                dot={dots ? { r: 3, strokeWidth: 2, stroke: chartColors.surface, fill: item.color } : false}
                activeDot={{ r: 4, strokeWidth: 2, stroke: chartColors.surface, fill: item.color }}
                isAnimationActive={false}
              />
            ))}
          </LineChart>
        </ResponsiveContainer>
      </div>
    </figure>
  )
}
