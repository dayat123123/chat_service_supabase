import { useNavigate } from '@tanstack/react-router'
import {
  ArrowRightLeftIcon,
  BarChart3Icon,
  ClockIcon,
  FolderSearchIcon,
  GaugeIcon,
  HandIcon,
  KeyboardIcon,
  LayoutDashboardIcon,
  ListIcon,
  MessageSquareTextIcon,
  MoonIcon,
  RowsIcon,
  ScrollTextIcon,
  SettingsIcon,
  ShieldCheckIcon,
  SquareCheckBigIcon,
  StickyNoteIcon,
  TicketIcon,
  Undo2Icon,
  UsersIcon,
} from 'lucide-react'
import { useMemo, useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'

import { PriorityText, StatusDot, TicketStatusText } from '@/components/badges'
import { Dialog, DialogContent, DialogTitle } from '@/components/ui/dialog'
import {
  Command,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList,
  CommandSeparator,
} from '@/components/ui/overlay'
import { Kbd } from '@/components/ui/primitives'
import { useAgent } from '@/features/auth/hooks'
import { useSetStatus } from '@/features/presence/hooks'
import {
  agentStatuses,
  canViewTickets,
  hasNasabah,
  isCompliance,
  isSuperAdmin,
  worksTickets,
  type AgentStatus,
} from '@/features/presence/types'
import { useTicketLists, useTicketSearch, useTicketUi, useTopicName } from '@/features/tickets/hooks'
import { byPriorityThenWait, ticketTabs } from '@/features/tickets/logic'
import { customerName, tabLabelKeys, type Ticket } from '@/features/tickets/types'
import { useDebounced } from '@/hooks/use-now'
import { usePreferences } from '@/lib/preferences'

import { hasCommand, runCommand, useCommandRegistry, useOverlays, type ConsoleCommand } from '../bus'
import { matchesQuery } from '../search'

type Icon = React.ComponentType<{ className?: string }>
type PaletteItem = { id: string; label: string; icon: Icon; keys?: string; run: () => void }

const ticketCommands: { command: ConsoleCommand; label: string; icon: Icon; keys?: string }[] = [
  { command: 'claim', label: 'shortcuts.claim', icon: HandIcon, keys: 'A' },
  { command: 'focusReply', label: 'shortcuts.reply', icon: MessageSquareTextIcon, keys: 'R' },
  { command: 'focusNote', label: 'shortcuts.note', icon: StickyNoteIcon, keys: 'N' },
  { command: 'waitCustomer', label: 'conversation.waitCustomer', icon: ClockIcon },
  { command: 'transfer', label: 'conversation.transfer', icon: ArrowRightLeftIcon },
  { command: 'release', label: 'conversation.release', icon: Undo2Icon },
  { command: 'resolve', label: 'conversation.resolve', icon: SquareCheckBigIcon, keys: 'E' },
]

function ticketText(ticket: Ticket) {
  return `${ticket.ticket_number} ${customerName(ticket)} ${ticket.topic} ${ticket.preview ?? ''}`
}

function Item({ item, onSelect }: { item: PaletteItem; onSelect: (run: () => void) => void }) {
  return (
    <CommandItem value={item.id} onSelect={() => onSelect(item.run)}>
      <item.icon className="text-muted-foreground" />
      <span className="flex-1 truncate">{item.label}</span>
      {item.keys ? <Kbd>{item.keys}</Kbd> : null}
    </CommandItem>
  )
}

function Section({
  heading,
  children,
  first,
}: {
  heading: string
  children: React.ReactNode
  first?: boolean
}) {
  return (
    <>
      {first ? null : <CommandSeparator />}
      <CommandGroup heading={heading}>{children}</CommandGroup>
    </>
  )
}

type SectionTarget =
  | '/dashboard'
  | '/reports'
  | '/settings'
  | '/compliance'
  | '/compliance/cases'
  | '/compliance/audit'
  | '/compliance/policy'
  | '/nasabah'

function PaletteBody({
  choose,
  onOpenTicket,
}: {
  choose: (run: () => void) => void
  onOpenTicket: (ticketId: string) => void
}) {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const agent = useAgent()
  const tickets = canViewTickets(agent)
  const worker = worksTickets(agent)
  const superAdmin = isSuperAdmin(agent)
  const compliance = isCompliance(agent)
  const topicName = useTopicName()
  const lists = useTicketLists(tickets)
  const setStatus = useSetStatus()
  const setShortcuts = useOverlays((state) => state.setShortcuts)
  const [query, setQuery] = useState('')
  const trimmed = query.trim()
  const debounced = useDebounced(trimmed, 250)
  const search = useTicketSearch(tickets ? debounced : '')
  useCommandRegistry((state) => state.version)

  const ticketResults = useMemo(() => {
    if (!tickets) return []
    if (trimmed.length >= 2) return debounced === trimmed ? (search.data ?? []).slice(0, 12) : []
    const data = lists.data
    if (!data) return []
    const seen = new Set<string>()
    return [...data.mine, ...[...data.open].sort(byPriorityThenWait)]
      .filter((ticket) => {
        if (seen.has(ticket.id)) return false
        seen.add(ticket.id)
        return trimmed === '' || matchesQuery(ticketText(ticket), trimmed)
      })
      .slice(0, 8)
  }, [tickets, trimmed, debounced, search.data, lists.data])

  const actions: PaletteItem[] = ticketCommands
    .filter((item) => hasCommand(item.command))
    .map((item) => ({
      id: `command:${item.command}`,
      label: t(item.label as 'shortcuts.claim'),
      icon: item.icon,
      keys: item.keys,
      run: () => window.setTimeout(() => runCommand(item.command), 0),
    }))

  const tabs = ticketTabs(agent).map((tab) => ({ tab, label: t(tabLabelKeys[tab]) }))
  const sections: { label: string; icon: Icon; to: SectionTarget }[] = [
    ...(superAdmin
      ? [
          { label: t('nav.dashboard'), icon: LayoutDashboardIcon, to: '/dashboard' as const },
          { label: t('nav.reports'), icon: BarChart3Icon, to: '/reports' as const },
          { label: t('nav.settings'), icon: SettingsIcon, to: '/settings' as const },
        ]
      : []),
    ...(compliance
      ? [
          { label: t('nav.overview'), icon: GaugeIcon, to: '/compliance' as const },
          { label: t('nav.cases'), icon: FolderSearchIcon, to: '/compliance/cases' as const },
          { label: t('nav.audit'), icon: ScrollTextIcon, to: '/compliance/audit' as const },
          { label: t('nav.policy'), icon: ShieldCheckIcon, to: '/compliance/policy' as const },
        ]
      : []),
    ...(hasNasabah(agent) ? [{ label: t('nav.nasabah'), icon: UsersIcon, to: '/nasabah' as const }] : []),
  ]
  const navigation: PaletteItem[] = [
    ...tabs.map((item) => ({
      id: `tab:${item.tab}`,
      label: t('command.tab', { tab: item.label }),
      icon: ListIcon,
      run: () => {
        useTicketUi.getState().setTab(item.tab)
        void navigate({ to: '/' })
      },
    })),
    ...sections.map((section) => ({
      id: `nav:${section.to}`,
      label: t('command.goTo', { section: section.label }),
      icon: section.icon,
      run: () => void navigate({ to: section.to }),
    })),
  ]

  const statuses: { id: string; label: string; status: AgentStatus }[] = worker
    ? agentStatuses
        .filter((status) => status !== agent.status)
        .map((status) => ({
          id: `status:${status}`,
          status,
          label: t('command.setStatus', { status: t(`presence.${status}`) }),
        }))
    : []

  const preferences: PaletteItem[] = [
    {
      id: 'pref:theme',
      label: t('command.toggleTheme'),
      icon: MoonIcon,
      run: () =>
        usePreferences
          .getState()
          .setTheme(document.documentElement.classList.contains('dark') ? 'light' : 'dark'),
    },
    {
      id: 'pref:density',
      label: t('command.toggleDensity'),
      icon: RowsIcon,
      run: () => {
        const { density, setDensity } = usePreferences.getState()
        setDensity(density === 'compact' ? 'comfortable' : 'compact')
      },
    },
    {
      id: 'pref:shortcuts',
      label: t('command.shortcuts'),
      icon: KeyboardIcon,
      keys: '?',
      run: () => setShortcuts(true),
    },
  ]

  const visible = <T extends { label: string }>(items: T[]) =>
    trimmed ? items.filter((item) => matchesQuery(item.label, trimmed)) : items
  const groups = {
    actions: visible(actions),
    navigation: visible(navigation),
    statuses: visible(statuses),
    preferences: visible(preferences),
  }
  const searching = tickets && trimmed.length >= 2 && (debounced !== trimmed || search.isFetching)
  const order = [
    ticketResults.length > 0 ? 'tickets' : null,
    groups.actions.length > 0 ? 'actions' : null,
    groups.navigation.length > 0 ? 'navigation' : null,
    groups.statuses.length > 0 ? 'statuses' : null,
    groups.preferences.length > 0 ? 'preferences' : null,
  ].filter(Boolean)
  const isFirst = (key: string) => order[0] === key

  return (
    <Command shouldFilter={false} loop label={t('command.label')}>
      <CommandInput value={query} onValueChange={setQuery} placeholder={t('command.placeholder')} />
      <CommandList className="max-h-[min(420px,60vh)]">
        {searching ? (
          <div className="px-3 py-2 text-xs text-muted-foreground" aria-live="polite">
            {t('tickets.searching')}
          </div>
        ) : (
          <CommandEmpty>{t('command.empty')}</CommandEmpty>
        )}
        {ticketResults.length > 0 ? (
          <Section first heading={t('command.tickets')}>
            {ticketResults.map((ticket) => (
              <CommandItem
                key={ticket.id}
                value={`ticket:${ticket.id}`}
                aria-label={t('command.openTicket', { number: ticket.ticket_number })}
                onSelect={() => choose(() => onOpenTicket(ticket.id))}
              >
                <TicketIcon className="text-muted-foreground" />
                <span className="min-w-0 flex-1 truncate">
                  {customerName(ticket)}
                  <span className="text-muted-foreground"> · {topicName(ticket.topic)}</span>
                </span>
                <span className="shrink-0 font-mono text-xs text-muted-foreground">
                  {ticket.ticket_number}
                </span>
                <PriorityText priority={ticket.priority} className="w-5 shrink-0 text-xs" />
                <TicketStatusText status={ticket.status} className="hidden w-28 shrink-0 truncate sm:block" />
              </CommandItem>
            ))}
          </Section>
        ) : null}
        {groups.actions.length > 0 ? (
          <Section heading={t('command.actions')} first={isFirst('actions')}>
            {groups.actions.map((item) => (
              <Item key={item.id} item={item} onSelect={choose} />
            ))}
          </Section>
        ) : null}
        {groups.navigation.length > 0 ? (
          <Section heading={t('command.navigation')} first={isFirst('navigation')}>
            {groups.navigation.map((item) => (
              <Item key={item.id} item={item} onSelect={choose} />
            ))}
          </Section>
        ) : null}
        {groups.statuses.length > 0 ? (
          <Section heading={t('command.status')} first={isFirst('statuses')}>
            {groups.statuses.map((item) => (
              <CommandItem
                key={item.id}
                value={item.id}
                onSelect={() => choose(() => setStatus.mutate({ status: item.status }))}
              >
                <StatusDot status={item.status} className="mx-1" />
                <span className="flex-1 truncate">{item.label}</span>
              </CommandItem>
            ))}
          </Section>
        ) : null}
        {groups.preferences.length > 0 ? (
          <Section heading={t('command.preferences')} first={isFirst('preferences')}>
            {groups.preferences.map((item) => (
              <Item key={item.id} item={item} onSelect={choose} />
            ))}
          </Section>
        ) : null}
      </CommandList>
    </Command>
  )
}

export function CommandPalette({ onOpenTicket }: { onOpenTicket: (ticketId: string) => void }) {
  const { t } = useTranslation()
  const open = useOverlays((state) => state.palette)
  const setOpen = useOverlays((state) => state.setPalette)
  const chosen = useRef(false)

  const choose = (run: () => void) => {
    chosen.current = true
    setOpen(false)
    run()
  }

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogContent
        className="top-[16%] translate-y-0 gap-0 overflow-hidden p-0 sm:max-w-[560px]"
        aria-describedby={undefined}
        onCloseAutoFocus={(event) => {
          if (!chosen.current) return
          chosen.current = false
          event.preventDefault()
        }}
      >
        <DialogTitle className="sr-only">{t('command.label')}</DialogTitle>
        {open ? <PaletteBody choose={choose} onOpenTicket={onOpenTicket} /> : null}
      </DialogContent>
    </Dialog>
  )
}
