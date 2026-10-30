import { AlertTriangleIcon } from 'lucide-react'
import { useTranslation } from 'react-i18next'

export function ConfigError({ problems }: { problems: string[] }) {
  const { t } = useTranslation()
  return (
    <main className="flex min-h-full items-center justify-center p-6">
      <div role="alert" className="max-w-md rounded-xl border bg-card p-6 text-center shadow-sm">
        <AlertTriangleIcon className="mx-auto size-8 text-destructive" aria-hidden="true" />
        <h1 className="mt-3 text-lg font-semibold">{t('app.configTitle')}</h1>
        <p className="mt-1 text-sm text-muted-foreground">
          {t('app.configBody', { fields: problems.join(', ') })}
        </p>
      </div>
    </main>
  )
}
