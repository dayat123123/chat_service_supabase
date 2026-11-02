import { useTranslation } from 'react-i18next'

import type { CaseRow, Deadline } from './types'

export function useDeadlineLabel() {
  const { t } = useTranslation()
  return (deadline: Deadline) => {
    const days = deadline.business_days
    switch (deadline.state) {
      case 'running':
        return t('compliance.deadline.running', { days })
      case 'due_soon':
        return days === 0 ? t('compliance.deadline.dueToday') : t('compliance.deadline.dueNext')
      case 'overdue':
        return days > 0 ? t('compliance.deadline.overdueDays', { days }) : t('compliance.deadline.overdue')
      case 'met':
        return t('compliance.deadline.met')
      case 'missed':
        return days > 0 ? t('compliance.deadline.missedDays', { days }) : t('compliance.deadline.missed')
    }
  }
}

export function useCaseKindLabel() {
  const { t } = useTranslation()
  return (row: Pick<CaseRow, 'flags'>) =>
    [
      row.flags.includes('complaint') ? t('compliance.kind.complaint') : null,
      row.flags.includes('fraud') ? t('compliance.kind.fraud') : null,
    ]
      .filter(Boolean)
      .join(' + ')
}
