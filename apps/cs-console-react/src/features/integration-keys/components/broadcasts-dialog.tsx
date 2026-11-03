import { MegaphoneIcon } from 'lucide-react'
import { useTranslation } from 'react-i18next'

import { EngagementItems } from '@/components/engagement-stats'
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { QueryContent } from '@/features/settings/components/settings-ui'
import { ToneBadge } from '@/features/system/components/system-ui'
import { formatNumber, stamp } from '@/lib/time'

import { useKeyBroadcasts } from '../hooks'
import { broadcastTitle } from '../logic'
import {
  BROADCAST_LIMIT,
  type BroadcastStatus,
  type BroadcastTarget,
  type IntegrationBroadcast,
  type IntegrationKey,
} from '../types'

const statusTone: Record<BroadcastStatus, 'ok' | 'warn' | 'late' | 'neutral'> = {
  queued: 'neutral',
  sending: 'warn',
  done: 'ok',
  failed: 'late',
}

const counters = ['targeted', 'recipients', 'devices', 'inbox', 'capped', 'pref_skipped'] as const

function TargetText({ target }: { target: BroadcastTarget }) {
  const { t } = useTranslation()
  if (target.type === 'all') return <>{t('platform.keys.broadcasts.target.all')}</>
  if (target.type === 'stock_watchers')
    return <>{t('platform.keys.broadcasts.target.stock_watchers', { stock: target.stock })}</>
  return (
    <>
      {t('platform.keys.broadcasts.target.olt_user_ids', {
        count: target.count,
        value: formatNumber(target.count),
      })}
    </>
  )
}

function BroadcastItem({ item }: { item: IntegrationBroadcast }) {
  const { t, i18n } = useTranslation()
  const title = broadcastTitle(item.title, i18n.language === 'en' ? 'en' : 'id')
  return (
    <li className="flex flex-col gap-2 rounded-md border p-3">
      <div className="flex flex-wrap items-start justify-between gap-2">
        <div className="min-w-0">
          <p className={title ? 'font-medium break-words' : 'text-muted-foreground'}>
            {title || t('platform.keys.broadcasts.untitled')}
          </p>
          <p className="font-mono text-xs break-all text-muted-foreground">{item.message_id}</p>
        </div>
        <ToneBadge tone={statusTone[item.status]}>
          {t(`platform.keys.broadcasts.status.${item.status}`)}
        </ToneBadge>
      </div>
      <p className="flex flex-wrap gap-x-2 gap-y-0.5 text-xs text-muted-foreground">
        <span>{stamp(item.created_at)}</span>
        <span aria-hidden="true">·</span>
        <span>{t(`platform.keys.broadcasts.category.${item.category}`)}</span>
        <span aria-hidden="true">·</span>
        <span>
          {item.channels.map((channel) => t(`platform.keys.broadcasts.channels.${channel}`)).join(', ')}
        </span>
        <span aria-hidden="true">·</span>
        <span className="text-foreground">
          <TargetText target={item.target} />
        </span>
      </p>
      <dl className="grid grid-cols-2 gap-x-4 gap-y-1 text-xs sm:grid-cols-4">
        {counters.map((counter) => (
          <div key={counter} className="min-w-0">
            <dt className="truncate text-muted-foreground">
              {t(`platform.keys.broadcasts.counters.${counter}`)}
            </dt>
            <dd className="tabular font-medium">{formatNumber(item[counter])}</dd>
          </div>
        ))}
        <EngagementItems
          value={item}
          termClassName="truncate text-muted-foreground"
          valueClassName="font-medium"
        />
      </dl>
      {item.error ? (
        <p className="text-xs break-words text-destructive">
          {t('platform.keys.broadcasts.error', { error: item.error })}
        </p>
      ) : null}
    </li>
  )
}

function BroadcastList({ items }: { items: IntegrationBroadcast[] }) {
  const { t } = useTranslation()
  if (items.length === 0) {
    return (
      <p className="flex items-center justify-center gap-2 border-y py-6 text-row text-muted-foreground">
        <MegaphoneIcon className="size-4" aria-hidden="true" />
        {t('platform.keys.broadcasts.empty')}
      </p>
    )
  }
  return (
    <ul className="flex flex-col gap-2" aria-label={t('platform.keys.broadcasts.list')}>
      {items.map((item) => (
        <BroadcastItem key={item.id} item={item} />
      ))}
    </ul>
  )
}

function BroadcastsBody({ keyId }: { keyId: string }) {
  const broadcasts = useKeyBroadcasts(keyId)
  return <QueryContent query={broadcasts}>{(items) => <BroadcastList items={items} />}</QueryContent>
}

export function BroadcastsDialog({ item, onClose }: { item: IntegrationKey | null; onClose: () => void }) {
  const { t } = useTranslation()
  return (
    <Dialog open={item !== null} onOpenChange={(next) => !next && onClose()}>
      <DialogContent className="max-h-[92vh] overflow-y-auto sm:max-w-2xl" closeLabel={t('app.close')}>
        <DialogHeader>
          <DialogTitle>{t('platform.keys.broadcasts.title', { name: item?.name ?? '' })}</DialogTitle>
          <DialogDescription>
            {t('platform.keys.broadcasts.description', { max: BROADCAST_LIMIT })}
          </DialogDescription>
        </DialogHeader>
        {item ? <BroadcastsBody keyId={item.id} /> : null}
      </DialogContent>
    </Dialog>
  )
}
