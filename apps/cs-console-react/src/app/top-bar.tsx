import { Link } from '@tanstack/react-router'
import {
  BarChart3Icon,
  BellIcon,
  BellOffIcon,
  KeyboardIcon,
  LayoutDashboardIcon,
  LogOutIcon,
  SearchIcon,
  SettingsIcon,
  TicketIcon,
} from 'lucide-react'
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
import { ActiveCount, ConnectionIndicator, StatusMenu } from '@/features/presence/components/status-menu'
import { handlesTickets, isAdmin, isSupervisor } from '@/features/presence/types'
import { notificationPermission, playSound, requestNotificationPermission } from '@/lib/alerts'
import { usePreferences, type Density, type Theme, type TicketAlerts } from '@/lib/preferences'
import { cn } from '@/lib/utils'

function NavLink({
  to,
  icon: Icon,
  label,
  badge,
}: {
  to: '/' | '/dashboard' | '/reports' | '/settings'
  icon: React.ComponentType<{ className?: string }>
  label: string
  badge?: number
}) {
  return (
    <Link
      to={to}
      activeOptions={{ exact: to === '/' }}
      className="relative inline-flex h-8 items-center gap-1.5 rounded-md px-3 text-sm font-medium text-muted-foreground transition-colors outline-none hover:bg-accent hover:text-accent-foreground focus-visible:ring-[3px] focus-visible:ring-ring/50 data-[status=active]:bg-accent data-[status=active]:font-semibold data-[status=active]:text-accent-foreground"
    >
      <Icon className="size-4" />
      <span className="hidden md:inline">{label}</span>
      {badge ? (
        <span className="tabular absolute -top-1 -right-1 inline-flex min-w-4 items-center justify-center rounded-full bg-destructive px-1 text-[10px] font-bold text-destructive-foreground">
          {badge}
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
    .filter((role): role is 'cs_agent' | 'cs_supervisor' | 'cs_admin' | 'compliance' =>
      ['cs_agent', 'cs_supervisor', 'cs_admin', 'compliance'].includes(role),
    )
    .map((role) => t(`roles.${role}`))
    .join(' · ')
  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="ghost" size="sm" className="gap-2 px-1.5" aria-label={t('nav.account')}>
          <Avatar name={agent.display_name} className="size-7 bg-primary/12 text-primary" />
          <span className="hidden text-sm font-medium lg:inline">
            {agent.display_name} <span className="text-muted-foreground">({agent.agent_code})</span>
          </span>
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" className="w-60">
        <DropdownMenuLabel className="text-foreground">
          <div className="text-sm font-semibold">{agent.display_name}</div>
          <div className="font-normal text-muted-foreground">
            {agent.agent_code} · {roles}
          </div>
        </DropdownMenuLabel>
        <DropdownMenuSeparator />
        <DropdownMenuSub>
          <DropdownMenuSubTrigger>{t('preferences.theme')}</DropdownMenuSubTrigger>
          <DropdownMenuSubContent>
            <DropdownMenuRadioGroup value={theme} onValueChange={(value) => setTheme(value as Theme)}>
              <DropdownMenuRadioItem value="system">{t('preferences.system')}</DropdownMenuRadioItem>
              <DropdownMenuRadioItem value="light">{t('preferences.light')}</DropdownMenuRadioItem>
              <DropdownMenuRadioItem value="dark">{t('preferences.dark')}</DropdownMenuRadioItem>
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

export function TopBar({ attention }: { attention: number }) {
  const { t } = useTranslation()
  const agent = useAgent()
  const setPalette = useOverlays((state) => state.setPalette)
  const tickets = handlesTickets(agent)
  const supervisor = isSupervisor(agent)
  const admin = isAdmin(agent)
  return (
    <header className="flex h-14 shrink-0 items-center gap-3 border-b bg-card px-3 lg:px-4">
      <Logo compact className="mr-1 hidden sm:flex" />
      <nav aria-label="Menu" className="flex items-center gap-1">
        {tickets ? <NavLink to="/" icon={TicketIcon} label={t('nav.tickets')} /> : null}
        {supervisor ? (
          <NavLink
            to="/dashboard"
            icon={LayoutDashboardIcon}
            label={t('nav.dashboard')}
            badge={attention || undefined}
          />
        ) : null}
        {supervisor || admin ? <NavLink to="/reports" icon={BarChart3Icon} label={t('nav.reports')} /> : null}
        {admin ? <NavLink to="/settings" icon={SettingsIcon} label={t('nav.settings')} /> : null}
      </nav>
      <button
        type="button"
        onClick={() => setPalette(true)}
        className={cn(
          'ml-2 hidden h-8 w-64 items-center gap-2 rounded-md border bg-background px-3 text-sm text-muted-foreground transition-colors outline-none hover:bg-accent focus-visible:ring-[3px] focus-visible:ring-ring/50 xl:flex',
        )}
      >
        <SearchIcon className="size-4" />
        <span className="flex-1 text-left">{t('nav.searchHint')}</span>
        <Kbd>Ctrl K</Kbd>
      </button>
      <div className="ml-auto flex items-center gap-2">
        {tickets ? (
          <>
            <StatusMenu />
            <ActiveCount />
          </>
        ) : null}
        <ConnectionIndicator />
        <AlertsMenu />
        <AccountMenu />
      </div>
    </header>
  )
}
