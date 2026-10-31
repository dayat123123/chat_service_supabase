import { expect, type Browser, type Page } from '@playwright/test'

import { member, type StaffName } from './env'
import { freshTotp } from './totp'

export async function signIn(page: Page, name: StaffName, { online = true }: { online?: boolean } = {}) {
  const person = member(name)
  await page.goto('/')
  await page.getByLabel('Email', { exact: true }).fill(person.email)
  await page.getByLabel('Password', { exact: true }).fill(person.password)
  await page.getByRole('button', { name: 'Masuk', exact: true }).click()
  await page.getByLabel('Kode 6 digit').fill(await freshTotp(person.totp_secret))
  await page.getByRole('button', { name: 'Verifikasi' }).click()
  await expect(page.getByRole('button', { name: 'Akun', exact: true })).toBeVisible()
  if (online && person.roles.includes('cs_agent')) await goOnline(page)
}

export async function goOnline(page: Page) {
  const trigger = page.getByRole('button', { name: 'Ubah status' })
  await expect(trigger).toBeVisible()
  if ((await trigger.textContent())?.includes('Online')) return
  await trigger.click()
  await page.getByRole('menuitem', { name: 'Online', exact: true }).click()
  await expect(trigger).toContainText('Online')
}

export async function staffPage(browser: Browser, name: StaffName) {
  const context = await browser.newContext()
  const page = await context.newPage()
  await signIn(page, name)
  return { context, page }
}

export async function signOut(page: Page) {
  await page.getByRole('button', { name: 'Akun', exact: true }).click()
  await page.getByRole('menuitem', { name: 'Keluar' }).click()
  await expect(page.getByRole('button', { name: 'Masuk', exact: true })).toBeVisible()
}

export function ticketCard(page: Page, ticketId: string) {
  return page.locator(`[data-ticket-id="${ticketId}"]`)
}

export async function openTab(page: Page, name: RegExp) {
  await page.getByRole('tab', { name }).click()
}

export async function searchTicket(page: Page, number: string) {
  await page.getByRole('textbox', { name: 'Cari tiket' }).fill(number)
}

export async function openTicket(page: Page, ticketId: string, number: string) {
  await ticketCard(page, ticketId)
    .getByRole('button', { name: new RegExp(`^${number} `) })
    .click()
}

export async function claim(page: Page, ticketId: string, number: string) {
  await ticketCard(page, ticketId)
    .getByRole('button', { name: `Ambil ${number}` })
    .click()
  await expect(page.getByRole('textbox', { name: 'Balas' })).toBeVisible()
}
