import { useState } from 'react'
import { useTranslation } from 'react-i18next'

import { EmptyState } from '@/components/states'
import { useAgent } from '@/features/auth/hooks'
import { cn } from '@/lib/utils'

import { useFreshPermissions } from '../hooks'
import { nasabahTabs, type NasabahTab } from '../logic'
import { ApprovalsTab } from './approvals-tab'
import { NasabahSummary } from './nasabah-summary'
import { OpeningTab } from './opening-tab'
import { UsersTab } from './users-tab'

export function NasabahPage() {
  const { t } = useTranslation()
  const agent = useAgent()
  useFreshPermissions()
  const tabs = nasabahTabs(agent.nasabah_permissions)
  const [chosen, setChosen] = useState<NasabahTab | null>(null)
  const tab = chosen && tabs.includes(chosen) ? chosen : tabs[0]

  if (!tab) return <EmptyState className="h-full" title={t('nasabah.noAccess')} />

  return (
    <div className="h-full overflow-y-auto">
      <div className="mx-auto flex max-w-[1440px] flex-col gap-4 px-4 py-5 lg:px-6">
        <header>
          <h1 className="text-lg font-semibold">{t('nasabah.title')}</h1>
          <p className="text-row text-muted-foreground">{t('nasabah.subtitle')}</p>
        </header>
        <NasabahSummary tabs={tabs} />
        <div
          role="tablist"
          aria-label={t('nasabah.tabsLabel')}
          className="flex gap-4 overflow-x-auto border-b"
        >
          {tabs.map((item) => (
            <button
              key={item}
              id={`nasabah-tab-${item}`}
              type="button"
              role="tab"
              aria-selected={tab === item}
              aria-controls={`nasabah-panel-${item}`}
              onClick={() => setChosen(item)}
              className={cn(
                'relative inline-flex h-10 shrink-0 items-center text-row whitespace-nowrap transition-colors outline-none after:absolute after:inset-x-0 after:bottom-0 after:h-0.5 focus-visible:ring-2 focus-visible:ring-ring/50 focus-visible:ring-inset',
                tab === item
                  ? 'font-medium text-foreground after:bg-foreground'
                  : 'text-muted-foreground hover:text-foreground',
              )}
            >
              {t(`nasabah.tabs.${item}`)}
            </button>
          ))}
        </div>
        <div role="tabpanel" id={`nasabah-panel-${tab}`} aria-labelledby={`nasabah-tab-${tab}`}>
          {tab === 'users' ? <UsersTab /> : null}
          {tab === 'approvals' ? <ApprovalsTab /> : null}
          {tab === 'opening' ? <OpeningTab /> : null}
        </div>
      </div>
    </div>
  )
}
