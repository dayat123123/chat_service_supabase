import { useVirtualizer } from '@tanstack/react-virtual'
import { ArrowDownIcon, LoaderCircleIcon } from 'lucide-react'
import { useCallback, useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'

import { EmptyState } from '@/components/states'
import { Button } from '@/components/ui/button'
import type { AgentNote } from '@/features/customer/types'

import { buildRows, type MessageRow } from '../rows'
import { isStaffMessage, type ChatMessage, type PendingMessage } from '../types'
import { MessageBubble, NoteMessage, PendingBubble, SystemMessage } from './message-bubble'

type Props = {
  messages: ChatMessage[]
  notes?: AgentNote[]
  pending: PendingMessage[]
  meId: string
  customerReadAt: string | null
  hasOlder: boolean
  loadingOlder: boolean
  onLoadOlder: () => void
  trustedHost: (host: string) => boolean
  onReply?: (message: ChatMessage) => void
  onResend: (pending: PendingMessage) => void
  onDiscard: (pending: PendingMessage) => void
}

const NEAR_BOTTOM = 96

export function MessageList({
  messages,
  notes,
  pending,
  meId,
  customerReadAt,
  hasOlder,
  loadingOlder,
  onLoadOlder,
  trustedHost,
  onReply,
  onResend,
  onDiscard,
}: Props) {
  const { t } = useTranslation()
  const rows = useMemo(() => buildRows(messages, pending, { notes }), [messages, pending, notes])
  const scrollRef = useRef<HTMLDivElement>(null)
  const atBottom = useRef(true)
  const anchor = useRef<{ key: string; delta: number; count: number } | null>(null)
  const lastKey = useRef<string | undefined>(undefined)
  const lastCount = useRef(0)
  const initialized = useRef(false)
  const [unseen, setUnseen] = useState(0)

  const virtualizer = useVirtualizer({
    count: rows.length,
    getScrollElement: () => scrollRef.current,
    estimateSize: (index) => (rows[index]?.kind === 'day' ? 36 : 64),
    overscan: 12,
    getItemKey: (index) => rows[index]?.key ?? index,
  })

  const scrollToEnd = useCallback(() => {
    if (rows.length === 0) return
    virtualizer.scrollToIndex(rows.length - 1, { align: 'end' })
    setUnseen(0)
  }, [rows.length, virtualizer])

  const requestOlder = useCallback(() => {
    const element = scrollRef.current
    if (!element || !hasOlder || loadingOlder || anchor.current) return
    const first = virtualizer.getVirtualItems().find((item) => item.end > element.scrollTop)
    const row = first ? rows[first.index] : undefined
    if (first && row)
      anchor.current = { key: row.key, delta: first.start - element.scrollTop, count: rows.length }
    onLoadOlder()
  }, [hasOlder, loadingOlder, onLoadOlder, rows, virtualizer])

  useLayoutEffect(() => {
    const saved = anchor.current
    if (!saved || rows.length === saved.count) return
    anchor.current = null
    const index = rows.findIndex((row) => row.key === saved.key)
    if (index < 0) return
    const offset = virtualizer.getOffsetForIndex(index, 'start')
    if (offset) virtualizer.scrollToOffset(offset[0] - saved.delta)
  }, [rows, virtualizer])

  useEffect(() => {
    if (!loadingOlder && anchor.current && rows.length === anchor.current.count && !hasOlder)
      anchor.current = null
  }, [loadingOlder, hasOlder, rows.length])

  useEffect(() => {
    const last = rows[rows.length - 1]
    if (!last) return
    if (!initialized.current) {
      initialized.current = true
      lastKey.current = last.key
      lastCount.current = rows.length
      requestAnimationFrame(() => virtualizer.scrollToIndex(rows.length - 1, { align: 'end' }))
      return
    }
    const newLast = last.key !== lastKey.current
    const grew = rows.length > lastCount.current
    lastKey.current = last.key
    lastCount.current = rows.length
    if (!newLast && !grew) return
    const ownMessage = last.kind === 'pending' || (last.kind === 'message' && last.message.sender_id === meId)
    if (atBottom.current || (newLast && ownMessage)) requestAnimationFrame(() => scrollToEnd())
    else if (newLast) setUnseen((count) => count + 1)
  }, [rows, meId, scrollToEnd, virtualizer])

  const onScroll = () => {
    const element = scrollRef.current
    if (!element) return
    atBottom.current = element.scrollHeight - element.scrollTop - element.clientHeight < NEAR_BOTTOM
    if (atBottom.current && unseen > 0) setUnseen(0)
    if (element.scrollTop < 240) requestOlder()
  }

  const renderRow = (row: MessageRow) => {
    if (row.kind === 'day') {
      return (
        <div className="flex items-center gap-3 px-(--pane-px) pt-4 pb-1">
          <span className="h-px flex-1 bg-border" />
          <span className="text-xs text-muted-foreground">{row.label}</span>
          <span className="h-px flex-1 bg-border" />
        </div>
      )
    }
    if (row.kind === 'note') return <NoteMessage note={row.note} />
    if (row.kind === 'pending') {
      return (
        <PendingBubble
          pending={row.pending}
          onResend={() => onResend(row.pending)}
          onDiscard={() => onDiscard(row.pending)}
        />
      )
    }
    const message = row.message
    if (message.kind === 'system' || message.kind === 'csat') return <SystemMessage message={message} />
    const staff = isStaffMessage(message)
    return (
      <MessageBubble
        message={message}
        staff={staff}
        first={row.first}
        last={row.last}
        read={staff && customerReadAt !== null && customerReadAt >= message.created_at}
        trustedHost={trustedHost}
        onReply={onReply}
      />
    )
  }

  return (
    <div className="relative min-h-0 flex-1">
      <div
        ref={scrollRef}
        onScroll={onScroll}
        className="h-full overflow-y-auto"
        role="log"
        aria-live="polite"
        aria-relevant="additions"
        tabIndex={0}
      >
        {loadingOlder ? (
          <div className="flex justify-center py-2 text-xs text-muted-foreground" role="status">
            <LoaderCircleIcon className="mr-1.5 size-3.5 animate-spin" />
            {t('conversation.loadOlder')}
          </div>
        ) : null}
        {rows.length === 0 ? (
          <EmptyState className="h-full" title={t('conversation.emptyHistory')} />
        ) : (
          <div style={{ height: virtualizer.getTotalSize() }} className="relative w-full">
            {virtualizer.getVirtualItems().map((item) => {
              const row = rows[item.index]
              if (!row) return null
              return (
                <div
                  key={item.key}
                  data-index={item.index}
                  ref={virtualizer.measureElement}
                  className="absolute top-0 left-0 w-full"
                  style={{ transform: `translateY(${item.start}px)` }}
                >
                  {renderRow(row)}
                </div>
              )
            })}
          </div>
        )}
      </div>
      {unseen > 0 ? (
        <Button
          size="sm"
          variant="outline"
          className="absolute bottom-3 left-1/2 -translate-x-1/2 shadow-float"
          onClick={scrollToEnd}
        >
          <ArrowDownIcon />
          {t('conversation.newMessages', { count: unseen })}
        </Button>
      ) : null}
    </div>
  )
}
