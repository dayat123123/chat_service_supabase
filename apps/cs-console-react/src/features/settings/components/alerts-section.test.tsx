import { screen } from '@testing-library/react'
import { describe, expect, it, vi } from 'vitest'

import { renderWithProviders } from '@/test/render'

import { settingsSections } from '../types'
import { AlertsSection } from './alerts-section'

vi.mock('@/features/system/components/alerts-tab', () => ({
  AlertsTab: () => <p>Isi kanal alert</p>,
}))

describe('AlertsSection', () => {
  it('is listed in the settings menu', () => {
    expect(settingsSections).toContain('alerts')
  })

  it('shows the alert channel settings under a settings heading', () => {
    renderWithProviders(<AlertsSection />)
    expect(screen.getByRole('heading', { level: 1, name: 'Alert' })).toBeInTheDocument()
    expect(screen.getByText(/Telegram dan\/atau email/)).toBeInTheDocument()
    expect(screen.getByText('Isi kanal alert')).toBeInTheDocument()
  })
})
