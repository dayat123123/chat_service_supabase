import { LoaderCircleIcon } from 'lucide-react'
import { useEffect, useId, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { Button } from '@/components/ui/button'
import { Checkbox, RadioGroup, RadioGroupItem, Switch } from '@/components/ui/controls'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import { fromJakartaInput, jakartaInput, staffMediaUrl } from '@/features/community/logic'
import { FieldText } from '@/features/system/components/system-ui'
import { bannerErrorText } from '@/lib/error-text'
import { appEnv } from '@/lib/supabase'

import { useBannerSettings, useSaveBanner } from '../hooks'
import { bannerDraft, bannerProblems, type BannerProblems } from '../logic'
import {
  appPlatforms,
  BANNER_AUDIENCE_DAYS_MAX,
  BANNER_BODY_MAX,
  BANNER_CTA_MAX,
  BANNER_LINK_MAX,
  BANNER_TITLE_MAX,
  bannerAudiences,
  bannerDisplays,
  bannerFrequencies,
  bannerLevels,
  type AppBanner,
  type BannerAudience,
  type BannerDisplay,
  type BannerDraft,
  type BannerFrequency,
  type BannerLevel,
  type BannerRatio,
} from '../types'
import { BannerImageCropper, BannerImageField, type BannerImage } from './banner-image-field'
import { BannerPreview } from './banner-preview'

const optional = (value: string) => (value.trim() === '' ? null : value.trim())

function useProblemText(problems: BannerProblems, schemes: string[]) {
  const { t } = useTranslation()
  const list =
    schemes.length > 0 ? schemes.map((item) => `${item}://`).join(', ') : t('platform.banners.schemes.none')
  return {
    title: problems.title
      ? problems.title === 'required'
        ? t('platform.banners.problems.titleRequired')
        : t('platform.banners.problems.titleLength', { max: BANNER_TITLE_MAX })
      : undefined,
    body: problems.body ? t('platform.banners.problems.bodyLength', { max: BANNER_BODY_MAX }) : undefined,
    link: problems.link
      ? problems.link === 'length'
        ? t('platform.banners.problems.linkLength', { max: BANNER_LINK_MAX })
        : problems.link === 'scheme'
          ? t('platform.banners.problems.linkScheme', { schemes: list })
          : t('platform.banners.problems.linkFormat')
      : undefined,
    cta: problems.cta
      ? problems.cta === 'length'
        ? t('platform.banners.problems.ctaLength', { max: BANNER_CTA_MAX })
        : t('platform.banners.problems.ctaLink')
      : undefined,
    audienceDays: problems.audienceDays ? t('platform.banners.problems.audienceDays') : undefined,
    minVersion: problems.minVersion ? t('platform.banners.problems.version') : undefined,
    maxVersion: problems.maxVersion
      ? problems.maxVersion === 'order'
        ? t('platform.banners.problems.versionOrder')
        : t('platform.banners.problems.version')
      : undefined,
    priority: problems.priority ? t('platform.banners.problems.priority') : undefined,
    starts: problems.starts ? t('platform.banners.problems.dateFormat') : undefined,
    ends: problems.ends
      ? problems.ends === 'order'
        ? t('platform.banners.problems.endsOrder')
        : t('platform.banners.problems.dateFormat')
      : undefined,
  }
}

function BannerForm({ editing, onClose }: { editing: AppBanner | null; onClose: () => void }) {
  const { t } = useTranslation()
  const id = useId()
  const save = useSaveBanner()
  const settings = useBannerSettings()
  const schemes = settings.data?.deep_link_schemes ?? []
  const initial = bannerDraft(editing)
  const [draft, setDraft] = useState<BannerDraft>(initial)
  const [linkText, setLinkText] = useState(initial.link_url ?? '')
  const [ctaText, setCtaText] = useState(initial.cta_label ?? '')
  const [daysText, setDaysText] = useState(String(initial.audience_days))
  const [startsText, setStartsText] = useState(jakartaInput(initial.starts_at))
  const [endsText, setEndsText] = useState(jakartaInput(initial.ends_at))
  const [minText, setMinText] = useState(initial.min_app_version ?? '')
  const [maxText, setMaxText] = useState(initial.max_app_version ?? '')
  const [priorityText, setPriorityText] = useState(String(initial.priority))
  const [image, setImage] = useState<BannerImage>({ kind: 'keep' })
  const [ratio, setRatio] = useState<BannerRatio>('portrait')
  const [cropping, setCropping] = useState<File | null>(null)
  const [checked, setChecked] = useState(false)
  const popup = draft.display === 'popup'

  useEffect(
    () => () => {
      if (image.kind === 'new') URL.revokeObjectURL(image.preview)
    },
    [image],
  )

  const shownImage =
    image.kind === 'new'
      ? image.preview
      : image.kind === 'remove' || !initial.image_url
        ? null
        : staffMediaUrl(initial.image_url, appEnv().publicApiUrl, appEnv().supabaseUrl)
  const current: BannerDraft = {
    ...draft,
    title: draft.title.trim(),
    body: draft.body.trim(),
    link_url: optional(linkText),
    cta_label: optional(ctaText),
    image_url: popup && image.kind === 'keep' ? initial.image_url : null,
    frequency: popup ? draft.frequency : 'once',
    audience_days:
      draft.audience === 'new_users'
        ? daysText.trim() === ''
          ? Number.NaN
          : Number(daysText.trim())
        : initial.audience_days,
    starts_at: startsText.trim() === '' ? null : fromJakartaInput(startsText.trim()),
    ends_at: endsText.trim() === '' ? null : fromJakartaInput(endsText.trim()),
    min_app_version: optional(minText),
    max_app_version: optional(maxText),
    priority: priorityText.trim() === '' ? Number.NaN : Number(priorityText.trim()),
  }
  const problems = bannerProblems(current, { startsText, endsText, schemes })
  const text = useProblemText(checked ? problems : {}, schemes)
  const field = (name: string, error: string | undefined) => ({
    id: `${id}-${name}`,
    'aria-invalid': error ? true : undefined,
    'aria-describedby': `${id}-${name}-text`,
  })

  if (cropping) {
    return (
      <BannerImageCropper
        file={cropping}
        ratio={ratio}
        onCancel={() => setCropping(null)}
        onDone={(blob) => {
          setImage({ kind: 'new', blob, preview: URL.createObjectURL(blob) })
          setCropping(null)
        }}
      />
    )
  }

  return (
    <form
      className="grid gap-5 sm:grid-cols-[minmax(0,1fr)_15rem]"
      noValidate
      onSubmit={(event) => {
        event.preventDefault()
        setChecked(true)
        if (Object.keys(problems).length > 0) return
        save
          .mutateAsync({
            id: editing?.id ?? null,
            draft: current,
            image: popup && image.kind === 'new' ? image.blob : null,
          })
          .then(() => {
            toast.success(t('platform.banners.saved'))
            onClose()
          })
          .catch((error: unknown) => toast.error(bannerErrorText(error)))
      }}
    >
      <div className="flex min-w-0 flex-col gap-4">
        <fieldset className="flex flex-col gap-2">
          <legend className="mb-1 text-sm font-medium">{t('platform.banners.fields.display')}</legend>
          <RadioGroup
            value={draft.display}
            onValueChange={(value) => setDraft((item) => ({ ...item, display: value as BannerDisplay }))}
            className="flex flex-wrap gap-4"
          >
            {bannerDisplays.map((display) => (
              <label key={display} className="flex items-center gap-2 text-row">
                <RadioGroupItem value={display} />
                {t(`platform.banners.displayOptions.${display}`)}
              </label>
            ))}
          </RadioGroup>
        </fieldset>
        {popup ? (
          <BannerImageField
            shown={shownImage}
            ratio={ratio}
            disabled={save.isPending}
            onRatio={setRatio}
            onChoose={setCropping}
            onRemove={() => setImage({ kind: 'remove' })}
          />
        ) : null}
        <div className="flex flex-col gap-1.5">
          <Label htmlFor={`${id}-title`}>{t('platform.banners.fields.title')}</Label>
          <Input
            {...field('title', text.title)}
            autoFocus={!editing}
            maxLength={BANNER_TITLE_MAX}
            value={draft.title}
            onChange={(event) => setDraft((value) => ({ ...value, title: event.target.value }))}
          />
          <FieldText
            id={`${id}-title-text`}
            error={text.title}
            hint={`${draft.title.trim().length}/${BANNER_TITLE_MAX}`}
          />
        </div>
        <div className="flex flex-col gap-1.5">
          <Label htmlFor={`${id}-body`}>{t('platform.banners.fields.body')}</Label>
          <Textarea
            {...field('body', text.body)}
            rows={3}
            maxLength={BANNER_BODY_MAX}
            value={draft.body}
            onChange={(event) => setDraft((value) => ({ ...value, body: event.target.value }))}
          />
          <FieldText
            id={`${id}-body-text`}
            error={text.body}
            hint={`${draft.body.trim().length}/${BANNER_BODY_MAX}`}
          />
        </div>
        <div className="grid gap-4 sm:grid-cols-[minmax(0,1fr)_11rem]">
          <div className="flex flex-col gap-1.5">
            <Label htmlFor={`${id}-link`}>{t('platform.banners.fields.link')}</Label>
            <Input
              {...field('link', text.link)}
              inputMode="url"
              placeholder={t('platform.banners.hints.linkPlaceholder')}
              maxLength={BANNER_LINK_MAX}
              value={linkText}
              onChange={(event) => setLinkText(event.target.value)}
            />
            <FieldText
              id={`${id}-link-text`}
              error={text.link}
              hint={
                schemes.length > 0
                  ? t('platform.banners.hints.link', {
                      schemes: schemes.map((item) => `${item}://`).join(', '),
                    })
                  : t('platform.banners.hints.linkNoSchemes')
              }
            />
          </div>
          <div className="flex flex-col gap-1.5">
            <Label htmlFor={`${id}-cta`}>{t('platform.banners.fields.cta')}</Label>
            <Input
              {...field('cta', text.cta)}
              maxLength={BANNER_CTA_MAX}
              disabled={linkText.trim() === '' && ctaText.trim() === ''}
              value={ctaText}
              onChange={(event) => setCtaText(event.target.value)}
            />
            <FieldText id={`${id}-cta-text`} error={text.cta} hint={t('platform.banners.hints.cta')} />
          </div>
        </div>
        {popup ? (
          <fieldset className="flex flex-col gap-2">
            <legend className="mb-1 text-sm font-medium">{t('platform.banners.fields.frequency')}</legend>
            <RadioGroup
              value={draft.frequency}
              onValueChange={(value) =>
                setDraft((item) => ({ ...item, frequency: value as BannerFrequency }))
              }
              className="flex flex-wrap gap-4"
            >
              {bannerFrequencies.map((frequency) => (
                <label key={frequency} className="flex items-center gap-2 text-row">
                  <RadioGroupItem value={frequency} />
                  {t(`platform.banners.frequencies.${frequency}`)}
                </label>
              ))}
            </RadioGroup>
            <p className="text-xs text-muted-foreground">{t('platform.banners.hints.frequency')}</p>
          </fieldset>
        ) : null}
        <fieldset className="flex flex-col gap-2">
          <legend className="mb-1 text-sm font-medium">{t('platform.banners.fields.audience')}</legend>
          <RadioGroup
            value={draft.audience}
            onValueChange={(value) => setDraft((item) => ({ ...item, audience: value as BannerAudience }))}
            className="flex flex-wrap gap-4"
          >
            {bannerAudiences.map((audience) => (
              <label key={audience} className="flex items-center gap-2 text-row">
                <RadioGroupItem value={audience} />
                {t(`platform.banners.audiences.${audience}`)}
              </label>
            ))}
          </RadioGroup>
          {draft.audience === 'new_users' ? (
            <div className="flex max-w-60 flex-col gap-1.5">
              <Label htmlFor={`${id}-days`}>{t('platform.banners.fields.audienceDays')}</Label>
              <Input
                {...field('days', text.audienceDays)}
                inputMode="numeric"
                maxLength={2}
                value={daysText}
                onChange={(event) => setDaysText(event.target.value)}
              />
              <FieldText
                id={`${id}-days-text`}
                error={text.audienceDays}
                hint={t('platform.banners.hints.audienceDays', { max: BANNER_AUDIENCE_DAYS_MAX })}
              />
            </div>
          ) : null}
          <p className="text-xs text-muted-foreground">{t('platform.banners.hints.audience')}</p>
        </fieldset>
        <fieldset className="flex flex-col gap-2">
          <legend className="mb-1 text-sm font-medium">{t('platform.banners.fields.level')}</legend>
          <RadioGroup
            value={draft.level}
            onValueChange={(value) => setDraft((item) => ({ ...item, level: value as BannerLevel }))}
            className="flex flex-wrap gap-4"
          >
            {bannerLevels.map((level) => (
              <label key={level} className="flex items-center gap-2 text-row">
                <RadioGroupItem value={level} />
                {t(`platform.banners.levels.${level}`)}
              </label>
            ))}
          </RadioGroup>
        </fieldset>
        <div className="grid gap-4 sm:grid-cols-2">
          <div className="flex flex-col gap-1.5">
            <Label htmlFor={`${id}-starts`}>{t('platform.banners.fields.starts')}</Label>
            <Input
              {...field('starts', text.starts)}
              type="datetime-local"
              value={startsText}
              onChange={(event) => setStartsText(event.target.value)}
            />
            <FieldText
              id={`${id}-starts-text`}
              error={text.starts}
              hint={editing ? t('platform.banners.hints.startsEdit') : t('platform.banners.hints.startsNew')}
            />
          </div>
          <div className="flex flex-col gap-1.5">
            <Label htmlFor={`${id}-ends`}>{t('platform.banners.fields.ends')}</Label>
            <Input
              {...field('ends', text.ends)}
              type="datetime-local"
              value={endsText}
              onChange={(event) => setEndsText(event.target.value)}
            />
            <FieldText id={`${id}-ends-text`} error={text.ends} hint={t('platform.banners.hints.ends')} />
          </div>
        </div>
        <fieldset className="flex flex-col gap-2">
          <legend className="mb-1 text-sm font-medium">{t('platform.banners.fields.platforms')}</legend>
          <div className="flex flex-wrap gap-x-5 gap-y-2">
            {appPlatforms.map((platform) => (
              <label key={platform} className="flex items-center gap-2 text-row">
                <Checkbox
                  checked={draft.platforms.includes(platform)}
                  onCheckedChange={(value) =>
                    setDraft((item) => ({
                      ...item,
                      platforms:
                        value === true
                          ? appPlatforms.filter(
                              (entry) => entry === platform || item.platforms.includes(entry),
                            )
                          : item.platforms.filter((entry) => entry !== platform),
                    }))
                  }
                />
                {t(`platform.platforms.${platform}`)}
              </label>
            ))}
          </div>
          <p className="text-xs text-muted-foreground">{t('platform.banners.hints.platforms')}</p>
        </fieldset>
        <div className="grid gap-4 sm:grid-cols-3">
          <div className="flex flex-col gap-1.5">
            <Label htmlFor={`${id}-min`}>{t('platform.banners.fields.minVersion')}</Label>
            <Input
              {...field('min', text.minVersion)}
              inputMode="decimal"
              placeholder="2.4.0"
              value={minText}
              onChange={(event) => setMinText(event.target.value)}
            />
            <FieldText
              id={`${id}-min-text`}
              error={text.minVersion}
              hint={t('platform.banners.hints.version')}
            />
          </div>
          <div className="flex flex-col gap-1.5">
            <Label htmlFor={`${id}-max`}>{t('platform.banners.fields.maxVersion')}</Label>
            <Input
              {...field('max', text.maxVersion)}
              inputMode="decimal"
              value={maxText}
              onChange={(event) => setMaxText(event.target.value)}
            />
            <FieldText id={`${id}-max-text`} error={text.maxVersion} />
          </div>
          <div className="flex flex-col gap-1.5">
            <Label htmlFor={`${id}-priority`}>{t('platform.banners.fields.priority')}</Label>
            <Input
              {...field('priority', text.priority)}
              inputMode="numeric"
              value={priorityText}
              onChange={(event) => setPriorityText(event.target.value)}
            />
            <FieldText
              id={`${id}-priority-text`}
              error={text.priority}
              hint={t('platform.banners.hints.priority')}
            />
          </div>
        </div>
        <label className="flex items-start gap-2 text-row">
          <Switch
            className="mt-0.5"
            checked={draft.dismissible}
            onCheckedChange={(value) => setDraft((item) => ({ ...item, dismissible: value }))}
          />
          <span>
            <span className="block font-medium">{t('platform.banners.fields.dismissible')}</span>
            <span className="block text-xs text-muted-foreground">
              {t('platform.banners.hints.dismissible')}
            </span>
          </span>
        </label>
      </div>
      <div className="sm:sticky sm:top-0 sm:self-start">
        <BannerPreview
          display={draft.display}
          level={draft.level}
          title={current.title}
          body={current.body}
          link={current.link_url}
          cta={current.cta_label}
          image={popup ? shownImage : null}
          dismissible={draft.dismissible}
        />
      </div>
      <DialogFooter className="sm:col-span-2">
        <Button type="button" variant="outline" disabled={save.isPending} onClick={onClose}>
          {t('app.cancel')}
        </Button>
        <Button type="submit" disabled={save.isPending}>
          {save.isPending ? <LoaderCircleIcon className="animate-spin" /> : null}
          {t('app.save')}
        </Button>
      </DialogFooter>
    </form>
  )
}

export function BannerDialog({ editing, onClose }: { editing: AppBanner | null; onClose: () => void }) {
  const { t } = useTranslation()
  return (
    <Dialog open onOpenChange={(next) => !next && onClose()}>
      <DialogContent className="max-h-[92vh] overflow-y-auto sm:max-w-3xl" closeLabel={t('app.close')}>
        <DialogHeader>
          <DialogTitle>
            {editing ? t('platform.banners.editTitle') : t('platform.banners.addTitle')}
          </DialogTitle>
          <DialogDescription>{t('platform.banners.formHint')}</DialogDescription>
        </DialogHeader>
        <BannerForm editing={editing} onClose={onClose} />
      </DialogContent>
    </Dialog>
  )
}
