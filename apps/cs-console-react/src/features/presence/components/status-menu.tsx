import { ChevronDownIcon, WifiIcon, WifiOffIcon, LoaderCircleIcon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'

import { StatusDot } from '@/components/badges'
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
            variant="outline"
            size="sm"
            className="rounded-full"
            aria-label={t('presence.changeStatus')}
          >
            {setStatus.isPending ? (
              <LoaderCircleIcon className="animate-spin" />
            ) : (
              <StatusDot status={agent.status} />
            )}
            <span className="font-semibold">{t(`presence.${agent.status}`)}</span>
            {agent.reason ? (
              <span className="hidden text-muted-foreground xl:inline">· {agent.reason}</span>
            ) : null}
            <ChevronDownIcon className="opacity-60" />
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
        <DialogContent className="sm:max-w-sm" closeLabel={t('app.close')}>
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
              <Button type="button" variant="outline" onClick={() => setCustom(null)}>
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
          'tabular hidden text-sm font-medium lg:inline',
          atCapacity(agent) ? 'text-destructive' : 'text-muted-foreground',
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
  const Icon = state === 'offline' ? WifiOffIcon : state === 'connected' ? WifiIcon : LoaderCircleIcon
  return (
    <Tooltip content={t('presence.connectionHint')}>
      <span
        role="status"
        aria-live="polite"
        className={cn(
          'inline-flex h-7 items-center gap-1.5 rounded-full px-2.5 text-xs font-medium',
          state === 'connected' && 'text-sla-ok',
          state === 'offline' && 'bg-destructive/10 text-destructive',
          (state === 'reconnecting' || state === 'connecting') && 'bg-sla-warn/12 text-sla-warn',
        )}
      >
        <Icon className={cn('size-3.5', state !== 'connected' && state !== 'offline' && 'animate-spin')} />
        <span className="hidden 2xl:inline">{label}</span>
        <span className="sr-only 2xl:hidden">{label}</span>
      </span>
    </Tooltip>
  )
}
