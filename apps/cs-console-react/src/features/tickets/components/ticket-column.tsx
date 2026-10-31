import { useVirtualizer } from '@tanstack/react-virtual'
import { ListFilterIcon, SearchIcon, XIcon } from 'lucide-react'
import { useCallback, useMemo, useRef } from 'react'
import { useTranslation } from 'react-i18next'

import { Dot } from '@/components/badges'
import { EmptyState, ErrorState, ListSkeleton } from '@/components/states'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuRadioGroup,
  DropdownMenuRadioItem,
  DropdownMenuSub,
  DropdownMenuSubContent,
  DropdownMenuSubTrigger,
  DropdownMenuTrigger,
} from '@/components/ui/menu'
import { useAgent } from '@/features/auth/hooks'
import { useCommandHandler } from '@/features/command/bus'
import { GoOnlineButton } from '@/features/presence/components/go-online-button'
import { useClaimGate } from '@/features/presence/hooks'
import { worksTickets } from '@/features/presence/types'
import { useDebounced, useNow } from '@/hooks/use-now'
import { usePreferences } from '@/lib/preferences'
import { cn } from '@/lib/utils'

import {
  useClaimTicket,
  useTicketLists,
  useTicketSearch,
  useTicketUi,
  useTopicName,
  useTopics,
} from '../hooks'
import { currentTab, isFiltered, noFilter, ticketTabs, visibleTickets } from '../logic'
import { emptyLists, tabLabelKeys, ticketFlags, ticketPriorities, type TicketFilter } from '../types'
import { TicketRow } from './ticket-row'
import { TransferInbox } from './transfer-inbox'

const ALL = '__all__'

type FilterGroup = {
  key: keyof TicketFilter
  label: string
  allLabel: string
  options: { value: string; label: string }[]
}

function FilterMenu({
  groups,
  filter,
  onChange,
}: {
  groups: FilterGroup[]
  filter: TicketFilter
  onChange: (patch: Partial<TicketFilter>) => void
}) {
  const { t } = useTranslation()
  const active = groups.filter((group) => filter[group.key] !== null).length
  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="outline" size="sm" className="shrink-0">
          <ListFilterIcon />
          {t('tickets.filter')}
          {active > 0 ? <span className="tabular text-muted-foreground">{active}</span> : null}
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" className="w-48">
        {groups.map((group) => (
          <DropdownMenuSub key={group.key}>
            <DropdownMenuSubTrigger>{group.label}</DropdownMenuSubTrigger>
            <DropdownMenuSubContent className="max-h-72 overflow-y-auto">
              <DropdownMenuRadioGroup
                value={filter[group.key] ?? ALL}
                onValueChange={(value) => onChange({ [group.key]: value === ALL ? null : value })}
              >
                <DropdownMenuRadioItem value={ALL}>{group.allLabel}</DropdownMenuRadioItem>
                {group.options.map((option) => (
                  <DropdownMenuRadioItem key={option.value} value={option.value}>
                    {option.label}
                  </DropdownMenuRadioItem>
                ))}
              </DropdownMenuRadioGroup>
            </DropdownMenuSubContent>
          </DropdownMenuSub>
        ))}
      </DropdownMenuContent>
    </DropdownMenu>
  )
}

function FilterChips({
  groups,
  filter,
  onChange,
  onClear,
}: {
  groups: FilterGroup[]
  filter: TicketFilter
  onChange: (patch: Partial<TicketFilter>) => void
  onClear: () => void
}) {
  const { t } = useTranslation()
  const chips = groups.flatMap((group) => {
    const value = filter[group.key]
    if (value === null) return []
    const option = group.options.find((item) => item.value === value)
    return [{ group, text: `${group.label}: ${option?.label ?? value}` }]
  })
  if (chips.length === 0) return null
  return (
    <div className="flex flex-wrap items-center gap-1.5">
      {chips.map(({ group, text }) => (
        <span
          key={group.key}
          className="inline-flex h-6 max-w-full items-center gap-1 rounded-md border bg-background pr-0.5 pl-2 text-xs"
        >
          <span className="truncate">{text}</span>
          <button
            type="button"
            aria-label={t('tickets.removeFilter', { name: group.label })}
            onClick={() => onChange({ [group.key]: null })}
            className="inline-flex size-5 items-center justify-center rounded-sm text-muted-foreground outline-none hover:bg-muted hover:text-foreground focus-visible:ring-2 focus-visible:ring-ring/50"
          >
            <XIcon className="size-3" />
          </button>
        </span>
      ))}
      <button
        type="button"
        onClick={onClear}
        className="rounded-sm px-1 text-xs text-muted-foreground underline-offset-4 outline-none hover:text-foreground hover:underline focus-visible:ring-2 focus-visible:ring-ring/50"
      >
        {t('tickets.clearFilters')}
      </button>
    </div>
  )
}

