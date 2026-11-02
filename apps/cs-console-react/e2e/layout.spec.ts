import { expect, test } from '@playwright/test'

import { checkLayout } from './support/quality'
import { signIn } from './support/staff'

test('login dan ruang kerja tanpa scroll horizontal atau teks terpotong', async ({ page }) => {
  await page.goto('/')
  await expect(page.getByRole('heading', { name: 'Masuk ke CS Console' })).toBeVisible()
  await checkLayout(page, 'login')
  await signIn(page, 'Bima')
  await checkLayout(page, 'ruang kerja')
})

test('dashboard dan laporan muat di semua resolusi', async ({ page }) => {
  await signIn(page, 'Sinta')
  await page.getByRole('link', { name: 'Dashboard' }).click()
  await expect(page.getByRole('heading', { name: 'Dashboard', exact: true })).toBeVisible()
  await checkLayout(page, 'dashboard')
  await page.getByRole('link', { name: 'Laporan' }).click()
  await expect(page.getByRole('heading', { name: 'Tiket per hari' })).toBeVisible()
  await checkLayout(page, 'laporan')
})

test('pengaturan Super Admin muat di semua resolusi', async ({ page }) => {
  await signIn(page, 'Adi')
  await page.getByRole('link', { name: 'Pengaturan' }).click()
  await expect(page.getByRole('heading', { name: 'Akun CS' })).toBeVisible()
  await checkLayout(page, 'pengaturan')
})
