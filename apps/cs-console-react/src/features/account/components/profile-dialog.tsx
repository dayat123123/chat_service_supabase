import { InfoIcon } from 'lucide-react'
import type { ReactNode } from 'react'
import { useTranslation } from 'react-i18next'

import { ErrorState, ListSkeleton } from '@/components/states'
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { communityPermissions, type CommunityPermission } from '@/features/community/types'
import { nasabahPermissions, type NasabahPermission } from '@/features/nasabah/types'
import { isStaffRole } from '@/features/settings/types'
import { format, shortDate } from '@/lib/time'

import { useMyProfile } from '../hooks'
import { teamLabel } from '../logic'
import type { MyProfile } from '../types'

const isCommunityPermission = (value: string): value is CommunityPermission =>
  (communityPermissions as readonly string[]).includes(value)

const isNasabahPermission = (value: string): value is NasabahPermission =>
  (nasabahPermissions as readonly string[]).includes(value)

function Row({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="grid gap-0.5 py-2 sm:grid-cols-[180px_1fr] sm:gap-3">
      <dt className="text-xs text-muted-foreground sm:text-row">{label}</dt>
      <dd className="min-w-0 text-row break-words">{children}</dd>
    </div>
  )
}

function List({ items, empty }: { items: string[]; empty: string }) {
  if (items.length === 0) return <span className="text-muted-foreground">{empty}</span>
  return (
    <ul className="flex flex-col gap-0.5">
      {items.map((item) => (
        <li key={item}>{item}</li>
      ))}
    </ul>
  )
}

function ProfileDetails({ profile }: { profile: MyProfile }) {
  const { t, i18n } = useTranslation()
  const roles = profile.roles.filter(isStaffRole).map((role) => t(`roles.${role}`))
  const community = profile.community_permissions
    .filter(isCommunityPermission)
    .map((code) => t(`community.permissions.${code}`))
  const nasabah = profile.nasabah_permissions
    .filter(isNasabahPermission)
    .map((code) => t(`nasabah.permissions.${code.replace('.', '_') as 'online_user_view'}`))
  const languages = profile.languages.map((code) =>
    code === 'en' || code === 'id' ? t(`account.languageNames.${code}`) : code,
  )
  const none = t('account.profile.noPermissions')
  return (
    <dl className="divide-y">
      <Row label={t('account.profile.email')}>{profile.email ?? t('app.none')}</Row>
      <Row label={t('account.profile.displayName')}>{profile.display_name}</Row>
      <Row label={t('account.profile.agentCode')}>
        <span className="tabular">{profile.agent_code}</span>
      </Row>
      <Row label={t('account.profile.roles')}>{roles.length > 0 ? roles.join(' · ') : none}</Row>
      <Row label={t('account.profile.team')}>
        {teamLabel(profile, i18n.language) ?? t('account.profile.noTeam')}
      </Row>
      <Row label={t('account.profile.maxTickets')}>
        {t('account.profile.maxTicketsValue', { count: profile.max_active_tickets })}
      </Row>
      <Row label={t('account.profile.languages')}>{languages.join(', ') || none}</Row>
      <Row label={t('account.profile.communityPermissions')}>
        <List items={community} empty={none} />
      </Row>
      <Row label={t('account.profile.nasabahPermissions')}>
        <List items={nasabah} empty={none} />
      </Row>
      <Row label={t('account.profile.createdAt')}>
        {profile.created_at ? shortDate(profile.created_at) : t('app.none')}
      </Row>
      <Row label={t('account.profile.passwordChangedAt')}>
        {profile.password_changed_at
          ? `${format(profile.password_changed_at, 'd MMM yyyy, HH.mm')} WIB`
          : t('account.profile.passwordUnknown')}
      </Row>
    </dl>
  )
}

export function ProfileDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const { t } = useTranslation()
  const profile = useMyProfile()
  return (
    <Dialog open={open} onOpenChange={(next) => !next && onClose()}>
      <DialogContent closeLabel={t('app.close')} className="sm:max-w-[560px]">
        <DialogHeader>
          <DialogTitle>{t('account.profile.title')}</DialogTitle>
          <DialogDescription>{t('account.profile.subtitle')}</DialogDescription>
        </DialogHeader>
        {profile.data ? (
          <ProfileDetails profile={profile.data} />
        ) : profile.error ? (
          <ErrorState error={profile.error} onRetry={() => void profile.refetch()} />
        ) : (
          <ListSkeleton rows={6} />
        )}
        <p className="flex items-start gap-2 rounded-md bg-muted px-3 py-2 text-row text-muted-foreground">
          <InfoIcon className="mt-0.5 size-4 shrink-0" aria-hidden="true" />
          {t('account.profile.contactAdmin')}
        </p>
      </DialogContent>
    </Dialog>
  )
}
