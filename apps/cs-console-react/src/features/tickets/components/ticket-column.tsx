import { useVirtualizer } from '@tanstack/react-virtual'
import { FilterXIcon, SearchIcon, XIcon } from 'lucide-react'
import { useCallback, useMemo, useRef } from 'react'
import { useTranslation } from 'react-i18next'

import { EmptyState, ErrorState, ListSkeleton } from '@/components/states'
import { Button } from '@/components/ui/button'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/controls'
import { Input } from '@/components/ui/input'
import { useAgent } from '@/features/auth/hooks'
import { useCommandHandler } from '@/features/command/bus'
import { atCapacity, isSupervisor } from '@/features/presence/types'
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
import { isFiltered, noFilter, visibleTickets } from '../logic'
import { emptyLists, ticketFlags, ticketPriorities, type TicketFilter, type TicketTab } from '../types'
import { TicketCard } from './ticket-card'
import { TransferInbox } from './transfer-inbox'

const ALL = '__all__'

function FilterSelect({
  value,
  label,
  allLabel,
  options,
  onChange,
}: {
  value: string | null
  label: string
  allLabel: string
  options: { value: string; label: string }[]
  onChange: (value: string | null) => void
}) {
  return (
    <Select value={value ?? ALL} onValueChange={(next) => onChange(next === ALL ? null : next)}>
      <SelectTrigger aria-label={label} className="h-8 min-w-0 flex-1 px-2 text-xs">
        <SelectValue />
      </SelectTrigger>
      <SelectContent>
        <SelectItem value={ALL}>{allLabel}</SelectItem>
        {options.map((option) => (
          <SelectItem key={option.value} value={option.value}>
            {option.label}
          </SelectItem>
        ))}
      </SelectContent>
    </Select>
  )
}

export function TicketColumn() {
  const { t } = useTranslation()
  const agent = useAgent()
  const supervisor = isSupervisor(agent)
  const now = useNow()
  const density = usePreferences((state) => state.density)
  const { tab, filter, query, selectedId, leaving, setTab, setFilter, setQuery, select } = useTicketUi()
  const lists = useTicketLists()
  const topics = useTopics()
  const topicName = useTopicName()
  const search = useDebounced(query.trim(), 300)
  const results = useTicketSearch(search)
  const claim = useClaimTicket()
  const data = lists.data ?? emptyLists
  const searching = search.length >= 2
  const tickets = useMemo(
    () => visibleTickets(data, tab, filter, searching ? (results.data ?? []) : null),
    [data, tab, filter, searching, results.data],
  )
  const canClaim = agent.status === 'online' && !atCapacity(agent)

  const tabs: { value: TicketTab; label: string; count: number }[] = [
    { value: 'open', label: t('tickets.open'), count: data.open.length },
    { value: 'mine', label: t('tickets.mine'), count: data.mine.length },
    { value: 'resolved_today', label: t('tickets.resolvedToday'), count: data.resolved_today.length },
    ...(supervisor
      ? [{ value: 'all_active' as const, label: t('tickets.allActive'), count: data.all_active.length }]
      : []),
  ]

  const scrollRef = useRef<HTMLDivElement>(null)
  const virtualizer = useVirtualizer({
    count: tickets.length,
    getScrollElement: () => scrollRef.current,
    estimateSize: () => (density === 'compact' ? 78 : 102),
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
  useCommandHandler('claim', claimSelected)

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

  return (
    <section aria-label={t('tickets.list')} className="flex h-full flex-col bg-card">
      <div className="flex flex-col gap-2 border-b p-3 compact:gap-1.5 compact:p-2">
        <div role="tablist" aria-label={t('tickets.list')} className="flex flex-wrap gap-1">
          {tabs.map((item) => (
            <button
              key={item.value}
              type="button"
              role="tab"
              aria-selected={!searching && tab === item.value}
              onClick={() => {
                setTab(item.value)
                setQuery('')
              }}
              className={cn(
                'inline-flex h-7 items-center gap-1.5 rounded-full border px-2.5 text-xs font-medium transition-colors outline-none focus-visible:ring-[3px] focus-visible:ring-ring/50',
                !searching && tab === item.value
                  ? 'border-primary bg-primary text-primary-foreground'
                  : 'bg-card text-muted-foreground hover:bg-accent hover:text-accent-foreground',
              )}
            >
              {item.label}
              <span className="tabular opacity-80">{item.count}</span>
            </button>
          ))}
        </div>
        <div className="relative">
          <SearchIcon className="pointer-events-none absolute top-2.5 left-2.5 size-4 text-muted-foreground" />
          <Input
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder={t('tickets.searchPlaceholder')}
            aria-label={t('tickets.searchLabel')}
            className="h-9 pr-8 pl-8"
          />
          {query ? (
            <Button
              variant="ghost"
              size="icon-xs"
              className="absolute top-1 right-1"
              aria-label={t('tickets.clearSearch')}
              onClick={() => setQuery('')}
            >
              <XIcon />
            </Button>
          ) : null}
        </div>
        <div className="flex items-center gap-1.5">
          <FilterSelect
            value={filter.topic}
            label={t('tickets.topic')}
            allLabel={t('tickets.allTopics')}
            options={(topics.data ?? []).map((topic) => ({ value: topic.code, label: topic.name }))}
            onChange={(topic) => updateFilter({ topic })}
          />
          <FilterSelect
            value={filter.priority}
            label={t('tickets.priority')}
            allLabel={t('tickets.allPriorities')}
            options={ticketPriorities.map((priority) => ({ value: priority, label: priority }))}
            onChange={(priority) => updateFilter({ priority })}
          />
          <FilterSelect
            value={filter.flag}
            label={t('tickets.flag')}
            allLabel={t('tickets.allFlags')}
            options={ticketFlags.map((flag) => ({ value: flag, label: t(`tickets.flags.${flag}`) }))}
            onChange={(flag) => updateFilter({ flag })}
          />
          {isFiltered(filter) ? (
            <Button
              variant="ghost"
              size="icon-sm"
              aria-label={t('tickets.clearFilters')}
              onClick={() => setFilter(noFilter)}
            >
              <FilterXIcon />
            </Button>
          ) : null}
        </div>
        {tab === 'open' && !searching && !canClaim ? (
          <p role="status" className="rounded-md bg-sla-warn/12 px-2.5 py-1.5 text-xs text-sla-warn">
            {agent.status !== 'online' ? t('tickets.needOnline') : t('tickets.atCapacity')}
          </p>
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
      <div ref={scrollRef} className="relative min-h-0 flex-1 scrollbar-thin overflow-y-auto">
        {lists.isPending ? (
          <ListSkeleton />
        ) : lists.isError && !lists.data ? (
          <ErrorState error={lists.error} onRetry={() => void lists.refetch()} />
        ) : tickets.length === 0 ? (
          <EmptyState title={empty} />
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
                  <TicketCard
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
                      ticket.status === 'open'
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
