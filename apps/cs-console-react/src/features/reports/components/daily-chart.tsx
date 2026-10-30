import { useMemo } from 'react'
import { useTranslation } from 'react-i18next'
import {
  CartesianGrid,
  LabelList,
  Line,
  LineChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
  type LabelProps,
} from 'recharts'

import { ChartTooltip } from '@/components/chart-tooltip'
import { axisTick, chartColors } from '@/lib/chart'
import { formatDay, formatNumber } from '@/lib/time'

import type { ReportStats } from '../types'

const series = [
  { key: 'created', label: 'reports.created', color: chartColors.series1 },
  { key: 'resolved', label: 'reports.resolved', color: chartColors.series2 },
] as const

const endLabel =
  (last: number) =>
  ({ x, y, value, index }: LabelProps) => {
    if (index !== last || x === undefined || y === undefined) return null
    return (
      <text x={Number(x) + 8} y={Number(y)} dy={4} fill="var(--foreground)" fontSize={12} fontWeight={600}>
        {formatNumber(Number(value ?? 0))}
      </text>
    )
  }

export function DailyChart({ daily }: { daily: ReportStats[] }) {
  const { t } = useTranslation()
  const data = useMemo(
    () =>
      daily
        .filter((day) => day.day)
        .map((day) => ({ day: day.day ?? '', created: day.created, resolved: day.resolved })),
    [daily],
  )
  const last = data.length - 1
  const final = data[last]
  const peak = Math.max(1, ...data.map((day) => Math.max(day.created, day.resolved)))
  const labelled = final !== undefined && Math.abs(final.created - final.resolved) / peak >= 0.12
  const dots = data.length <= 31
  return (
    <figure className="flex flex-col gap-2">
      <ul className="flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-muted-foreground">
        {series.map((item) => (
          <li key={item.key} className="inline-flex items-center gap-1.5">
            <span
              aria-hidden="true"
              className="h-0.5 w-4 rounded-full"
              style={{ backgroundColor: item.color }}
            />
            {t(item.label)}
          </li>
        ))}
      </ul>
      <div className="h-64">
        <ResponsiveContainer width="100%" height="100%">
          <LineChart data={data} margin={{ top: 8, right: labelled ? 40 : 16, bottom: 0, left: 0 }}>
            <CartesianGrid vertical={false} stroke={chartColors.grid} />
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
              content={({ active, payload, label }) => (
                <ChartTooltip
                  active={active}
                  payload={payload}
                  title={typeof label === 'string' ? formatDay(label, 'EEEE, d MMM yyyy') : ''}
                />
              )}
            />
            {series.map((item) => (
              <Line
                key={item.key}
                type="linear"
                dataKey={item.key}
                name={t(item.label)}
                stroke={item.color}
                strokeWidth={2}
                strokeLinecap="round"
                strokeLinejoin="round"
                dot={dots ? { r: 4, strokeWidth: 2, stroke: chartColors.surface, fill: item.color } : false}
                activeDot={{ r: 5, strokeWidth: 2, stroke: chartColors.surface, fill: item.color }}
                isAnimationActive={false}
              >
                {labelled ? <LabelList dataKey={item.key} content={endLabel(last)} /> : null}
              </Line>
            ))}
          </LineChart>
        </ResponsiveContainer>
      </div>
    </figure>
  )
}
