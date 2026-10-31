import { LockIcon, ShieldCheckIcon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { Dot, TicketStatusText } from '@/components/badges'
import { ErrorState } from '@/components/states'
import { Button } from '@/components/ui/button'
import { Accordion, AccordionContent, AccordionItem, AccordionTrigger } from '@/components/ui/controls'
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogTitle,
} from '@/components/ui/dialog'
import { Avatar, Skeleton } from '@/components/ui/primitives'
import { useAgent } from '@/features/auth/hooks'
import { isSupervisor } from '@/features/presence/types'
import { useTopicName } from '@/features/tickets/hooks'
import { customerName, type Ticket } from '@/features/tickets/types'
import { errorText } from '@/lib/error-text'
import { formatNumber, formatRupiah, shortDate, stamp } from '@/lib/time'
import { cn } from '@/lib/utils'

import { customerApi } from '../api'
import { customerKeys, useCustomerSection, useHistory } from '../hooks'
import type { CustomerProfile, RevealField, SecurityStatus } from '../types'
import { NotesSection } from './notes-section'
import { InfoRow, RevealableValue } from './revealable-value'

function SectionSkeleton() {
  return (
    <div className="flex flex-col gap-2.5 py-1" aria-busy="true">
      <Skeleton className="h-2 w-3/4" />
      <Skeleton className="h-2 w-1/2" />
      <Skeleton className="h-2 w-2/3" />
    </div>
  )
}

function Empty({ children }: { children: React.ReactNode }) {
  return <p className="py-1 text-row text-muted-foreground">{children}</p>
}

function ListItem({
  title,
  meta,
  side,
  extra,
}: {
  title: React.ReactNode
  meta?: React.ReactNode
  side?: React.ReactNode
  extra?: React.ReactNode
}) {
  return (
    <li className="py-2 first:pt-1">
      <div className="flex items-start justify-between gap-3 text-row">
        <span className="tabular min-w-0 font-medium">{title}</span>
        {side ? <span className="shrink-0 text-xs text-muted-foreground">{side}</span> : null}
      </div>
      {meta ? <div className="tabular mt-0.5 text-xs text-muted-foreground">{meta}</div> : null}
      {extra}
    </li>
  )
}

function SectionError({ error, onRetry }: { error: unknown; onRetry: () => void }) {
  const { t } = useTranslation()
  return (
    <div role="alert" className="flex flex-col items-start gap-1.5 py-1 text-xs text-destructive">
      {t('customer.adapterError', { reason: errorText(error) })}
      <Button size="xs" variant="outline" onClick={onRetry}>
        {t('app.retry')}
      </Button>
    </div>
  )
}

function ProfileSection({ ticket, enabled }: { ticket: Ticket; enabled: boolean }) {
  const { t } = useTranslation()
  const profile = useCustomerSection(
    customerKeys.profile(ticket.id),
    () => customerApi.profile(ticket.id),
    enabled,
  )
  if (!enabled) return <Empty>{t('customer.needOwner')}</Empty>
  if (profile.isPending) return <SectionSkeleton />
  if (profile.isError) return <SectionError error={profile.error} onRetry={() => void profile.refetch()} />
  const p: CustomerProfile = profile.data
  const account = (value: CustomerProfile['rdn']) =>
    value ? [value.bank, value.number].filter(Boolean).join(' ') : undefined
  const field = (key: RevealField, masked: string | undefined) => (
    <RevealableValue
      key={key}
      ticketId={ticket.id}
      field={key}
      masked={masked}
      label={t(`customer.fields.${key}`)}
      canReveal
    />
  )
  return (
    <dl>
      <InfoRow label={t('customer.fields.name')} value={p.name} />
      {field('client_code', p.client_code)}
      {field('sid', p.sid)}
      {field('nik', p.nik)}
      {field('phone', p.phone)}
      {field('email', p.email)}
      {field('birth_date', p.birth_date)}
      {field('address', p.address)}
      {field('rdn_number', account(p.rdn))}
      {field('bank_account', account(p.withdrawal_account))}
      <InfoRow label={t('customer.fields.account_status')} value={p.account_status} />
      <InfoRow label={t('customer.fields.kyc_status')} value={p.kyc_status} />
      <InfoRow label={t('customer.fields.segment')} value={p.segment} />
    </dl>
  )
}

