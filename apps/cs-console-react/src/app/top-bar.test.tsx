import type * as RouterModule from '@tanstack/react-router'
import { screen, within } from '@testing-library/react'
import { describe, expect, it, vi } from 'vitest'

import { systemApi } from '@/features/system/api'
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

vi.mock('@/features/community/api', () => ({
  communityApi: {
    overview: vi.fn(() =>
      Promise.resolve({
        pending_posts: 2,
        scheduled_posts: 0,
        pending_campaigns: 1,
        open_reports: 4,
        accounts: 1,
        four_eyes: true,
        push_ready: false,
      }),
    ),
  },
}))

vi.mock('@/features/system/api', () => ({
  systemApi: {
    badge: vi.fn(() => Promise.resolve({ critical: 0, warning: 0, open: 0 })),
  },
}))

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
    expect(navLinks()).toEqual(['Layanan Nasabah', 'Dashboard', 'Laporan', 'Pengaturan', 'Kesehatan sistem'])
  })

  it('places Akun Nasabah right before Pengaturan for CS accounts with customer access', () => {
    renderWithProviders(<TopBar attention={0} caseAttention={0} />, {
      ...monitorFixture,
      roles: ['cs_agent', 'cs_super_admin'],
      nasabah_permissions: ['online_user.view'],
    })
    expect(navLinks()).toEqual([
      'Layanan Nasabah',
      'Dashboard',
      'Laporan',
      'Akun Nasabah',
      'Pengaturan',
      'Kesehatan sistem',
    ])
  })

  it('shows only Komunitas to community staff, with the items they can act on', async () => {
    renderWithProviders(<TopBar attention={0} caseAttention={0} />, {
      ...agentFixture,
      roles: ['community'],
      community_permissions: ['community.publish'],
    })
    expect(navLinks()).toEqual(['Komunitas'])
    expect(await screen.findByLabelText('3 perlu tindakan di Komunitas')).toBeInTheDocument()
  })

  it('shows Akun Nasabah after Layanan Nasabah to plain CS accounts with customer access', () => {
    renderWithProviders(<TopBar attention={0} caseAttention={0} />, {
      ...agentFixture,
      nasabah_permissions: ['online_user.view'],
    })
    expect(navLinks()).toEqual(['Layanan Nasabah', 'Akun Nasabah'])
  })

  it('marks unhandled critical system alerts in red on Kesehatan sistem', async () => {
    vi.mocked(systemApi.badge).mockResolvedValue({ critical: 2, warning: 3, open: 5 })
    renderWithProviders(<TopBar attention={0} caseAttention={0} />, monitorFixture)

    const count = await screen.findByLabelText('2 alert kritis belum ditangani')
    expect(count).toHaveTextContent('2')
    expect(count).toHaveClass('text-danger')
    expect(systemApi.badge).toHaveBeenCalled()
  })

  it('shows unhandled warnings in amber when nothing is critical', async () => {
    vi.mocked(systemApi.badge).mockResolvedValue({ critical: 0, warning: 1, open: 1 })
    renderWithProviders(<TopBar attention={0} caseAttention={0} />, monitorFixture)

    const count = await screen.findByLabelText('1 peringatan belum ditangani')
    expect(count).toHaveClass('text-warning')
  })

  it('does not ask for the system badge without Super Admin access', () => {
    vi.mocked(systemApi.badge).mockClear()
    renderWithProviders(<TopBar attention={0} caseAttention={0} />, agentFixture)

    expect(systemApi.badge).not.toHaveBeenCalled()
  })

  it('lists Dokumen hukum among the compliance menus', () => {
    renderWithProviders(<TopBar attention={0} caseAttention={0} />, {
      ...agentFixture,
      roles: ['compliance'],
    })
    expect(navLinks()).toEqual([
      'Ringkasan',
      'Kasus',
      'Jejak Audit',
      'Kebijakan',
      'Kata terlarang',
      'Dokumen hukum',
    ])
  })
})
