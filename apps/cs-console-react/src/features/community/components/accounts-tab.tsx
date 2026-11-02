import {
  BadgeCheckIcon,
  CameraIcon,
  LoaderCircleIcon,
  PlusIcon,
  SearchIcon,
  Trash2Icon,
  Undo2Icon,
} from 'lucide-react'
import { useEffect, useRef, useState } from 'react'
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
import { appEnv } from '@/lib/supabase'
import { formatNumber, stamp } from '@/lib/time'
import { cn, initials } from '@/lib/utils'

import { communityApi } from '../api'
import { avatarTypes, MAX_PHOTO_BYTES } from '../avatar-crop'
import {
  useFindUsers,
  useOfficialAccounts,
  useSaveAccount,
  useSetAccountDisabled,
  useSetVerified,
} from '../hooks'
import { staffMediaUrl } from '../logic'
import type { CommunityUserRow, OfficialAccount } from '../types'
import { AvatarCropper } from './avatar-cropper'
import { AccountAvatar, OfficialBadge, ReasonDialog } from './shared'

const usernamePattern = /^[A-Za-z0-9_]{3,30}$/
const NAME_MAX = 60
const BIO_MAX = 300

type Photo = { kind: 'keep' } | { kind: 'remove' } | { kind: 'new'; blob: Blob; preview: string }

function PreviewAvatar({ src, name, className }: { src: string | null; name: string; className?: string }) {
  const [failed, setFailed] = useState<string | null>(null)
  return src && failed !== src ? (
    <img
      src={src}
      alt=""
      onError={() => setFailed(src)}
      className={cn('shrink-0 rounded-full border object-cover', className)}
    />
  ) : (
    <span
      aria-hidden="true"
      className={cn(
        'inline-flex shrink-0 items-center justify-center rounded-full bg-primary/10 font-medium text-primary',
        className,
      )}
    >
      {initials(name || '?')}
    </span>
  )
}

function ProfilePreview({
  name,
  username,
  bio,
  avatar,
  followers,
  posts,
}: {
  name: string
  username: string
  bio: string
  avatar: string | null
  followers: number
  posts: number
}) {
  const { t } = useTranslation()
  return (
    <figure className="flex flex-col gap-1.5" aria-label={t('community.profilePreview')}>
      <figcaption className="text-xs text-muted-foreground">{t('community.profilePreview')}</figcaption>
      <div className="flex flex-col items-center gap-1.5 rounded-xl border bg-subtle px-4 py-5 text-center">
        <PreviewAvatar src={avatar} name={name} className="size-16 text-lg" />
        <p className="mt-1 flex max-w-full items-center gap-1.5 font-semibold">
          <span className="truncate">{name || t('community.accountName')}</span>
          <OfficialBadge />
        </p>
        <p className="max-w-full truncate font-mono text-xs text-muted-foreground">
          @{username || 'username'}
        </p>
        <p className="text-xs text-muted-foreground">
          {[
            t('community.followers', { count: followers, formatted: formatNumber(followers) }),
            t('community.postsCount', { count: posts, formatted: formatNumber(posts) }),
          ].join(' · ')}
        </p>
        {bio ? (
          <p className="mt-1 max-w-full text-row break-words whitespace-pre-line text-muted-foreground">
            {bio}
          </p>
        ) : null}
      </div>
    </figure>
  )
}

function Counter({ value, max }: { value: string; max: number }) {
  return (
    <span className="tabular text-xs text-muted-foreground" aria-hidden="true">
      {value.length}/{max}
    </span>
  )
}

