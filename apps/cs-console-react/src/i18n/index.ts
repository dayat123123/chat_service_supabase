import i18n from 'i18next'
import { initReactI18next } from 'react-i18next'

import { readLocal } from '@/lib/storage'

import { en } from './en'
import { id } from './id'

export const languages = ['id', 'en'] as const
export type Language = (typeof languages)[number]

declare module 'i18next' {
  interface CustomTypeOptions {
    defaultNS: 'translation'
    resources: { translation: typeof id }
  }
}

void i18n.use(initReactI18next).init({
  resources: { id: { translation: id }, en: { translation: en } },
  lng: readLocal('language') === 'en' ? 'en' : 'id',
  fallbackLng: 'id',
  interpolation: { escapeValue: false },
  returnNull: false,
})

i18n.on('languageChanged', (language) => {
  document.documentElement.lang = language
})
document.documentElement.lang = i18n.language

export default i18n
