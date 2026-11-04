import { screen } from '@testing-library/react'
import { describe, expect, it, vi } from 'vitest'

import { renderWithProviders } from '@/test/render'

import { settingsSections } from '../types'
import { BackupSection } from './backup-section'

vi.mock('@/features/system/components/backup-tab', () => ({
  BackupTab: () => <p>Isi pengaturan backup</p>,
}))

describe('BackupSection', () => {
  it('is listed in the settings menu', () => {
    expect(settingsSections).toContain('backup')
  })

  it('shows the backup settings under a settings heading', () => {
    renderWithProviders(<BackupSection />)
    expect(screen.getByRole('heading', { level: 1, name: 'Backup' })).toBeInTheDocument()
    expect(screen.getByText(/Tujuan, password enkripsi, jadwal/)).toBeInTheDocument()
    expect(screen.getByText('Isi pengaturan backup')).toBeInTheDocument()
  })
})
