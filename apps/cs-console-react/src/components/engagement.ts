import { useTranslation } from 'react-i18next'

import { formatNumber } from '@/lib/time'

export type Engagement = {
  opened?: number | null
  tapped?: number | null
  open_rate?: number | null
  tap_rate?: number | null
}

export function engagementValue(count: number | null | undefined, rate: number | null | undefined) {
  const total = formatNumber(count ?? 0)
  return rate === null || rate === undefined ? total : `${total} (${formatNumber(rate, 1)}%)`
}

export function useEngagementSummary() {
  const { t } = useTranslation()
  return (value: Engagement) =>
    t('notificationStats.summary', {
      opened: engagementValue(value.opened, value.open_rate),
      tapped: engagementValue(value.tapped, value.tap_rate),
    })
}
