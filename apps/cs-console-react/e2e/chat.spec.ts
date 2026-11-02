import { expect, test } from '@playwright/test'

import { Customer } from './support/customer'
import { claimMode, pinAssignmentMode } from './support/settings'
import { claim, signIn } from './support/staff'
import { tag } from './support/text'

const png = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYGD4DwABBAEAwS2OUAAAAABJRU5ErkJggg==',
  'base64',
)

const pdf = Buffer.from(['%PDF-1.4', '1 0 obj<<>>endobj', 'trailer<<>>', '%%EOF', ''].join('\n'))

pinAssignmentMode(claimMode)

test('balas, tanda dibaca, lampiran, pesan nasabah realtime, dan panel info nasabah', async ({ page }) => {
  const customer = await Customer.login('andi_trader')
  try {
    await signIn(page, 'Nadia')
    const opening = `Halo, order saya belum masuk ${tag()}`
    const ticket = await customer.openTicket(opening)
    await claim(page, ticket.id, ticket.ticket_number)
    const log = page.getByRole('log')
    await expect(log.getByText(opening)).toBeVisible()

    const panel = page.getByRole('complementary', { name: 'Info nasabah' })
    await expect(panel.getByText(`@${customer.username}`)).toBeVisible()
    await expect(panel.getByRole('heading')).toHaveText(['Riwayat tiket', 'Catatan internal'])

    const box = page.getByRole('textbox', { name: 'Balas' })
    const reply = `Baik, kami cek dulu ya ${tag()}`
    await box.fill(reply)
    await box.press('Enter')
    await expect(box).toHaveValue('')
    await expect(log.getByText(reply)).toHaveCount(1)
    await expect
      .poll(async () => (await customer.messages()).some((message) => message.body === reply))
      .toBe(true)

    await expect(page.getByLabel('Terkirim').last()).toBeVisible()
    await customer.markRead()
    await expect(page.getByLabel('Dibaca').last()).toBeVisible()

    await page
      .locator('input[type="file"]')
      .setInputFiles({ name: 'bukti.png', mimeType: 'image/png', buffer: png })
    await expect(page.getByRole('button', { name: 'Lihat bukti.png' })).toBeVisible()
    const caption = `Ini tangkapan layarnya ${tag()}`
    await box.fill(caption)
    await box.press('Enter')
    await expect
      .poll(async () =>
        (await customer.messages()).some(
          (message) => message.body === caption && message.attachments.length === 1,
        ),
      )
      .toBe(true)

    const inbound = `Terima kasih kak ${tag()}`
    await customer.send(inbound)
    await expect(log.getByText(inbound)).toBeVisible()
    await expect(log.getByText(inbound)).toHaveCount(1)
  } finally {
    await customer.closeActiveTicket()
  }
})

test('PDF dua arah di chat CS, video ditolak', async ({ page }) => {
  const customer = await Customer.login('andi_trader')
  try {
    await signIn(page, 'Nadia')
    const ticket = await customer.openTicket(`Mau kirim bukti transfer ${tag()}`)
    await claim(page, ticket.id, ticket.ticket_number)
    const log = page.getByRole('log')

    const path = await customer.upload('cs-documents', 'pdf', 'application/pdf', pdf)
    await customer.send(`Ini bukti transfernya ${tag()}`, [
      { bucket: 'cs-documents', path, mime: 'application/pdf', name: 'Bukti Transfer.pdf', size: pdf.length },
    ])
    await expect(log.getByRole('link', { name: 'Buka Bukti Transfer.pdf' })).toHaveAttribute(
      'href',
      /\/storage\/v1\/object\/sign\/cs-documents\//,
    )
    await expect(customer.upload('attachments', 'mp4', 'video/mp4', Buffer.from('video'))).rejects.toThrow()

    const input = page.locator('input[type="file"]')
    await input.setInputFiles({ name: 'rekaman.mp4', mimeType: 'video/mp4', buffer: Buffer.from('video') })
    await expect(page.getByText(/^rekaman\.mp4 tidak didukung/)).toBeVisible()

    await input.setInputFiles({ name: 'Formulir.pdf', mimeType: 'application/pdf', buffer: pdf })
    const box = page.getByRole('textbox', { name: 'Balas' })
    const caption = `Silakan isi formulir ini ${tag()}`
    await box.fill(caption)
    await box.press('Enter')
    const sent = log.getByRole('link', { name: 'Buka Formulir.pdf' })
    await expect(sent).toHaveAttribute('href', /token=/)
    await expect
      .poll(async () =>
        (await customer.messages()).some(
          (message) =>
            message.body === caption &&
            (message.attachments[0] as { bucket?: string } | undefined)?.bucket === 'cs-documents',
        ),
      )
      .toBe(true)
    const file = await fetch((await sent.getAttribute('href')) ?? '')
    expect(file.headers.get('content-type')).toContain('application/pdf')
  } finally {
    await customer.closeActiveTicket()
  }
})
