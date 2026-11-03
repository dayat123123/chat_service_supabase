import i18n from 'i18next'
import { initReactI18next } from 'react-i18next'

import { logger } from '@/lib/logger'
import { readLocal } from '@/lib/storage'

import { id } from './id'

export const languages = ['id', 'en'] as const
export type Language = (typeof languages)[number]

declare module 'i18next' {
  interface CustomTypeOptions {
    defaultNS: 'translation'
    resources: { translation: typeof id }
  }
}

export function storedLanguage(): Language {
  return readLocal('language') === 'en' ? 'en' : 'id'
}

void i18n.use(initReactI18next).init({
  resources: { id: { translation: id } },
  lng: storedLanguage(),
  fallbackLng: 'id',
  interpolation: { escapeValue: false },
  returnNull: false,
})

export async function loadLanguage(language: Language) {
  if (i18n.hasResourceBundle(language, 'translation')) return
  const { en } = await import('./en')
  i18n.addResourceBundle('en', 'translation', en)
}

export async function switchLanguage(language: Language) {
  await loadLanguage(language)
  await i18n.changeLanguage(language)
}

export async function prepareLanguage() {
  try {
    await loadLanguage(storedLanguage())
  } catch (error) {
    logger.warn('Terjemahan bahasa Inggris gagal dimuat', error)
    await i18n.changeLanguage('id')
  }
}

i18n.on('languageChanged', (language) => {
  document.documentElement.lang = language
})
document.documentElement.lang = i18n.language

export default i18n
