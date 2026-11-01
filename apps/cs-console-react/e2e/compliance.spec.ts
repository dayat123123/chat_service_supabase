import { createHash } from 'node:crypto'
import { readFile } from 'node:fs/promises'

import { expect, test } from '@playwright/test'

import { Customer } from './support/customer'
import { staffPage } from './support/staff'
import { tag } from './support/text'

test('Kepatuhan meninjau pengaduan, memperpanjang tenggat, mengunduh transkrip, dan melihat jejak audit', async ({
  browser,
}) => {
  const customer = await Customer.login('olt_official')
  const kirana = await staffPage(browser, 'Kirana')
  const page = kirana.page
  try {
    const story = `Dana saya belum masuk sejak kemarin ${tag()}`
    const ticket = await customer.openTicket(story)
    await customer.rpc('request_complaint')

    await expect(page.getByRole('heading', { name: 'Ringkasan Kepatuhan' })).toBeVisible()
    const menu = page.getByRole('navigation', { name: 'Menu' })
    await expect(menu.getByRole('link', { name: 'Layanan Nasabah' })).toHaveCount(0)
    for (const name of ['Ringkasan', 'Jejak Audit', 'Kebijakan']) {
      await expect(menu.getByRole('link', { name, exact: true })).toBeVisible()
    }

    await page.getByRole('button', { name: 'Muat ulang' }).click()
    await page
      .getByRole('link', { name: new RegExp(ticket.ticket_number) })
      .first()
      .click()
    const panel = page.getByRole('dialog')
    await expect(panel.getByRole('heading', { name: ticket.ticket_number })).toBeVisible()
    await expect(panel.getByRole('log').getByText(story)).toBeVisible()

    await panel.getByRole('button', { name: 'Perpanjang tenggat' }).click()
    const extend = page.getByRole('dialog', { name: 'Perpanjang tenggat pengaduan' })
    await extend.getByLabel('Alasan perpanjangan').fill('Menunggu konfirmasi mutasi dari bank kustodian')
    await extend.getByRole('button', { name: 'Perpanjang', exact: true }).click()
    await expect(page.getByText('Tenggat diperpanjang dan nasabah sudah diberi tahu.')).toBeVisible()
    await expect(panel.getByText(/Diperpanjang .*Menunggu konfirmasi mutasi/)).toBeVisible()
    await expect(panel.getByRole('button', { name: 'Perpanjang tenggat' })).toHaveCount(0)
    await expect
      .poll(async () =>
        (await customer.messages()).some((m) => m.body.includes('membutuhkan waktu lebih lama')),
      )
      .toBe(true)

    const [download] = await Promise.all([
      page.waitForEvent('download'),
      panel.getByRole('button', { name: 'Unduh transkrip' }).click(),
    ])
    const content = await readFile(await download.path())
    const sha256 = createHash('sha256').update(content).digest('hex')
    expect(download.suggestedFilename()).toBe(`transkrip-${ticket.ticket_number}-${sha256.slice(0, 12)}.txt`)
    expect(content.toString('utf8')).toContain(story)
    await expect(panel.getByText(sha256)).toBeVisible()

    await panel.getByRole('tab', { name: /^Tinjauan/ }).click()
    await panel.getByRole('radio', { name: /Perlu tindak lanjut/ }).click()
    await panel.getByLabel('Catatan tinjauan').fill('Minta tim CS menjelaskan keterlambatan mutasi')
    await panel.getByRole('button', { name: 'Simpan tinjauan' }).click()
    await expect(page.getByText('Tinjauan disimpan.')).toBeVisible()
    await expect(panel.getByText('Minta tim CS menjelaskan keterlambatan mutasi')).toBeVisible()
    await page.keyboard.press('Escape')

    const row = page.getByRole('row', { name: new RegExp(ticket.ticket_number) })
    await expect(row.getByText('Perlu tindak lanjut')).toBeVisible()
    await expect(row.getByText('Diperpanjang')).toBeVisible()

    await menu.getByRole('link', { name: 'Jejak Audit', exact: true }).click()
    await page
      .getByRole('searchbox', { name: 'Cari pelaku, tiket, atau nasabah…' })
      .fill(ticket.ticket_number)
    await expect(page.getByRole('row').filter({ hasNotText: ticket.ticket_number })).toHaveCount(1)
    for (const action of [
      'compliance.review',
      'compliance.transcript_export',
      'compliance.deadline_extended',
    ]) {
      await expect(page.getByRole('cell', { name: new RegExp(action.replace('.', '\\.')) })).toBeVisible()
    }
    await expect(page.getByText(sha256)).toBeVisible()

    await menu.getByRole('link', { name: 'Kebijakan', exact: true }).click()
    for (const name of ['Tenggat pengaduan', 'Perpanjangan tenggat', 'Retensi riwayat chat']) {
      await expect(page.getByRole('heading', { name, exact: true })).toBeVisible()
    }
  } finally {
    await customer.closeActiveTicket()
    await kirana.context.close()
  }
})
