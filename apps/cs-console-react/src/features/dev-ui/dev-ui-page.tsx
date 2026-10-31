import { CheckIcon, LogOutIcon, PanelRightOpenIcon, SearchIcon } from 'lucide-react'
import { useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'

import { Dot, FlagText, PriorityText, StatusDot, UnreadBadge, WaitTime } from '@/components/badges'
import { MetricStrip } from '@/components/metric-strip'
import { Button } from '@/components/ui/button'
import {
  Checkbox,
  RadioGroup,
  RadioGroupItem,
  Switch,
  ToggleGroup,
  ToggleGroupItem,
} from '@/components/ui/controls'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { floatClass, itemClass } from '@/components/ui/menu'
import { Kbd } from '@/components/ui/primitives'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { Textarea } from '@/components/ui/textarea'
import { toastClasses } from '@/components/ui/toaster'
import { Composer } from '@/features/conversation/components/composer'
import { MessageList } from '@/features/conversation/components/message-list'
import type { SendResult } from '@/features/conversation/types'
import { CustomerHeader, HistoryList } from '@/features/customer/components/customer-panel'
import { NoteList } from '@/features/customer/components/notes-section'
import { TicketRow } from '@/features/tickets/components/ticket-row'
import { cn } from '@/lib/utils'

import {
  conversationTicket,
  sampleAgent,
  sampleHistory,
  sampleMessages,
  sampleNotes,
  sampleNow,
  samplePending,
  sampleTickets,
  sampleTopicName,
} from './samples'

type ThemeName = 'light' | 'dark'

const tokens = [
  'bg',
  'bg-subtle',
  'bg-muted',
  'bg-selected',
  'bg-float',
  'border',
  'border-strong',
  'text',
  'text-muted',
  'text-subtle',
  'primary',
  'primary-fg',
  'bubble-agent',
  'bubble-agent-fg',
  'note-bg',
  'note-border',
  'success',
  'warning',
  'danger',
  'info',
  'success-text',
  'warning-text',
  'danger-text',
  'danger-solid',
  'chart-neutral',
]

const noop = () => undefined
const blocked = (): Promise<SendResult> => Promise.resolve({ status: 'blocked' })

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="flex flex-col gap-3">
      <h2 className="text-label font-medium text-muted-foreground uppercase">{title}</h2>
      {children}
    </section>
  )
}

function Tokens({ column }: { column: HTMLElement | null }) {
  const values = useMemo<Record<string, string>>(() => {
    if (!column) return {}
    const style = getComputedStyle(column)
    return Object.fromEntries(tokens.map((name) => [name, style.getPropertyValue(`--${name}`).trim()]))
  }, [column])
  return (
    <div className="grid grid-cols-2 gap-x-6 gap-y-2 sm:grid-cols-3">
      {tokens.map((name) => (
        <div key={name} className="flex min-w-0 items-center gap-2">
          <span className="size-6 shrink-0 rounded-md border" style={{ background: `var(--${name})` }} />
          <span className="min-w-0">
            <span className="block truncate font-mono text-xs">--{name}</span>
            <span className="tabular block truncate font-mono text-xs text-muted-foreground">
              {values[name]}
            </span>
          </span>
        </div>
      ))}
    </div>
  )
}

function DialogPreview({ theme }: { theme: ThemeName }) {
  const { t } = useTranslation()
  const [box, setBox] = useState<HTMLDivElement | null>(null)
  return (
    <div
      ref={setBox}
      className="relative h-72 [transform:translateZ(0)] overflow-hidden rounded-lg border bg-scrim"
    >
      {box ? (
        <Dialog open modal={false}>
          <DialogContent
            container={box}
            closeLabel={t('app.close')}
            onOpenAutoFocus={(event) => event.preventDefault()}
            onInteractOutside={(event) => event.preventDefault()}
            aria-describedby={undefined}
          >
            <DialogHeader>
              <DialogTitle>{t('conversation.resolveTitle')}</DialogTitle>
              <DialogDescription>{t('devUi.dialogBody')}</DialogDescription>
            </DialogHeader>
            <div className="flex flex-col gap-1.5">
              <Label htmlFor={`summary-${theme}`}>{t('conversation.summary')}</Label>
              <Textarea id={`summary-${theme}`} defaultValue={t('devUi.summarySample')} />
            </div>
            <DialogFooter>
              <Button variant="ghost">{t('app.cancel')}</Button>
              <Button>{t('conversation.resolve')}</Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>
      ) : null}
    </div>
  )
}

