import { BellRingIcon, InfoIcon, LoaderCircleIcon, PlusIcon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { EmptyState, ErrorState, ListSkeleton } from '@/components/states'
import { Button } from '@/components/ui/button'
import {
  RadioGroup,
  RadioGroupItem,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  ToggleGroup,
  ToggleGroupItem,
} from '@/components/ui/controls'
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Sheet, SheetContent } from '@/components/ui/overlay'
import { Textarea } from '@/components/ui/textarea'
import { useAgent } from '@/features/auth/hooks'
import { Confirm } from '@/features/nasabah/components/confirm'
import { useDebounced } from '@/hooks/use-now'
import { errorText } from '@/lib/error-text'
import { formatNumber, stamp } from '@/lib/time'

import {
  useAudienceSize,
  useCampaigns,
  useCancelCampaign,
  useCommunityOverview,
  useCommunityPosts,
  useOfficialAccounts,
  useReviewCampaign,
  useSaveCampaign,
  useSubmitCampaign,
} from '../hooks'
import {
  campaignFilters,
  canCancel,
  canEdit,
  canReview,
  canSubmit,
  cleanStock,
  excerpt,
  filterCampaigns,
  fromJakartaInput,
  jakartaInput,
  reviewBlockedByFourEyes,
  stockCodePattern,
  type CampaignFilter,
} from '../logic'
import type { Audience, Campaign } from '../types'
import { AccountAvatar, AccountChip, CampaignStatusText, ReasonDialog } from './shared'

type Link = 'none' | 'post' | 'url'

function FieldError({ message }: { message?: string }) {
  return message ? <p className="text-xs text-destructive">{message}</p> : null
}

function NotificationPreview({
  account,
  title,
  body,
}: {
  account: Campaign['account'] | null
  title: string
  body: string
}) {
  const { t } = useTranslation()
  return (
    <div
      className="flex items-start gap-3 rounded-xl border bg-subtle p-3"
      aria-label={t('community.preview')}
    >
      {account ? (
        <AccountAvatar account={account} />
      ) : (
        <BellRingIcon className="size-8 text-muted-foreground" />
      )}
      <div className="min-w-0">
        <p className="truncate text-xs text-muted-foreground">
          {account?.display_name ?? t('community.preview')}
        </p>
        <p className="truncate text-sm font-medium">{title || t('community.campaignTitle')}</p>
        <p className="line-clamp-2 text-row text-muted-foreground">{body || t('community.campaignBody')}</p>
      </div>
    </div>
  )
}