function PhotoPicker({
  shown,
  name,
  photo,
  hasPrevious,
  disabled,
  onChoose,
  onChange,
}: {
  shown: string | null
  name: string
  photo: Photo
  hasPrevious: boolean
  disabled: boolean
  onChoose: (file: File | undefined) => void
  onChange: (photo: Photo) => void
}) {
  const { t } = useTranslation()
  const [dragging, setDragging] = useState(false)
  const fileInput = useRef<HTMLInputElement>(null)
  const undo = (photo.kind === 'new' && hasPrevious) || photo.kind === 'remove'
  return (
    <div
      className={cn(
        'flex items-center gap-3 rounded-lg border border-dashed p-3 transition-colors',
        dragging && 'border-primary bg-primary/5',
      )}
      onDragOver={(event) => {
        event.preventDefault()
        setDragging(true)
      }}
      onDragLeave={() => setDragging(false)}
      onDrop={(event) => {
        event.preventDefault()
        setDragging(false)
        onChoose(event.dataTransfer.files[0])
      }}
    >
      <PreviewAvatar src={shown} name={name} className="size-14 text-sm" />
      <div className="flex min-w-0 flex-col gap-1.5">
        <div className="flex flex-wrap gap-1.5">
          <Button
            type="button"
            variant="outline"
            size="sm"
            disabled={disabled}
            onClick={() => fileInput.current?.click()}
          >
            <CameraIcon />
            {shown ? t('community.changePhoto') : t('community.choosePhoto')}
          </Button>
          {undo ? (
            <Button
              type="button"
              variant="ghost"
              size="sm"
              disabled={disabled}
              onClick={() => onChange({ kind: 'keep' })}
            >
              <Undo2Icon />
              {t('community.undoPhoto')}
            </Button>
          ) : shown ? (
            <Button
              type="button"
              variant="ghost"
              size="sm"
              disabled={disabled}
              onClick={() => onChange(hasPrevious ? { kind: 'remove' } : { kind: 'keep' })}
            >
              <Trash2Icon />
              {t('community.removePhoto')}
            </Button>
          ) : null}
        </div>
        <p className="text-xs text-muted-foreground">{t('community.photoHint')}</p>
      </div>
      <input
        ref={fileInput}
        type="file"
        hidden
        accept={avatarTypes.join(',')}
        onChange={(event) => {
          onChoose(event.target.files?.[0])
          event.target.value = ''
        }}
      />
    </div>
  )
}

