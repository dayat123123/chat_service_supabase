import { readdirSync, readFileSync, statSync, writeFileSync } from 'node:fs'
import { extname, join, resolve } from 'node:path'
import { constants, gzipSync } from 'node:zlib'

const dist = resolve(process.argv[2] ?? 'dist')
const types = new Set(['.js', '.css', '.html', '.svg', '.json', '.txt'])

function walk(dir) {
  return readdirSync(dir).flatMap((name) => {
    const path = join(dir, name)
    return statSync(path).isDirectory() ? walk(path) : [path]
  })
}

let count = 0
for (const file of walk(dist)) {
  if (!types.has(extname(file)) || statSync(file).size < 1024) continue
  writeFileSync(`${file}.gz`, gzipSync(readFileSync(file), { level: constants.Z_BEST_COMPRESSION }))
  count += 1
}
console.log(`precompress: ${count} file`)
