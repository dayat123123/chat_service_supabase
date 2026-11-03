import { useTranslation } from 'react-i18next'

import { cn } from '@/lib/utils'

import { engagementValue, type Engagement } from './engagement'

export function EngagementItems({
  value,
  termClassName,
  valueClassName,
}: {
  value: Engagement
  termClassName?: string
  valueClassName?: string
}) {
  const { t } = useTranslation()
  const items = [
    {
      key: 'opened',
      label: t('notificationStats.opened'),
      text: engagementValue(value.opened, value.open_rate),
    },
    {
      key: 'tapped',
      label: t('notificationStats.tapped'),
      text: engagementValue(value.tapped, value.tap_rate),
    },
  ]
  return (
    <>
      {items.map((item) => (
        <div key={item.key} className="min-w-0" title={t('notificationStats.hint')}>
          <dt className={termClassName}>{item.label}</dt>
          <dd className={cn('tabular', valueClassName)}>{item.text}</dd>
        </div>
      ))}
    </>
  )
}
