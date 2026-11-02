import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { monitorFixture } from '@/test/fixtures'
import { renderWithProviders } from '@/test/render'

import type * as ApiModule from '../api'
import { settingsApi } from '../api'
import type { IntegrationStatus, SettingEntry } from '../types'
import { IntegrationSection } from './integration-section'

vi.mock('../api', async (importOriginal) => {
  const actual = await importOriginal<typeof ApiModule>()
  return {
    ...actual,
    settingsApi: {
      ...actual.settingsApi,
      settings: vi.fn(),
      setSetting: vi.fn(),
      integration: vi.fn(),
      testIntegration: vi.fn(),
    },
  }
})

const entry = (key: string, value: string): SettingEntry => ({
  key,
  value,
  description: null,
  version: 1,
  updated_at: null,
  updated_by: null,
})

const serverStatus: IntegrationStatus = {
  url: 'http://csadmin:8080',
  url_source: 'server',
  client_id: 'web-cs',
  client_id_source: 'server',
  public_key: 'MCowBQYDK2VwAyEAkey',
  key_configured: true,
  configured: true,
}

beforeEach(() => {
  vi.mocked(settingsApi.settings).mockResolvedValue([
    entry('nasabah.csadmin_url', ''),
    entry('nasabah.csadmin_client_id', ''),
  ])
  vi.mocked(settingsApi.integration).mockResolvedValue(serverStatus)
})

describe('IntegrationSection', () => {
  it('shows the address in use and the block to paste into csAdminEL.cfg', async () => {
    const user = userEvent.setup()
    renderWithProviders(<IntegrationSection />, monitorFixture)

    expect(
      await screen.findByText('Dipakai sekarang: http://csadmin:8080 (dari docker/.env di server)'),
    ).toBeVisible()
    const block = await screen.findByLabelText('Kunci integrasi')
    expect(block.textContent).toContain('        client_id       = web-cs\n')
    expect(block.textContent).toContain('        public_key      = MCowBQYDK2VwAyEAkey\n')

    await user.click(screen.getByRole('button', { name: 'Salin' }))
    expect(await navigator.clipboard.readText()).toContain('integration {')
    expect(screen.getByRole('button', { name: 'Disalin' })).toBeInTheDocument()
  })

  it('rejects unsafe addresses and saves only what changed', async () => {
    const user = userEvent.setup()
    vi.mocked(settingsApi.setSetting).mockResolvedValue({
      key: 'nasabah.csadmin_url',
      value: 'http://10.0.0.5:9001/csAdmin',
      version: 2,
      updated_at: '2026-11-02T02:00:00.000Z',
    })
    renderWithProviders(<IntegrationSection />, monitorFixture)

    const address = await screen.findByLabelText('Alamat API Nasabah')
    await user.type(address, 'http://admin:rahasia@10.0.0.5')
    await user.click(screen.getByRole('button', { name: 'Simpan' }))
    expect(
      screen.getByText('Alamat harus diawali http:// atau https://, tanpa spasi, login, atau query'),
    ).toBeVisible()
    expect(settingsApi.setSetting).not.toHaveBeenCalled()

    await user.clear(address)
    await user.type(address, ' http://10.0.0.5:9001/csAdmin ')
    await user.click(screen.getByRole('button', { name: 'Simpan' }))
    await waitFor(() => expect(settingsApi.setSetting).toHaveBeenCalledTimes(1))
    expect(settingsApi.setSetting).toHaveBeenCalledWith('nasabah.csadmin_url', 'http://10.0.0.5:9001/csAdmin')
    await waitFor(() => expect(settingsApi.integration).toHaveBeenCalledTimes(2))
  })

  it('tests the typed address and explains a refused key', async () => {
    const user = userEvent.setup()
    vi.mocked(settingsApi.testIntegration).mockResolvedValue({
      result: 'refused',
      status: 401,
      duration_ms: 12,
    })
    renderWithProviders(<IntegrationSection />, monitorFixture)

    await user.type(await screen.findByLabelText('Alamat API Nasabah'), 'http://10.0.0.5:8080')
    await user.type(screen.getByLabelText('Client id'), 'web-cs.prod')
    await user.click(screen.getByRole('button', { name: 'Tes koneksi' }))

    expect(settingsApi.testIntegration).toHaveBeenCalledWith('http://10.0.0.5:8080', 'web-cs.prod')
    expect(await screen.findByRole('status')).toHaveTextContent('API Nasabah menolak kunci integrasi')
    await user.type(screen.getByLabelText('Client id'), 'x')
    expect(screen.queryByRole('status')).not.toBeInTheDocument()
  })

  it('tells the Super Admin to generate the key when the server has none', async () => {
    vi.mocked(settingsApi.integration).mockResolvedValue({
      ...serverStatus,
      url: '',
      url_source: 'none',
      public_key: '',
      key_configured: false,
      configured: false,
    })
    renderWithProviders(<IntegrationSection />, monitorFixture)

    expect(
      await screen.findByText('Belum ada alamat API Nasabah, jadi menu Akun Nasabah belum aktif.'),
    ).toBeVisible()
    expect(screen.getByText(/Jalankan make gen-secrets di server/)).toBeVisible()
    expect(screen.queryByLabelText('Kunci integrasi')).not.toBeInTheDocument()
  })
})
