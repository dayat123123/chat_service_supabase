import { Link } from '@tanstack/react-router'
import { BellIcon, BellOffIcon, KeyboardIcon, LogOutIcon, SearchIcon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'

import { Logo } from '@/components/logo'
import { Button } from '@/components/ui/button'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuRadioGroup,
  DropdownMenuRadioItem,
  DropdownMenuSeparator,
  DropdownMenuSub,
  DropdownMenuSubContent,
  DropdownMenuSubTrigger,
  DropdownMenuTrigger,
} from '@/components/ui/menu'
import { Avatar, Kbd } from '@/components/ui/primitives'
import { useAgent, useAuth } from '@/features/auth/hooks'
import { useOverlays } from '@/features/command/bus'
import {
  ActiveCount,
  ConnectionIndicator,
  MonitorIndicator,
  StatusMenu,
} from '@/features/presence/components/status-menu'
import {
  canViewTickets,
  isCompliance,
  isMonitor,
  isSuperAdmin,
  worksTickets,
} from '@/features/presence/types'
import { isStaffRole } from '@/features/settings/types'
import { notificationPermission, playSound, requestNotificationPermission } from '@/lib/alerts'
import { usePreferences, type Density, type Theme, type TicketAlerts } from '@/lib/preferences'

type NavTarget =
  | '/'
  | '/dashboard'
  | '/reports'
  | '/settings'
  | '/compliance'
  | '/compliance/cases'
  | '/compliance/audit'
  | '/compliance/policy'

function NavLink({
  to,
  label,
  count,
  countLabel,
}: {
  to: NavTarget
  label: string
  count?: number
  countLabel?: string
}) {
  return (
    <Link
      to={to}
      activeOptions={{ exact: to === '/' || to === '/compliance' }}
      className="relative inline-flex h-12 shrink-0 items-center gap-1.5 px-2 text-row whitespace-nowrap text-muted-foreground transition-colors outline-none after:absolute after:inset-x-2 after:bottom-0 after:h-0.5 hover:text-foreground focus-visible:ring-2 focus-visible:ring-ring/50 focus-visible:ring-inset data-[status=active]:font-medium data-[status=active]:text-foreground data-[status=active]:after:bg-foreground"
    >
      {label}
      {count ? (
        <span className="tabular text-xs font-medium text-danger" aria-label={countLabel}>
          {count}
        </span>
      ) : null}
    </Link>
  )
}

function AlertsMenu() {
  const { t } = useTranslation()
  const mode = usePreferences((state) => state.ticketAlerts)
  const setMode = usePreferences((state) => state.setTicketAlerts)
  const [permission, setPermission] = useState(notificationPermission())
  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="ghost" size="icon-sm" aria-label={t('notifications.settings')}>
          {mode === 'off' ? <BellOffIcon /> : <BellIcon />}
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" className="w-60">
        <DropdownMenuLabel>{t('notifications.newTickets')}</DropdownMenuLabel>
        <DropdownMenuRadioGroup value={mode} onValueChange={(value) => setMode(value as TicketAlerts)}>
          <DropdownMenuRadioItem value="all">{t('notifications.all')}</DropdownMenuRadioItem>
          <DropdownMenuRadioItem value="high">{t('notifications.high')}</DropdownMenuRadioItem>
          <DropdownMenuRadioItem value="off">{t('notifications.off')}</DropdownMenuRadioItem>
        </DropdownMenuRadioGroup>
        <DropdownMenuSeparator />
        {permission !== 'granted' && permission !== 'unsupported' ? (
          <DropdownMenuItem
            disabled={permission === 'denied'}
            onSelect={() => void requestNotificationPermission().then((value) => setPermission(value))}
          >
            {permission === 'denied' ? t('notifications.blocked') : t('notifications.allowBrowser')}
          </DropdownMenuItem>
        ) : null}
        <DropdownMenuItem onSelect={() => playSound('ticket', true)}>
          {t('notifications.testSound')}
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  )
}