export function TicketColumn() {
  const { t } = useTranslation()
  const agent = useAgent()
  const worker = worksTickets(agent)
  const now = useNow()
  const density = usePreferences((state) => state.density)
  const {
    tab: chosen,
    filter,
    query,
    selectedId,
    leaving,
    setTab,
    setFilter,
    setQuery,
    select,
  } = useTicketUi()
  const lists = useTicketLists()
  const topics = useTopics()
  const topicName = useTopicName()
  const search = useDebounced(query.trim(), 300)
  const results = useTicketSearch(search)
  const claim = useClaimTicket()
  const data = lists.data ?? emptyLists
  const searching = search.length >= 2
  const available = ticketTabs(agent)
  const tab = currentTab(available, chosen)
  const tickets = useMemo(
    () => visibleTickets(data, tab, filter, searching ? (results.data ?? []) : null),
    [data, tab, filter, searching, results.data],
  )
  const gate = useClaimGate()
  const canClaim = gate.canClaim

  const tabs = available.map((value) => ({ value, label: t(tabLabelKeys[value]), count: data[value].length }))

  const scrollRef = useRef<HTMLDivElement>(null)
  const virtualizer = useVirtualizer({
    count: tickets.length,
    getScrollElement: () => scrollRef.current,
    estimateSize: () => (density === 'compact' ? 64 : 76),
    overscan: 8,
    getItemKey: (index) => tickets[index]?.id ?? index,
  })

  const move = useCallback(
    (step: number) => {
      if (tickets.length === 0) return
      const index = tickets.findIndex((ticket) => ticket.id === selectedId)
      const next = tickets[Math.min(tickets.length - 1, Math.max(0, index === -1 ? 0 : index + step))]
      if (!next) return
      select(next.id)
      virtualizer.scrollToIndex(tickets.indexOf(next), { align: 'auto' })
    },
    [tickets, selectedId, select, virtualizer],
  )
  const claimSelected = useCallback(() => {
    const ticket = tickets.find((item) => item.id === selectedId)
    if (ticket?.status === 'open' && canClaim && !claim.isPending) claim.mutate(ticket.id)
  }, [tickets, selectedId, canClaim, claim])
  useCommandHandler(
    'next',
    useCallback(() => move(1), [move]),
  )
  useCommandHandler(
    'previous',
    useCallback(() => move(-1), [move]),
  )
  useCommandHandler('claim', worker ? claimSelected : null)

  const empty = searching
    ? t('tickets.emptyFiltered')
    : isFiltered(filter)
      ? t('tickets.emptyFiltered')
      : {
          open: t('tickets.emptyOpen'),
          mine: t('tickets.emptyMine'),
          resolved_today: t('tickets.emptyResolved'),
          all_active: t('tickets.emptyActive'),
        }[tab]

  const updateFilter = (patch: Partial<TicketFilter>) => setFilter({ ...filter, ...patch })
  const groups: FilterGroup[] = [
    {
      key: 'topic',
      label: t('tickets.topic'),
      allLabel: t('tickets.allTopics'),
      options: (topics.data ?? []).map((topic) => ({ value: topic.code, label: topic.name })),
    },
    {
      key: 'priority',
      label: t('tickets.priority'),
      allLabel: t('tickets.allPriorities'),
      options: ticketPriorities.map((priority) => ({ value: priority, label: priority })),
    },
    {
      key: 'flag',
      label: t('tickets.flag'),
      allLabel: t('tickets.allFlags'),
      options: ticketFlags.map((flag) => ({ value: flag, label: t(`tickets.flags.${flag}`) })),
    },
  ]

  return (
    <section aria-label={t('tickets.list')} className="flex h-full flex-col bg-subtle">
      <div
        role="tablist"
        aria-label={t('tickets.list')}
        className="flex shrink-0 gap-4 overflow-x-auto border-b px-3"
      >
        {tabs.map((item) => {
          const selected = !searching && tab === item.value
          return (
            <button
              key={item.value}
              type="button"
              role="tab"
              aria-selected={selected}
              onClick={() => {
                setTab(item.value)
                setQuery('')
              }}
              className={cn(
                'relative inline-flex h-10 shrink-0 items-center gap-1.5 text-row whitespace-nowrap transition-colors outline-none after:absolute after:inset-x-0 after:bottom-0 after:h-0.5 focus-visible:ring-2 focus-visible:ring-ring/50 focus-visible:ring-inset',
                selected
                  ? 'font-medium text-foreground after:bg-foreground'
                  : 'text-muted-foreground hover:text-foreground',
              )}
            >
              {item.label}
              {item.value !== 'resolved_today' ? (
                <span className="tabular font-normal text-muted-foreground">{item.count}</span>
              ) : null}
            </button>
          )
        })}
      </div>
      <div className="flex shrink-0 flex-col gap-2 border-b px-3 py-2">
        <div className="flex items-center gap-2">
          <div className="relative min-w-0 flex-1">
            <SearchIcon className="pointer-events-none absolute top-2 left-2.5 size-4 text-muted-foreground" />
            <Input
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder={t('tickets.searchPlaceholder')}
              aria-label={t('tickets.searchLabel')}
              className={cn('h-8 pl-8 text-row', query ? 'pr-8' : 'pr-2')}
            />
            {query ? (
              <Button
                variant="ghost"
                size="icon-xs"
                className="absolute top-1 right-1 size-6"
                aria-label={t('tickets.clearSearch')}
                onClick={() => setQuery('')}
              >
                <XIcon />
              </Button>
            ) : null}
          </div>
          <FilterMenu groups={groups} filter={filter} onChange={updateFilter} />
        </div>
        <FilterChips
          groups={groups}
          filter={filter}
          onChange={updateFilter}
          onClear={() => setFilter(noFilter)}
        />
        {worker && tab === 'open' && !searching && gate.reason ? (
          <div
            role="status"
            className="flex flex-wrap items-center gap-x-1.5 gap-y-1 text-xs text-muted-foreground"
          >
            <Dot tone="warn" />
            <span className="min-w-0 flex-1">{gate.reason}</span>
            {gate.needsOnline ? <GoOnlineButton size="xs" /> : null}
          </div>
        ) : null}
        {searching ? (
          <p className="text-xs text-muted-foreground" aria-live="polite">
            {results.isFetching
              ? t('tickets.searching')
              : t('tickets.searchResults', { count: tickets.length })}
          </p>
        ) : null}
      </div>
      <TransferInbox incoming={data.transfers_in} outgoing={data.transfers_out} />
      <div ref={scrollRef} className="relative min-h-0 flex-1 overflow-y-auto">
        {lists.isPending ? (
          <ListSkeleton />
        ) : lists.isError && !lists.data ? (
          <ErrorState error={lists.error} onRetry={() => void lists.refetch()} />
        ) : tickets.length === 0 ? (
          <EmptyState className="h-full" title={empty} />
        ) : (
          <div style={{ height: virtualizer.getTotalSize() }} className="relative w-full">
            {virtualizer.getVirtualItems().map((item) => {
              const ticket = tickets[item.index]
              if (!ticket) return null
              return (
                <div
                  key={item.key}
                  data-index={item.index}
                  ref={virtualizer.measureElement}
                  className="absolute top-0 left-0 w-full"
                  style={{ transform: `translateY(${item.start}px)` }}
                >
                  <TicketRow
                    ticket={ticket}
                    topicName={topicName(ticket.topic)}
                    selected={ticket.id === selectedId}
                    now={now}
                    warn={agent.settings.wait_warn_minutes}
                    late={agent.settings.wait_late_minutes}
                    meId={agent.id}
                    showOwner={tab === 'all_active' || searching}
                    leavingName={leaving[ticket.id]}
                    claim={
                      worker && ticket.status === 'open'
                        ? {
                            disabled: !canClaim,
                            pending: claim.isPending && claim.variables === ticket.id,
                            onClaim: () => claim.mutate(ticket.id),
                          }
                        : undefined
                    }
                    onSelect={() => select(ticket.id)}
                  />
                </div>
              )
            })}
          </div>
        )}
      </div>
    </section>
  )
}
