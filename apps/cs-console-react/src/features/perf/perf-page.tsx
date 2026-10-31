import { useVirtualizer } from '@tanstack/react-virtual'
import { GaugeIcon, LoaderCircleIcon } from 'lucide-react'
import { memo, useMemo, useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'

import { Button } from '@/components/ui/button'
import { MessageList } from '@/features/conversation/components/message-list'
import type { ChatMessage, PendingMessage } from '@/features/conversation/types'
import { TicketRow } from '@/features/tickets/components/ticket-row'
import { ticketPriorities, type Ticket } from '@/features/tickets/types'

const TICKETS = 1000
const MESSAGES = 5000
const RUN_MS = 4000
const ME = '00000000-0000-4000-8000-000000000001'
const CUSTOMER = '00000000-0000-4000-8000-000000000002'
const ROOM = '00000000-0000-4000-8000-000000000003'

type Result = { fps: number; p95: number; frames: number }

function syntheticTickets(now: number): Ticket[] {
  return Array.from({ length: TICKETS }, (_, index) => {
    const queued = new Date(now - (index % 120) * 60_000).toISOString()
    return {
      id: `perf-ticket-${index}`,
      ticket_number: `CS-${String(100000 + index)}`,
      room_id: ROOM,
      status: index % 3 === 0 ? 'claimed' : 'open',
      version: 1,
      topic: ['order', 'deposit', 'withdrawal', 'account'][index % 4] ?? 'order',
      priority: ticketPriorities[index % ticketPriorities.length] ?? 'P3',
      flags: index % 17 === 0 ? ['complaint'] : index % 29 === 0 ? ['vip'] : [],
      language: 'id',
      customer: {
        id: `perf-customer-${index}`,
        display_name: `Nasabah ${index + 1}`,
        username: `nasabah${index + 1}`,
      },
      owner: null,
      is_mine: false,
      queued_at: queued,
      created_at: queued,
      claimed_at: null,
      first_response_at: null,
      last_customer_message_at: queued,
      last_agent_message_at: null,
      resolved_at: null,
      closed_at: null,
      outcome: null,
      resolution_summary: null,
      returned_reason: index % 41 === 0 ? 'CS offline' : null,
      complaint_received_at: null,
      complaint_due_at: null,
      rating: null,
      rating_comment: null,
      transfer: null,
      preview:
        index % 2 === 0
          ? 'Order saya belum masuk, mohon dicek ya kak.'
          : 'Dana penarikan belum diterima sejak kemarin.',
      unread_count: index % 5,
      waiting_since: queued,
    }
  })
}

function syntheticMessages(now: number): ChatMessage[] {
  const start = now - MESSAGES * 45_000
  return Array.from({ length: MESSAGES }, (_, index) => {
    const mine = index % 3 === 1
    const created = new Date(start + index * 45_000).toISOString()
    return {
      id: `perf-message-${index}`,
      room_id: ROOM,
      sender_id: mine ? ME : CUSTOMER,
      sender_username: mine ? 'cs.perf' : 'nasabah',
      sender_display_name: mine ? 'CS Perf' : 'Nasabah',
      body:
        index % 7 === 0
          ? 'Baik, kami cek dulu ya. Mohon tunggu sebentar, kami akan kabari kembali setelah pengecekan selesai di sistem.'
          : `Pesan uji ${index + 1}`,
      is_deleted: false,
      reply_to_id: null,
      reply_to_body: null,
      reply_to_sender_username: null,
      attachments: [],
      client_id: null,
      created_at: created,
      cursor: created,
      kind: 'text',
      payload: {},
      session_id: null,
      sender_role: mine ? 'agent' : 'customer',
    }
  })
}

function measure(step: () => void): Promise<Result> {
  return new Promise((resolve) => {
    const gaps: number[] = []
    let started = 0
    let last = 0
    const tick = (time: number) => {
      if (started === 0) {
        started = time
        last = time
      } else {
        gaps.push(time - last)
        last = time
      }
      step()
      if (time - started < RUN_MS) {
        requestAnimationFrame(tick)
        return
      }
      const sorted = [...gaps].sort((a, b) => a - b)
      resolve({
        fps: Math.round((gaps.length / ((time - started) / 1000)) * 10) / 10,
        p95: Math.round((sorted[Math.floor(sorted.length * 0.95)] ?? 0) * 10) / 10,
        frames: gaps.length,
      })
    }
    requestAnimationFrame(tick)
  })
}

const noPending: PendingMessage[] = []
const noop = () => undefined
const untrusted = () => false

function PerfTickets({
  tickets,
  now,
  listRef,
}: {
  tickets: Ticket[]
  now: Date
  listRef: React.RefObject<HTMLDivElement | null>
}) {
  const [selected, setSelected] = useState<string | null>(null)
  const virtualizer = useVirtualizer({
    count: tickets.length,
    getScrollElement: () => listRef.current,
    estimateSize: () => 76,
    overscan: 8,
    getItemKey: (index) => tickets[index]?.id ?? index,
  })
  return (
    <div ref={listRef} className="overflow-y-auto border-r bg-subtle" data-testid="perf-tickets">
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
                topicName={ticket.topic}
                selected={ticket.id === selected}
                now={now}
                warn={5}
                late={15}
                meId={ME}
                showOwner={false}
                onSelect={() => setSelected(ticket.id)}
              />
            </div>
          )
        })}
      </div>
    </div>
  )
}

