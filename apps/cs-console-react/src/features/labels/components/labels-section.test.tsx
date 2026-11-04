import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { ApiError } from '@/lib/errors'
import { monitorFixture } from '@/test/fixtures'
import { renderWithProviders } from '@/test/render'
import { dismissToasts, findToast, Toaster } from '@/test/toast'

import type * as ApiModule from '../api'
import { labelsApi } from '../api'
import type { LabelConfig } from '../types'
import { LabelsSection } from './labels-section'

vi.mock('../api', async (importOriginal) => {
  const actual = await importOriginal<typeof ApiModule>()
  return {
    ...actual,
    labelsApi: { ...actual.labelsApi, configs: vi.fn(), save: vi.fn(), reorder: vi.fn() },
  }
})

function config(overrides: Partial<LabelConfig>): LabelConfig {
  return {
    id: 'refund',
    name: 'Refund',
    color: 'warning',
    active: true,
    sort_order: 0,
    updated_at: '2026-11-04T02:00:00.000Z',
    tickets: 3,
    ...overrides,
  }
}

const refund = config({})
const akun = config({ id: 'akun', name: 'Akun terkunci', color: 'danger', sort_order: 1, tickets: 0 })
const arsip = config({
  id: 'arsip',
  name: 'Arsip',
  color: 'neutral',
  active: false,
  sort_order: 2,
  tickets: 1,
})

function setup() {
  const user = userEvent.setup()
  renderWithProviders(
    <>
      <LabelsSection />
      <Toaster />
    </>,
    monitorFixture,
  )
  return user
}

describe('LabelsSection', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    vi.mocked(labelsApi.configs).mockResolvedValue([refund, akun, arsip])
  })
  afterEach(dismissToasts)

  it('lists labels with color, status, usage, and the active count', async () => {
    setup()
    const table = await screen.findByRole('table')
    const rows = within(table).getAllByRole('row').slice(1)
    expect(rows.map((row) => within(row).getAllByRole('cell')[1]?.textContent)).toEqual([
      'Refund',
      'Akun terkunci',
      'Arsip',
    ])
    expect(within(rows[0]!).getByText('3 tiket')).toBeInTheDocument()
    expect(within(rows[2]!).getByText('Nonaktif')).toBeInTheDocument()
    expect(screen.getByText('2 dari 50 label aktif')).toBeInTheDocument()
  })

  it('creates a label with a palette color', async () => {
    vi.mocked(labelsApi.save).mockResolvedValue([
      refund,
      akun,
      arsip,
      config({ id: 'vip', name: 'VIP', color: 'info' }),
    ])
    const user = setup()
    await user.click(await screen.findByRole('button', { name: 'Tambah label' }))
    const dialog = await screen.findByRole('dialog', { name: 'Tambah label' })
    await user.type(within(dialog).getByLabelText('Nama label'), '  VIP   nasabah ')
    await user.click(within(dialog).getByRole('radio', { name: 'Biru' }))
    await user.click(within(dialog).getByRole('button', { name: 'Simpan' }))
    await waitFor(() =>
      expect(labelsApi.save).toHaveBeenCalledWith({
        id: null,
        name: 'VIP nasabah',
        color: 'info',
        active: true,
      }),
    )
    expect(await findToast('Label disimpan')).toBeInTheDocument()
  })

  it('validates the name length and shows server errors in the dialog', async () => {
    vi.mocked(labelsApi.save).mockRejectedValue(
      new ApiError('duplicate_label', 'Nama label sudah dipakai', 409),
    )
    const user = setup()
    await user.click(await screen.findByRole('button', { name: 'Tambah label' }))
    const dialog = await screen.findByRole('dialog', { name: 'Tambah label' })
    await user.click(within(dialog).getByRole('button', { name: 'Simpan' }))
    expect(within(dialog).getByText('Nama label 1–30 karakter.')).toBeInTheDocument()
    expect(labelsApi.save).not.toHaveBeenCalled()
    await user.type(within(dialog).getByLabelText('Nama label'), 'refund')
    await user.click(within(dialog).getByRole('button', { name: 'Simpan' }))
    expect(await within(dialog).findByRole('alert')).toHaveTextContent('Nama label sudah dipakai.')
  })

  it('edits and deactivates a label', async () => {
    vi.mocked(labelsApi.save).mockResolvedValue([refund, { ...akun, active: false }, arsip])
    const user = setup()
    const table = await screen.findByRole('table')
    const row = within(table).getAllByRole('row')[2]!
    await user.click(within(row).getByRole('button', { name: 'Ubah' }))
    const dialog = await screen.findByRole('dialog', { name: 'Ubah label' })
    expect(within(dialog).getByLabelText('Nama label')).toHaveValue('Akun terkunci')
    await user.click(within(dialog).getByRole('switch'))
    await user.click(within(dialog).getByRole('button', { name: 'Simpan' }))
    await waitFor(() =>
      expect(labelsApi.save).toHaveBeenCalledWith({
        id: 'akun',
        name: 'Akun terkunci',
        color: 'danger',
        active: false,
      }),
    )
  })

  it('reorders labels with the arrow buttons', async () => {
    vi.mocked(labelsApi.reorder).mockResolvedValue([akun, refund, arsip])
    const user = setup()
    expect(await screen.findByRole('button', { name: 'Naikkan Refund' })).toBeDisabled()
    await user.click(screen.getByRole('button', { name: 'Naikkan Akun terkunci' }))
    await waitFor(() => expect(labelsApi.reorder).toHaveBeenCalledWith(['akun', 'refund', 'arsip']))
  })

  it('blocks a new active label at the 50 label limit', async () => {
    vi.mocked(labelsApi.configs).mockResolvedValue(
      Array.from({ length: 50 }, (_, index) =>
        config({ id: `l${index}`, name: `Label ${index}`, sort_order: index }),
      ),
    )
    const user = setup()
    expect(await screen.findByText('50 dari 50 label aktif')).toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'Tambah label' }))
    const dialog = await screen.findByRole('dialog', { name: 'Tambah label' })
    expect(within(dialog).getByRole('switch')).not.toBeChecked()
    await user.type(within(dialog).getByLabelText('Nama label'), 'Baru')
    await user.click(within(dialog).getByRole('switch'))
    expect(within(dialog).getByRole('alert')).toHaveTextContent('Batas 50 label aktif tercapai')
    await user.click(within(dialog).getByRole('button', { name: 'Simpan' }))
    expect(labelsApi.save).not.toHaveBeenCalled()
  })
})
