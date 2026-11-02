import { useNavigate, useSearch } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'

import { MetricStrip } from '@/components/metric-strip'
import { EmptyState } from '@/components/states'
import { useAgent } from '@/features/auth/hooks'
import { formatNumber } from '@/lib/time'
import { cn } from '@/lib/utils'

import { useCommunityOverview } from '../hooks'
import { communityTabsFor } from '../logic'
import type { CommunityTab } from '../types'
import { AccountsTab } from './accounts-tab'
import { CampaignsTab } from './campaigns-tab'
import { ModerationTab } from './moderation-tab'
import { StreamTab } from './stream-tab'

export function CommunityPage() {
  const { t } = useTranslation()
  const agent = useAgent()
  const navigate = useNavigate()
  const search: { tab?: CommunityTab } = useSearch({ strict: false })
  const overview = useCommunityOverview()
  const tabs = communityTabsFor(agent.community_permissions)
  const tab = search.tab && tabs.includes(search.tab) ? search.tab : tabs[0]
  const data = overview.data

  if (!tab) return <EmptyState className="h-full" title={t('community.noAccess')} />

  return (
    <div className="h-full overflow-y-auto">
      <div className="mx-auto flex max-w-[1200px] flex-col gap-4 px-4 py-5 lg:px-6">
        <header>
          <h1 className="text-lg font-semibold">{t('community.pageTitle')}</h1>
          <p className="text-row text-muted-foreground">{t('community.pageSubtitle')}</p>
        </header>
        <MetricStrip
          className="md:grid-cols-4 xl:grid-cols-4"
          metrics={[
            {
              label: t('community.metrics.pendingPosts'),
              value: data ? formatNumber(data.pending_posts) : '–',
              tone: data && data.pending_posts > 0 ? 'warn' : undefined,
            },
            {
              label: t('community.metrics.scheduled'),
              value: data ? formatNumber(data.scheduled_posts) : '–',
            },
            {
              label: t('community.metrics.pendingCampaigns'),
              value: data ? formatNumber(data.pending_campaigns) : '–',
              tone: data && data.pending_campaigns > 0 ? 'warn' : undefined,
            },
            {
              label: t('community.metrics.openReports'),
              value: data ? formatNumber(data.open_reports) : '–',
              tone: data && data.open_reports > 0 ? 'late' : undefined,
            },
          ]}
        />
        <div
          role="tablist"
          aria-label={t('community.tabsLabel')}
          className="flex gap-4 overflow-x-auto border-b"
        >
          {tabs.map((item) => (
            <button
              key={item}
              id={`community-tab-${item}`}
              type="button"
              role="tab"
              aria-selected={tab === item}
              aria-controls={`community-panel-${item}`}
              onClick={() => void navigate({ to: '/community', search: { tab: item } })}
              className={cn(
                'relative inline-flex h-10 shrink-0 items-center text-row whitespace-nowrap transition-colors outline-none after:absolute after:inset-x-0 after:bottom-0 after:h-0.5 focus-visible:ring-2 focus-visible:ring-ring/50 focus-visible:ring-inset',
                tab === item
                  ? 'font-medium text-foreground after:bg-foreground'
                  : 'text-muted-foreground hover:text-foreground',
              )}
            >
              {t(`community.tabs.${item}`)}
            </button>
          ))}
        </div>
        <div role="tabpanel" id={`community-panel-${tab}`} aria-labelledby={`community-tab-${tab}`}>
          {tab === 'stream' ? <StreamTab /> : null}
          {tab === 'notifications' ? <CampaignsTab /> : null}
          {tab === 'moderation' ? <ModerationTab /> : null}
          {tab === 'accounts' ? <AccountsTab /> : null}
        </div>
      </div>
    </div>
  )
}
