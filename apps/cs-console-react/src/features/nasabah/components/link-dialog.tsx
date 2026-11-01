import { LoaderCircleIcon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { Button } from '@/components/ui/button'
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { errorText } from '@/lib/error-text'

import { useAccountCatalog, useSubmitApproval } from '../hooks'
import { approvalPayload, fitsLinkParameter, formFromUser, linkChanges } from '../logic'
import type { OnlineUser } from '../types'
import { AccountPicker } from './account-picker'

function LinkForm({
  user,
  links,
  names,
  onDone,
}: {
  user: OnlineUser
  links: string[]
  names: Record<string, string>
  onDone: () => void
}) {
  const { t } = useTranslation()
  const catalog = useAccountCatalog(true)
  const submit = useSubmitApproval()
  const [selected, setSelected] = useState<string[]>(links)
  const form = { ...formFromUser(user, links), links: selected }
  const changes = linkChanges(2, form, links)
  const unchanged = changes.link.length === 0 && changes.unlink.length === 0
  const tooMany = !fitsLinkParameter(changes.link) || !fitsLinkParameter(changes.unlink)

  return (
    <form
      className="flex min-h-0 flex-col gap-3"
      onSubmit={(event) => {
        event.preventDefault()
        if (unchanged || tooMany) return
        submit.mutate(approvalPayload(2, form, links), {
          onSuccess: () => {
            toast.success(t('nasabah.toast.submitted'))
            onDone()
          },
          onError: (error) => toast.error(errorText(error)),
        })
      }}
    >
      <AccountPicker
        catalog={catalog}
        linked={links}
        names={names}
        selected={selected}
        onChange={setSelected}
        showEmptyLinked
        className="max-h-[60vh]"
      />
      {tooMany ? (
        <p role="alert" className="text-xs text-destructive">
          {t('nasabah.form.problems.links')}
        </p>
      ) : null}
      <DialogFooter>
        <Button type="button" variant="ghost" disabled={submit.isPending} onClick={onDone}>
          {t('app.cancel')}
        </Button>
        <Button type="submit" disabled={unchanged || tooMany || submit.isPending}>
          {submit.isPending ? <LoaderCircleIcon className="animate-spin" /> : null}
          {t('nasabah.link.submit')}
        </Button>
      </DialogFooter>
    </form>
  )
}

export function LinkDialog({
  user,
  links,
  names = {},
  open,
  onClose,
}: {
  user: OnlineUser
  links: string[]
  names?: Record<string, string>
  open: boolean
  onClose: () => void
}) {
  const { t } = useTranslation()
  return (
    <Dialog open={open} onOpenChange={(next) => !next && onClose()}>
      <DialogContent className="sm:max-w-xl" closeLabel={t('app.close')} aria-describedby={undefined}>
        <DialogHeader>
          <DialogTitle>{t('nasabah.link.title', { loginId: user.LoginId })}</DialogTitle>
        </DialogHeader>
        {open ? <LinkForm user={user} links={links} names={names} onDone={onClose} /> : null}
      </DialogContent>
    </Dialog>
  )
}
