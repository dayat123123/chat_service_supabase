import { useTranslation } from 'react-i18next'

import {
  contentActions,
  contentCategories,
  contentScopes,
  domainCategories,
  imageCategories,
} from '@/features/content-policy/types'
import { ToneBadge } from '@/features/system/components/system-ui'
import { cn } from '@/lib/utils'

import {
  diffEntries,
  hiddenItems,
  objectValue,
  percentText,
  scalarText,
  settingLabel,
  thresholdParts,
  windowsText,
} from '../logic'
import type { DiffItem, DiffOp, PolicyDiff, PolicySection } from '../types'

const opTones: Record<DiffOp, 'ok' | 'late' | 'warn'> = { added: 'ok', removed: 'late', changed: 'warn' }

const among = <T extends string>(list: readonly T[], value: unknown): value is T =>
  typeof value === 'string' && (list as readonly string[]).includes(value)

function useValueText() {
  const { t } = useTranslation()
  const action = (value: unknown) =>
    among(contentActions, value) ? t(`policy.actions.${value}`) : scalarText(value)
  return (section: PolicySection, key: string, value: unknown): string => {
    const object = objectValue(value)
    switch (section) {
      case 'banned_words':
        return value === 'mask' || value === 'block'
          ? t(`policy.versions.diff.wordActions.${value}`)
          : scalarText(value)
      case 'content_rules':
        return [
          action(object.action),
          among(contentScopes, object.scope) ? t(`policy.scopes.${object.scope}`) : null,
        ]
          .filter(Boolean)
          .join(', ')
      case 'blocked_domains':
        return [
          object.match === 'keyword' ? t('policy.versions.diff.keyword') : null,
          among(domainCategories, object.category) ? t(`policy.categories.${object.category}`) : null,
          object.action === undefined ? t('policy.domains.followsCategory') : action(object.action),
          typeof object.note === 'string' ? object.note : null,
        ]
          .filter(Boolean)
          .join(' · ')
      case 'allowed_domains':
        return typeof object.note === 'string' ? object.note : ''
      case 'allowlist':
      case 'promo_phrases':
        return ''
      case 'image_thresholds': {
        const parts = thresholdParts(value)
        return [
          parts.hold === null ? null : t('policy.versions.diff.hold', { value: parts.hold }),
          parts.block === null ? null : t('policy.versions.diff.block', { value: parts.block }),
        ]
          .filter(Boolean)
          .join(' · ')
      }
      case 'settings': {
        const label = settingLabel(key)
        if (label.kind === 'windows') return windowsText(value)
        if (typeof value === 'boolean')
          return value ? t('policy.versions.diff.on') : t('policy.versions.diff.off')
        if (label.kind === 'number' && label.percent) return percentText(value)
        return scalarText(value)
      }
    }
  }
}

function useKeyText() {
  const { t } = useTranslation()
  return (section: PolicySection, key: string): string => {
    if (section === 'content_rules' && among(contentCategories, key)) return t(`policy.categories.${key}`)
    if (section === 'image_thresholds' && among(imageCategories, key))
      return t(`policy.images.categories.${key}`)
    if (section !== 'settings') return key
    const label = settingLabel(key)
    switch (label.kind) {
      case 'number':
        return t(`policy.manipulation.fields.${label.id}`)
      case 'autoSlow':
        return t('policy.manipulation.fields.autoSlow')
      case 'autoHold':
        return t('policy.manipulation.fields.autoHold')
      case 'windows':
        return t('policy.manipulation.windows')
      case 'newAccount':
        return t('policy.newAccount.title')
      case 'raw':
        return key
    }
  }
}

function ItemRow({ section, item }: { section: PolicySection; item: DiffItem }) {
  const { t } = useTranslation()
  const valueText = useValueText()
  const keyText = useKeyText()
  const from = item.op === 'added' ? '' : valueText(section, item.key, item.from)
  const to = item.op === 'removed' ? '' : valueText(section, item.key, item.to)
  return (
    <li className="flex flex-wrap items-baseline gap-x-2 gap-y-0.5 text-row">
      <ToneBadge tone={opTones[item.op]}>{t(`policy.versions.diff.ops.${item.op}`)}</ToneBadge>
      <span className={cn('font-medium break-all', item.op === 'removed' && 'line-through decoration-1')}>
        {keyText(section, item.key)}
      </span>
      {item.op === 'changed' ? (
        <span className="text-muted-foreground">
          {from || '–'} → <span className="text-foreground">{to || '–'}</span>
        </span>
      ) : (to || from) !== '' ? (
        <span className="text-muted-foreground">{to || from}</span>
      ) : null}
    </li>
  )
}

export function DiffCounts({ diff }: { diff: PolicyDiff }) {
  const { t } = useTranslation()
  const entries = diffEntries(diff)
  if (entries.length === 0)
    return <span className="text-muted-foreground">{t('policy.versions.diff.none')}</span>
  return (
    <span className="inline-flex flex-wrap gap-x-3 gap-y-0.5">
      {entries.map((entry) => (
        <span key={entry.section} className="whitespace-nowrap">
          {t(`policy.versions.diff.sections.${entry.section}`)}{' '}
          <span className="tabular text-muted-foreground">
            {t('policy.versions.diff.counts', {
              added: entry.added,
              removed: entry.removed,
              changed: entry.changed,
            })}
          </span>
        </span>
      ))}
    </span>
  )
}

export function DiffView({ diff, label }: { diff: PolicyDiff; label?: string }) {
  const { t } = useTranslation()
  const entries = diffEntries(diff)
  if (entries.length === 0)
    return <p className="text-row text-muted-foreground">{t('policy.versions.diff.none')}</p>
  return (
    <div className="flex flex-col gap-3" aria-label={label ?? t('policy.versions.diff.label')} role="group">
      {entries.map((entry) => {
        const hidden = hiddenItems(entry)
        return (
          <section key={entry.section} className="flex flex-col gap-1.5">
            <h4 className="text-row font-medium">
              {t(`policy.versions.diff.sections.${entry.section}`)}{' '}
              <span className="tabular font-normal text-muted-foreground">
                {t('policy.versions.diff.counts', {
                  added: entry.added,
                  removed: entry.removed,
                  changed: entry.changed,
                })}
              </span>
            </h4>
            <ul className="flex flex-col gap-1">
              {entry.items.map((item) => (
                <ItemRow key={`${item.op}:${item.key}`} section={entry.section} item={item} />
              ))}
            </ul>
            {hidden > 0 ? (
              <p className="text-xs text-muted-foreground">
                {t('policy.versions.diff.more', { count: hidden })}
              </p>
            ) : null}
          </section>
        )
      })}
    </div>
  )
}
