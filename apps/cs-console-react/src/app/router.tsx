import {
  createRootRouteWithContext,
  createRoute,
  createRouter,
  lazyRouteComponent,
  redirect,
} from '@tanstack/react-router'

import { communityTabs, type CommunityTab } from '@/features/community/types'
import { caseStates, type CaseState } from '@/features/compliance/types'
import {
  canViewTickets,
  hasCommunityAccess,
  hasNasabah,
  isCompliance,
  isSuperAdmin,
  type AgentProfile,
} from '@/features/presence/types'
import { appEnv } from '@/lib/supabase'

import { Home, NoAccess } from './home'
import { Shell } from './shell'

type RouterContext = { agent: AgentProfile }

const superAdminOnly = ({ context }: { context: RouterContext }) => {
  if (!isSuperAdmin(context.agent)) throw redirect({ to: '/' })
}

const complianceOnly = ({ context }: { context: RouterContext }) => {
  if (!isCompliance(context.agent)) throw redirect({ to: '/' })
}

const text = (value: unknown) => (typeof value === 'string' && value !== '' ? value : undefined)

const rootRoute = createRootRouteWithContext<RouterContext>()({
  component: Shell,
  notFoundComponent: NoAccess,
})

const homeRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/',
  beforeLoad: ({ context }) => {
    if (canViewTickets(context.agent)) return
    if (isCompliance(context.agent)) throw redirect({ to: '/compliance' })
    if (hasNasabah(context.agent)) throw redirect({ to: '/nasabah' })
    if (hasCommunityAccess(context.agent)) throw redirect({ to: '/community' })
  },
  component: Home,
})

const dashboardRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/dashboard',
  beforeLoad: superAdminOnly,
  component: lazyRouteComponent(
    () => import('@/features/supervisor/components/dashboard-page'),
    'DashboardPage',
  ),
})

const reportsRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/reports',
  beforeLoad: superAdminOnly,
  component: lazyRouteComponent(() => import('@/features/reports/components/reports-page'), 'ReportsPage'),
})

const settingsRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/settings',
  beforeLoad: superAdminOnly,
  component: lazyRouteComponent(() => import('@/features/settings/components/settings-page'), 'SettingsPage'),
})

const complianceRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/compliance',
  beforeLoad: complianceOnly,
  component: lazyRouteComponent(
    () => import('@/features/compliance/components/overview-page'),
    'ComplianceOverviewPage',
  ),
})

const complianceCasesRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/compliance/cases',
  beforeLoad: complianceOnly,
  validateSearch: (search: Record<string, unknown>): { case?: string; state?: CaseState } => {
    const state = text(search.state)
    return {
      case: text(search.case),
      state: caseStates.includes(state as CaseState) ? (state as CaseState) : undefined,
    }
  },
  component: lazyRouteComponent(
    () => import('@/features/compliance/components/cases-page'),
    'ComplianceCasesPage',
  ),
})

const complianceAuditRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/compliance/audit',
  beforeLoad: complianceOnly,
  validateSearch: (search: Record<string, unknown>): { action?: string } => ({ action: text(search.action) }),
  component: lazyRouteComponent(
    () => import('@/features/compliance/components/audit-page'),
    'ComplianceAuditPage',
  ),
})

const compliancePolicyRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/compliance/policy',
  beforeLoad: complianceOnly,
  component: lazyRouteComponent(
    () => import('@/features/compliance/components/policy-page'),
    'CompliancePolicyPage',
  ),
})

const complianceWordsRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/compliance/words',
  beforeLoad: complianceOnly,
  component: lazyRouteComponent(
    () => import('@/features/compliance/components/banned-words-page'),
    'BannedWordsPage',
  ),
})

const nasabahRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/nasabah',
  validateSearch: (search: Record<string, unknown>): { q?: string } =>
    typeof search.q === 'string' && search.q.trim() ? { q: search.q.trim() } : {},
  beforeLoad: ({ context }) => {
    if (!hasNasabah(context.agent)) throw redirect({ to: '/' })
  },
  component: lazyRouteComponent(() => import('@/features/nasabah/components/nasabah-page'), 'NasabahPage'),
})

const communityRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/community',
  validateSearch: (search: Record<string, unknown>): { tab?: CommunityTab } => {
    const tab = text(search.tab)
    return communityTabs.includes(tab as CommunityTab) ? { tab: tab as CommunityTab } : {}
  },
  beforeLoad: ({ context }) => {
    if (!hasCommunityAccess(context.agent)) throw redirect({ to: '/' })
  },
  component: lazyRouteComponent(
    () => import('@/features/community/components/community-page'),
    'CommunityPage',
  ),
})

const perfRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/__perf',
  beforeLoad: () => {
    if (appEnv().appEnv === 'production') throw redirect({ to: '/' })
  },
  component: lazyRouteComponent(() => import('@/features/perf/perf-page'), 'PerfPage'),
})

const routeTree = rootRoute.addChildren([
  homeRoute,
  dashboardRoute,
  reportsRoute,
  settingsRoute,
  complianceRoute,
  complianceCasesRoute,
  complianceAuditRoute,
  compliancePolicyRoute,
  complianceWordsRoute,
  nasabahRoute,
  communityRoute,
  perfRoute,
])

export function createAppRouter(agent: AgentProfile) {
  return createRouter({ routeTree, context: { agent }, defaultPreload: 'intent' })
}

declare module '@tanstack/react-router' {
  interface Register {
    router: ReturnType<typeof createAppRouter>
  }
}
