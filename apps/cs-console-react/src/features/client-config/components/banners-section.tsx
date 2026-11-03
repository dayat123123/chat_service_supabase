import { PencilIcon, PlusIcon, Trash2Icon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { Button } from '@/components/ui/button'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { Confirm } from '@/features/nasabah/components/confirm'
import { QueryContent, SectionFrame, SettingsCard } from '@/features/settings/components/settings-ui'
import { ToneBadge } from '@/features/system/components/system-ui'
import { bannerErrorText } from '@/lib/error-text'
import { stamp } from '@/lib/time'

import { useBanners, useDeleteBanner } from '../hooks'
import type { AppBanner, BannerStatus } from '../types'
import { BannerDialog } from './banner-dialog'

const statusTone: Record<BannerStatus, 'ok' | 'warn' | 'neutral'> = {
  active: 'ok',
  scheduled: 'warn',
  ended: 'neutral',
}

function Audience({ banner }: { banner: AppBanner }) {
  const { t } = useTranslation()
  const versions = [
    banner.min_app_version ? t('platform.banners.versionFrom', { version: banner.min_app_version }) : null,
    banner.max_app_version ? t('platform.banners.versionUntil', { version: banner.max_app_version }) : null,
  ].filter(Boolean)
  return (
    <span className="text-xs">
      {banner.platforms.length === 0
        ? t('platform.banners.allPlatforms')
        : banner.platforms.map((item) => t(`platform.platforms.${item}`)).join(', ')}
      <span className="block text-muted-foreground">
        {versions.length > 0 ? versions.join(', ') : t('platform.banners.allVersions')}
      </span>
    </span>
  )
}

function BannersTable({ banners }: { banners: AppBanner[] }) {
  const { t } = useTranslation()
  const remove = useDeleteBanner()
  const [editing, setEditing] = useState<AppBanner | 'new' | null>(null)
  const [removing, setRemoving] = useState<AppBanner | null>(null)
  return (
    <SettingsCard title={t('platform.banners.title')} subtitle={t('platform.banners.subtitle')}>
      <Button size="sm" variant="outline" className="self-start" onClick={() => setEditing('new')}>
        <PlusIcon />
        {t('platform.banners.add')}
      </Button>
      {banners.length === 0 ? (
        <p className="border-y py-6 text-center text-row text-muted-foreground">
          {t('platform.banners.empty')}
        </p>
      ) : (
        <Table>
          <caption className="sr-only">{t('platform.banners.title')}</caption>
          <TableHeader>
            <TableRow>
              <TableHead>{t('platform.banners.cols.banner')}</TableHead>
              <TableHead>{t('platform.banners.cols.status')}</TableHead>
              <TableHead>{t('platform.banners.cols.schedule')}</TableHead>
              <TableHead>{t('platform.banners.cols.target')}</TableHead>
              <TableHead>{t('platform.banners.cols.priority')}</TableHead>
              <TableHead>{t('platform.banners.cols.updated')}</TableHead>
              <TableHead>
                <span className="sr-only">{t('platform.banners.cols.actions')}</span>
              </TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {banners.map((banner) => (
              <TableRow key={banner.id} className="align-top">
                <TableCell className="py-2 whitespace-normal">
                  <p className="text-row font-medium break-words">{banner.title}</p>
                  <p className="text-xs text-muted-foreground">
                    {[
                      t(`platform.banners.levels.${banner.level}`),
                      banner.dismissible ? null : t('platform.banners.notDismissible'),
                    ]
                      .filter(Boolean)
                      .join(' · ')}
                  </p>
                  {banner.body ? (
                    <p className="line-clamp-2 max-w-80 text-xs text-muted-foreground">{banner.body}</p>
                  ) : null}
                </TableCell>
                <TableCell className="py-2">
                  <ToneBadge tone={statusTone[banner.status]}>
                    {t(`platform.banners.status.${banner.status}`)}
                  </ToneBadge>
                </TableCell>
                <TableCell className="py-2 text-xs whitespace-normal">
                  <span className="block">
                    {t('platform.banners.from', { time: stamp(banner.starts_at) })}
                  </span>
                  <span className="block text-muted-foreground">
                    {banner.ends_at
                      ? t('platform.banners.until', { time: stamp(banner.ends_at) })
                      : t('platform.banners.noEnd')}
                  </span>
                </TableCell>
                <TableCell className="py-2 whitespace-normal">
                  <Audience banner={banner} />
                </TableCell>
                <TableCell className="tabular py-2 text-xs">{banner.priority}</TableCell>
                <TableCell className="py-2 text-xs whitespace-normal text-muted-foreground">
                  {stamp(banner.updated_at)}
                  {banner.updated_by?.name ? <span className="block">{banner.updated_by.name}</span> : null}
                </TableCell>
                <TableCell className="py-2">
                  <div className="flex justify-end gap-1">
                    <Button
                      size="icon-xs"
                      variant="ghost"
                      aria-label={t('platform.banners.editLabel', { title: banner.title })}
                      onClick={() => setEditing(banner)}
                    >
                      <PencilIcon />
                    </Button>
                    <Button
                      size="icon-xs"
                      variant="ghost"
                      aria-label={t('platform.banners.deleteLabel', { title: banner.title })}
                      onClick={() => setRemoving(banner)}
                    >
                      <Trash2Icon />
                    </Button>
                  </div>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      )}
      {editing ? (
        <BannerDialog editing={editing === 'new' ? null : editing} onClose={() => setEditing(null)} />
      ) : null}
      <Confirm
        open={removing !== null}
        title={t('platform.banners.deleteTitle', { title: removing?.title ?? '' })}
        body={t('platform.banners.deleteBody')}
        action={t('app.delete')}
        destructive
        pending={remove.isPending}
        onClose={() => setRemoving(null)}
        onConfirm={() =>
          removing &&
          remove
            .mutateAsync(removing.id)
            .then(() => {
              toast.success(t('platform.banners.deleted'))
              setRemoving(null)
            })
            .catch((error: unknown) => toast.error(bannerErrorText(error)))
        }
      />
    </SettingsCard>
  )
}

export function BannersSection() {
  const { t } = useTranslation()
  const banners = useBanners()
  return (
    <SectionFrame title={t('platform.banners.pageTitle')} description={t('platform.banners.pageDescription')}>
      <QueryContent query={banners}>{(data) => <BannersTable banners={data} />}</QueryContent>
    </SectionFrame>
  )
}
