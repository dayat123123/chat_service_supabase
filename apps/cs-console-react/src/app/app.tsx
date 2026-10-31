import { QueryClientProvider } from '@tanstack/react-query'
import { LoaderCircleIcon } from 'lucide-react'
import { lazy, Suspense, useEffect, useState } from 'react'

import { TooltipProvider } from '@/components/ui/menu'
import { AppToaster } from '@/components/ui/toaster'
import { LoginPage } from '@/features/auth/components/login-page'
import { EnrollPage, PasswordPage, TotpPage } from '@/features/auth/components/second-factor'
import { onSignedOut, useAuth } from '@/features/auth/hooks'
import { usePreferences, watchSystemTheme } from '@/lib/preferences'
import { createQueryClient } from '@/lib/query-client'
import { realtime } from '@/lib/realtime'
import { removeLocalPrefix } from '@/lib/storage'
import { appEnv } from '@/lib/supabase'
import { tabs } from '@/lib/tabs'

const queryClient = createQueryClient()

const loadWorkspace = () => import('./workspace')

const Workspace = lazy(() => loadWorkspace().then((module) => ({ default: module.Workspace })))

const DevUiPage = lazy(() =>
  import('@/features/dev-ui/dev-ui-page').then((module) => ({ default: module.DevUiPage })),
)

function isDevUi() {
  return window.location.pathname === '/dev/ui' && appEnv().appEnv === 'development'
}

function Loading() {
  return (
    <div className="flex h-full items-center justify-center" aria-busy="true">
      <LoaderCircleIcon className="size-4 animate-spin text-muted-foreground" />
    </div>
  )
}

function AuthGate() {
  const phase = useAuth((state) => state.phase)
  const start = useAuth((state) => state.start)

  useEffect(() => {
    void start()
  }, [start])

  switch (phase.kind) {
    case 'checking':
      return <Loading />
    case 'signedOut':
      return <LoginPage reason={phase.reason} idleMinutes={30} />
    case 'totp':
      return <TotpPage />
    case 'enroll':
      return <EnrollPage secret={phase.secret} qr={phase.qr} />
    case 'password':
      return <PasswordPage />
    case 'ready':
      return (
        <Suspense fallback={<Loading />}>
          <Workspace key={phase.agent.id} agent={phase.agent} />
        </Suspense>
      )
  }
}

export function App() {
  const theme = usePreferences((state) => state.theme)
  const [devUi] = useState(isDevUi)

  useEffect(() => {
    tabs.start()
    const stopTheme = watchSystemTheme()
    const stopCleanup = onSignedOut(() => {
      realtime.stop()
      queryClient.clear()
      removeLocalPrefix('draft.')
    })
    const prefetch = window.setTimeout(() => void loadWorkspace().catch(() => undefined), 1_500)
    return () => {
      window.clearTimeout(prefetch)
      stopTheme()
      stopCleanup()
      tabs.stop()
    }
  }, [])

  return (
    <QueryClientProvider client={queryClient}>
      <TooltipProvider>
        {devUi ? (
          <Suspense fallback={<Loading />}>
            <DevUiPage />
          </Suspense>
        ) : (
          <AuthGate />
        )}
        <AppToaster theme={theme} />
      </TooltipProvider>
    </QueryClientProvider>
  )
}
