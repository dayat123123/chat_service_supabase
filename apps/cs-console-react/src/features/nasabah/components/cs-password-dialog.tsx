import {
  CheckIcon,
  CopyIcon,
  EyeIcon,
  EyeOffIcon,
  KeyRoundIcon,
  LoaderCircleIcon,
  ShieldCheckIcon,
  WandSparklesIcon,
} from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { Button } from '@/components/ui/button'
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
import { errorText } from '@/lib/error-text'

import { useSetCsPassword } from '../hooks'
import { generatePassword, passwordOk } from '../logic'

function useCopy() {
  const { t } = useTranslation()
  const [copied, setCopied] = useState(false)
  const copy = (value: string) => {
    void navigator.clipboard
      .writeText(value)
      .then(() => {
        setCopied(true)
        toast.success(t('nasabah.csUsers.toast.copied'))
      })
      .catch(() => {
        setCopied(false)
        toast.error(t('nasabah.csUsers.toast.copyFailed'))
      })
  }
  return { copied, copy, reset: () => setCopied(false) }
}

function PasswordForm({ loginId, onDone }: { loginId: string; onDone: () => void }) {
  const { t } = useTranslation()
  const save = useSetCsPassword()
  const { copied, copy, reset } = useCopy()
  const [password, setPassword] = useState('')
  const [visible, setVisible] = useState(false)
  const [checked, setChecked] = useState(false)
  const invalid = checked && !passwordOk(password)

  return (
    <form
      className="flex flex-col gap-4"
      noValidate
      onSubmit={(event) => {
        event.preventDefault()
        setChecked(true)
        if (!passwordOk(password)) return
        save.mutate(
          { loginId, password },
          {
            onSuccess: () => {
              toast.success(t('nasabah.csUsers.toast.password', { loginId }))
              onDone()
            },
            onError: (error) => toast.error(errorText(error)),
          },
        )
      }}
    >
      <DialogDescription>{t('nasabah.csUsers.passwordDialog.hint')}</DialogDescription>
      <div className="flex flex-col gap-1.5">
        <Label htmlFor="cs-new-password">{t('nasabah.csUsers.passwordDialog.label')}</Label>
        <div className="flex gap-2">
          <div className="relative flex-1">
            <Input
              id="cs-new-password"
              type={visible ? 'text' : 'password'}
              autoComplete="new-password"
              spellCheck={false}
              maxLength={20}
              autoFocus
              className="pr-9 font-mono"
              aria-invalid={invalid ? true : undefined}
              aria-describedby="cs-new-password-rule"
              value={password}
              onChange={(event) => {
                setPassword(event.target.value)
                reset()
              }}
            />
            <Button
              type="button"
              variant="ghost"
              size="icon-sm"
              className="absolute top-0.5 right-0.5"
              aria-label={
                visible ? t('nasabah.csUsers.passwordDialog.hide') : t('nasabah.csUsers.passwordDialog.show')
              }
              aria-pressed={visible}
              onClick={() => setVisible((value) => !value)}
            >
              {visible ? <EyeOffIcon /> : <EyeIcon />}
            </Button>
          </div>
          <Button
            type="button"
            variant="outline"
            onClick={() => {
              setPassword(generatePassword())
              setVisible(true)
              reset()
            }}
          >
            <WandSparklesIcon />
            {t('nasabah.csUsers.passwordDialog.generate')}
          </Button>
          <Button
            type="button"
            variant="outline"
            size="icon"
            disabled={!password}
            aria-label={t('nasabah.csUsers.passwordDialog.copy')}
            onClick={() => copy(password)}
          >
            {copied ? <CheckIcon /> : <CopyIcon />}
          </Button>
        </div>
        <p
          id="cs-new-password-rule"
          role={invalid ? 'alert' : undefined}
          className={invalid ? 'text-xs text-destructive' : 'text-xs text-muted-foreground'}
        >
          {t('nasabah.csUsers.passwordDialog.problem')}
        </p>
      </div>
      <DialogFooter>
        <Button type="button" variant="ghost" disabled={save.isPending} onClick={onDone}>
          {t('app.cancel')}
        </Button>
        <Button type="submit" disabled={save.isPending}>
          {save.isPending ? <LoaderCircleIcon className="animate-spin" /> : <KeyRoundIcon />}
          {t('nasabah.csUsers.passwordDialog.submit')}
        </Button>
      </DialogFooter>
    </form>
  )
}

export function CsPasswordDialog({ loginId, onClose }: { loginId: string | null; onClose: () => void }) {
  const { t } = useTranslation()
  return (
    <Dialog open={loginId !== null} onOpenChange={(next) => !next && onClose()}>
      <DialogContent className="sm:max-w-lg" closeLabel={t('app.close')}>
        <DialogHeader>
          <DialogTitle>{t('nasabah.csUsers.passwordDialog.title', { loginId: loginId ?? '' })}</DialogTitle>
        </DialogHeader>
        {loginId ? <PasswordForm key={loginId} loginId={loginId} onDone={onClose} /> : null}
      </DialogContent>
    </Dialog>
  )
}

export type IssuedCsPassword = { loginId: string; password: string }

export function TemporaryPasswordDialog({
  issued,
  onClose,
}: {
  issued: IssuedCsPassword | null
  onClose: () => void
}) {
  const { t } = useTranslation()
  const { copied, copy, reset } = useCopy()
  return (
    <Dialog
      open={issued !== null}
      onOpenChange={(open) => {
        if (open) return
        reset()
        onClose()
      }}
    >
      <DialogContent className="sm:max-w-md" onInteractOutside={(event) => event.preventDefault()}>
        {issued ? (
          <>
            <DialogHeader>
              <ShieldCheckIcon className="size-5 text-success" aria-hidden="true" />
              <DialogTitle>{t('nasabah.csUsers.temporary.title', { loginId: issued.loginId })}</DialogTitle>
              <DialogDescription>{t('nasabah.csUsers.temporary.body')}</DialogDescription>
            </DialogHeader>
            <dl className="flex flex-col gap-1 text-sm">
              <dt className="text-xs font-medium text-muted-foreground">
                {t('nasabah.csUsers.temporary.label')}
              </dt>
              <dd className="flex items-center gap-2">
                <code className="flex-1 rounded-md bg-muted px-2 py-1.5 font-mono text-base tracking-wider select-all">
                  {issued.password}
                </code>
                <Button type="button" variant="outline" size="sm" onClick={() => copy(issued.password)}>
                  {copied ? <CheckIcon /> : <CopyIcon />}
                  {copied ? t('app.copied') : t('app.copy')}
                </Button>
              </dd>
            </dl>
            <DialogFooter>
              <Button
                type="button"
                onClick={() => {
                  reset()
                  onClose()
                }}
              >
                {t('nasabah.csUsers.temporary.done')}
              </Button>
            </DialogFooter>
          </>
        ) : null}
      </DialogContent>
    </Dialog>
  )
}
