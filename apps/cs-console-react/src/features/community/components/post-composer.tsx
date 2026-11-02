import { ImagePlusIcon, LoaderCircleIcon, XIcon } from 'lucide-react'
import { useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { Button } from '@/components/ui/button'
import {
  RadioGroup,
  RadioGroupItem,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Switch,
} from '@/components/ui/controls'
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import { useAgent } from '@/features/auth/hooks'
import { IMAGE_TYPES } from '@/features/conversation/types'
import { errorText } from '@/lib/error-text'
import { cn } from '@/lib/utils'

import { communityApi } from '../api'
import { useOfficialAccounts, useReviewPost, useSavePost, useSubmitPost } from '../hooks'
import { cleanStock, fromJakartaInput, jakartaInput, stockCodePattern } from '../logic'
import {
  MAX_POST_BODY,
  MAX_POST_IMAGES,
  type CommunityPost,
  type PinScope,
  type PostAttachment,
  type PostKind,
} from '../types'
import { PostImages } from './shared'

type Pin = 'none' | PinScope
type When = 'now' | 'later'

function FieldError({ message }: { message?: string }) {
  return message ? <p className="text-xs text-destructive">{message}</p> : null
}

export function PostComposer({
  post,
  open,
  onClose,
}: {
  post: CommunityPost | null
  open: boolean
  onClose: (saved?: CommunityPost) => void
}) {
  const { t } = useTranslation()
  const agent = useAgent()
  const accounts = useOfficialAccounts()
  const save = useSavePost()
  const submit = useSubmitPost()
  const review = useReviewPost()
  const active = (accounts.data ?? []).filter((account) => account.disabled_at === null)
  const [accountId, setAccountId] = useState(post?.account.id ?? '')
  const [kind, setKind] = useState<PostKind>(post?.kind ?? 'post')
  const [title, setTitle] = useState(post?.title ?? '')
  const [body, setBody] = useState(post?.body ?? '')
  const [media, setMedia] = useState<PostAttachment[]>(post?.attachments ?? [])
  const [uploading, setUploading] = useState(false)
  const [pin, setPin] = useState<Pin>(post?.pin_scope ?? 'none')
  const [stock, setStock] = useState(post?.pin_stock ?? '')
  const [pinUntil, setPinUntil] = useState(jakartaInput(post?.pin_until ?? null))
  const [notify, setNotify] = useState(post?.notify ?? false)
  const [when, setWhen] = useState<When>(post?.publish_at ? 'later' : 'now')
  const [publishAt, setPublishAt] = useState(jakartaInput(post?.publish_at ?? null))
  const [touched, setTouched] = useState(false)
  const fileInput = useRef<HTMLInputElement>(null)
  const pending = save.isPending || submit.isPending || review.isPending || uploading
  const canPublish = agent.community_permissions.includes('community.publish')
  const directPublish = canPublish && !agent.settings.community_four_eyes
  const effectivePin: Pin = kind === 'announcement' && pin === 'none' ? 'global' : pin

  const errors = {
    account: accountId ? undefined : t('community.errors.accountRequired'),
    title:
      kind === 'announcement' && (title.trim().length < 3 || title.trim().length > 80)
        ? t('community.errors.titleLength')
        : undefined,
    body:
      body.trim().length < 1 || body.trim().length > MAX_POST_BODY
        ? t('community.errors.bodyLength', { max: MAX_POST_BODY })
        : undefined,
    stock:
      effectivePin === 'stock' && !stockCodePattern.test(cleanStock(stock))
        ? t('community.errors.stockInvalid')
        : undefined,
    pinUntil: pinUntil && !fromJakartaInput(pinUntil) ? t('community.errors.dateInvalid') : undefined,
    publishAt:
      when === 'later' &&
      (!fromJakartaInput(publishAt) || (fromJakartaInput(publishAt) ?? '') <= new Date().toISOString())
        ? t('community.errors.scheduleFuture')
        : undefined,
  }
  const valid = Object.values(errors).every((value) => value === undefined)

  const addImages = async (files: File[]) => {
    if (!accountId) {
      toast.error(t('community.errors.accountFirst'))
      return
    }
    const room = MAX_POST_IMAGES - media.length
    if (files.length > room) toast.error(t('community.errors.tooManyImages', { max: MAX_POST_IMAGES }))
    setUploading(true)
    try {
      for (const file of files.slice(0, room)) {
        if (!IMAGE_TYPES.includes(file.type)) {
          toast.error(t('composer.badType', { name: file.name }))
          continue
        }
        const uploaded = await communityApi.uploadPostImage(accountId, file)
        setMedia((current) => [...current, uploaded])
      }
    } catch (error) {
      toast.error(errorText(error))
    } finally {
      setUploading(false)
    }
  }

  const persist = async (then: 'draft' | 'submit' | 'publish') => {
    setTouched(true)
    if (!valid) return
    try {
      let saved = await save.mutateAsync({
        id: post?.id ?? null,
        version: post?.version ?? null,
        draft: {
          account_id: accountId,
          kind,
          title: kind === 'announcement' ? title.trim() : null,
          body: body.trim(),
          attachments: media,
          pin_scope: effectivePin === 'none' ? null : effectivePin,
          pin_stock: effectivePin === 'stock' ? cleanStock(stock) : null,
          pin_until: effectivePin === 'none' ? null : fromJakartaInput(pinUntil),
          notify,
          publish_at: when === 'later' ? fromJakartaInput(publishAt) : null,
        },
      })
      if (then === 'submit') saved = await submit.mutateAsync({ id: saved.id, version: saved.version })
      if (then === 'publish')
        saved = await review.mutateAsync({ id: saved.id, approve: true, note: null, version: saved.version })
      toast.success(
        t(`community.saved.${then === 'publish' && saved.status === 'scheduled' ? 'scheduled' : then}`),
      )
      onClose(saved)
    } catch (error) {
      toast.error(errorText(error))
    }
  }

  return (
    <Dialog open={open} onOpenChange={(next) => !next && !pending && onClose()}>
      <DialogContent className="max-h-[92vh] overflow-y-auto sm:max-w-2xl" closeLabel={t('app.close')}>
        <DialogHeader>
          <DialogTitle>{post ? t('community.editPost') : t('community.newPost')}</DialogTitle>
        </DialogHeader>
        <form
          className="flex flex-col gap-4"
          noValidate
          onSubmit={(event) => {
            event.preventDefault()
            void persist('submit')
          }}
        >
          <div className="grid gap-4 sm:grid-cols-2">
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="post-account">{t('community.account')}</Label>
              <Select
                value={accountId || undefined}
                onValueChange={(value) => {
                  if (media.length > 0 && value !== accountId) setMedia([])
                  setAccountId(value)
                }}
              >
                <SelectTrigger
                  id="post-account"
                  className="w-full"
                  aria-invalid={touched && errors.account ? true : undefined}
                >
                  <SelectValue placeholder={t('community.chooseAccount')} />
                </SelectTrigger>
                <SelectContent>
                  {active.map((account) => (
                    <SelectItem key={account.id} value={account.id}>
                      {account.display_name ?? account.username}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
              {touched ? <FieldError message={errors.account} /> : null}
              {active.length === 0 && accounts.data ? (
                <p className="text-xs text-warning">{t('community.noAccounts')}</p>
              ) : null}
            </div>
            <fieldset className="flex flex-col gap-1.5">
              <legend className="mb-1.5 text-sm font-medium">{t('community.kind')}</legend>
              <RadioGroup
                value={kind}
                onValueChange={(value) => setKind(value as PostKind)}
                className="flex gap-4"
              >
                {(['post', 'announcement'] as const).map((item) => (
                  <label key={item} className="flex items-center gap-2 text-row">
                    <RadioGroupItem value={item} />
                    {t(`community.kinds.${item}`)}
                  </label>
                ))}
              </RadioGroup>
            </fieldset>
          </div>
          {kind === 'announcement' ? (
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="post-title">{t('community.title')}</Label>
              <Input
                id="post-title"
                maxLength={80}
                value={title}
                aria-invalid={touched && errors.title ? true : undefined}
                onChange={(event) => setTitle(event.target.value)}
              />
              {touched ? <FieldError message={errors.title} /> : null}
            </div>
          ) : null}
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="post-body">{t('community.body')}</Label>
            <Textarea
              id="post-body"
              rows={6}
              maxLength={MAX_POST_BODY}
              value={body}
              aria-invalid={touched && errors.body ? true : undefined}
              onChange={(event) => setBody(event.target.value)}
            />
            <div className="flex items-start justify-between gap-3 text-xs text-muted-foreground">
              <span>{t('community.bodyHint')}</span>
              <span className="tabular shrink-0">
                {body.length}/{MAX_POST_BODY}
              </span>
            </div>
            {touched ? <FieldError message={errors.body} /> : null}
          </div>
          <div className="flex flex-col gap-2">
            <div className="flex items-center justify-between gap-3">
              <span className="text-sm font-medium">{t('community.images')}</span>
              <Button
                type="button"
                variant="outline"
                size="sm"
                disabled={pending || media.length >= MAX_POST_IMAGES}
                onClick={() => fileInput.current?.click()}
              >
                {uploading ? <LoaderCircleIcon className="animate-spin" /> : <ImagePlusIcon />}
                {t('community.addImage')}
              </Button>
            </div>
            {media.length > 0 ? (
              <div className="flex flex-wrap items-start gap-2">
                {media.map((item) => (
                  <div key={item.path} className="relative">
                    <PostImages attachments={[item]} />
                    <button
                      type="button"
                      aria-label={t('community.removeImage')}
                      onClick={() =>
                        setMedia((current) => current.filter((value) => value.path !== item.path))
                      }
                      className="absolute -top-1.5 -right-1.5 inline-flex size-5 items-center justify-center rounded-full border bg-background text-muted-foreground outline-none hover:text-foreground focus-visible:ring-2 focus-visible:ring-ring/50"
                    >
                      <XIcon className="size-3" />
                    </button>
                  </div>
                ))}
              </div>
            ) : (
              <p className="text-xs text-muted-foreground">
                {t('community.imagesHint', { max: MAX_POST_IMAGES })}
              </p>
            )}
            <input
              ref={fileInput}
              type="file"
              hidden
              multiple
              accept={IMAGE_TYPES.join(',')}
              onChange={(event) => {
                void addImages([...(event.target.files ?? [])])
                event.target.value = ''
              }}
            />
          </div>
          <fieldset className="flex flex-col gap-2 rounded-lg border p-3">
            <legend className="px-1 text-sm font-medium">{t('community.pin')}</legend>
            <RadioGroup
              value={effectivePin}
              onValueChange={(value) => setPin(value as Pin)}
              className="flex flex-wrap gap-4"
            >
              {(['none', 'global', 'stock'] as const).map((item) => (
                <label
                  key={item}
                  className={cn(
                    'flex items-center gap-2 text-row',
                    kind === 'announcement' && item === 'none' && 'opacity-50',
                  )}
                >
                  <RadioGroupItem value={item} disabled={kind === 'announcement' && item === 'none'} />
                  {t(`community.pins.${item}`)}
                </label>
              ))}
            </RadioGroup>
            {effectivePin !== 'none' ? (
              <div className="grid gap-3 sm:grid-cols-2">
                {effectivePin === 'stock' ? (
                  <div className="flex flex-col gap-1.5">
                    <Label htmlFor="post-stock">{t('community.stockCode')}</Label>
                    <Input
                      id="post-stock"
                      maxLength={13}
                      placeholder="BBCA"
                      value={stock}
                      aria-invalid={touched && errors.stock ? true : undefined}
                      onChange={(event) => setStock(event.target.value)}
                    />
                    {touched ? <FieldError message={errors.stock} /> : null}
                  </div>
                ) : null}
                <div className="flex flex-col gap-1.5">
                  <Label htmlFor="post-pin-until">{t('community.pinUntil')}</Label>
                  <Input
                    id="post-pin-until"
                    type="datetime-local"
                    value={pinUntil}
                    onChange={(event) => setPinUntil(event.target.value)}
                  />
                  <p className="text-xs text-muted-foreground">{t('community.pinUntilHint')}</p>
                  {touched ? <FieldError message={errors.pinUntil} /> : null}
                </div>
              </div>
            ) : null}
          </fieldset>
          <label className="flex items-start gap-3 rounded-lg border p-3">
            <Switch
              checked={notify}
              onCheckedChange={setNotify}
              className="mt-0.5"
              aria-label={t('community.notify')}
            />
            <span>
              <span className="block text-sm font-medium">{t('community.notify')}</span>
              <span className="block text-xs text-muted-foreground">
                {effectivePin === 'stock' ? t('community.notifyStockHint') : t('community.notifyHint')}
              </span>
            </span>
          </label>
          <fieldset className="flex flex-col gap-2">
            <legend className="mb-1.5 text-sm font-medium">{t('community.publishTime')}</legend>
            <RadioGroup
              value={when}
              onValueChange={(value) => setWhen(value as When)}
              className="flex flex-wrap gap-4"
            >
              <label className="flex items-center gap-2 text-row">
                <RadioGroupItem value="now" />
                {t('community.publishNow')}
              </label>
              <label className="flex items-center gap-2 text-row">
                <RadioGroupItem value="later" />
                {t('community.publishLater')}
              </label>
            </RadioGroup>
            {when === 'later' ? (
              <div className="flex w-64 flex-col gap-1.5">
                <Label htmlFor="post-publish-at">{t('community.publishAt')}</Label>
                <Input
                  id="post-publish-at"
                  type="datetime-local"
                  value={publishAt}
                  aria-invalid={touched && errors.publishAt ? true : undefined}
                  onChange={(event) => setPublishAt(event.target.value)}
                />
                {touched ? <FieldError message={errors.publishAt} /> : null}
              </div>
            ) : null}
          </fieldset>
          <p className="text-xs text-muted-foreground">
            {directPublish ? t('community.directPublishHint') : t('community.reviewHint')}
          </p>
          <DialogFooter className="flex-wrap">
            <Button type="button" variant="outline" disabled={pending} onClick={() => void persist('draft')}>
              {t('community.saveDraft')}
            </Button>
            {directPublish ? (
              <Button type="button" disabled={pending} onClick={() => void persist('publish')}>
                {pending ? <LoaderCircleIcon className="animate-spin" /> : null}
                {t('community.savePublish')}
              </Button>
            ) : (
              <Button type="submit" disabled={pending}>
                {pending ? <LoaderCircleIcon className="animate-spin" /> : null}
                {t('community.saveSubmit')}
              </Button>
            )}
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}
