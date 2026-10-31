import {
  createRootRouteWithContext,
  createRoute,
  createRouter,
  lazyRouteComponent,
  redirect,
} from '@tanstack/react-router'

import { isSuperAdmin, type AgentProfile } from '@/features/presence/types'
import { appEnv } from '@/lib/supabase'

import { Home, NoAccess } from './home'
import { Shell } from './shell'

type RouterContext = { agent: AgentProfile }

const superAdminOnly = ({ context }: { context: RouterContext }) => {
  if (!isSuperAdmin(context.agent)) throw redirect({ to: '/' })
}

const rootRoute = createRootRouteWithContext<RouterContext>()({
  component: Shell,
  notFoundComponent: NoAccess,
})

const homeRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/',
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

const perfRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/__perf',
  beforeLoad: () => {
    if (appEnv().appEnv === 'production') throw redirect({ to: '/' })
  },
  component: lazyRouteComponent(() => import('@/features/perf/perf-page'), 'PerfPage'),
})

const routeTree = rootRoute.addChildren([homeRoute, dashboardRoute, reportsRoute, settingsRoute, perfRoute])

export function createAppRouter(agent: AgentProfile) {
  return createRouter({ routeTree, context: { agent }, defaultPreload: 'intent' })
}

declare module '@tanstack/react-router' {
  interface Register {
    router: ReturnType<typeof createAppRouter>
  }
}
