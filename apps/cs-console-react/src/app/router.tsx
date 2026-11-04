import {
  createRootRouteWithContext,
  createRoute,
  createRouter,
  lazyRouteComponent,
  redirect,
} from '@tanstack/react-router'

import {
  communityTabs,
  moderationQueues,
  type CommunityTab,
  type ModerationQueue,
} from '@/features/community/types'
import { policyTabs, type PolicyTab } from '@/features/content-policy/types'
import { caseStates, type CaseState } from '@/features/compliance/types'
import { systemTabs, type SystemTab } from '@/features/system/types'
import {
  canOpenCommunity,
  canViewTickets,
  hasCommunityAccess,
  hasNasabah,
  isCompliance,
  isSuperAdmin,
  type AgentProfile,
} from '@/features/presence/types'
import { loadStrings, withStrings } from '@/i18n'
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
  loader: () => loadStrings('labels', 'replies'),
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

const analyticsRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/analytics',
  beforeLoad: ({ context }) => {
    superAdminOnly({ context })
    throw redirect({ to: '/community', search: { tab: 'analytics' }, replace: true })
  },
})

const reportsRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/reports',
  beforeLoad: superAdminOnly,
  component: lazyRouteComponent(
    withStrings(() => import('@/features/reports/components/reports-page'), 'labels'),
    'ReportsPage',
  ),
})

const settingsRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/settings',
  beforeLoad: superAdminOnly,
  component: lazyRouteComponent(
    withStrings(() => import('@/features/settings/components/settings-page'), 'platform', 'labels'),
    'SettingsPage',
  ),
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
    withStrings(() => import('@/features/compliance/components/banned-words-page'), 'policy'),
    'BannedWordsPage',
  ),
})

const complianceContentRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/compliance/content',
  beforeLoad: complianceOnly,
  validateSearch: (search: Record<string, unknown>): { tab?: PolicyTab } => {
    const tab = text(search.tab)
    return policyTabs.includes(tab as PolicyTab) ? { tab: tab as PolicyTab } : {}
  },
  component: lazyRouteComponent(
    withStrings(() => import('@/features/content-policy/components/content-policy-page'), 'policy'),
    'ContentPolicyPage',
  ),
})

const complianceLegalRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/compliance/legal',
  beforeLoad: complianceOnly,
  component: lazyRouteComponent(() => import('@/features/legal/components/legal-page'), 'LegalPage'),
})

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

const complianceEvidenceRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/compliance/evidence',
  beforeLoad: ({ context }) => {
    if (!isCompliance(context.agent) && !isSuperAdmin(context.agent)) throw redirect({ to: '/' })
  },
  validateSearch: (search: Record<string, unknown>): { id?: string } => {
    const id = text(search.id)
    return id && uuidPattern.test(id) ? { id } : {}
  },
  component: lazyRouteComponent(
    withStrings(() => import('@/features/compliance/evidence/components/evidence-page'), 'evidence'),
    'EvidencePage',
  ),
})

const systemRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/system',
  beforeLoad: superAdminOnly,
  validateSearch: (search: Record<string, unknown>): { tab?: SystemTab } => {
    const tab = text(search.tab)
    return systemTabs.includes(tab as SystemTab) ? { tab: tab as SystemTab } : {}
  },
  component: lazyRouteComponent(() => import('@/features/system/components/system-page'), 'SystemPage'),
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
  validateSearch: (
    search: Record<string, unknown>,
  ): { tab?: CommunityTab; queue?: ModerationQueue; stock?: string } => {
    const tab = text(search.tab)
    const queue = text(search.queue)
    const stock = text(search.stock)?.trim().toUpperCase()
    return {
      tab: communityTabs.includes(tab as CommunityTab) ? (tab as CommunityTab) : undefined,
      queue: moderationQueues.includes(queue as ModerationQueue) ? (queue as ModerationQueue) : undefined,
      stock: stock && /^[A-Z][A-Z0-9]{1,11}$/.test(stock) ? stock : undefined,
    }
  },
  beforeLoad: ({ context }) => {
    if (!canOpenCommunity(context.agent)) throw redirect({ to: '/' })
  },
  component: lazyRouteComponent(
    withStrings(() => import('@/features/community/components/community-page'), 'moderation'),
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
  analyticsRoute,
  settingsRoute,
  complianceRoute,
  complianceCasesRoute,
  complianceAuditRoute,
  compliancePolicyRoute,
  complianceWordsRoute,
  complianceContentRoute,
  complianceLegalRoute,
  complianceEvidenceRoute,
  systemRoute,
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
