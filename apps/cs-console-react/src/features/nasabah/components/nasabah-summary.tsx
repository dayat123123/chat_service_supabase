import { useTranslation } from 'react-i18next'

import { MetricStrip, type Metric } from '@/components/metric-strip'

import { useApprovals, useCsUsers, useOnlineUsers } from '../hooks'
import type { NasabahTab } from '../logic'

const pendingFilter = { status: 1 as const, action: -1 as const, query: '' }
const allCsUsers = { loginId: '', employeeId: '' }

export function NasabahSummary({ tabs }: { tabs: NasabahTab[] }) {
  const { t, i18n } = useTranslation()
  const showUsers = tabs.includes('users')
  const showPending = tabs.includes('approvals')
  const showCs = tabs.includes('cs_users')
  const users = useOnlineUsers(1, '', showUsers)
  const pending = useApprovals(1, pendingFilter, '', showPending)
  const cs = useCsUsers(1, allCsUsers, showCs)
  const count = (value: number | undefined) =>
    value === undefined ? '–' : new Intl.NumberFormat(i18n.language).format(value)

  const metrics: Metric[] = []
  if (showUsers)
    metrics.push({
      label: t('nasabah.summary.users'),
      value: count(users.data?.total),
      caption: t('nasabah.summary.usersCaption'),
    })
  if (showPending) {
    const total = pending.data?.total
    metrics.push({
      label: t('nasabah.summary.pending'),
      value: count(total),
      caption: t('nasabah.summary.pendingCaption'),
      tone: total ? 'warn' : undefined,
    })
  }
  if (showCs)
    metrics.push({
      label: t('nasabah.summary.csUsers'),
      value: count(cs.data?.total),
      caption: t('nasabah.summary.csCaption'),
    })
  if (metrics.length === 0) return null

  return (
    <section aria-label={t('nasabah.summary.label')}>
      <MetricStrip metrics={metrics} />
    </section>
  )
}
