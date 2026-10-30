import { MessagesSquareIcon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Group, Panel, Separator, useDefaultLayout } from 'react-resizable-panels'

import { EmptyState, SectionBoundary } from '@/components/states'
import { Sheet, SheetContent } from '@/components/ui/overlay'
import { ConversationPane } from '@/features/conversation/components/conversation-pane'
import { CustomerPanel } from '@/features/customer/components/customer-panel'
import { useMediaQuery } from '@/hooks/use-now'
import { usePreferences } from '@/lib/preferences'

import { useTicketDetail, useTicketUi } from '../hooks'
import { TicketColumn } from './ticket-column'

function CustomerColumn({ ticketId }: { ticketId: string }) {
  const detail = useTicketDetail(ticketId)
  if (!detail.data) return null
  return (
    <SectionBoundary label="customer">
      <CustomerPanel key={ticketId} ticket={detail.data} />
    </SectionBoundary>
  )
}

function ResizeHandle() {
  return (
    <Separator className="relative w-px bg-border transition-colors outline-none after:absolute after:inset-y-0 after:-left-1 after:w-3 hover:bg-primary/60 focus-visible:bg-primary data-[separator=active]:bg-primary" />
  )
}

export function TicketsPage() {
  const { t } = useTranslation()
  const wide = useMediaQuery('(min-width: 1280px)')
  const medium = useMediaQuery('(min-width: 900px)')
  const selectedId = useTicketUi((state) => state.selectedId)
  const select = useTicketUi((state) => state.select)
  const infoOpen = usePreferences((state) => state.infoPanelOpen)
  const setInfoOpen = usePreferences((state) => state.setInfoPanelOpen)
  const [sheetOpen, setSheetOpen] = useState(false)
  const showColumn = wide && infoOpen && selectedId !== null
  const layout = useDefaultLayout({
    id: 'cs-console.tickets-layout',
    storage: window.localStorage,
    panelIds: showColumn ? ['tickets', 'conversation', 'customer'] : ['tickets', 'conversation'],
  })
  const toggleInfo = () => (wide ? setInfoOpen(!infoOpen) : setSheetOpen((open) => !open))

  const conversation = selectedId ? (
    <SectionBoundary label="conversation">
      <ConversationPane
        key={selectedId}
        ticketId={selectedId}
        infoOpen={wide ? infoOpen : sheetOpen}
        onToggleInfo={toggleInfo}
        onBack={medium ? undefined : () => select(null)}
      />
    </SectionBoundary>
  ) : (
    <EmptyState
      icon={MessagesSquareIcon}
      className="h-full bg-background"
      title={t('tickets.selectTicket')}
    />
  )

  const sheet =
    !wide && selectedId ? (
      <Sheet open={sheetOpen} onOpenChange={setSheetOpen}>
        <SheetContent title={t('customer.title')} closeLabel={t('app.close')} className="p-0">
          <CustomerColumn ticketId={selectedId} />
        </SheetContent>
      </Sheet>
    ) : null

  if (!medium) {
    return (
      <div className="h-full">
        {selectedId ? (
          conversation
        ) : (
          <SectionBoundary label="tickets">
            <TicketColumn />
          </SectionBoundary>
        )}
        {sheet}
      </div>
    )
  }

  return (
    <>
      <Group
        orientation="horizontal"
        className="h-full"
        defaultLayout={layout.defaultLayout}
        onLayoutChanged={layout.onLayoutChanged}
      >
        <Panel id="tickets" defaultSize="340px" minSize="280px" maxSize="560px">
          <SectionBoundary label="tickets">
            <TicketColumn />
          </SectionBoundary>
        </Panel>
        <ResizeHandle />
        <Panel id="conversation" minSize="420px">
          {conversation}
        </Panel>
        {showColumn ? (
          <>
            <ResizeHandle />
            <Panel id="customer" defaultSize="340px" minSize="280px" maxSize="560px">
              <CustomerColumn ticketId={selectedId} />
            </Panel>
          </>
        ) : null}
      </Group>
      {sheet}
    </>
  )
}
