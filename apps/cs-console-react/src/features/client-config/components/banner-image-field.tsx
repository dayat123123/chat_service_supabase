import { ImageIcon, ImagePlusIcon, Trash2Icon } from 'lucide-react'
import { useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { Button } from '@/components/ui/button'
import { RadioGroup, RadioGroupItem } from '@/components/ui/controls'
import { avatarTypes, MAX_PHOTO_BYTES } from '@/features/community/avatar-crop'
import { AvatarCropper } from '@/features/community/components/avatar-cropper'
import { cn } from '@/lib/utils'

import { ratioFrames } from '../logic'
import { bannerRatios, type BannerRatio } from '../types'

export type BannerImage = { kind: 'keep' } | { kind: 'new'; blob: Blob; preview: string } | { kind: 'remove' }

export function BannerImageCropper({
  file,
  ratio,
  onCancel,
  onDone,
}: {
  file: File
  ratio: BannerRatio
  onCancel: () => void
  onDone: (blob: Blob) => void
}) {
  const { t } = useTranslation()
  return (
    <div className="flex flex-col gap-3">
      <p className="text-sm font-medium">{t('platform.banners.image.cropTitle')}</p>
      <AvatarCropper
        key={`${file.name}-${file.lastModified}-${ratio}`}
        file={file}
        frame={ratioFrames[ratio].frame}
        output={ratioFrames[ratio].output}
        round={false}
        smallBelow={480}
        hint={t('platform.banners.image.cropHint')}
        doneLabel={t('platform.banners.image.use')}
        onCancel={onCancel}
        onDone={onDone}
      />
    </div>
  )
}

export function BannerImageField({
  shown,
  ratio,
  disabled,
  onRatio,
  onChoose,
  onRemove,
}: {
  shown: string | null
  ratio: BannerRatio
  disabled: boolean
  onRatio: (ratio: BannerRatio) => void
  onChoose: (file: File) => void
  onRemove: () => void
}) {
  const { t } = useTranslation()
  const fileInput = useRef<HTMLInputElement>(null)
  const [dragging, setDragging] = useState(false)
  const choose = (file: File | undefined) => {
    if (!file) return
    if (!avatarTypes.includes(file.type)) {
      toast.error(t('platform.banners.image.type'))
      return
    }
    if (file.size > MAX_PHOTO_BYTES) {
      toast.error(t('platform.banners.image.tooLarge'))
      return
    }
    onChoose(file)
  }
  return (
    <fieldset className="flex flex-col gap-2">
      <legend className="mb-1 text-sm font-medium">{t('platform.banners.fields.image')}</legend>
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
          choose(event.dataTransfer.files[0])
        }}
      >
        <div className="grid size-16 shrink-0 place-items-center overflow-hidden rounded-md bg-muted">
          {shown ? (
            <img src={shown} alt={t('platform.banners.image.alt')} className="size-full object-cover" />
          ) : (
            <ImageIcon className="size-5 text-muted-foreground" aria-hidden="true" />
          )}
        </div>
        <div className="flex min-w-0 flex-col gap-2">
          <div className="flex flex-wrap gap-1.5">
            <Button
              type="button"
              variant="outline"
              size="sm"
              disabled={disabled}
              onClick={() => fileInput.current?.click()}
            >
              <ImagePlusIcon />
              {shown ? t('platform.banners.image.replace') : t('platform.banners.image.choose')}
            </Button>
            {shown ? (
              <Button type="button" variant="ghost" size="sm" disabled={disabled} onClick={onRemove}>
                <Trash2Icon />
                {t('platform.banners.image.remove')}
              </Button>
            ) : null}
          </div>
          <RadioGroup
            aria-label={t('platform.banners.fields.ratio')}
            value={ratio}
            onValueChange={(value) => onRatio(value as BannerRatio)}
            className="flex flex-wrap gap-4"
          >
            {bannerRatios.map((item) => (
              <label key={item} className="flex items-center gap-2 text-xs">
                <RadioGroupItem value={item} />
                {t(`platform.banners.ratios.${item}`)}
              </label>
            ))}
          </RadioGroup>
        </div>
      </div>
      <p className="text-xs text-muted-foreground">
        {t('platform.banners.hints.image', { ratio: t(`platform.banners.ratios.${ratio}`) })}
      </p>
      <input
        ref={fileInput}
        type="file"
        hidden
        data-testid="banner-image-input"
        accept={avatarTypes.join(',')}
        onChange={(event) => {
          choose(event.target.files?.[0])
          event.target.value = ''
        }}
      />
    </fieldset>
  )
}
