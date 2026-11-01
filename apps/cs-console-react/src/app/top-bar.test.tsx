import type * as RouterModule from '@tanstack/react-router'
import { screen, within } from '@testing-library/react'
import { describe, expect, it, vi } from 'vitest'

import { agentFixture, monitorFixture } from '@/test/fixtures'
import { renderWithProviders } from '@/test/render'

import { TopBar } from './top-bar'

vi.mock('@tanstack/react-router', async (importOriginal) => {
  const actual = await importOriginal<typeof RouterModule>()
  const { createElement } = await import('react')
  return {
    ...actual,
    Link: ({ to, children }: { to: string; children: React.ReactNode }) =>
      createElement('a', { href: to }, children),
  }
})

function navLinks() {
  return within(screen.getByRole('navigation', { name: 'Menu' }))
    .getAllByRole('link')
    .map((link) => link.textContent)
}

describe('TopBar', () => {
  it('shows status and capacity to agents', () => {
    renderWithProviders(<TopBar attention={0} caseAttention={0} />, agentFixture)

    expect(screen.getByRole('button', { name: 'Ubah status: Online' })).toBeInTheDocument()
    expect(screen.getByText('Aktif 1/5')).toBeInTheDocument()
    expect(screen.queryByText('Mode pantau')).not.toBeInTheDocument()
    expect(navLinks()).toEqual(['Layanan Nasabah'])
  })

  it('shows monitor mode and admin menus to Super Admins without status or capacity', () => {
    renderWithProviders(<TopBar attention={0} caseAttention={0} />, monitorFixture)

    expect(screen.getByText('Mode pantau')).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /^Ubah status/ })).not.toBeInTheDocument()
    expect(screen.queryByText(/^Aktif \d+\/\d+$/)).not.toBeInTheDocument()
    expect(navLinks()).toEqual(['Layanan Nasabah', 'Dashboard', 'Laporan', 'Pengaturan'])
  })

  it('places Akun Nasabah right before Pengaturan for CS accounts with customer access', () => {
    renderWithProviders(<TopBar attention={0} caseAttention={0} />, {
      ...monitorFixture,
      roles: ['cs_agent', 'cs_super_admin'],
      nasabah_permissions: ['online_user.view'],
    })
    expect(navLinks()).toEqual(['Layanan Nasabah', 'Dashboard', 'Laporan', 'Akun Nasabah', 'Pengaturan'])
  })

  it('shows Akun Nasabah after Layanan Nasabah to plain CS accounts with customer access', () => {
    renderWithProviders(<TopBar attention={0} caseAttention={0} />, {
      ...agentFixture,
      nasabah_permissions: ['online_user.view'],
    })
    expect(navLinks()).toEqual(['Layanan Nasabah', 'Akun Nasabah'])
  })
})
