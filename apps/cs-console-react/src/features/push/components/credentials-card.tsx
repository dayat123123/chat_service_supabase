import {
  CircleCheckIcon,
  FileJsonIcon,
  KeyRoundIcon,
  LoaderCircleIcon,
  ShieldAlertIcon,
  Trash2Icon,
  TriangleAlertIcon,
  UploadIcon,
} from 'lucide-react'
import { useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { Button } from '@/components/ui/button'
import { Confirm } from '@/features/nasabah/components/confirm'
import { SettingsCard } from '@/features/settings/components/settings-ui'
import { errorText } from '@/lib/error-text'
import { toApiError } from '@/lib/errors'
import { stamp } from '@/lib/time'
import { cn } from '@/lib/utils'

import {
  checkKeyFile,
  keyProblems,
  shortKeyId,
  type KeyProblem,
  type ServiceAccountKey,
} from '../firebase-key'
import { credentialsLoading, useRemovePushCredentials, useSetPushCredentials } from '../hooks'
import type { PushCredentials, PushStatus } from '../types'

type Chosen = { name: string; key: ServiceAccountKey }

function Facts({ rows }: { rows: [string, string | null, 'plain'?][] }) {
  return (
    <dl className="grid grid-cols-[auto_minmax(0,1fr)] gap-x-4 gap-y-1 text-row">
      {rows.map(([label, value, style]) =>
        value ? (
          <div key={label} className="contents">
            <dt className="text-muted-foreground">{label}</dt>
            <dd className={cn('truncate', style !== 'plain' && 'font-mono text-xs leading-5')} title={value}>
              {value}
            </dd>
          </div>
        ) : null,
      )}
    </dl>
  )
}

function CurrentKey({ credentials, status }: { credentials: PushCredentials; status: PushStatus }) {
  const { t } = useTranslation()
  const loading = credentialsLoading(status)
  const verified = !loading && status.state === 'active'
  return (
    <div className="flex flex-col gap-2">
      <Facts
        rows={[
          [t('push.key.project'), credentials.project_id],
          [t('push.key.account'), credentials.client_email],
          [t('push.key.keyId'), shortKeyId(credentials.key_id)],
          [
            t('push.key.uploaded'),
            credentials.updated_by
              ? t('push.key.uploadedBy', {
                  time: stamp(credentials.updated_at),
                  name: credentials.updated_by,
                })
              : stamp(credentials.updated_at),
            'plain',
          ],
        ]}
      />
      {loading ? (
        <p className="flex items-center gap-2 text-row text-muted-foreground">
          <LoaderCircleIcon className="size-4 animate-spin" aria-hidden="true" />
          {t('push.key.loading')}
        </p>
      ) : verified ? (
        <p className="flex items-center gap-2 text-row text-success">
          <CircleCheckIcon className="size-4" aria-hidden="true" />
          {t('push.key.verified')}
        </p>
      ) : null}
    </div>
  )
}

function Steps() {
  const { t } = useTranslation()
  return (
    <ol className="flex list-decimal flex-col gap-1.5 pl-5 text-row">
      <li>{t('push.key.steps.console')}</li>
      <li>{t('push.key.steps.generate')}</li>
      <li>{t('push.key.steps.upload')}</li>
    </ol>
  )
}

function Review({
  chosen,
  current,
  saving,
  onSave,
  onCancel,
}: {
  chosen: Chosen
  current: PushCredentials | null
  saving: boolean
  onSave: (replaceProject: boolean) => void
  onCancel: () => void
}) {
  const { t } = useTranslation()
  const otherProject = current !== null && current.project_id !== chosen.key.project_id
  return (
    <div
      className="flex flex-col gap-3 rounded-lg border bg-subtle p-3"
      aria-label={t('push.key.reviewTitle')}
      role="group"
    >
      <p className="flex items-center gap-2 text-panel font-semibold">
        <FileJsonIcon className="size-4 text-muted-foreground" aria-hidden="true" />
        {t('push.key.reviewTitle')}
      </p>
      <Facts
        rows={[
          [t('push.key.file'), chosen.name],
          [t('push.key.project'), chosen.key.project_id],
          [t('push.key.account'), chosen.key.client_email],
          [t('push.key.keyId'), shortKeyId(chosen.key.private_key_id)],
        ]}
      />
      {otherProject ? (
        <p role="alert" className="flex items-start gap-2 text-row text-warning">
          <TriangleAlertIcon className="mt-0.5 size-4 shrink-0" aria-hidden="true" />
          {t('push.key.otherProject', { project: current.project_id })}
        </p>
      ) : null}
      <div className="flex flex-wrap gap-2">
        <Button size="sm" disabled={saving} onClick={() => onSave(otherProject)}>
          {saving ? <LoaderCircleIcon className="animate-spin" /> : <KeyRoundIcon />}
          {otherProject ? t('push.key.saveOtherProject') : t('push.key.save')}
        </Button>
        <Button size="sm" variant="ghost" disabled={saving} onClick={onCancel}>
          {t('app.cancel')}
        </Button>
      </div>
    </div>
  )
}

export function CredentialsCard({ status }: { status: PushStatus }) {
  const { t } = useTranslation()
  const save = useSetPushCredentials()
  const remove = useRemovePushCredentials()
  const fileInput = useRef<HTMLInputElement>(null)
  const [dragging, setDragging] = useState(false)
  const [checking, setChecking] = useState(false)
  const [problem, setProblem] = useState<string | null>(null)
  const [chosen, setChosen] = useState<Chosen | null>(null)
  const [confirmRemove, setConfirmRemove] = useState(false)
  const current = status.credentials

  const choose = async (file: File | undefined) => {
    if (!file || checking) return
    setProblem(null)
    setChosen(null)
    setChecking(true)
    try {
      const check = await checkKeyFile(file)
      if (check.ok) setChosen({ name: file.name, key: check.key })
      else setProblem(t(`push.key.problems.${check.problem}`))
    } finally {
      setChecking(false)
    }
  }

  const submit = (replaceProject: boolean) => {
    if (!chosen) return
    setProblem(null)
    save
      .mutateAsync({ key: chosen.key, replaceProject })
      .then(() => {
        setChosen(null)
        toast.success(t('push.key.saved'))
      })
      .catch((error: unknown) => {
        const e = toApiError(error)
        if (e.code === 'invalid_push_credentials' && keyProblems.includes(e.detail as KeyProblem)) {
          setProblem(t(`push.key.problems.${e.detail as KeyProblem}`))
        } else if (e.code === 'push_project_changed') {
          setProblem(t('push.key.projectChanged', { project: e.detail ?? '-' }))
        } else {
          setProblem(errorText(error))
        }
      })
  }

  return (
    <SettingsCard title={t('push.key.title')} subtitle={t('push.key.subtitle')}>
      <div
        className={cn(
          'flex flex-col gap-3 rounded-lg border border-dashed p-3 transition-colors',
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
          void choose(event.dataTransfer.files[0])
        }}
      >
        {current ? <CurrentKey credentials={current} status={status} /> : <Steps />}
        <input
          ref={fileInput}
          type="file"
          accept=".json,application/json"
          className="sr-only"
          tabIndex={-1}
          aria-hidden="true"
          onChange={(event) => {
            void choose(event.target.files?.[0])
            event.target.value = ''
          }}
        />
        {chosen ? (
          <Review
            chosen={chosen}
            current={current}
            saving={save.isPending}
            onSave={submit}
            onCancel={() => setChosen(null)}
          />
        ) : (
          <div className="flex flex-wrap items-center gap-2">
            <Button
              size="sm"
              variant={current ? 'outline' : 'default'}
              disabled={checking}
              onClick={() => fileInput.current?.click()}
            >
              {checking ? <LoaderCircleIcon className="animate-spin" /> : <UploadIcon />}
              {current ? t('push.key.replace') : t('push.key.choose')}
            </Button>
            {current ? (
              <Button size="sm" variant="ghost" onClick={() => setConfirmRemove(true)}>
                <Trash2Icon />
                {t('push.key.remove')}
              </Button>
            ) : null}
            <span className="text-xs text-muted-foreground">{t('push.key.drop')}</span>
          </div>
        )}
        {problem ? (
          <p role="alert" className="flex items-start gap-2 text-row text-destructive">
            <ShieldAlertIcon className="mt-0.5 size-4 shrink-0" aria-hidden="true" />
            {problem}
          </p>
        ) : null}
      </div>
      <ul className="flex flex-col gap-1 text-xs text-muted-foreground">
        <li>{t('push.key.secret')}</li>
        <li>{t('push.key.apns')}</li>
        <li>{t('push.key.app')}</li>
      </ul>
      <Confirm
        open={confirmRemove}
        title={t('push.key.removeTitle')}
        body={t('push.key.removeBody', { hours: status.ttl_hours })}
        action={t('push.key.remove')}
        pending={remove.isPending}
        destructive
        onClose={() => setConfirmRemove(false)}
        onConfirm={() =>
          void remove
            .mutateAsync()
            .then(() => {
              setConfirmRemove(false)
              toast.success(t('push.key.removed'))
            })
            .catch((error: unknown) => {
              setConfirmRemove(false)
              toast.error(errorText(error))
            })
        }
      />
    </SettingsCard>
  )
}