function ThemeColumn({ theme }: { theme: ThemeName }) {
  const { t } = useTranslation()
  const [column, setColumn] = useState<HTMLDivElement | null>(null)
  return (
    <div
      ref={setColumn}
      data-theme-column={theme}
      className={cn(theme, 'flex min-w-0 flex-col gap-10 bg-background px-6 py-6 text-foreground')}
    >
      <h2 className="text-panel font-semibold">
        {theme === 'light' ? t('preferences.light') : t('preferences.dark')}
      </h2>

      <Section title={t('devUi.tokens')}>
        <Tokens column={column} />
      </Section>

      <Section title={t('devUi.typography')}>
        <div className="flex flex-col gap-1.5">
          <p className="text-lg font-semibold">18 · {t('devUi.pageTitle')}</p>
          <p className="text-panel font-semibold">15 · {t('devUi.panelTitle')}</p>
          <p className="text-sm">14 · {t('devUi.body')}</p>
          <p className="text-row">13 · {t('devUi.list')}</p>
          <p className="text-xs text-muted-foreground">12 · {t('devUi.meta')}</p>
          <p className="text-label font-medium text-muted-foreground uppercase">
            11 · {t('devUi.sectionLabel')}
          </p>
          <p className="tabular text-sm">
            <span className="font-normal">400</span> · <span className="font-medium">500</span> ·{' '}
            <span className="font-semibold">600</span> · 0123456789 · 15.58
          </p>
        </div>
      </Section>

      <Section title={t('devUi.buttons')}>
        <div className="flex flex-wrap items-center gap-2">
          <Button>{t('conversation.resolve')}</Button>
          <Button variant="outline">{t('conversation.transfer')}</Button>
          <Button variant="secondary">{t('app.refresh')}</Button>
          <Button variant="ghost">{t('app.cancel')}</Button>
          <Button variant="destructive">{t('app.delete')}</Button>
          <Button variant="link">{t('auth.useOtherAccount')}</Button>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <Button size="sm">{t('composer.send')}</Button>
          <Button size="sm" variant="outline">
            {t('conversation.release')}
          </Button>
          <Button size="xs" variant="outline">
            {t('tickets.claim')}
          </Button>
          <Button size="icon-sm" variant="ghost" aria-label={t('customer.expand')}>
            <PanelRightOpenIcon />
          </Button>
          <Button disabled>{t('app.save')}</Button>
        </div>
      </Section>

      <Section title={t('devUi.controls')}>
        <div className="grid gap-3 sm:grid-cols-2">
          <Input placeholder={t('tickets.searchPlaceholder')} aria-label={t('tickets.searchLabel')} />
          <Input aria-invalid defaultValue="nadia@" aria-label={t('auth.email')} />
          <Input disabled defaultValue={t('devUi.disabled')} aria-label={t('devUi.disabled')} />
          <div className="relative">
            <SearchIcon className="pointer-events-none absolute top-2.5 left-2.5 size-4 text-muted-foreground" />
            <Input className="pl-8" placeholder={t('nav.searchHint')} aria-label={t('nav.searchHint')} />
          </div>
        </div>
        <div className="flex flex-wrap items-center gap-5 text-row">
          <label className="flex items-center gap-2">
            <Switch defaultChecked /> {t('devUi.on')}
          </label>
          <label className="flex items-center gap-2">
            <Switch /> {t('devUi.off')}
          </label>
          <label className="flex items-center gap-2">
            <Checkbox defaultChecked /> {t('roles.cs_agent')}
          </label>
          <RadioGroup defaultValue="claim" className="flex gap-4" aria-label={t('devUi.radio')}>
            <label className="flex items-center gap-2">
              <RadioGroupItem value="claim" /> claim
            </label>
            <label className="flex items-center gap-2">
              <RadioGroupItem value="auto" /> auto
            </label>
          </RadioGroup>
          <ToggleGroup type="single" defaultValue="week" aria-label={t('reports.rangeLabel')}>
            <ToggleGroupItem value="today">{t('reports.today')}</ToggleGroupItem>
            <ToggleGroupItem value="week">{t('reports.week')}</ToggleGroupItem>
            <ToggleGroupItem value="month">{t('reports.month')}</ToggleGroupItem>
          </ToggleGroup>
        </div>
      </Section>

      <Section title={t('devUi.status')}>
        <div className="flex flex-wrap items-center gap-x-5 gap-y-2 text-row">
          <span className="flex items-center gap-1.5">
            <StatusDot status="online" /> {t('presence.online')}
          </span>
          <span className="flex items-center gap-1.5">
            <StatusDot status="busy" /> {t('presence.busy')}
          </span>
          <span className="flex items-center gap-1.5">
            <StatusDot status="break" /> {t('presence.break')}
          </span>
          <span className="flex items-center gap-1.5">
            <StatusDot status="offline" /> {t('presence.offline')}
          </span>
          <WaitTime minutes={3} warn={5} late={15} />
          <WaitTime minutes={9} warn={5} late={15} />
          <WaitTime minutes={27} warn={5} late={15} />
        </div>
        <div className="flex flex-wrap items-center gap-x-5 gap-y-2 text-row">
          <PriorityText priority="P1" />
          <PriorityText priority="P2" />
          <PriorityText priority="P3" />
          <PriorityText priority="P4" />
          <FlagText flag="complaint" />
          <FlagText flag="fraud" />
          <FlagText flag="vip" />
          <UnreadBadge count={2} label={t('tickets.unread', { count: 2 })} />
          <Kbd>Ctrl K</Kbd>
          <span className="flex items-center gap-1.5 text-xs text-muted-foreground">
            <Dot tone="warn" />
            {t('presence.reconnecting')}
          </span>
        </div>
      </Section>

      <Section title={t('devUi.ticketRows')}>
        <div className="overflow-hidden rounded-lg border bg-subtle">
          {sampleTickets.map((item) => (
            <TicketRow
              key={item.ticket.id}
              ticket={item.ticket}
              topicName={item.topic}
              selected={item.selected === true}
              now={sampleNow}
              warn={5}
              late={15}
              meId={sampleAgent.id}
              showOwner={false}
              claim={item.claimable ? { disabled: false, pending: false, onClaim: noop } : undefined}
              onSelect={noop}
            />
          ))}
        </div>
      </Section>

      <Section title={t('devUi.conversation')}>
        <div className="flex h-[560px] flex-col overflow-hidden rounded-lg border bg-background">
          <MessageList
            messages={sampleMessages}
            notes={sampleNotes}
            pending={samplePending}
            meId={sampleAgent.id}
            customerReadAt={sampleMessages[5]?.created_at ?? null}
            hasOlder={false}
            loadingOlder={false}
            onLoadOlder={noop}
            trustedHost={() => true}
            onResend={noop}
            onDiscard={noop}
          />
          <Composer
            ticket={conversationTicket}
            agent={sampleAgent}
            replyTo={null}
            onCancelReply={noop}
            send={blocked}
            onTyping={noop}
            onStopTyping={noop}
          />
        </div>
      </Section>

      <Section title={t('devUi.customerPanel')}>
        <div className="overflow-hidden rounded-lg border bg-subtle">
          <CustomerHeader ticket={conversationTicket} />
          <div className="flex flex-col gap-3 px-4 py-3">
            <HistoryList items={sampleHistory} topicName={sampleTopicName} />
            <NoteList notes={sampleNotes} />
          </div>
        </div>
      </Section>

      <Section title={t('devUi.metrics')}>
        <MetricStrip
          metrics={[
            { label: t('dashboard.statOpen'), value: '7' },
            { label: t('dashboard.statLongestWait'), value: '9m', tone: 'warn' },
            { label: t('dashboard.statActive'), value: '12' },
            { label: t('dashboard.statResolvedToday'), value: '48' },
          ]}
        />
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>{t('dashboard.colAgent')}</TableHead>
              <TableHead>{t('dashboard.colStatus')}</TableHead>
              <TableHead className="text-right">{t('dashboard.colResolvedToday')}</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {[
              ['Nadia', 'online', 12],
              ['Bima', 'busy', 9],
              ['Laras', 'offline', 0],
            ].map(([name, status, count]) => (
              <TableRow key={String(name)}>
                <TableCell className="font-medium">{name}</TableCell>
                <TableCell>
                  <span className="inline-flex items-center gap-1.5">
                    <StatusDot status={status as 'online'} />
                    {t(`presence.${status as 'online'}`)}
                  </span>
                </TableCell>
                <TableCell className="tabular text-right">{count}</TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </Section>

      <Section title={t('devUi.overlays')}>
        <DialogPreview theme={theme} />
        <div className="flex flex-wrap items-start gap-4">
          <div className={cn(floatClass, 'w-56 p-1')} role="presentation">
            <div className={cn(itemClass, 'pl-8')}>
              <CheckIcon className="absolute left-2" />
              {t('preferences.light')}
            </div>
            <div className={cn(itemClass, 'bg-muted pl-8')}>{t('preferences.dark')}</div>
            <div className={cn(itemClass, 'pl-8')}>{t('preferences.system')}</div>
            <div className="-mx-1 my-1 h-px bg-border" />
            <div className={cn(itemClass, 'text-destructive')}>
              <LogOutIcon className="text-destructive" />
              {t('auth.signOut')}
            </div>
          </div>
          <div className="flex w-[356px] max-w-full flex-col gap-2">
            <div className={toastClasses.toast}>
              <div className={toastClasses.content}>
                <div className={toastClasses.title}>{t('conversation.resolved')}</div>
              </div>
            </div>
            <div className={toastClasses.toast}>
              <span className={toastClasses.icon}>
                <Dot tone="late" />
              </span>
              <div className={toastClasses.content}>
                <div className={toastClasses.title}>{t('tickets.takenByOther', { name: 'Bima' })}</div>
              </div>
            </div>
          </div>
        </div>
      </Section>
    </div>
  )
}

export function DevUiPage() {
  const { t } = useTranslation()
  return (
    <div className="min-h-full bg-background">
      <header className="border-b px-6 py-4">
        <h1 className="text-lg font-semibold">{t('devUi.title')}</h1>
        <p className="text-row text-muted-foreground">{t('devUi.subtitle')}</p>
      </header>
      <div className="grid divide-y xl:grid-cols-2 xl:divide-x xl:divide-y-0">
        <ThemeColumn theme="light" />
        <ThemeColumn theme="dark" />
      </div>
    </div>
  )
}
