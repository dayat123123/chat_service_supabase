import { useTranslation } from 'react-i18next'

import { AlertsTab } from '@/features/system/components/alerts-tab'

import { SectionFrame } from './settings-ui'

export function AlertsSection() {
  const { t } = useTranslation()
  return (
    <SectionFrame title={t('settings.alerts')} description={t('settings.alertsDescription')}>
      <AlertsTab />
    </SectionFrame>
  )
}
