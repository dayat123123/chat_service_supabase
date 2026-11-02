import { BadgeCheckIcon, CameraIcon, LoaderCircleIcon, PlusIcon, SearchIcon } from 'lucide-react'
import { useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { EmptyState, ErrorState, ListSkeleton } from '@/components/states'
import { Button } from '@/components/ui/button'
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Avatar } from '@/components/ui/primitives'
import { Textarea } from '@/components/ui/textarea'
import { Confirm } from '@/features/nasabah/components/confirm'
import { useDebounced } from '@/hooks/use-now'
import { errorText } from '@/lib/error-text'
import { formatNumber, stamp } from '@/lib/time'

import { communityApi } from '../api'
import {
  useFindUsers,
  useOfficialAccounts,
  useSaveAccount,
  useSetAccountDisabled,
  useSetVerified,
} from '../hooks'
import type { CommunityUserRow, OfficialAccount } from '../types'
import { AccountAvatar, OfficialBadge, ReasonDialog } from './shared'

const usernamePattern = /^[A-Za-z0-9_]{3,30}$/
const avatarTypes = ['image/jpeg', 'image/png', 'image/webp']

function AccountDialog({ account, onClose }: { account: OfficialAccount | null; onClose: () => void }) {
  const { t } = useTranslation()
  const save = useSaveAccount()
  const [username, setUsername] = useState(account?.username ?? '')
  const [name, setName] = useState(account?.display_name ?? '')
  const [bio, setBio] = useState(account?.bio ?? '')
  const [avatar, setAvatar] = useState(account?.avatar_url ?? null)
  const [uploading, setUploading] = useState(false)
  const [touched, setTouched] = useState(false)
  const fileInput = useRef<HTMLInputElement>(null)
  const errors = {
    username: usernamePattern.test(username.trim()) ? undefined : t('community.errors.username'),
    name: name.trim().length >= 2 && name.trim().length <= 60 ? undefined : t('community.errors.accountName'),
  }
  const valid = !errors.username && !errors.name
  const pending = save.isPending || uploading

  const upload = async (file: File | undefined) => {
    if (!file || !account) return
    if (!avatarTypes.includes(file.type)) {
      toast.error(t('composer.badType', { name: file.name }))
      return
    }
    setUploading(true)
    try {
      setAvatar(await communityApi.uploadAvatar(account.id, file))
    } catch (error) {
      toast.error(errorText(error))
    } finally {
      setUploading(false)
    }
  }

  return (
    <Dialog open onOpenChange={(next) => !next && !pending && onClose()}>
      <DialogContent className="sm:max-w-md" closeLabel={t('app.close')}>
        <DialogHeader>
          <DialogTitle>{account ? t('community.editAccount') : t('community.newAccount')}</DialogTitle>
        </DialogHeader>
        <form
          className="flex flex-col gap-4"
          noValidate
          onSubmit={(event) => {
            event.preventDefault()
            setTouched(true)
            if (!valid) return
            void save
              .mutateAsync({
                id: account?.id ?? null,
                values: {
                  username: username.trim(),
                  display_name: name.trim(),
                  bio: bio.trim() || null,
                  avatar_url: account ? avatar : null,
                },
              })
              .then(() => {
                toast.success(t('community.accountSaved'))
                onClose()
              })
              .catch((error: unknown) => toast.error(errorText(error)))
          }}
        >
          {account ? (
            <div className="flex items-center gap-3">
              <AccountAvatar account={{ ...account, avatar_url: avatar }} className="size-14 text-sm" />
              <Button
                type="button"
                variant="outline"
                size="sm"
                disabled={pending}
                onClick={() => fileInput.current?.click()}
              >
                {uploading ? <LoaderCircleIcon className="animate-spin" /> : <CameraIcon />}
                {t('community.changePhoto')}
              </Button>
              <input
                ref={fileInput}
                type="file"
                hidden
                accept={avatarTypes.join(',')}
                onChange={(event) => {
                  void upload(event.target.files?.[0])
                  event.target.value = ''
                }}
              />
            </div>
          ) : (
            <p className="text-xs text-muted-foreground">{t('community.photoAfterCreate')}</p>
          )}
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="official-name">{t('community.accountName')}</Label>
            <Input
              id="official-name"
              maxLength={60}
              value={name}
              aria-invalid={touched && errors.name ? true : undefined}
              onChange={(event) => setName(event.target.value)}
            />
            {touched && errors.name ? <p className="text-xs text-destructive">{errors.name}</p> : null}
          </div>
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="official-username">{t('community.username')}</Label>
            <Input
              id="official-username"
              maxLength={30}
              value={username}
              aria-invalid={touched && errors.username ? true : undefined}
              onChange={(event) => setUsername(event.target.value)}
            />
            {touched && errors.username ? (
              <p className="text-xs text-destructive">{errors.username}</p>
            ) : (
              <p className="text-xs text-muted-foreground">{t('community.usernameHint')}</p>
            )}
          </div>
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="official-bio">{t('community.bio')}</Label>
            <Textarea
              id="official-bio"
              rows={3}
              maxLength={300}
              value={bio}
              onChange={(event) => setBio(event.target.value)}
            />
          </div>
          <DialogFooter>
            <Button type="button" variant="outline" disabled={pending} onClick={onClose}>
              {t('app.cancel')}
            </Button>
            <Button type="submit" disabled={pending}>
              {save.isPending ? <LoaderCircleIcon className="animate-spin" /> : null}
              {t('app.save')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

function VerifySection() {
  const { t } = useTranslation()
  const [query, setQuery] = useState('')
  const search = useDebounced(query, 300)
  const users = useFindUsers(search)
  const verify = useSetVerified()
  const [target, setTarget] = useState<CommunityUserRow | null>(null)
  const rows = (users.data ?? []).filter((user) => !user.is_official)
  return (
    <section className="flex flex-col gap-3" aria-labelledby="verify-title">
      <div>
        <h2 id="verify-title" className="text-panel font-semibold">
          {t('community.verifyTitle')}
        </h2>
        <p className="text-row text-muted-foreground">{t('community.verifyHint')}</p>
      </div>
      <div className="relative w-full sm:w-80">
        <SearchIcon className="pointer-events-none absolute top-2 left-2.5 size-4 text-muted-foreground" />
        <Input
          type="search"
          value={query}
          maxLength={60}
          placeholder={t('community.findUserPlaceholder')}
          aria-label={t('community.verifySearch')}
          className="h-8 pl-8"
          onChange={(event) => setQuery(event.target.value)}
        />
      </div>
      {search.trim().length >= 2 ? (
        rows.length === 0 && users.data ? (
          <p className="text-row text-muted-foreground">{t('community.noUsers')}</p>
        ) : (
          <ul className="border-t">
            {rows.map((user) => (
              <li key={user.id} className="flex items-center gap-2 border-b px-1 py-2">
                <Avatar name={user.display_name ?? user.username} />
                <span className="min-w-0 flex-1">
                  <span className="flex items-center gap-1 truncate text-row font-medium">
                    {user.display_name ?? user.username}
                    {user.is_verified ? (
                      <BadgeCheckIcon className="size-4 text-primary" aria-label={t('community.verified')} />
                    ) : null}
                  </span>
                  <span className="block truncate font-mono text-xs text-muted-foreground">
                    @{user.username}
                  </span>
                </span>
                <Button
                  size="xs"
                  variant={user.is_verified ? 'ghost' : 'outline'}
                  onClick={() => setTarget(user)}
                >
                  {user.is_verified ? t('community.unverify') : t('community.verify')}
                </Button>
              </li>
            ))}
          </ul>
        )
      ) : null}
      <ReasonDialog
        key={target?.id ?? 'none'}
        open={target !== null}
        title={
          target
            ? t(target.is_verified ? 'community.unverifyTitle' : 'community.verifyUserTitle', {
                name: target.display_name ?? target.username,
              })
            : ''
        }
        label={t('community.reason')}
        action={target?.is_verified ? t('community.unverify') : t('community.verify')}
        pending={verify.isPending}
        onClose={() => setTarget(null)}
        onSubmit={(reason) => {
          if (!target) return
          void verify
            .mutateAsync({ id: target.id, verified: !target.is_verified, reason })
            .then(() => {
              setTarget(null)
              toast.success(t('community.verifySaved'))
            })
            .catch((error: unknown) => toast.error(errorText(error)))
        }}
      />
    </section>
  )
}

export function AccountsTab() {
  const { t } = useTranslation()
  const accounts = useOfficialAccounts()
  const toggle = useSetAccountDisabled()
  const [editing, setEditing] = useState<OfficialAccount | null>(null)
  const [creating, setCreating] = useState(false)
  const [disabling, setDisabling] = useState<OfficialAccount | null>(null)
  return (
    <div className="flex flex-col gap-8">
      <section className="flex flex-col gap-3" aria-labelledby="official-title">
        <div className="flex flex-wrap items-end justify-between gap-3">
          <div>
            <h2 id="official-title" className="text-panel font-semibold">
              {t('community.officialAccounts')}
            </h2>
            <p className="text-row text-muted-foreground">{t('community.officialHint')}</p>
          </div>
          <Button size="sm" onClick={() => setCreating(true)}>
            <PlusIcon />
            {t('community.newAccount')}
          </Button>
        </div>
        {accounts.isError ? (
          <ErrorState error={accounts.error} onRetry={() => void accounts.refetch()} />
        ) : !accounts.data ? (
          <ListSkeleton rows={3} />
        ) : accounts.data.length === 0 ? (
          <EmptyState title={t('community.noAccounts')} />
        ) : (
          <ul className="border-t">
            {accounts.data.map((account) => (
              <li key={account.id} className="flex flex-wrap items-center gap-3 border-b px-1 py-3">
                <AccountAvatar account={account} className="size-10" />
                <div className="min-w-0 flex-1">
                  <p className="flex items-center gap-1.5 truncate text-row font-medium">
                    {account.display_name ?? account.username}
                    <OfficialBadge />
                    {account.disabled_at ? (
                      <span className="text-xs font-normal text-warning">{t('community.disabled')}</span>
                    ) : null}
                  </p>
                  <p className="truncate text-xs text-muted-foreground">
                    {[
                      `@${account.username}`,
                      t('community.followers', {
                        count: account.follower_count,
                        formatted: formatNumber(account.follower_count),
                      }),
                      t('community.postsCount', {
                        count: account.post_count,
                        formatted: formatNumber(account.post_count),
                      }),
                      account.created_by
                        ? t('community.createdBy', {
                            name: account.created_by,
                            time: stamp(account.created_at),
                          })
                        : null,
                    ]
                      .filter(Boolean)
                      .join(' · ')}
                  </p>
                  {account.bio ? <p className="mt-0.5 text-xs text-muted-foreground">{account.bio}</p> : null}
                </div>
                <div className="flex gap-1.5">
                  <Button size="xs" variant="outline" onClick={() => setEditing(account)}>
                    {t('app.edit')}
                  </Button>
                  {account.disabled_at ? (
                    <Button
                      size="xs"
                      variant="ghost"
                      disabled={toggle.isPending}
                      onClick={() =>
                        void toggle
                          .mutateAsync({ id: account.id, disabled: false })
                          .then(() => toast.success(t('community.accountEnabled')))
                          .catch((error: unknown) => toast.error(errorText(error)))
                      }
                    >
                      {t('community.enable')}
                    </Button>
                  ) : (
                    <Button
                      size="xs"
                      variant="ghost"
                      className="text-destructive"
                      onClick={() => setDisabling(account)}
                    >
                      {t('community.disable')}
                    </Button>
                  )}
                </div>
              </li>
            ))}
          </ul>
        )}
      </section>
      <VerifySection />
      {creating ? <AccountDialog account={null} onClose={() => setCreating(false)} /> : null}
      {editing ? <AccountDialog key={editing.id} account={editing} onClose={() => setEditing(null)} /> : null}
      <Confirm
        open={disabling !== null}
        title={t('community.disableTitle', { name: disabling?.display_name ?? '' })}
        body={t('community.disableBody')}
        action={t('community.disable')}
        pending={toggle.isPending}
        destructive
        onConfirm={() => {
          if (!disabling) return
          void toggle
            .mutateAsync({ id: disabling.id, disabled: true })
            .then(() => {
              setDisabling(null)
              toast.success(t('community.accountDisabled'))
            })
            .catch((error: unknown) => toast.error(errorText(error)))
        }}
        onClose={() => setDisabling(null)}
      />
    </div>
  )
}