function OrdersSection({ ticketId }: { ticketId: string }) {
  const { t } = useTranslation()
  const orders = useCustomerSection(customerKeys.orders(ticketId), () => customerApi.orders(ticketId), true)
  if (orders.isPending) return <SectionSkeleton />
  if (orders.isError) return <SectionError error={orders.error} onRetry={() => void orders.refetch()} />
  if (orders.data.length === 0) return <Empty>{t('customer.noOrders')}</Empty>
  return (
    <ul className="divide-y">
      {orders.data.map((order) => (
        <ListItem
          key={order.order_id}
          title={
            <>
              {order.code} · {order.side === 'sell' ? t('customer.order.sell') : t('customer.order.buy')}{' '}
              {order.lot !== undefined ? formatNumber(order.lot) : ''} lot @{' '}
              {order.price !== undefined ? formatNumber(order.price) : '–'}
            </>
          }
          side={<span className={cn(order.status === 'rejected' && 'text-destructive')}>{order.status}</span>}
          meta={
            <>
              <span className="font-mono">{order.order_id}</span>
              {order.time ? ` · ${stamp(order.time)}` : ''}
              {order.channel ? ` · ${order.channel}` : ''}
            </>
          }
          extra={
            order.reject_reason ? (
              <div className="mt-0.5 text-xs text-destructive">{order.reject_reason}</div>
            ) : null
          }
        />
      ))}
    </ul>
  )
}

function CashSection({ ticketId }: { ticketId: string }) {
  const { t } = useTranslation()
  const cash = useCustomerSection(customerKeys.cash(ticketId), () => customerApi.cash(ticketId), true)
  if (cash.isPending) return <SectionSkeleton />
  if (cash.isError) return <SectionError error={cash.error} onRetry={() => void cash.refetch()} />
  if (cash.data.length === 0) return <Empty>{t('customer.noCash')}</Empty>
  return (
    <ul className="divide-y">
      {cash.data.map((item) => (
        <ListItem
          key={item.id}
          title={`${item.kind} · ${item.amount !== undefined ? formatRupiah(item.amount) : '–'}`}
          side={item.status}
          meta={`${item.bank} · ${item.bank_ref}${item.time ? ` · ${stamp(item.time)}` : ''}`}
        />
      ))}
    </ul>
  )
}

function DevicesSection({ ticketId }: { ticketId: string }) {
  const { t } = useTranslation()
  const sessions = useCustomerSection(
    customerKeys.sessions(ticketId),
    () => customerApi.sessions(ticketId),
    true,
  )
  if (sessions.isPending) return <SectionSkeleton />
  if (sessions.isError) return <SectionError error={sessions.error} onRetry={() => void sessions.refetch()} />
  const active = sessions.data.sessions ?? []
  const logins = sessions.data.logins ?? []
  return (
    <div className="flex flex-col">
      {active.length === 0 ? <Empty>{t('customer.noSessions')}</Empty> : null}
      <ul className="divide-y">
        {active.map((session) => (
          <ListItem
            key={session.id ?? session.device}
            title={`${session.device} · ${session.platform}`}
            meta={`${t('customer.sessionFields.app')} ${session.app_version} · ${session.ip}${
              session.last_active ? ` · ${stamp(session.last_active)}` : ''
            }`}
          />
        ))}
      </ul>
      {logins.length > 0 ? (
        <p className="mt-2 mb-1 text-xs text-muted-foreground">{t('customer.sessionFields.logins')}</p>
      ) : null}
      {logins.map((login, index) => (
        <div key={`${login.time}-${index}`} className="tabular flex justify-between gap-2 py-0.5 text-xs">
          <span className="text-muted-foreground">
            {login.time ? stamp(login.time) : ''} · {login.device} · {login.ip}
          </span>
          <span className={cn(login.result !== 'success' && 'text-destructive')}>{login.result}</span>
        </div>
      ))}
    </div>
  )
}

