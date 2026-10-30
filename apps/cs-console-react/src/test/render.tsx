import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { render } from '@testing-library/react'
import type { ReactElement } from 'react'

import { TooltipProvider } from '@/components/ui/menu'
import { useAuth } from '@/features/auth/hooks'
import type { AgentProfile } from '@/features/presence/types'

import { agentFixture } from './fixtures'

export function renderWithProviders(ui: ReactElement, agent: AgentProfile = agentFixture) {
  useAuth.setState({ phase: { kind: 'ready', agent } })
  const client = new QueryClient({
    defaultOptions: { queries: { retry: false }, mutations: { retry: false } },
  })
  const result = render(
    <QueryClientProvider client={client}>
      <TooltipProvider>{ui}</TooltipProvider>
    </QueryClientProvider>,
  )
  return { ...result, client }
}
