import {
  CalendarClockIcon,
  MessageSquareTextIcon,
  MessagesSquareIcon,
  PlugZapIcon,
  SlidersHorizontalIcon,
  TagsIcon,
  UsersIcon,
} from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'

import { SectionBoundary } from '@/components/states'
import { cn } from '@/lib/utils'

import type { SettingsSection } from '../types'
import { AccountsSection } from './accounts-section'
import { AssignmentSection } from './assignment-section'
import { HoursSection } from './hours-section'
import { IntegrationSection } from './integration-section'
import { MessagesSection } from './messages-section'
import { QuickRepliesSection } from './quick-replies-section'
import { TopicsSection } from './topics-section'

const sections: { id: SettingsSection; icon: React.ComponentType<{ className?: string }> }[] = [
  { id: 'accounts', icon: UsersIcon },
  { id: 'topics', icon: TagsIcon },
  { id: 'quickReplies', icon: MessageSquareTextIcon },
  { id: 'hours', icon: CalendarClockIcon },
  { id: 'messages', icon: MessagesSquareIcon },
  { id: 'assignment', icon: SlidersHorizontalIcon },
  { id: 'integration', icon: PlugZapIcon },
]

const content: Record<SettingsSection, () => React.ReactNode> = {
  accounts: () => <AccountsSection />,
  topics: () => <TopicsSection />,
  quickReplies: () => <QuickRepliesSection />,
  hours: () => <HoursSection />,
  messages: () => <MessagesSection />,
  assignment: () => <AssignmentSection />,
  integration: () => <IntegrationSection />,
}

export function SettingsPage() {
  const { t } = useTranslation()
  const [section, setSection] = useState<SettingsSection>('accounts')
  return (
    <div className="flex h-full flex-col md:flex-row">
      <nav
        aria-label={t('settings.title')}
        className="flex shrink-0 gap-0.5 overflow-x-auto border-b bg-subtle p-2 md:w-56 md:flex-col md:overflow-x-visible md:border-r md:border-b-0 md:p-3"
      >
        <h1 className="hidden px-2.5 pt-1 pb-3 text-panel font-semibold md:block">{t('settings.title')}</h1>
        {sections.map((item) => (
          <button
            key={item.id}
            type="button"
            aria-current={section === item.id ? 'page' : undefined}
            onClick={() => setSection(item.id)}
            className={cn(
              'inline-flex h-8 shrink-0 items-center gap-2.5 rounded-md px-2.5 text-left text-row whitespace-nowrap text-muted-foreground transition-colors outline-none hover:bg-muted hover:text-foreground focus-visible:ring-2 focus-visible:ring-ring/50',
              section === item.id && 'bg-selected font-medium text-foreground',
            )}
          >
            <item.icon className="size-4" />
            {t(`settings.${item.id}`)}
          </button>
        ))}
      </nav>
      <div className="min-h-0 flex-1 overflow-y-auto">
        <SectionBoundary key={section} label={`settings:${section}`}>
          {content[section]()}
        </SectionBoundary>
      </div>
    </div>
  )
}
