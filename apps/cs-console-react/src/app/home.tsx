import { useTranslation } from 'react-i18next'

import { EmptyState } from '@/components/states'
import { useAgent } from '@/features/auth/hooks'
import { handlesTickets } from '@/features/presence/types'
import { TicketsPage } from '@/features/tickets/components/tickets-page'

export function NoAccess() {
  const { t } = useTranslation()
  return <EmptyState className="h-full" title={t('nav.noAccess')} />
}

export function Home() {
  const agent = useAgent()
  return handlesTickets(agent) ? <TicketsPage /> : <NoAccess />
}
