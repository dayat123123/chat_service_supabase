import type { VariantProps } from 'class-variance-authority'
import { LoaderCircleIcon } from 'lucide-react'
import { useTranslation } from 'react-i18next'

import { Button, type buttonVariants } from '@/components/ui/button'

import { useSetStatus } from '../hooks'

export function GoOnlineButton({
  variant = 'outline',
  size = 'sm',
}: Pick<VariantProps<typeof buttonVariants>, 'variant' | 'size'>) {
  const { t } = useTranslation()
  const setStatus = useSetStatus()
  return (
    <Button
      variant={variant}
      size={size}
      disabled={setStatus.isPending}
      onClick={() => setStatus.mutate({ status: 'online' })}
    >
      {setStatus.isPending ? <LoaderCircleIcon className="animate-spin" /> : null}
      {t('presence.goOnline')}
    </Button>
  )
}
