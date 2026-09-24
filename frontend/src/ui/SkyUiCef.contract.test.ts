import { readdirSync, readFileSync } from 'node:fs'
import { join, relative } from 'node:path'
import { fileURLToPath } from 'node:url'

import { describe, expect, it } from 'vitest'

const uiDirectory = fileURLToPath(new URL('.', import.meta.url))
const frontendDirectory = fileURLToPath(new URL('..', import.meta.url))
const mainSource = readFileSync(new URL('../main.ts', import.meta.url), 'utf8')
const mainCssSource = readFileSync(
  new URL('../assets/main.css', import.meta.url),
  'utf8',
)
const appProfileAuthSource = readFileSync(
  new URL('../components/account/AppProfileAuth.vue', import.meta.url),
  'utf8',
)

interface StyleSource {
  content: string
  name: string
}

function displayPath(path: string): string {
  return relative(uiDirectory, path).replace(/\\/g, '/')
}

function walkFiles(directory: string): string[] {
  return readdirSync(directory, { withFileTypes: true })
    .flatMap((entry) => {
      const path = join(directory, entry.name)
      return entry.isDirectory() ? walkFiles(path) : [path]
    })
    .sort()
}

function productionUiSources(): string[] {
  return walkFiles(uiDirectory).filter(
    (path) =>
      /\.(?:ts|vue)$/.test(path) && !/\.(?:test|spec)\.(?:ts|tsx)$/.test(path),
  )
}

function uiStyleSources(): StyleSource[] {
  const sources: StyleSource[] = walkFiles(uiDirectory)
    .filter((path) => path.endsWith('.css'))
    .map((path) => ({
      content: readFileSync(path, 'utf8'),
      name: displayPath(path),
    }))

  for (const path of walkFiles(uiDirectory).filter((file) =>
    file.endsWith('.vue'),
  )) {
    const componentSource = readFileSync(path, 'utf8')
    const styles = Array.from(
      componentSource.matchAll(/<style\b[^>]*>([\s\S]*?)<\/style>/gi),
      ([, content]) => content,
    )

    styles.forEach((content, index) => {
      sources.push({
        content,
        name: `${displayPath(path)}#style-${index + 1}`,
      })
    })
  }

  return sources
}

