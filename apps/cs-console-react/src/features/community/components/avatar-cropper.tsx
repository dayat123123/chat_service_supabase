import { LoaderCircleIcon, ZoomInIcon, ZoomOutIcon } from 'lucide-react'
import { useEffect, useId, useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'

import { Button } from '@/components/ui/button'
import { cn } from '@/lib/utils'

import {
  AVATAR_OUTPUT,
  avatarFrame,
  clampFrameCrop,
  type CropFrame,
  type CropState,
  frameScale,
  initialCrop,
  MAX_ZOOM,
  renderCrop,
  SMALL_PHOTO,
} from '../avatar-crop'

const STEP = 8
const ZOOM_STEP = 1.1
const avatarOutput: CropFrame = { width: AVATAR_OUTPUT, height: AVATAR_OUTPUT }

export function AvatarCropper({
  file,
  onCancel,
  onDone,
  frame = avatarFrame,
  output = avatarOutput,
  round = true,
  smallBelow = SMALL_PHOTO,
  hint,
  doneLabel,
}: {
  file: File
  onCancel: () => void
  onDone: (blob: Blob) => void
  frame?: CropFrame
  output?: CropFrame
  round?: boolean
  smallBelow?: number
  hint?: string
  doneLabel?: string
}) {
  const { t } = useTranslation()
  const hintId = useId()
  const [url] = useState(() => URL.createObjectURL(file))
  const [image, setImage] = useState<HTMLImageElement | null>(null)
  const [failed, setFailed] = useState(false)
  const [crop, setCrop] = useState<CropState>(initialCrop)
  const [busy, setBusy] = useState(false)
  const area = useRef<HTMLDivElement>(null)
  const drag = useRef<{ pointer: number; x: number; y: number; start: CropState } | null>(null)

  useEffect(() => () => URL.revokeObjectURL(url), [url])

  const update = (next: CropState) => {
    if (image) setCrop(clampFrameCrop(next, image.naturalWidth, image.naturalHeight, frame))
  }

  const zoomBy = (factor: number) => update({ ...crop, zoom: crop.zoom * factor })

  useEffect(() => {
    const element = area.current
    if (!element || !image) return
    const onWheel = (event: WheelEvent) => {
      event.preventDefault()
      setCrop((current) =>
        clampFrameCrop(
          { ...current, zoom: current.zoom * (event.deltaY < 0 ? ZOOM_STEP : 1 / ZOOM_STEP) },
          image.naturalWidth,
          image.naturalHeight,
          frame,
        ),
      )
    }
    element.addEventListener('wheel', onWheel, { passive: false })
    return () => element.removeEventListener('wheel', onWheel)
  }, [image, frame])

  const scale = image ? frameScale(image.naturalWidth, image.naturalHeight, frame) * crop.zoom : 1
  const small = image ? Math.min(image.naturalWidth, image.naturalHeight) < smallBelow : false

  if (failed) {
    return (
      <div className="flex flex-col gap-3">
        <p role="alert" className="text-row text-destructive">
          {t('community.photoUnreadable')}
        </p>
        <Button type="button" variant="outline" size="sm" className="self-start" onClick={onCancel}>
          {t('app.cancel')}
        </Button>
      </div>
    )
  }

  return (
    <div className="flex flex-col items-center gap-3">
      <div
        ref={area}
        role="group"
        tabIndex={0}
        aria-label={t('community.cropArea')}
        aria-describedby={hintId}
        className="relative cursor-grab touch-none overflow-hidden rounded-xl bg-muted outline-none select-none focus-visible:ring-2 focus-visible:ring-ring/50 active:cursor-grabbing"
        style={{ width: frame.width, height: frame.height }}
        onPointerDown={(event) => {
          event.currentTarget.setPointerCapture(event.pointerId)
          drag.current = { pointer: event.pointerId, x: event.clientX, y: event.clientY, start: crop }
        }}
        onPointerMove={(event) => {
          const current = drag.current
          if (!current || current.pointer !== event.pointerId) return
          update({
            ...current.start,
            x: current.start.x + event.clientX - current.x,
            y: current.start.y + event.clientY - current.y,
          })
        }}
        onPointerUp={() => (drag.current = null)}
        onPointerCancel={() => (drag.current = null)}
        onKeyDown={(event) => {
          const moves: Record<string, [number, number]> = {
            ArrowLeft: [STEP, 0],
            ArrowRight: [-STEP, 0],
            ArrowUp: [0, STEP],
            ArrowDown: [0, -STEP],
          }
          const move = moves[event.key]
          if (move) {
            event.preventDefault()
            update({ ...crop, x: crop.x + move[0], y: crop.y + move[1] })
          } else if (event.key === '+' || event.key === '=') {
            event.preventDefault()
            zoomBy(ZOOM_STEP)
          } else if (event.key === '-') {
            event.preventDefault()
            zoomBy(1 / ZOOM_STEP)
          }
        }}
      >
        <img
          src={url}
          alt=""
          draggable={false}
          onLoad={(event) => setImage(event.currentTarget)}
          onError={() => setFailed(true)}
          className="pointer-events-none absolute top-1/2 left-1/2 max-w-none"
          style={
            image
              ? {
                  width: image.naturalWidth * scale,
                  height: image.naturalHeight * scale,
                  transform: `translate(calc(-50% + ${crop.x}px), calc(-50% + ${crop.y}px))`,
                }
              : { opacity: 0 }
          }
        />
        {!image ? (
          <LoaderCircleIcon
            className="absolute top-1/2 left-1/2 size-6 -translate-1/2 animate-spin text-muted-foreground"
            aria-hidden="true"
          />
        ) : null}
        <div
          aria-hidden="true"
          className={cn(
            'pointer-events-none absolute inset-0 ring-1 ring-background/70',
            round ? 'rounded-full shadow-[0_0_0_999px_var(--scrim)]' : 'rounded-xl ring-inset',
          )}
        />
      </div>
      <div className="flex items-center gap-2" style={{ width: Math.max(frame.width, 200) }}>
        <ZoomOutIcon className="size-4 shrink-0 text-muted-foreground" aria-hidden="true" />
        <input
          type="range"
          min={1}
          max={MAX_ZOOM}
          step={0.01}
          value={crop.zoom}
          disabled={!image}
          aria-label={t('community.zoom')}
          className="min-w-0 flex-1 accent-primary"
          onChange={(event) => update({ ...crop, zoom: Number(event.target.value) })}
        />
        <ZoomInIcon className="size-4 shrink-0 text-muted-foreground" aria-hidden="true" />
      </div>
      <p id={hintId} className="text-center text-xs text-muted-foreground">
        {hint ?? t('community.cropHint')}
      </p>
      {small ? <p className="text-center text-xs text-warning">{t('community.photoSmall')}</p> : null}
      <div className="flex gap-2">
        <Button type="button" variant="outline" size="sm" disabled={busy} onClick={onCancel}>
          {t('app.cancel')}
        </Button>
        <Button
          type="button"
          size="sm"
          disabled={!image || busy}
          onClick={() => {
            if (!image) return
            setBusy(true)
            void renderCrop(image, crop, frame, output)
              .then(onDone)
              .catch(() => setFailed(true))
              .finally(() => setBusy(false))
          }}
        >
          {busy ? <LoaderCircleIcon className="animate-spin" /> : null}
          {doneLabel ?? t('community.usePhoto')}
        </Button>
      </div>
    </div>
  )
}
