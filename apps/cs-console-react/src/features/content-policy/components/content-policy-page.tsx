import { useNavigate, useSearch } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'

import { SectionBoundary } from '@/components/states'
import { cn } from '@/lib/utils'

import { policyTabs, type PolicyTab } from '../types'
import { DomainsTab } from './domains-tab'
import { ImagesTab } from './images-tab'
import { ManipulationTab } from './manipulation-tab'
import { RulesTab } from './rules-tab'
import { TermsTab } from './terms-tab'
import { TesterTab } from './tester-tab'

const panels: Record<PolicyTab, () => React.ReactNode> = {
  rules: () => <RulesTab />,
  domains: () => <DomainsTab />,
  terms: () => <TermsTab />,
  images: () => <ImagesTab />,
  manipulation: () => <ManipulationTab />,
  tester: () => <TesterTab />,
}

export function ContentPolicyPage() {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const search: { tab?: PolicyTab } = useSearch({ strict: false })
  const tab = search.tab ?? 'rules'
  const go = (next: PolicyTab) => void navigate({ to: '/compliance/content', search: { tab: next } })
  return (
    <div className="h-full overflow-y-auto">
      <div className="mx-auto flex max-w-[1120px] flex-col gap-4 px-4 py-5 lg:px-6">
        <header>
          <h1 className="text-lg font-semibold">{t('policy.title')}</h1>
          <p className="max-w-3xl text-row text-muted-foreground">{t('policy.subtitle')}</p>
        </header>
        <div
          role="tablist"
          aria-label={t('policy.tabsLabel')}
          className="flex gap-4 overflow-x-auto border-b"
        >
          {policyTabs.map((item) => (
            <button
              key={item}
              id={`policy-tab-${item}`}
              type="button"
              role="tab"
              aria-selected={tab === item}
              aria-controls={`policy-panel-${item}`}
              tabIndex={tab === item ? 0 : -1}
              onKeyDown={(event) => {
                if (event.key !== 'ArrowRight' && event.key !== 'ArrowLeft') return
                const index = policyTabs.indexOf(item)
                const next =
                  policyTabs[
                    (index + (event.key === 'ArrowRight' ? 1 : policyTabs.length - 1)) % policyTabs.length
                  ]
                if (!next) return
                go(next)
                document.getElementById(`policy-tab-${next}`)?.focus()
              }}
              onClick={() => go(item)}
              className={cn(
                'relative inline-flex h-10 shrink-0 items-center text-row whitespace-nowrap transition-colors outline-none after:absolute after:inset-x-0 after:bottom-0 after:h-0.5 focus-visible:ring-2 focus-visible:ring-ring/50 focus-visible:ring-inset',
                tab === item
                  ? 'font-medium text-foreground after:bg-foreground'
                  : 'text-muted-foreground hover:text-foreground',
              )}
            >
              {t(`policy.tabs.${item}`)}
            </button>
          ))}
        </div>
        <div role="tabpanel" id={`policy-panel-${tab}`} aria-labelledby={`policy-tab-${tab}`}>
          <SectionBoundary key={tab} label={`policy:${tab}`}>
            {panels[tab]()}
          </SectionBoundary>
        </div>
      </div>
    </div>
  )
}
