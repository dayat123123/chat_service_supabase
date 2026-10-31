import { RouterProvider } from '@tanstack/react-router'
import { useEffect, useState } from 'react'

import { onSignedOut } from '@/features/auth/hooks'
import { usePending } from '@/features/conversation/hooks'
import type { AgentProfile } from '@/features/presence/types'
import { useTicketUi } from '@/features/tickets/hooks'

import { createAppRouter } from './router'

onSignedOut(() => {
  useTicketUi.getState().reset()
  usePending.getState().clear()
})

export function Workspace({ agent }: { agent: AgentProfile }) {
  const [router] = useState(() => createAppRouter(agent))
  useEffect(() => {
    void router.invalidate()
  }, [router, agent])
  return <RouterProvider router={router} context={{ agent }} />
}