function SecuritySection({ ticketId }: { ticketId: string }) {
  const { t } = useTranslation()
  const security = useCustomerSection(
    customerKeys.security(ticketId),
    () => customerApi.security(ticketId),
    true,
  )
  const [confirming, setConfirming] = useState(false)
  const [busy, setBusy] = useState(false)
  if (security.isPending) return <SectionSkeleton />
  if (security.isError) return <SectionError error={security.error} onRetry={() => void security.refetch()} />
  const data: SecurityStatus = security.data
  const fields = Object.keys(t('customer.securityFields', { returnObjects: true }))
  const show = (value: SecurityStatus[string]) =>
    typeof value === 'boolean'
      ? value
        ? t('app.yes')
        : t('app.no')
      : typeof value === 'string' && /^\d{4}-\d{2}-\d{2}T/.test(value)
        ? shortDate(value)
        : (value ?? '–')
  return (
    <div className="flex flex-col gap-2">
      <dl>
        {fields
          .filter((key) => key in data)
          .map((key) => (
            <InfoRow
              key={key}
              label={t(`customer.securityFields.${key as 'otp_enabled'}`)}
              value={
                <span
                  className={cn(key === 'suspicious' && data[key] === true && 'font-medium text-destructive')}
                >
                  {show(data[key] ?? null)}
                </span>
              }
            />
          ))}
      </dl>
      <Button
        size="sm"
        variant="destructive"
        className="self-start"
        disabled={busy}
        onClick={() => setConfirming(true)}
      >
        <LockIcon />
        {t('customer.secureAccount')}
      </Button>
      <AlertDialog open={confirming} onOpenChange={setConfirming}>
        <AlertDialogContent>
          <AlertDialogTitle>{t('customer.secureTitle')}</AlertDialogTitle>
          <AlertDialogDescription>{t('customer.secureBody')}</AlertDialogDescription>
          <div className="flex justify-end gap-2">
            <AlertDialogCancel>{t('app.cancel')}</AlertDialogCancel>
            <AlertDialogAction
              destructive
              onClick={() => {
                setBusy(true)
                customerApi
                  .secureAccount(ticketId)
                  .then((result) => {
                    if (result.ok) toast.success(t('customer.secured'))
                    else toast.warning(t('customer.securePartial'))
                    void security.refetch()
                  })
                  .catch((error: unknown) => toast.error(errorText(error)))
                  .finally(() => setBusy(false))
              }}
            >
              <ShieldCheckIcon />
              {t('customer.secureAccount')}
            </AlertDialogAction>
          </div>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  )
}

function HistorySection({ customerId, currentId }: { customerId: string; currentId: string }) {
  const { t } = useTranslation()
  const topicName = useTopicName()
  const history = useHistory(customerId)
  if (history.isPending) return <SectionSkeleton />
  if (history.isError) return <ErrorState error={history.error} onRetry={() => void history.refetch()} />
  const items = history.data.filter((item) => item.id !== currentId)
  if (items.length === 0) return <Empty>{t('customer.noHistory')}</Empty>
  return (
    <ul className="divide-y">
      {items.map((item) => (
        <ListItem
          key={item.id}
          title={<span className="font-mono text-xs">{item.ticket_number}</span>}
          side={<TicketStatusText status={item.status} />}
          meta={`${topicName(item.topic)} · ${shortDate(item.created_at)}${item.agent ? ` · ${item.agent}` : ''}${
            item.rating ? ` · ${t('customer.rating', { rating: item.rating })}` : ''
          }`}
        />
      ))}
    </ul>
  )
}

const accountTone: Record<string, 'ok' | 'late'> = {
  active: 'ok',
  suspended: 'late',
  blocked: 'late',
  closed: 'late',
}