function withoutCssComments(source: string): string {
  return source.replace(/\/\*[\s\S]*?\*\//g, '')
}

describe('Sky UI FiveM CEF contracts', () => {
  it('does not import transitional Konsta components into Sky UI', () => {
    const forbiddenModule = ['konsta', 'vue'].join('/')
    const escapedModule = forbiddenModule.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
    const forbiddenImport = new RegExp(
      `(?:\\bfrom\\s*|\\bimport\\s*\\(\\s*|\\brequire\\s*\\(\\s*|\\bimport\\s+)['"]${escapedModule}(?:/[^'"]*)?['"]`,
    )
    const offenders = productionUiSources()
      .filter((path) => forbiddenImport.test(readFileSync(path, 'utf8')))
      .map(displayPath)

    expect(offenders).toEqual([])
  })

  it('keeps shared styles within the conservative Chrome 103 feature floor', () => {
    const forbiddenFeatures = [
      { name: ':has()', pattern: /:has\s*\(/i },
      {
        name: 'container queries',
        pattern: /@container\b|(?:^|[;{])\s*container(?:-type|-name)?\s*:/im,
      },
      {
        name: 'dynamic viewport units',
        pattern: /(?:^|[^a-z0-9_-])(?:\d*\.)?\d+(?:dvh|svh|lvh)\b/i,
      },
      { name: 'color-mix()', pattern: /color-mix\s*\(/i },
      { name: 'oklab()', pattern: /oklab\s*\(/i },
      { name: 'oklch()', pattern: /oklch\s*\(/i },
      {
        name: 'CSS math division',
        pattern: /calc\([^)]*\s\/\s[^)]*\)/i,
      },
    ]
    const violations = uiStyleSources().flatMap(({ content, name }) => {
      const css = withoutCssComments(content)

      return forbiddenFeatures
        .filter(({ pattern }) => pattern.test(css))
        .map(({ name: feature }) => `${name}: ${feature}`)
    })

    expect(violations).toEqual([])
  })

  it('does not make production component styling depend on :has()', () => {
    const offenders = walkFiles(frontendDirectory)
      .filter(
        (path) =>
          /\.(?:css|vue)$/.test(path) &&
          !/\.(?:test|spec)\.(?:ts|tsx)$/.test(path),
      )
      .filter((path) => /:has\s*\(/i.test(readFileSync(path, 'utf8')))
      .map((path) => relative(frontendDirectory, path).replace(/\\/g, '/'))

    expect(offenders).toEqual([])
  })

  it('keeps variable profile color mixes behind Chrome 103 fallbacks', () => {
    expect(appProfileAuthSource).toMatch(
      /\.app-profile-auth__card\s*\{[^}]*background:\s*var\(--sky-surface\);[^}]*background:\s*color-mix\(/s,
    )
    expect(appProfileAuthSource).toMatch(
      /\.app-profile-auth__mark\s*\{[^}]*background:\s*rgba\(255, 214, 62, 0\.14\);[^}]*background:\s*color-mix\(/s,
    )
    expect(appProfileAuthSource).toMatch(
      /\.app-profile-auth__avatar\s*\{[^}]*background:\s*var\(--sky-surface\);[^}]*background:\s*color-mix\(/s,
    )
  })

  it('keeps Performance hold transforms on the Chrome 103 syntax floor', () => {
    const performanceStart = mainCssSource.indexOf(
      '/* FiveM CEF blur-free glass fallback.',
    )
    const performanceEnd = mainCssSource.indexOf(
      '/* Chromium 103 cannot resolve color-mix()',
      performanceStart,
    )
    const performanceCss = mainCssSource.slice(
      performanceStart,
      performanceEnd,
    )

    expect(performanceStart).toBeGreaterThanOrEqual(0)
    expect(performanceEnd).toBeGreaterThan(performanceStart)
    expect(performanceCss).not.toMatch(/(?:^|[;{])\s*scale\s*:/m)
    expect(performanceCss).toMatch(
      /transform:\s*translate3d\([\s\S]*?var\(--tw-translate-x, 0\)[\s\S]*?var\(--tw-translate-y, 0\)[\s\S]*?scale\(1\) !important;/,
    )
  })

  it('keeps optional glass blur behind a solid CEF fallback', () => {
    const blurDeclaration = /(?:^|[;{])\s*(?:-webkit-)?backdrop-filter\s*:/im
    const blurSources = uiStyleSources().filter(({ content }) =>
      blurDeclaration.test(withoutCssComments(content)),
    )
    const violations = blurSources.flatMap(({ content, name }) => {
      const css = withoutCssComments(content)
      const failures: string[] = []

      if (!/@supports\s*\([^{}]*backdrop-filter[^{}]*\)\s*\{/im.test(css)) {
        failures.push(`${name}: glass blur is not feature-gated`)
      }
      if (!/background(?:-color)?\s*:[^;]*var\(--sky-glass-solid/im.test(css)) {
        failures.push(`${name}: glass blur has no solid background fallback`)
      }

      return failures
    })

    expect(violations).toEqual([])
  })

  it('loads tokens before the shared foundation, controls, settings, and overlays', () => {
    const requiredOrder = [
      './ui/tokens.css',
      './ui/foundation.css',
      './ui/controls.css',
      './ui/settings.css',
      './ui/overlays.css',
    ]
    const stylesheetImports = Array.from(
      mainSource.matchAll(/^\s*import\s+['"]([^'"]+\.css)['"]\s*;?\s*$/gm),
      ([, path]) => path,
    )
    const sharedStylesheetImports = stylesheetImports.filter((path) =>
      requiredOrder.includes(path),
    )

    expect(sharedStylesheetImports).toEqual(requiredOrder)
    for (const path of requiredOrder) {
      expect(stylesheetImports.filter((value) => value === path)).toHaveLength(
        1,
      )
    }
  })
})