function AccountDialog({ account, onClose }: { account: OfficialAccount | null; onClose: () => void }) {
  const { t } = useTranslation()
  const save = useSaveAccount()
  const [createdId, setCreatedId] = useState<string | null>(null)
  const [username, setUsername] = useState(account?.username ?? '')
  const [name, setName] = useState(account?.display_name ?? '')
  const [bio, setBio] = useState(account?.bio ?? '')
  const [photo, setPhoto] = useState<Photo>({ kind: 'keep' })
  const [cropping, setCropping] = useState<File | null>(null)
  const [saving, setSaving] = useState(false)
  const [touched, setTouched] = useState(false)
  const previous = account?.avatar_url ?? null
  const shown =
    photo.kind === 'new'
      ? photo.preview
      : photo.kind === 'remove' || !previous
        ? null
        : staffMediaUrl(previous, appEnv().publicApiUrl, appEnv().supabaseUrl)
  const errors = {
    username: usernamePattern.test(username.trim()) ? undefined : t('community.errors.username'),
    name:
      name.trim().length >= 2 && name.trim().length <= NAME_MAX
        ? undefined
        : t('community.errors.accountName'),
  }
  const valid = !errors.username && !errors.name

  useEffect(
    () => () => {
      if (photo.kind === 'new') URL.revokeObjectURL(photo.preview)
    },
    [photo],
  )

  const choose = (file: File | undefined) => {
    if (!file) return
    if (!avatarTypes.includes(file.type)) {
      toast.error(t('community.photoType'))
      return
    }
    if (file.size > MAX_PHOTO_BYTES) {
      toast.error(t('community.photoTooLarge'))
      return
    }
    setCropping(file)
  }

  const submit = async () => {
    setTouched(true)
    if (!valid || saving) return
    setSaving(true)
    const values = { username: username.trim(), display_name: name.trim(), bio: bio.trim() || null }
    try {
      let id = account?.id ?? createdId
      if (!id) {
        const created = await save.mutateAsync({ id: null, values: { ...values, avatar_url: null } })
        id = created.id
        setCreatedId(created.id)
      }
      const avatar =
        photo.kind === 'new'
          ? await communityApi.uploadAvatar(id, photo.blob)
          : photo.kind === 'remove'
            ? null
            : previous
      if (account || avatar) await save.mutateAsync({ id, values: { ...values, avatar_url: avatar } })
      if (previous && previous !== avatar) void communityApi.removeAvatar(id, previous).catch(() => undefined)
      toast.success(account ? t('community.accountSaved') : t('community.accountCreated'))
      onClose()
    } catch (error) {
      toast.error(errorText(error))
    } finally {
      setSaving(false)
    }
  }

  return (
    <Dialog open onOpenChange={(next) => !next && !saving && onClose()}>
      <DialogContent className="sm:max-w-2xl" closeLabel={t('app.close')}>
        <DialogHeader>
          <DialogTitle>
            {cropping
              ? t('community.cropTitle')
              : account
                ? t('community.editAccount')
                : t('community.newAccount')}
          </DialogTitle>
        </DialogHeader>
        {cropping ? (
          <AvatarCropper
            key={`${cropping.name}-${cropping.lastModified}`}
            file={cropping}
            onCancel={() => setCropping(null)}
            onDone={(blob) => {
              setPhoto({ kind: 'new', blob, preview: URL.createObjectURL(blob) })
              setCropping(null)
            }}
          />
        ) : (
          <form
            className="grid gap-5 sm:grid-cols-[minmax(0,1fr)_15rem]"
            noValidate
            onSubmit={(event) => {
              event.preventDefault()
              void submit()
            }}
          >
            <div className="flex min-w-0 flex-col gap-4">
              <PhotoPicker
                shown={shown}
                name={name}
                photo={photo}
                hasPrevious={previous !== null}
                disabled={saving}
                onChoose={choose}
                onChange={setPhoto}
              />
              <div className="flex flex-col gap-1.5">
                <div className="flex items-center justify-between gap-2">
                  <Label htmlFor="official-name">{t('community.accountName')}</Label>
                  <Counter value={name} max={NAME_MAX} />
                </div>
                <Input
                  id="official-name"
                  maxLength={NAME_MAX}
                  value={name}
                  aria-invalid={touched && errors.name ? true : undefined}
                  onChange={(event) => setName(event.target.value)}
                />
                {touched && errors.name ? <p className="text-xs text-destructive">{errors.name}</p> : null}
              </div>
              <div className="flex flex-col gap-1.5">
                <Label htmlFor="official-username">{t('community.username')}</Label>
                <div className="relative">
                  <span
                    aria-hidden="true"
                    className="pointer-events-none absolute top-1/2 left-2.5 -translate-y-1/2 text-row text-muted-foreground"
                  >
                    @
                  </span>
                  <Input
                    id="official-username"
                    maxLength={30}
                    value={username}
                    className="pl-6 font-mono"
                    autoComplete="off"
                    spellCheck={false}
                    aria-invalid={touched && errors.username ? true : undefined}
                    onChange={(event) =>
                      setUsername(event.target.value.replace(/^@+/, '').replace(/\s+/g, '_'))
                    }
                  />
                </div>
                {touched && errors.username ? (
                  <p className="text-xs text-destructive">{errors.username}</p>
                ) : (
                  <p className="text-xs text-muted-foreground">
                    {account && username.trim() !== account.username
                      ? t('community.usernameChangeHint')
                      : t('community.usernameHint')}
                  </p>
                )}
              </div>
              <div className="flex flex-col gap-1.5">
                <div className="flex items-center justify-between gap-2">
                  <Label htmlFor="official-bio">{t('community.bio')}</Label>
                  <Counter value={bio} max={BIO_MAX} />
                </div>
                <Textarea
                  id="official-bio"
                  rows={3}
                  maxLength={BIO_MAX}
                  value={bio}
                  placeholder={t('community.bioPlaceholder')}
                  onChange={(event) => setBio(event.target.value)}
                />
              </div>
            </div>
            <ProfilePreview
              name={name.trim()}
              username={username.trim()}
              bio={bio.trim()}
              avatar={shown}
              followers={account?.follower_count ?? 0}
              posts={account?.post_count ?? 0}
            />
            <DialogFooter className="sm:col-span-2">
              <Button type="button" variant="outline" disabled={saving} onClick={onClose}>
                {t('app.cancel')}
              </Button>
              <Button type="submit" disabled={saving}>
                {saving ? <LoaderCircleIcon className="animate-spin" /> : null}
                {account ? t('app.save') : t('community.createAccount')}
              </Button>
            </DialogFooter>
          </form>
        )}
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
