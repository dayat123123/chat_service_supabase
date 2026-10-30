import { readFileSync, writeFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'

const api = process.env.SUPABASE_URL ?? 'http://localhost:8000'
const keyFile = fileURLToPath(new URL('../../../docker/secrets/service_role_key', import.meta.url))
const key = process.env.SUPABASE_SERVICE_ROLE_KEY ?? readFileSync(keyFile, 'utf8').trim()
const target = fileURLToPath(new URL('../src/types/database.ts', import.meta.url))

const response = await fetch(`${api}/pg/generators/typescript?included_schemas=cs_api`, {
  headers: { apikey: key, Authorization: `Bearer ${key}` },
})
if (!response.ok) {
  console.error(`Gagal membuat tipe database: HTTP ${response.status}`)
  process.exit(1)
}
const source = await response.text()
if (!source.includes('export type Database')) {
  console.error('Respons generator tidak berisi tipe Database')
  process.exit(1)
}
writeFileSync(target, source)
console.warn(`Tipe database ditulis ke ${target}`)