function PanelHeader({ ticket, allowed }: { ticket: Ticket; allowed: boolean }) {
  const profile = useCustomerSection(
    customerKeys.profile(ticket.id),
    () => customerApi.profile(ticket.id),
    allowed,
  )
  const name = customerName(ticket)
  const status = profile.data?.account_status
  const code = profile.data?.client_code
  return (
    <div className="flex items-center gap-3 border-b px-4 py-3">
      <Avatar name={name || '?'} className="size-9 text-xs" />
      <div className="min-w-0 flex-1">
        <p className="truncate text-panel font-medium">{name}</p>
        <p className="truncate font-mono text-xs text-muted-foreground">
          {code ?? (ticket.customer?.username ? `@${ticket.customer.username}` : '')}
        </p>
        {status ? (
          <p className="mt-0.5 flex items-center gap-1.5 text-xs text-muted-foreground">
            <Dot tone={accountTone[status] ?? 'neutral'} />
            {status}
          </p>
        ) : null}
      </div>
    </div>
  )
}

export function CustomerPanel({ ticket }: { ticket: Ticket }) {
  const { t } = useTranslation()
  const agent = useAgent()
  const owner =
    ticket.owner?.id === agent.id && (ticket.status === 'claimed' || ticket.status === 'waiting_customer')
  const allowed = owner || isSupervisor(agent)
  const [open, setOpen] = useState<string[]>(['profile', 'notes'])
  const customerId = ticket.customer?.id
  return (
    <aside aria-label={t('customer.title')} className="flex h-full flex-col bg-subtle">
      <PanelHeader ticket={ticket} allowed={allowed} />
      <div className="min-h-0 flex-1 overflow-y-auto px-4">
        <Accordion type="multiple" value={open} onValueChange={setOpen}>
          <AccordionItem value="profile">
            <AccordionTrigger>{t('customer.profile')}</AccordionTrigger>
            <AccordionContent>
              <ProfileSection ticket={ticket} enabled={allowed} />
            </AccordionContent>
          </AccordionItem>
          {allowed ? (
            <>
              <AccordionItem value="orders">
                <AccordionTrigger>{t('customer.orders')}</AccordionTrigger>
                <AccordionContent>
                  {open.includes('orders') ? <OrdersSection ticketId={ticket.id} /> : null}
                </AccordionContent>
              </AccordionItem>
              <AccordionItem value="cash">
                <AccordionTrigger>{t('customer.cash')}</AccordionTrigger>
                <AccordionContent>
                  {open.includes('cash') ? <CashSection ticketId={ticket.id} /> : null}
                </AccordionContent>
              </AccordionItem>
              <AccordionItem value="devices">
                <AccordionTrigger>{t('customer.devices')}</AccordionTrigger>
                <AccordionContent>
                  {open.includes('devices') ? <DevicesSection ticketId={ticket.id} /> : null}
                </AccordionContent>
              </AccordionItem>
              <AccordionItem value="security">
                <AccordionTrigger>{t('customer.security')}</AccordionTrigger>
                <AccordionContent>
                  {open.includes('security') ? <SecuritySection ticketId={ticket.id} /> : null}
                </AccordionContent>
              </AccordionItem>
            </>
          ) : null}
          {customerId ? (
            <>
              <AccordionItem value="history">
                <AccordionTrigger>{t('customer.history')}</AccordionTrigger>
                <AccordionContent>
                  {open.includes('history') ? (
                    <HistorySection customerId={customerId} currentId={ticket.id} />
                  ) : null}
                </AccordionContent>
              </AccordionItem>
              <AccordionItem value="notes" className="border-b-0">
                <AccordionTrigger>{t('customer.notes')}</AccordionTrigger>
                <AccordionContent>
                  <NotesSection customerId={customerId} ticketId={ticket.id} />
                </AccordionContent>
              </AccordionItem>
            </>
          ) : null}
        </Accordion>
      </div>
    </aside>
  )
}
