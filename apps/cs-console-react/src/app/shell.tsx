import { useQueryClient } from '@tanstack/react-query'
import { Outlet } from '@tanstack/react-router'
import { useEffect } from 'react'
import { useTranslation } from 'react-i18next'

import { IdleGuard } from '@/features/auth/components/idle-guard'
import { useAgent } from '@/features/auth/hooks'
import { CommandPalette } from '@/features/command/components/command-palette'
import { ShortcutsDialog } from '@/features/command/components/shortcuts-dialog'
import { useConsoleAlerts, useDocumentTitle, useOverdueAlerts } from '@/features/notifications/hooks'
import { useHeartbeat, useResumeStatus, useStatusOnClose } from '@/features/presence/hooks'
import { useComplianceOverview } from '@/features/compliance/hooks'
import { caseAttention } from '@/features/compliance/logic'
import { canViewTickets, isCompliance, isSuperAdmin, worksTickets } from '@/features/presence/types'
import { useSupervisorOverview } from '@/features/supervisor/hooks'
import { attentionCount } from '@/features/supervisor/types'
import { useOpenTicket, useTicketLists, useTicketRealtime } from '@/features/tickets/hooks'
import { unreadMine } from '@/features/tickets/logic'
import { useGlobalHotkeys } from '@/hooks/use-hotkeys'
import { realtime } from '@/lib/realtime'
import { tabs } from '@/lib/tabs'

import { TopBar } from './top-bar'

export function Shell() {
  const { t } = useTranslation()
  const agent = useAgent()
  const client = useQueryClient()
  const openTicket = useOpenTicket()
  const tickets = canViewTickets(agent)
  const worker = worksTickets(agent)
  const superAdmin = isSuperAdmin(agent)

  useEffect(() => {
    tabs.setScope(agent.id)
    return () => tabs.setScope(null)
  }, [agent.id])

  useEffect(() => {
    realtime.start(agent.id, tickets)
    return () => realtime.stop()
  }, [agent.id, tickets])

  useEffect(
    () =>
      realtime.onResync(() => {
        void client.invalidateQueries({ predicate: (query) => query.queryKey[0] !== 'messages' })
      }),
    [client],
  )

  useTicketRealtime(agent.id, tickets, superAdmin)
  useHeartbeat()
  useStatusOnClose(worker)
  useResumeStatus(worker)
  useGlobalHotkeys(tickets)
  useConsoleAlerts({ meId: agent.id, superAdmin, onOpenTicket: openTicket })

  const lists = useTicketLists(tickets)
  const overview = useSupervisorOverview(superAdmin)
  const complianceOverview = useComplianceOverview(isCompliance(agent))
  useOverdueAlerts(overview.data?.overdue, openTicket)
  useDocumentTitle(lists.data ? unreadMine(lists.data) : 0, t('app.title'))

  return (
    <div className="flex h-full flex-col">
      <a
        href="#main"
        className="sr-only z-50 rounded-md bg-primary px-3 py-2 text-primary-foreground focus:not-sr-only focus:fixed focus:top-2 focus:left-2"
      >
        {t('app.skipToContent')}
      </a>
      <TopBar
        attention={attentionCount(overview.data)}
        caseAttention={caseAttention(complianceOverview.data)}
      />
      <main id="main" className="min-h-0 flex-1">
        <Outlet />
      </main>
      <IdleGuard minutes={agent.settings.idle_logout_minutes} />
      <CommandPalette onOpenTicket={openTicket} />
      <ShortcutsDialog />
    </div>
  )
}