function CampaignComposer({
  campaign,
  onClose,
}: {
  campaign: Campaign | null
  onClose: (saved?: Campaign) => void
}) {
  const { t } = useTranslation()
  const agent = useAgent()
  const accounts = useOfficialAccounts()
  const posts = useCommunityPosts()
  const save = useSaveCampaign()
  const submit = useSubmitCampaign()
  const review = useReviewCampaign()
  const active = (accounts.data ?? []).filter((account) => account.disabled_at === null)
  const published = (posts.data ?? []).filter((post) => post.status === 'published' && !post.post?.deleted)
  const [accountId, setAccountId] = useState(campaign?.account.id ?? '')
  const [title, setTitle] = useState(campaign?.title ?? '')
  const [body, setBody] = useState(campaign?.body ?? '')
  const [link, setLink] = useState<Link>(campaign?.link_post ? 'post' : campaign?.link_url ? 'url' : 'none')
  const [postId, setPostId] = useState(campaign?.link_post?.id ?? '')
  const [url, setUrl] = useState(campaign?.link_url ?? '')
  const [audience, setAudience] = useState<Audience>(campaign?.audience ?? 'all')
  const [stock, setStock] = useState(campaign?.audience_stock ?? '')
  const [later, setLater] = useState(Boolean(campaign?.send_at))
  const [sendAt, setSendAt] = useState(jakartaInput(campaign?.send_at ?? null))
  const [touched, setTouched] = useState(false)
  const code = cleanStock(stock)
  const debouncedCode = useDebounced(code, 400)
  const size = useAudienceSize(
    audience,
    audience === 'stock' ? debouncedCode : null,
    audience === 'all' || stockCodePattern.test(debouncedCode),
  )
  const pending = save.isPending || submit.isPending || review.isPending
  const directPublish =
    agent.community_permissions.includes('community.publish') && !agent.settings.community_four_eyes
  const account = active.find((item) => item.id === accountId) ?? null

  const errors = {
    account: accountId ? undefined : t('community.errors.accountRequired'),
    title: title.trim().length < 3 ? t('community.errors.titleLength') : undefined,
    body: body.trim().length < 3 ? t('community.errors.notificationBody') : undefined,
    post: link === 'post' && !postId ? t('community.errors.postRequired') : undefined,
    url: link === 'url' && !/^https:\/\/\S+$/.test(url.trim()) ? t('community.errors.urlInvalid') : undefined,
    stock:
      audience === 'stock' && !stockCodePattern.test(code) ? t('community.errors.stockInvalid') : undefined,
    sendAt:
      later && (!fromJakartaInput(sendAt) || (fromJakartaInput(sendAt) ?? '') <= new Date().toISOString())
        ? t('community.errors.scheduleFuture')
        : undefined,
  }
  const valid = Object.values(errors).every((value) => value === undefined)

  const persist = async (then: 'draft' | 'submit' | 'publish') => {
    setTouched(true)
    if (!valid) return
    try {
      let saved = await save.mutateAsync({
        id: campaign?.id ?? null,
        version: campaign?.version ?? null,
        draft: {
          account_id: accountId,
          title: title.trim(),
          body: body.trim(),
          link_post_id: link === 'post' ? postId : null,
          link_url: link === 'url' ? url.trim() : null,
          audience,
          audience_stock: audience === 'stock' ? code : null,
          send_at: later ? fromJakartaInput(sendAt) : null,
        },
      })
      if (then === 'submit') saved = await submit.mutateAsync({ id: saved.id, version: saved.version })
      if (then === 'publish')
        saved = await review.mutateAsync({ id: saved.id, approve: true, note: null, version: saved.version })
      toast.success(
        t(
          `community.campaignSaved.${then === 'publish' && saved.status === 'scheduled' ? 'scheduled' : then}`,
        ),
      )
      onClose(saved)
    } catch (error) {
      toast.error(errorText(error))
    }
  }

  return (
    <Dialog open onOpenChange={(next) => !next && !pending && onClose()}>
      <DialogContent className="max-h-[92vh] overflow-y-auto sm:max-w-2xl" closeLabel={t('app.close')}>
        <DialogHeader>
          <DialogTitle>{campaign ? t('community.editCampaign') : t('community.newCampaign')}</DialogTitle>
        </DialogHeader>
        <form
          className="flex flex-col gap-4"
          noValidate
          onSubmit={(event) => {
            event.preventDefault()
            void persist('submit')
          }}
        >
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="campaign-account">{t('community.sender')}</Label>
            <Select value={accountId || undefined} onValueChange={setAccountId}>
              <SelectTrigger id="campaign-account" className="w-full sm:w-80">
                <SelectValue placeholder={t('community.chooseAccount')} />
              </SelectTrigger>
              <SelectContent>
                {active.map((item) => (
                  <SelectItem key={item.id} value={item.id}>
                    {item.display_name ?? item.username}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
            {touched ? <FieldError message={errors.account} /> : null}
          </div>
          <div className="grid gap-4 sm:grid-cols-[minmax(0,1fr)_minmax(0,1fr)]">
            <div className="flex flex-col gap-3">
              <div className="flex flex-col gap-1.5">
                <Label htmlFor="campaign-title">{t('community.campaignTitle')}</Label>
                <Input
                  id="campaign-title"
                  maxLength={80}
                  value={title}
                  aria-invalid={touched && errors.title ? true : undefined}
                  onChange={(event) => setTitle(event.target.value)}
                />
                {touched ? <FieldError message={errors.title} /> : null}
              </div>
              <div className="flex flex-col gap-1.5">
                <Label htmlFor="campaign-body">{t('community.campaignBody')}</Label>
                <Textarea
                  id="campaign-body"
                  rows={3}
                  maxLength={240}
                  value={body}
                  aria-invalid={touched && errors.body ? true : undefined}
                  onChange={(event) => setBody(event.target.value)}
                />
                <p className="tabular text-right text-xs text-muted-foreground">{body.length}/240</p>
                {touched ? <FieldError message={errors.body} /> : null}
              </div>
            </div>
            <div className="flex flex-col gap-1.5">
              <span className="text-sm font-medium">{t('community.preview')}</span>
              <NotificationPreview account={account} title={title.trim()} body={body.trim()} />
            </div>
          </div>
          <fieldset className="flex flex-col gap-2 rounded-lg border p-3">
            <legend className="px-1 text-sm font-medium">{t('community.linkTarget')}</legend>
            <RadioGroup
              value={link}
              onValueChange={(value) => setLink(value as Link)}
              className="flex flex-wrap gap-4"
            >
              {(['none', 'post', 'url'] as const).map((item) => (
                <label key={item} className="flex items-center gap-2 text-row">
                  <RadioGroupItem value={item} />
                  {t(`community.links.${item}`)}
                </label>
              ))}
            </RadioGroup>
            {link === 'post' ? (
              <div className="flex flex-col gap-1.5">
                <Select value={postId || undefined} onValueChange={setPostId}>
                  <SelectTrigger aria-label={t('community.links.post')} className="w-full">
                    <SelectValue placeholder={t('community.choosePost')} />
                  </SelectTrigger>
                  <SelectContent>
                    {published.map((post) => (
                      <SelectItem key={post.id} value={post.id}>
                        {excerpt(post.title ?? post.body, 70)}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
                {touched ? <FieldError message={errors.post} /> : null}
              </div>
            ) : null}
            {link === 'url' ? (
              <div className="flex flex-col gap-1.5">
                <Input
                  aria-label={t('community.links.url')}
                  inputMode="url"
                  placeholder="https://"
                  maxLength={500}
                  value={url}
                  onChange={(event) => setUrl(event.target.value)}
                />
                {touched ? <FieldError message={errors.url} /> : null}
              </div>
            ) : null}
          </fieldset>
          <fieldset className="flex flex-col gap-2 rounded-lg border p-3">
            <legend className="px-1 text-sm font-medium">{t('community.audience')}</legend>
            <RadioGroup
              value={audience}
              onValueChange={(value) => setAudience(value as Audience)}
              className="flex flex-wrap gap-4"
            >
              <label className="flex items-center gap-2 text-row">
                <RadioGroupItem value="all" />
                {t('community.audiences.all')}
              </label>
              <label className="flex items-center gap-2 text-row">
                <RadioGroupItem value="stock" />
                {t('community.audiences.stock')}
              </label>
            </RadioGroup>
            {audience === 'stock' ? (
              <div className="flex w-48 flex-col gap-1.5">
                <Input
                  aria-label={t('community.stockCode')}
                  maxLength={13}
                  placeholder="BBCA"
                  value={stock}
                  onChange={(event) => setStock(event.target.value)}
                />
                {touched ? <FieldError message={errors.stock} /> : null}
              </div>
            ) : null}
            <p className="text-xs text-muted-foreground" role="status">
              {size.data === undefined
                ? t('community.audienceCounting')
                : t('community.audienceSize', { count: size.data, formatted: formatNumber(size.data) })}
            </p>
          </fieldset>
          <fieldset className="flex flex-col gap-2">
            <legend className="mb-1.5 text-sm font-medium">{t('community.sendTime')}</legend>
            <RadioGroup
              value={later ? 'later' : 'now'}
              onValueChange={(value) => setLater(value === 'later')}
              className="flex flex-wrap gap-4"
            >
              <label className="flex items-center gap-2 text-row">
                <RadioGroupItem value="now" />
                {t('community.sendNow')}
              </label>
              <label className="flex items-center gap-2 text-row">
                <RadioGroupItem value="later" />
                {t('community.sendLater')}
              </label>
            </RadioGroup>
            {later ? (
              <div className="flex w-64 flex-col gap-1.5">
                <Input
                  type="datetime-local"
                  aria-label={t('community.sendAt')}
                  value={sendAt}
                  onChange={(event) => setSendAt(event.target.value)}
                />
                {touched ? <FieldError message={errors.sendAt} /> : null}
              </div>
            ) : null}
          </fieldset>
          <p className="text-xs text-muted-foreground">
            {directPublish ? t('community.directSendHint') : t('community.reviewHint')}
          </p>
          <DialogFooter className="flex-wrap">
            <Button type="button" variant="outline" disabled={pending} onClick={() => void persist('draft')}>
              {t('community.saveDraft')}
            </Button>
            {directPublish ? (
              <Button type="button" disabled={pending} onClick={() => void persist('publish')}>
                {pending ? <LoaderCircleIcon className="animate-spin" /> : null}
                {t('community.saveSend')}
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

function CampaignDetail({ campaign, onEdit }: { campaign: Campaign; onEdit: () => void }) {
  const { t } = useTranslation()
  const agent = useAgent()
  const actor = {
    id: agent.id,
    perms: agent.community_permissions,
    fourEyes: agent.settings.community_four_eyes,
  }
  const submit = useSubmitCampaign()
  const review = useReviewCampaign()
  const cancel = useCancelCampaign()
  const [rejecting, setRejecting] = useState(false)
  const [cancelling, setCancelling] = useState(false)
  const busy = submit.isPending || review.isPending || cancel.isPending
  const scheduled = Boolean(campaign.send_at && campaign.send_at > new Date().toISOString())
  const run = (action: Promise<unknown>, message: string) =>
    void action.then(() => toast.success(message)).catch((error: unknown) => toast.error(errorText(error)))
  return (
    <div className="flex h-full min-h-0 flex-col">
      <header className="flex flex-wrap items-center gap-3 border-b px-5 pt-4 pr-12 pb-3">
        <AccountChip account={campaign.account} />
        <CampaignStatusText status={campaign.status} />
      </header>
      <div className="flex min-h-0 flex-1 flex-col gap-4 overflow-y-auto px-5 py-4">
        <NotificationPreview account={campaign.account} title={campaign.title} body={campaign.body} />
        <dl className="grid grid-cols-2 gap-x-4 gap-y-3">
          <div>
            <dt className="text-xs text-muted-foreground">{t('community.audience')}</dt>
            <dd className="text-row">
              {campaign.audience === 'stock'
                ? t('community.audienceStockValue', { code: campaign.audience_stock })
                : t('community.audiences.all')}
            </dd>
          </div>
          <div>
            <dt className="text-xs text-muted-foreground">{t('community.linkTarget')}</dt>
            <dd className="text-row break-words">
              {campaign.link_post
                ? excerpt(campaign.link_post.title ?? campaign.link_post.body, 80)
                : (campaign.link_url ?? t('community.links.none'))}
            </dd>
          </div>
          <div>
            <dt className="text-xs text-muted-foreground">{t('community.sendTime')}</dt>
            <dd className="text-row">
              {campaign.finished_at
                ? stamp(campaign.finished_at)
                : campaign.send_at
                  ? t('community.scheduledAt', { time: stamp(campaign.send_at) })
                  : t('community.sendNow')}
            </dd>
          </div>
          <div>
            <dt className="text-xs text-muted-foreground">{t('community.recipientsLabel')}</dt>
            <dd className="tabular text-row">{formatNumber(campaign.recipients)}</dd>
          </div>
        </dl>
        <div className="text-xs text-muted-foreground">
          {[
            t('community.createdBy', {
              name: campaign.created_by?.name ?? '-',
              time: stamp(campaign.created_at),
            }),
            campaign.reviewed_at
              ? t(campaign.status === 'rejected' ? 'community.rejectedBy' : 'community.approvedBy', {
                  name: campaign.reviewed_by?.name ?? '-',
                  time: stamp(campaign.reviewed_at),
                })
              : null,
            campaign.review_note,
          ]
            .filter(Boolean)
            .map((line) => (
              <p key={line}>{line}</p>
            ))}
        </div>
      </div>
      <footer className="flex flex-col gap-2 border-t px-5 py-3">
        {reviewBlockedByFourEyes(campaign, actor) ? (
          <p className="text-xs text-muted-foreground">{t('community.fourEyesHint')}</p>
        ) : null}
        <div className="flex flex-wrap gap-2">
          {canEdit(campaign, actor) ? (
            <Button variant="outline" size="sm" disabled={busy} onClick={onEdit}>
              {t('app.edit')}
            </Button>
          ) : null}
          {canSubmit(campaign, actor) ? (
            <Button
              size="sm"
              disabled={busy}
              onClick={() =>
                run(
                  submit.mutateAsync({ id: campaign.id, version: campaign.version }),
                  t('community.campaignSaved.submit'),
                )
              }
            >
              {t('community.submit')}
            </Button>
          ) : null}
          {canReview(campaign, actor) ? (
            <>
              <Button
                size="sm"
                disabled={busy}
                onClick={() =>
                  run(
                    review.mutateAsync({
                      id: campaign.id,
                      approve: true,
                      note: null,
                      version: campaign.version,
                    }),
                    scheduled ? t('community.campaignSaved.scheduled') : t('community.campaignSaved.publish'),
                  )
                }
              >
                {scheduled ? t('community.approveSchedule') : t('community.approveSend')}
              </Button>
              {campaign.status === 'pending' ? (
                <Button variant="outline" size="sm" disabled={busy} onClick={() => setRejecting(true)}>
                  {t('community.reject')}
                </Button>
              ) : null}
            </>
          ) : null}
          {canCancel(campaign, actor) ? (
            <Button variant="ghost" size="sm" disabled={busy} onClick={() => setCancelling(true)}>
              {t('community.cancel')}
            </Button>
          ) : null}
        </div>
      </footer>
      <ReasonDialog
        open={rejecting}
        title={t('community.rejectCampaignTitle')}
        label={t('community.rejectNote')}
        action={t('community.reject')}
        pending={review.isPending}
        onClose={() => setRejecting(false)}
        onSubmit={(note) =>
          void review
            .mutateAsync({ id: campaign.id, approve: false, note, version: campaign.version })
            .then(() => {
              setRejecting(false)
              toast.success(t('community.rejected'))
            })
            .catch((error: unknown) => toast.error(errorText(error)))
        }
      />
      <Confirm
        open={cancelling}
        title={t('community.cancelCampaignTitle')}
        body={t('community.cancelCampaignBody')}
        action={t('community.cancel')}
        pending={cancel.isPending}
        destructive
        onConfirm={() =>
          void cancel
            .mutateAsync({ id: campaign.id, version: campaign.version })
            .then(() => {
              setCancelling(false)
              toast.success(t('community.cancelled'))
            })
            .catch((error: unknown) => toast.error(errorText(error)))
        }
        onClose={() => setCancelling(false)}
      />
    </div>
  )
}

export function CampaignsTab() {
  const { t } = useTranslation()
  const agent = useAgent()
  const campaigns = useCampaigns()
  const overview = useCommunityOverview()
  const canWrite = agent.community_permissions.includes('community.post')
  const canPublish = agent.community_permissions.includes('community.publish')
  const [filter, setFilter] = useState<CampaignFilter>(canPublish ? 'review' : 'mine')
  const [selected, setSelected] = useState<string | null>(null)
  const [editing, setEditing] = useState<Campaign | null>(null)
  const [composing, setComposing] = useState(false)
  const rows = campaigns.data ? filterCampaigns(campaigns.data, filter, agent.id) : []
  const current = campaigns.data?.find((campaign) => campaign.id === selected) ?? null

  return (
    <section className="flex flex-col gap-3" aria-label={t('community.tabs.notifications')}>
      {overview.data && !overview.data.push_ready ? (
        <p className="flex items-start gap-2 rounded-lg border bg-subtle px-3 py-2 text-row text-muted-foreground">
          <InfoIcon className="mt-0.5 size-4 shrink-0" aria-hidden="true" />
          {t('community.pushNotReady')}
        </p>
      ) : null}
      <div className="flex flex-wrap items-center justify-between gap-3">
        <ToggleGroup
          type="single"
          value={filter}
          onValueChange={(value) => {
            if ((campaignFilters as readonly string[]).includes(value)) setFilter(value as CampaignFilter)
          }}
          aria-label={t('community.filter')}
        >
          {campaignFilters.map((item) => (
            <ToggleGroupItem key={item} value={item}>
              {t(`community.campaignFilters.${item}`)}
            </ToggleGroupItem>
          ))}
        </ToggleGroup>
        {canWrite ? (
          <Button
            size="sm"
            onClick={() => {
              setEditing(null)
              setComposing(true)
            }}
          >
            <PlusIcon />
            {t('community.newCampaign')}
          </Button>
        ) : null}
      </div>
      {campaigns.isError ? (
        <ErrorState error={campaigns.error} onRetry={() => void campaigns.refetch()} />
      ) : !campaigns.data ? (
        <ListSkeleton rows={4} />
      ) : rows.length === 0 ? (
        <EmptyState title={t(`community.emptyCampaigns.${filter}`)} />
      ) : (
        <ul className="border-t">
          {rows.map((campaign) => (
            <li key={campaign.id}>
              <button
                type="button"
                onClick={() => setSelected(campaign.id)}
                className="flex w-full flex-col gap-1 border-b px-1 py-3 text-left outline-none hover:bg-muted/50 focus-visible:ring-2 focus-visible:ring-ring/50 focus-visible:ring-inset"
              >
                <span className="flex flex-wrap items-center justify-between gap-x-3 gap-y-1">
                  <span className="min-w-0 truncate text-row font-medium">{campaign.title}</span>
                  <CampaignStatusText status={campaign.status} />
                </span>
                <span className="text-row text-muted-foreground">{excerpt(campaign.body, 140)}</span>
                <span className="text-xs text-muted-foreground">
                  {[
                    campaign.account.display_name,
                    campaign.audience === 'stock'
                      ? t('community.audienceStockValue', { code: campaign.audience_stock })
                      : t('community.audiences.all'),
                    campaign.send_at ? stamp(campaign.send_at) : null,
                    campaign.recipients > 0
                      ? t('community.recipients', { count: campaign.recipients })
                      : null,
                  ]
                    .filter(Boolean)
                    .join(' · ')}
                </span>
              </button>
            </li>
          ))}
        </ul>
      )}
      <Sheet open={current !== null} onOpenChange={(open) => !open && setSelected(null)}>
        <SheetContent
          title={t('community.campaignDetail')}
          closeLabel={t('app.close')}
          className="w-[min(560px,100vw)] bg-background"
        >
          {current ? (
            <CampaignDetail
              key={current.id}
              campaign={current}
              onEdit={() => {
                setSelected(null)
                setEditing(current)
                setComposing(true)
              }}
            />
          ) : null}
        </SheetContent>
      </Sheet>
      {composing ? (
        <CampaignComposer
          key={editing?.id ?? 'new'}
          campaign={editing}
          onClose={(saved) => {
            setComposing(false)
            setEditing(null)
            if (saved) setSelected(saved.id)
          }}
        />
      ) : null}
    </section>
  )
}
