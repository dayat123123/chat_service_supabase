import {
  BellRingIcon,
  CalendarClockIcon,
  FlagIcon,
  KeyRoundIcon,
  MegaphoneIcon,
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
import { useAgent } from '@/features/auth/hooks'
import { FeaturesSection } from '@/features/client-config/components/features-section'
import { IntegrationKeysSection } from '@/features/integration-keys/components/keys-section'
import { PushSection } from '@/features/push/components/push-section'
import { PushInactiveBadge } from '@/features/push/components/push-state'
import { cn } from '@/lib/utils'

import type { SettingsSection } from '../types'
import { AccountsSection } from './accounts-section'
import { AssignmentSection } from './assignment-section'
import { CommunitySection } from './community-section'
import { HoursSection } from './hours-section'
import { IntegrationBadge, IntegrationSection } from './integration-section'
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
  { id: 'community', icon: MegaphoneIcon },
  { id: 'push', icon: BellRingIcon },
  { id: 'integration', icon: PlugZapIcon },
  { id: 'apiKeys', icon: KeyRoundIcon },
  { id: 'features', icon: FlagIcon },
]

const content: Record<SettingsSection, () => React.ReactNode> = {
  accounts: () => <AccountsSection />,
  topics: () => <TopicsSection />,
  quickReplies: () => <QuickRepliesSection />,
  hours: () => <HoursSection />,
  messages: () => <MessagesSection />,
  assignment: () => <AssignmentSection />,
  community: () => <CommunitySection />,
  push: () => <PushSection />,
  integration: () => <IntegrationSection />,
  apiKeys: () => <IntegrationKeysSection />,
  features: () => <FeaturesSection />,
}

export function SettingsPage() {
  const { t } = useTranslation()
  const [section, setSection] = useState<SettingsSection>('accounts')
  const settings = useAgent().settings
  const badges: Partial<Record<SettingsSection, React.ReactNode>> = {
    integration: settings.nasabah_ready ? null : <IntegrationBadge configured={false} />,
    push: settings.community_push_ready ? null : <PushInactiveBadge />,
  }
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
              'inline-flex min-h-8 shrink-0 items-center gap-2.5 rounded-md px-2.5 py-1 text-left text-row whitespace-nowrap text-muted-foreground transition-colors outline-none hover:bg-muted hover:text-foreground focus-visible:ring-2 focus-visible:ring-ring/50',
              section === item.id && 'bg-selected font-medium text-foreground',
            )}
          >
            <item.icon className="size-4 shrink-0" />
            {badges[item.id] ? (
              <span className="flex flex-col items-start gap-1 md:py-0.5">
                {t(`settings.${item.id}`)} {badges[item.id]}
              </span>
            ) : (
              t(`settings.${item.id}`)
            )}
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
