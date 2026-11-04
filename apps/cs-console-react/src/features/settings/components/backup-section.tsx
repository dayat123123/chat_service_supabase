import { useTranslation } from 'react-i18next'

import { BackupTab } from '@/features/system/components/backup-tab'

import { SectionFrame } from './settings-ui'

export function BackupSection() {
  const { t } = useTranslation()
  return (
    <SectionFrame title={t('settings.backup')} description={t('settings.backupDescription')}>
      <BackupTab />
    </SectionFrame>
  )
}
