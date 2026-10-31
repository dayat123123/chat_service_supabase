import AxeBuilder from '@axe-core/playwright'
import { expect, type Page } from '@playwright/test'

const viewports = [
  { width: 1366, height: 768 },
  { width: 1920, height: 1080 },
  { width: 2560, height: 1440 },
]

const chrome = 'button, [role="tab"], a, h1, h2, h3, th, label, [role="menuitem"]'

export async function audit(page: Page, label: string) {
  await page.waitForTimeout(300)
  const result = await new AxeBuilder({ page })
    .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'])
    .exclude('[data-sonner-toaster]')
    .analyze()
  const report = result.violations.map(
    (violation) =>
      `${label}: ${violation.id} (${violation.impact ?? ''}) ${violation.nodes
        .slice(0, 5)
        .map(
          (node) =>
            `${node.target.join(' ')} → ${node.failureSummary?.split('\n').slice(1, 2).join('') ?? ''}`,
        )
        .join(' | ')}`,
  )
  expect(report, report.join('\n')).toEqual([])
}

async function layoutProblems(page: Page) {
  return page.evaluate((selector) => {
    const problems: string[] = []
    const root = document.documentElement
    if (root.scrollWidth > window.innerWidth) problems.push(`scroll horizontal ${root.scrollWidth}px`)
    const describe = (element: Element) =>
      `${element.tagName.toLowerCase()}${element.getAttribute('aria-label') ? `[${element.getAttribute('aria-label')}]` : ''} "${(element.textContent ?? '').trim().slice(0, 40)}"`
    for (const element of Array.from(document.querySelectorAll<HTMLElement>('body *'))) {
      if (!element.offsetParent || element.closest('[aria-hidden="true"]')) continue
      const box = element.getBoundingClientRect()
      const style = getComputedStyle(element)
      if (box.width <= 1 || box.height <= 1 || style.clipPath.startsWith('inset(50%')) continue
      const clipsX = ['hidden', 'clip'].includes(style.overflowX)
      const hasText = Array.from(element.childNodes).some(
        (node) => node.nodeType === Node.TEXT_NODE && (node.textContent ?? '').trim() !== '',
      )
      if (!clipsX || !hasText || element.scrollWidth <= element.clientWidth + 1) continue
      if (style.textOverflow !== 'ellipsis') problems.push(`teks terpotong: ${describe(element)}`)
      else if (element.matches(selector) || element.closest(selector))
        problems.push(`label terpotong: ${describe(element)}`)
    }
    return problems
  }, chrome)
}

export async function checkLayout(page: Page, label: string) {
  const original = page.viewportSize()
  for (const viewport of viewports) {
    await page.setViewportSize(viewport)
    await page.waitForTimeout(250)
    const problems = await layoutProblems(page)
    expect(problems, `${label} ${viewport.width}×${viewport.height}\n${problems.join('\n')}`).toEqual([])
  }
  if (original) await page.setViewportSize(original)
}