function AccountMenu() {
  const { t } = useTranslation()
  const agent = useAgent()
  const signOut = useAuth((state) => state.signOut)
  const { theme, density, language, setTheme, setDensity, setLanguage } = usePreferences()
  const setShortcuts = useOverlays((state) => state.setShortcuts)
  const roles = agent.roles
    .filter(isStaffRole)
    .map((role) => t(`roles.${role}`))
    .join(' · ')
  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="ghost" size="icon-sm" className="rounded-full" aria-label={t('nav.account')}>
          <Avatar name={agent.display_name} />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" className="w-60">
        <DropdownMenuLabel className="flex flex-col gap-0.5">
          <span className="text-sm font-medium text-foreground">{agent.display_name}</span>
          <span>
            {agent.agent_code} · {roles}
          </span>
        </DropdownMenuLabel>
        <DropdownMenuSeparator />
        <DropdownMenuSub>
          <DropdownMenuSubTrigger>{t('preferences.theme')}</DropdownMenuSubTrigger>
          <DropdownMenuSubContent>
            <DropdownMenuRadioGroup value={theme} onValueChange={(value) => setTheme(value as Theme)}>
              <DropdownMenuRadioItem value="light">{t('preferences.light')}</DropdownMenuRadioItem>
              <DropdownMenuRadioItem value="dark">{t('preferences.dark')}</DropdownMenuRadioItem>
              <DropdownMenuRadioItem value="system">{t('preferences.system')}</DropdownMenuRadioItem>
            </DropdownMenuRadioGroup>
          </DropdownMenuSubContent>
        </DropdownMenuSub>
        <DropdownMenuSub>
          <DropdownMenuSubTrigger>{t('preferences.density')}</DropdownMenuSubTrigger>
          <DropdownMenuSubContent>
            <DropdownMenuRadioGroup value={density} onValueChange={(value) => setDensity(value as Density)}>
              <DropdownMenuRadioItem value="comfortable">
                {t('preferences.comfortable')}
              </DropdownMenuRadioItem>
              <DropdownMenuRadioItem value="compact">{t('preferences.compact')}</DropdownMenuRadioItem>
            </DropdownMenuRadioGroup>
          </DropdownMenuSubContent>
        </DropdownMenuSub>
        <DropdownMenuSub>
          <DropdownMenuSubTrigger>{t('preferences.language')}</DropdownMenuSubTrigger>
          <DropdownMenuSubContent>
            <DropdownMenuRadioGroup
              value={language}
              onValueChange={(value) => setLanguage(value === 'en' ? 'en' : 'id')}
            >
              <DropdownMenuRadioItem value="id">Bahasa Indonesia</DropdownMenuRadioItem>
              <DropdownMenuRadioItem value="en">English</DropdownMenuRadioItem>
            </DropdownMenuRadioGroup>
          </DropdownMenuSubContent>
        </DropdownMenuSub>
        <DropdownMenuItem onSelect={() => setShortcuts(true)}>
          <KeyboardIcon />
          {t('shortcuts.title')}
          <Kbd className="ml-auto">?</Kbd>
        </DropdownMenuItem>
        <DropdownMenuSeparator />
        <DropdownMenuItem destructive onSelect={() => void signOut('manual')}>
          <LogOutIcon />
          {t('auth.signOut')}
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  )
}

export function TopBar({ attention, caseAttention }: { attention: number; caseAttention: number }) {
  const { t } = useTranslation()
  const agent = useAgent()
  const setPalette = useOverlays((state) => state.setPalette)
  const tickets = canViewTickets(agent)
  const worker = worksTickets(agent)
  const monitor = isMonitor(agent)
  const superAdmin = isSuperAdmin(agent)
  const compliance = isCompliance(agent)
  return (
    <header className="flex h-12 shrink-0 items-center gap-3 border-b bg-background px-3 lg:px-4">
      <Logo className="mr-2 hidden sm:flex" />
      <nav aria-label="Menu" className="flex min-w-0 items-center overflow-x-auto">
        {tickets ? <NavLink to="/" label={t('nav.tickets')} /> : null}
        {superAdmin ? (
          <>
            <NavLink to="/dashboard" label={t('nav.dashboard')} count={attention || undefined} />
            <NavLink to="/reports" label={t('nav.reports')} />
            <NavLink to="/settings" label={t('nav.settings')} />
          </>
        ) : null}
        {compliance ? (
          <>
            <NavLink to="/compliance" label={t('nav.overview')} />
            <NavLink
              to="/compliance/cases"
              label={t('nav.cases')}
              count={caseAttention || undefined}
              countLabel={t('nav.caseAttention', { count: caseAttention })}
            />
            <NavLink to="/compliance/audit" label={t('nav.audit')} />
            <NavLink to="/compliance/policy" label={t('nav.policy')} />
          </>
        ) : null}
      </nav>
      <div className="hidden min-w-0 flex-1 justify-center px-2 lg:flex">
        <button
          type="button"
          onClick={() => setPalette(true)}
          className="flex h-8 w-full max-w-[360px] items-center gap-2 rounded-md bg-muted px-2.5 text-row text-muted-foreground transition-colors outline-none hover:bg-selected focus-visible:ring-2 focus-visible:ring-ring/50"
        >
          <SearchIcon className="size-4" />
          <span className="flex-1 truncate text-left">
            {tickets ? t('nav.searchHint') : t('nav.commandHint')}
          </span>
          <Kbd>Ctrl K</Kbd>
        </button>
      </div>
      <div className="ml-auto flex items-center gap-1 lg:ml-0">
        <ConnectionIndicator />
        {worker ? (
          <>
            <StatusMenu />
            <ActiveCount />
          </>
        ) : null}
        {monitor ? <MonitorIndicator /> : null}
        <AlertsMenu />
        <AccountMenu />
      </div>
    </header>
  )
}
