import { useNavigate, useSearch } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'

import { SectionBoundary } from '@/components/states'
import { cn } from '@/lib/utils'

import { systemTabs, type SystemTab } from '../types'
import { AlertsTab } from './alerts-tab'
import { BackupTab } from './backup-tab'
import { StatusTab } from './status-tab'

const panels: Record<SystemTab, () => React.ReactNode> = {
  status: () => <StatusTab />,
  backup: () => <BackupTab />,
  alerts: () => <AlertsTab />,
}

export function SystemPage() {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const search: { tab?: SystemTab } = useSearch({ strict: false })
  const tab = search.tab ?? 'status'
  return (
    <div className="h-full overflow-y-auto">
      <div className="mx-auto flex max-w-[1200px] flex-col gap-4 px-4 py-5 lg:px-6">
        <header>
          <h1 className="text-lg font-semibold">{t('system.title')}</h1>
          <p className="max-w-3xl text-row text-muted-foreground">{t('system.subtitle')}</p>
        </header>
        <div
          role="tablist"
          aria-label={t('system.tabsLabel')}
          className="flex gap-4 overflow-x-auto border-b"
        >
          {systemTabs.map((item) => (
            <button
              key={item}
              id={`system-tab-${item}`}
              type="button"
              role="tab"
              aria-selected={tab === item}
              aria-controls={`system-panel-${item}`}
              tabIndex={tab === item ? 0 : -1}
              onKeyDown={(event) => {
                if (event.key !== 'ArrowRight' && event.key !== 'ArrowLeft') return
                const index = systemTabs.indexOf(item)
                const next =
                  systemTabs[
                    (index + (event.key === 'ArrowRight' ? 1 : systemTabs.length - 1)) % systemTabs.length
                  ]
                if (!next) return
                void navigate({ to: '/system', search: { tab: next } })
                document.getElementById(`system-tab-${next}`)?.focus()
              }}
              onClick={() => void navigate({ to: '/system', search: { tab: item } })}
              className={cn(
                'relative inline-flex h-10 shrink-0 items-center text-row whitespace-nowrap transition-colors outline-none after:absolute after:inset-x-0 after:bottom-0 after:h-0.5 focus-visible:ring-2 focus-visible:ring-ring/50 focus-visible:ring-inset',
                tab === item
                  ? 'font-medium text-foreground after:bg-foreground'
                  : 'text-muted-foreground hover:text-foreground',
              )}
            >
              {t(`system.tabs.${item}`)}
            </button>
          ))}
        </div>
        <div role="tabpanel" id={`system-panel-${tab}`} aria-labelledby={`system-tab-${tab}`}>
          <SectionBoundary key={tab} label={`system:${tab}`}>
            {panels[tab]()}
          </SectionBoundary>
        </div>
      </div>
    </div>
  )
}
