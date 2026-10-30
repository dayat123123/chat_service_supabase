import { readdirSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { gzipSync } from 'node:zlib'

const LIMIT_KB = 300
const dist = fileURLToPath(new URL('../dist/', import.meta.url))
const html = readFileSync(join(dist, 'index.html'), 'utf8')

const initial = new Set(
  [
    ...html.matchAll(
      /<script[^>]+type="module"[^>]+src="\/([^"]+)"|<link[^>]+rel="modulepreload"[^>]+href="\/([^"]+)"/g,
    ),
  ].map((match) => match[1] ?? match[2]),
)

const gzipKb = (file) => gzipSync(readFileSync(join(dist, file))).length / 1024

const chunks = readdirSync(join(dist, 'assets'))
  .filter((file) => file.endsWith('.js'))
  .map((file) => ({ file: `assets/${file}`, kb: gzipKb(`assets/${file}`) }))
  .sort((a, b) => b.kb - a.kb)

let total = 0
for (const chunk of chunks) {
  const isInitial = initial.has(chunk.file)
  if (isInitial) total += chunk.kb
  console.log(`${isInitial ? 'initial' : 'lazy   '}  ${chunk.kb.toFixed(1).padStart(7)} KB  ${chunk.file}`)
}

console.log(`\nInitial JavaScript: ${total.toFixed(1)} KB gzip (limit ${LIMIT_KB} KB)`)
if (initial.size === 0) {
  console.error('Tidak menemukan entry script di dist/index.html')
  process.exit(1)
}
if (total > LIMIT_KB) {
  console.error('Bundle awal melebihi batas')
  process.exit(1)
}
