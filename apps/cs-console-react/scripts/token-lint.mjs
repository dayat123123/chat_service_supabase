import { readdirSync, readFileSync } from 'node:fs'
import { join, relative } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = fileURLToPath(new URL('..', import.meta.url))
const tokenFile = join(root, 'src', 'styles', 'globals.css')
const palette =
  'slate|gray|zinc|neutral|stone|red|orange|amber|yellow|lime|green|emerald|teal|cyan|sky|blue|indigo|violet|purple|fuchsia|pink|rose'
const utilities =
  'bg|text|border(?:-[xytrblse])?|ring(?:-offset)?|fill|stroke|outline|from|via|to|divide|decoration|caret|accent|placeholder|shadow|inset-shadow|drop-shadow'

const rules = [
  {
    message: 'hex color outside the token file',
    pattern: /(?<![\w&#/])#(?:[0-9a-fA-F]{8}|[0-9a-fA-F]{6}|[0-9a-fA-F]{3,4})(?![\w-])/g,
  },
  {
    message: 'raw Tailwind color class',
    pattern: new RegExp(
      `\\b(?:${utilities})-(?:white|black|(?:${palette})-(?:50|[1-9]00|950))(?:/\\d+)?\\b`,
      'g',
    ),
  },
  {
    message: 'CSS color function outside the token file',
    pattern: /\b(?:rgba?|hsla?|hwb|oklch|oklab|lab|lch|color-mix)\(/g,
  },
  {
    message: 'radius above 12px (use rounded-sm/md/lg/xl)',
    pattern: /\brounded(?:-[trblse]{1,2})?-(?:2xl|3xl)\b/g,
  },
  { message: 'shadow other than shadow-float', pattern: /\bshadow-(?:2xs|xs|sm|md|lg|xl|2xl)\b/g },
]

function files(dir) {
  return readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const path = join(dir, entry.name)
    if (entry.isDirectory()) return files(path)
    return /\.(?:css|tsx?|html)$/.test(entry.name) ? [path] : []
  })
}

const problems = []
for (const file of [...files(join(root, 'src')), join(root, 'index.html')]) {
  if (file === tokenFile) continue
  const lines = readFileSync(file, 'utf8').split(/\r?\n/)
  lines.forEach((line, index) => {
    for (const rule of rules) {
      for (const match of line.matchAll(rule.pattern)) {
        problems.push(`${relative(root, file)}:${index + 1}  ${rule.message}: ${match[0]}`)
      }
    }
  })
}

if (problems.length > 0) {
  console.error(problems.join('\n'))
  console.error(
    `\n${problems.length} token violation(s). Colors, radii and shadows only through src/styles/globals.css.`,
  )
  process.exit(1)
}
console.log('Token OK: no colors, radii or shadows outside the token file.')
