import { ChevronDownIcon, LoaderCircleIcon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'

import { Dot, StatusDot } from '@/components/badges'
import { Button } from '@/components/ui/button'
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuSub,
  DropdownMenuSubContent,
  DropdownMenuSubTrigger,
  DropdownMenuTrigger,
  Tooltip,
} from '@/components/ui/menu'
import { useAgent } from '@/features/auth/hooks'
import { useConnection } from '@/lib/realtime'
import { cn } from '@/lib/utils'

import { useSetStatus } from '../hooks'
import { atCapacity, type AgentStatus } from '../types'

const withReason: AgentStatus[] = ['busy', 'break']

export function StatusMenu() {
  const { t } = useTranslation()
  const agent = useAgent()
  const setStatus = useSetStatus()
  const [custom, setCustom] = useState<AgentStatus | null>(null)
  const [reason, setReason] = useState('')
  const presets = [t('presence.reasonLunch'), t('presence.reasonMeeting'), t('presence.reasonPrayer')]
  const apply = (status: AgentStatus, value?: string) => setStatus.mutate({ status, reason: value })

  return (
    <>
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button
            variant="ghost"
            size="sm"
            className="gap-2 text-foreground"
            aria-label={`${t('presence.changeStatus')}: ${t(`presence.${agent.status}`)}`}
          >
            {setStatus.isPending ? (
              <LoaderCircleIcon className="size-3 animate-spin" />
            ) : (
              <StatusDot status={agent.status} />
            )}
            <span>{t(`presence.${agent.status}`)}</span>
            {agent.reason ? (
              <span className="hidden max-w-40 truncate text-muted-foreground xl:inline">
                · {agent.reason}
              </span>
            ) : null}
            <ChevronDownIcon className="size-3.5 text-muted-foreground" />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="start" className="w-52">
          {(['online', 'busy', 'break', 'offline'] as const).map((status) =>
            withReason.includes(status) ? (
              <DropdownMenuSub key={status}>
                <DropdownMenuSubTrigger>
                  <StatusDot status={status} />
                  {t(`presence.${status}`)}
                </DropdownMenuSubTrigger>
                <DropdownMenuSubContent>
                  <DropdownMenuItem onSelect={() => apply(status)}>
                    {t(`presence.${status}`)}
                  </DropdownMenuItem>
                  <DropdownMenuSeparator />
                  {presets.map((preset) => (
                    <DropdownMenuItem key={preset} onSelect={() => apply(status, preset)}>
                      {preset}
                    </DropdownMenuItem>
                  ))}
                  <DropdownMenuItem
                    onSelect={() => {
                      setReason('')
                      setCustom(status)
                    }}
                  >
                    {t('presence.reasonOther')}…
                  </DropdownMenuItem>
                </DropdownMenuSubContent>
              </DropdownMenuSub>
            ) : (
              <DropdownMenuItem key={status} onSelect={() => apply(status)}>
                <StatusDot status={status} />
                {t(`presence.${status}`)}
              </DropdownMenuItem>
            ),
          )}
        </DropdownMenuContent>
      </DropdownMenu>
      <Dialog open={custom !== null} onOpenChange={(open) => !open && setCustom(null)}>
        <DialogContent closeLabel={t('app.close')}>
          <DialogHeader>
            <DialogTitle>
              {t('presence.reasonTitle', { status: custom ? t(`presence.${custom}`) : '' })}
            </DialogTitle>
          </DialogHeader>
          <form
            className="flex flex-col gap-4"
            onSubmit={(event) => {
              event.preventDefault()
              if (custom) apply(custom, reason.trim().slice(0, 120))
              setCustom(null)
            }}
          >
            <Input
              autoFocus
              maxLength={120}
              value={reason}
              placeholder={t('presence.reasonPlaceholder')}
              aria-label={t('presence.reasonPlaceholder')}
              onChange={(event) => setReason(event.target.value)}
            />
            <DialogFooter>
              <Button type="button" variant="ghost" onClick={() => setCustom(null)}>
                {t('app.cancel')}
              </Button>
              <Button type="submit">{t('presence.apply')}</Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>
    </>
  )
}

export function ActiveCount() {
  const { t } = useTranslation()
  const agent = useAgent()
  return (
    <Tooltip content={t('presence.activeHint')}>
      <span
        className={cn(
          'tabular hidden px-1 text-row lg:inline',
          atCapacity(agent) ? 'text-danger' : 'text-muted-foreground',
        )}
      >
        {t('presence.activeTickets', { count: agent.active_tickets, max: agent.max_active_tickets })}
      </span>
    </Tooltip>
  )
}

export function ConnectionIndicator() {
  const { t } = useTranslation()
  const state = useConnection((s) => s.state)
  const label =
    state === 'connected'
      ? t('presence.connected')
      : state === 'offline'
        ? t('presence.offlineNetwork')
        : t('presence.reconnecting')
  if (state === 'connected') {
    return (
      <span role="status" aria-live="polite" className="sr-only">
        {label}
      </span>
    )
  }
  return (
    <Tooltip content={t('presence.connectionHint')}>
      <span
        role="status"
        aria-live="polite"
        className="inline-flex h-8 items-center gap-1.5 px-2 text-xs text-muted-foreground"
      >
        <Dot tone={state === 'offline' ? 'late' : 'warn'} />
        {label}
      </span>
    </Tooltip>
  )
}
