import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { renderWithProviders } from '@/test/render'

import type * as ApiModule from '../api'
import { customerApi } from '../api'
import { useRevealed } from '../hooks'
import { RevealableValue } from './revealable-value'

vi.mock('../api', async (importOriginal) => {
  const actual = await importOriginal<typeof ApiModule>()
  return { ...actual, customerApi: { ...actual.customerApi, reveal: vi.fn() } }
})

const ticketId = '22222222-2222-4222-8222-222222222222'

function renderValue() {
  return renderWithProviders(
    <dl>
      <RevealableValue ticketId={ticketId} field="nik" masked="3174********0001" label="NIK" canReveal />
    </dl>,
  )
}

describe('RevealableValue', () => {
  beforeEach(() => {
    useRevealed.getState().clear()
    vi.mocked(customerApi.reveal).mockReset()
  })

  it('shows only the masked value until a reason is given', async () => {
    const user = userEvent.setup()
    vi.mocked(customerApi.reveal).mockResolvedValue({
      field: 'nik',
      value: '3174012345670001',
      until: Date.now() + 60_000,
    })
    renderValue()
    expect(screen.getByText('3174********0001')).toBeInTheDocument()
    expect(screen.queryByText('3174012345670001')).not.toBeInTheDocument()

    await user.click(screen.getByRole('button', { name: 'Tampilkan' }))
    const dialog = await screen.findByRole('dialog', { name: 'Tampilkan NIK' })
    const confirm = screen
      .getAllByRole('button', { name: 'Tampilkan' })
      .find((button) => dialog.contains(button))
    expect(confirm).toBeDisabled()

    await user.click(screen.getByRole('combobox', { name: 'Alasan membuka data' }))
    await user.click(await screen.findByRole('option', { name: 'Verifikasi nasabah' }))
    expect(confirm).toBeEnabled()
    await user.click(confirm!)

    await waitFor(() => expect(customerApi.reveal).toHaveBeenCalledWith(ticketId, 'nik', 'verification'))
    expect(await screen.findByText('3174012345670001')).toBeInTheDocument()
    expect(screen.queryByText('3174********0001')).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Tampilkan' })).not.toBeInTheDocument()
  })

  it('masks the value again when the reveal window ends', async () => {
    vi.mocked(customerApi.reveal).mockResolvedValue({
      field: 'nik',
      value: '3174012345670001',
      until: Date.now() + 300,
    })
    useRevealed.getState().put(ticketId, { field: 'nik', value: '3174012345670001', until: Date.now() + 300 })
    renderValue()
    expect(screen.getByText('3174012345670001')).toBeInTheDocument()
    await waitFor(() => expect(screen.getByText('3174********0001')).toBeInTheDocument(), { timeout: 2_000 })
    expect(screen.queryByText('3174012345670001')).not.toBeInTheDocument()
  })

  it('keeps the value masked when the adapter refuses', async () => {
    const user = userEvent.setup()
    vi.mocked(customerApi.reveal).mockRejectedValue(new Error('denied'))
    renderValue()
    await user.click(screen.getByRole('button', { name: 'Tampilkan' }))
    await user.click(await screen.findByRole('combobox', { name: 'Alasan membuka data' }))
    await user.click(await screen.findByRole('option', { name: 'Verifikasi nasabah' }))
    const dialog = screen.getByRole('dialog')
    await user.click(
      screen.getAllByRole('button', { name: 'Tampilkan' }).find((button) => dialog.contains(button))!,
    )
    expect(await screen.findByRole('alert')).toBeInTheDocument()
    expect(screen.getByText('3174********0001')).toBeInTheDocument()
  })
})