const PerfMessages = memo(function PerfMessages({ messages }: { messages: ChatMessage[] }) {
  return (
    <MessageList
      messages={messages}
      pending={noPending}
      meId={ME}
      customerReadAt={null}
      hasOlder={false}
      loadingOlder={false}
      onLoadOlder={noop}
      trustedHost={untrusted}
      onResend={noop}
      onDiscard={noop}
    />
  )
})

export function PerfPage() {
  const { t } = useTranslation()
  const [now] = useState(() => Date.now())
  const tickets = useMemo(() => syntheticTickets(now), [now])
  const messages = useMemo(() => syntheticMessages(now), [now])
  const nowDate = useMemo(() => new Date(now), [now])
  const [result, setResult] = useState<Result | null>(null)
  const [running, setRunning] = useState(false)
  const listRef = useRef<HTMLDivElement>(null)
  const chatRef = useRef<HTMLDivElement>(null)

  const run = async () => {
    setRunning(true)
    setResult(null)
    const list = listRef.current
    const chat = chatRef.current?.querySelector<HTMLElement>('[role="log"]')
    if (list) list.scrollTop = 0
    const measured = await measure(() => {
      if (list)
        list.scrollTop =
          list.scrollTop + 60 >= list.scrollHeight - list.clientHeight ? 0 : list.scrollTop + 60
      if (chat) chat.scrollTop = chat.scrollTop <= 0 ? chat.scrollHeight : chat.scrollTop - 60
    })
    setResult(measured)
    setRunning(false)
  }

  return (
    <div className="flex h-full flex-col">
      <header className="flex flex-wrap items-center gap-3 border-b bg-background px-4 py-3">
        <GaugeIcon className="size-4 text-muted-foreground" aria-hidden="true" />
        <h1 className="text-panel font-semibold">{t('perf.title')}</h1>
        <span className="text-sm text-muted-foreground">
          {TICKETS} {t('nav.tickets').toLowerCase()} · {MESSAGES} msg
        </span>
        <Button
          size="sm"
          className="ml-auto"
          disabled={running}
          onClick={() => void run()}
          data-testid="perf-run"
        >
          {running ? <LoaderCircleIcon className="animate-spin" /> : null}
          {t('perf.run')}
        </Button>
        <output
          data-testid="perf-result"
          data-fps={result?.fps ?? ''}
          data-p95={result?.p95 ?? ''}
          className="tabular min-w-48 text-sm"
        >
          {result ? t('perf.result', { fps: result.fps, p95: result.p95, frames: result.frames }) : null}
        </output>
      </header>
      <div className="grid min-h-0 flex-1 grid-cols-[340px_1fr]">
        <PerfTickets tickets={tickets} now={nowDate} listRef={listRef} />
        <div ref={chatRef} className="min-h-0" data-testid="perf-messages">
          <PerfMessages messages={messages} />
        </div>
      </div>
    </div>
  )
}
