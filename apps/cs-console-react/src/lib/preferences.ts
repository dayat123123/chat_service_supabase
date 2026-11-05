import { create } from 'zustand'

import i18n, { switchLanguage, type Language } from '@/i18n'
import { logger } from '@/lib/logger'
import { readLocal, writeLocal } from '@/lib/storage'

export type Theme = 'system' | 'light' | 'dark'
export type Density = 'comfortable' | 'compact'
export type TicketAlerts = 'all' | 'high' | 'off'

type Preferences = {
  theme: Theme
  density: Density
  language: Language
  ticketAlerts: TicketAlerts
  infoPanelOpen: boolean
  setTheme: (theme: Theme) => void
  setDensity: (density: Density) => void
  setLanguage: (language: Language) => void
  setTicketAlerts: (mode: TicketAlerts) => void
  setInfoPanelOpen: (open: boolean) => void
}

const media = () => window.matchMedia('(prefers-color-scheme: dark)')

export function applyTheme(theme: Theme) {
  const dark = theme === 'dark' || (theme === 'system' && media().matches)
  document.documentElement.classList.toggle('dark', dark)
}

export function applyDensity(density: Density) {
  if (density === 'compact') document.documentElement.dataset.density = 'compact'
  else delete document.documentElement.dataset.density
}

function readTheme(): Theme {
  const value = readLocal('theme')
  return value === 'dark' || value === 'system' ? value : 'light'
}

function readAlerts(): TicketAlerts {
  const value = readLocal('ticket-alerts')
  return value === 'high' || value === 'off' ? value : 'all'
}

export const usePreferences = create<Preferences>((set) => ({
  theme: readTheme(),
  density: readLocal('density') === 'compact' ? 'compact' : 'comfortable',
  language: i18n.language === 'en' ? 'en' : 'id',
  ticketAlerts: readAlerts(),
  infoPanelOpen: readLocal('info-panel') !== 'closed',
  setTheme: (theme) => {
    writeLocal('theme', theme)
    applyTheme(theme)
    set({ theme })
  },
  setDensity: (density) => {
    writeLocal('density', density)
    applyDensity(density)
    set({ density })
  },
  setLanguage: (language) => {
    writeLocal('language', language)
    set({ language })
    switchLanguage(language).catch((error: unknown) => {
      logger.warn('Language change failed', error)
      writeLocal('language', asLanguage(i18n.language))
      set({ language: asLanguage(i18n.language) })
    })
  },
  setTicketAlerts: (ticketAlerts) => {
    writeLocal('ticket-alerts', ticketAlerts)
    set({ ticketAlerts })
  },
  setInfoPanelOpen: (infoPanelOpen) => {
    writeLocal('info-panel', infoPanelOpen ? 'open' : 'closed')
    set({ infoPanelOpen })
  },
}))

const asLanguage = (value: string): Language => (value === 'en' ? 'en' : 'id')

i18n.on('languageChanged', (language) => {
  if (usePreferences.getState().language !== asLanguage(language)) {
    usePreferences.setState({ language: asLanguage(language) })
  }
})

export function watchSystemTheme() {
  const query = media()
  const listener = () => applyTheme(usePreferences.getState().theme)
  query.addEventListener('change', listener)
  return () => query.removeEventListener('change', listener)
}
