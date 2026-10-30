import { useEffect, useRef } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { useTicketUi } from '@/features/tickets/hooks'
import type { Ticket } from '@/features/tickets/types'
import { browserNotify, pageInBackground, playSound, type AlertSound } from '@/lib/alerts'
import { usePreferences } from '@/lib/preferences'
import { realtime } from '@/lib/realtime'
import { minutesSince } from '@/lib/time'

type Alert = { sound: AlertSound; title: string; body: string; ticketId: string; always?: boolean }

export function useConsoleAlerts(options: { supervisor: boolean; onOpenTicket: (ticketId: string) => void }) {
  const { t } = useTranslation()
  const { supervisor, onOpenTicket } = options
  const openRef = useRef(onOpenTicket)
  useEffect(() => {
    openRef.current = onOpenTicket
  }, [onOpenTicket])

  useEffect(() => {
    const raise = (alert: Alert) => {
      playSound(alert.sound)
      if (alert.always || pageInBackground()) {
        browserNotify({
          title: alert.title,
          body: alert.body,
          tag: alert.ticketId,
          onClick: () => openRef.current(alert.ticketId),
        })
      }
    }
    return realtime.subscribe((event) => {
      if (event.type === 'ticket' && event.event === 'ticket_opened') {
        const mode = usePreferences.getState().ticketAlerts
        const urgent = event.priority === 'P1' || event.priority === 'P2'
        if (mode === 'off' || (mode === 'high' && !urgent)) return
        raise({
          sound: 'ticket',
          title: urgent ? t('notifications.newUrgentTicket') : t('notifications.newTicket'),
          body: [event.ticketNumber, event.priority].filter(Boolean).join(' · '),
          ticketId: event.ticketId,
        })
      } else if (event.type === 'message' && event.status !== 'open') {
        if (event.ticketId === useTicketUi.getState().selectedId && !pageInBackground()) return
        raise({
          sound: 'message',
          title: t('notifications.customerMessage'),
          body: t('notifications.openTicketHint'),
          ticketId: event.ticketId,
        })
      } else if (event.type === 'transfer') {
        if (event.event === 'transfer_requested') {
          raise({
            sound: 'ticket',
            title: t('notifications.transferRequest', { name: event.byName ?? '' }),
            body: event.ticketNumber ?? '',
            ticketId: event.ticketId,
            always: true,
          })
        } else if (event.event === 'transfer_rejected') {
          toast.warning(
            t('notifications.transferRejected', {
              ticket: event.ticketNumber ?? '',
              name: event.byName ?? '',
            }),
          )
        } else if (event.event === 'transfer_expired') {
          toast.warning(t('notifications.transferExpired', { ticket: event.ticketNumber ?? '' }))
        } else if (event.event === 'transfer_cancelled') {
          toast.warning(
            t('notifications.transferCancelled', {
              ticket: event.ticketNumber ?? '',
              reason: event.reason ?? '',
            }),
          )
        }
      } else if (event.type === 'alert' && supervisor) {
        raise({
          sound: 'ticket',
          title:
            event.event === 'fake_cs_reported' ? t('notifications.fakeCs') : t('notifications.secretRequest'),
          body: [event.ticketNumber, event.agentCode].filter(Boolean).join(' · '),
          ticketId: event.ticketId,
          always: true,
        })
      }
    })
  }, [supervisor, t])
}

export function useOverdueAlerts(overdue: Ticket[] | undefined, onOpenTicket: (ticketId: string) => void) {
  const { t } = useTranslation()
  const seen = useRef<Set<string> | null>(null)
  const openRef = useRef(onOpenTicket)
  useEffect(() => {
    openRef.current = onOpenTicket
  }, [onOpenTicket])

  useEffect(() => {
    if (!overdue) return
    const previous = seen.current
    seen.current = new Set(overdue.map((ticket) => ticket.id))
    const fresh = overdue.filter((ticket) => !previous?.has(ticket.id))
    if (fresh.length === 0) return
    playSound('ticket')
    const first = fresh[0]
    if (!first) return
    if (fresh.length > 3) {
      browserNotify({
        title: t('nav.attention', { count: fresh.length }),
        body: t('dashboard.title'),
        tag: 'overdue',
        onClick: () => openRef.current(first.id),
      })
      return
    }
    fresh.forEach((ticket) =>
      browserNotify({
        title: t('notifications.overdue', {
          priority: ticket.priority,
          minutes: minutesSince(ticket.queued_at ?? ticket.created_at),
        }),
        body: `#${ticket.ticket_number} · ${ticket.customer?.display_name ?? ''}`,
        tag: ticket.id,
        onClick: () => openRef.current(ticket.id),
      }),
    )
  }, [overdue, t])
}

export function useDocumentTitle(unread: number, appTitle: string) {
  useEffect(() => {
    document.title = unread > 0 ? `(${unread}) ${appTitle}` : appTitle
  }, [unread, appTitle])
}
