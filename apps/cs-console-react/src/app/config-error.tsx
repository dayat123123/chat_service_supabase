import { useTranslation } from 'react-i18next'

export function ConfigError({ problems }: { problems: string[] }) {
  const { t } = useTranslation()
  return (
    <main className="flex min-h-full items-center justify-center bg-background p-6">
      <div role="alert" className="w-full max-w-[360px]">
        <h1 className="text-lg font-semibold">{t('app.configTitle')}</h1>
        <p className="mt-1 text-row text-muted-foreground">
          {t('app.configBody', { fields: problems.join(', ') })}
        </p>
      </div>
    </main>
  )
}
