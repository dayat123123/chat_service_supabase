import i18n from 'i18next'
import { initReactI18next } from 'react-i18next'

import { logger } from '@/lib/logger'
import { readLocal } from '@/lib/storage'

import type { evidence } from './evidence/id'
import { id } from './id'
import type { moderation } from './moderation/id'
import type { platform } from './platform/id'
import type { policy } from './policy/id'

export const languages = ['id', 'en'] as const
export type Language = (typeof languages)[number]

type Bundles = {
  platform: typeof platform
  policy: typeof policy
  moderation: typeof moderation
  evidence: typeof evidence
}
export type Bundle = keyof Bundles

declare module 'i18next' {
  interface CustomTypeOptions {
    defaultNS: 'translation'
    resources: { translation: typeof id & Bundles }
  }
}

const bundleLoaders: { [B in Bundle]: Record<Language, () => Promise<Bundles[B]>> } = {
  platform: {
    id: () => import('./platform/id').then((module) => module.platform),
    en: () => import('./platform/en').then((module) => module.platform),
  },
  policy: {
    id: () => import('./policy/id').then((module) => module.policy),
    en: () => import('./policy/en').then((module) => module.policy),
  },
  moderation: {
    id: () => import('./moderation/id').then((module) => module.moderation),
    en: () => import('./moderation/en').then((module) => module.moderation),
  },
  evidence: {
    id: () => import('./evidence/id').then((module) => module.evidence),
    en: () => import('./evidence/en').then((module) => module.evidence),
  },
}

const wanted = new Set<Bundle>()
const loadedBundles = new Set<string>()

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

const englishBase = { loaded: false }

export async function loadLanguage(language: Language) {
  if (language === 'id' || englishBase.loaded) return
  const { en } = await import('./en')
  i18n.addResourceBundle('en', 'translation', en, true, false)
  englishBase.loaded = true
}

async function loadBundle(bundle: Bundle, language: Language) {
  const key = `${language}:${bundle}`
  if (loadedBundles.has(key)) return
  if (language === 'en') await loadLanguage('en')
  const strings = await bundleLoaders[bundle][language]()
  i18n.addResourceBundle(language, 'translation', { [bundle]: strings }, true, true)
  loadedBundles.add(key)
}

const activeLanguage = (): Language => (i18n.language === 'en' ? 'en' : 'id')

export async function loadStrings(...bundles: Bundle[]) {
  bundles.forEach((bundle) => wanted.add(bundle))
  const language = activeLanguage()
  await Promise.all(bundles.map((bundle) => loadBundle(bundle, 'id')))
  if (language === 'en') {
    try {
      await Promise.all(bundles.map((bundle) => loadBundle(bundle, 'en')))
    } catch (error) {
      logger.warn('Terjemahan bahasa Inggris gagal dimuat', error)
    }
  }
}

export function withStrings<T>(load: () => Promise<T>, ...bundles: Bundle[]) {
  return () => Promise.all([load(), loadStrings(...bundles)]).then(([module]) => module)
}

export async function switchLanguage(language: Language) {
  await loadLanguage(language)
  await Promise.all([...wanted].map((bundle) => loadBundle(bundle, language)))
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
