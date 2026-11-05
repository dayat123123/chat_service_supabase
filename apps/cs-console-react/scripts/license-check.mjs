import { existsSync, readdirSync, readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = fileURLToPath(new URL('..', import.meta.url))
const modules = join(root, 'node_modules')

const permissive = new Set([
  '0BSD',
  'Apache-2.0',
  'BlueOak-1.0.0',
  'BSD-2-Clause',
  'BSD-3-Clause',
  'CC-BY-4.0',
  'CC0-1.0',
  'ISC',
  'MIT',
  'MIT-0',
  'Python-2.0',
  'Unlicense',
])
const fonts = new Set(['OFL-1.1'])
const buildOnly = new Set(['MPL-2.0'])
const forbidden = /(^|[^L])GPL|AGPL|LGPL|SSPL|EUPL|BUSL|Commons-Clause/i

function readJson(path) {
  return JSON.parse(readFileSync(path, 'utf8'))
}

function licenseOf(pkg) {
  if (typeof pkg.license === 'string') return pkg.license
  if (pkg.license && typeof pkg.license.type === 'string') return pkg.license.type
  if (Array.isArray(pkg.licenses)) return pkg.licenses.map((item) => item.type ?? item).join(' OR ')
  return 'UNKNOWN'
}

function accepted(expression, allowed) {
  const clean = expression.replace(/[()]/g, ' ').replace(/\s+/g, ' ').trim()
  if (/ OR /i.test(clean)) return clean.split(/ OR /i).some((part) => accepted(part, allowed))
  if (/ AND /i.test(clean)) return clean.split(/ AND /i).every((part) => accepted(part, allowed))
  return allowed.has(clean.replace(/\+$/, ''))
}

function installed(dir, found = new Map()) {
  if (!existsSync(dir)) return found
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    if (!entry.isDirectory() || entry.name.startsWith('.')) continue
    const path = join(dir, entry.name)
    if (entry.name.startsWith('@')) {
      installed(path, found)
      continue
    }
    const manifest = join(path, 'package.json')
    if (existsSync(manifest)) {
      const pkg = readJson(manifest)
      if (pkg.name && pkg.version) found.set(path, pkg)
    }
    installed(join(path, 'node_modules'), found)
  }
  return found
}

function resolve(name, fromDir) {
  let dir = fromDir
  for (;;) {
    const candidate = join(dir, 'node_modules', name)
    if (existsSync(join(candidate, 'package.json'))) return candidate
    const parent = dirname(dir)
    if (parent === dir) return null
    dir = parent
  }
}

function runtimeClosure() {
  const seen = new Set()
  const queue = Object.keys(readJson(join(root, 'package.json')).dependencies ?? {}).map((name) => [
    name,
    root,
  ])
  while (queue.length > 0) {
    const [name, from] = queue.shift()
    const path = resolve(name, from)
    if (!path || seen.has(path)) continue
    seen.add(path)
    const pkg = readJson(join(path, 'package.json'))
    for (const dependency of Object.keys({
      ...pkg.dependencies,
      ...pkg.optionalDependencies,
      ...pkg.peerDependencies,
    })) {
      queue.push([dependency, path])
    }
  }
  return seen
}

const runtime = runtimeClosure()
const problems = []
const summary = new Map()

for (const [path, pkg] of installed(modules)) {
  const id = `${pkg.name}@${pkg.version}`
  const license = licenseOf(pkg)
  const shipped = runtime.has(path)
  summary.set(license, (summary.get(license) ?? 0) + 1)
  if (forbidden.test(license)) {
    problems.push(`${id}: ${license} (forbidden)`)
    continue
  }
  if (accepted(license, permissive)) continue
  if (pkg.name.startsWith('@fontsource') && accepted(license, fonts)) continue
  if (!shipped && accepted(license, buildOnly)) continue
  problems.push(`${id}: ${license}${shipped ? ' (shipped in the bundle)' : ''}`)
}

for (const [license, count] of [...summary.entries()].sort((a, b) => b[1] - a[1])) {
  console.log(`${String(count).padStart(5)}  ${license}`)
}

if (problems.length > 0) {
  console.error(`\nLicenses not allowed:\n${problems.map((item) => `  - ${item}`).join('\n')}`)
  process.exit(1)
}
console.log(`\n${runtime.size} runtime packages and all dev packages pass the license policy.`)
