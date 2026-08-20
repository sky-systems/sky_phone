import { existsSync, readdirSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import { fileURLToPath } from 'node:url'

import { describe, expect, it } from 'vitest'

const sourceDirectory = fileURLToPath(new URL('..', import.meta.url))
const tokensSource = readFileSync(new URL('./tokens.css', import.meta.url), 'utf8')
const mainCssSource = readFileSync(
  new URL('../assets/main.css', import.meta.url),
  'utf8',
)

function styleSources(directory: string): Array<{
  file: string
  source: string
}> {
  return readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const path = join(directory, entry.name)
    if (entry.isDirectory()) return styleSources(path)
    if (!/\.(?:css|vue)$/.test(entry.name)) return []
    return [{ file: path, source: readFileSync(path, 'utf8') }]
  })
}

describe('Inter font contract', () => {
  it('bundles normal and italic variable fonts for every supported weight', () => {
    expect(
      existsSync(new URL('../assets/fonts/InterVariable.woff2', import.meta.url)),
    ).toBe(true)
    expect(
      existsSync(
        new URL('../assets/fonts/InterVariable-Italic.woff2', import.meta.url),
      ),
    ).toBe(true)
    expect(tokensSource.match(/@font-face/g)).toHaveLength(2)
    expect(tokensSource.match(/font-weight:\s*100 900;/g)).toHaveLength(2)
    expect(tokensSource).toContain("--sky-font-family: 'Inter', Arial, sans-serif;")
  })

  it('applies the shared font to the document and native form controls', () => {
    expect(mainCssSource).toMatch(
      /:root\s*\{[\s\S]*?font-family:\s*var\(--sky-font-family\);/,
    )
    expect(mainCssSource).toMatch(
      /button,\s*input,\s*textarea,\s*select\s*\{\s*font:\s*inherit;/,
    )
  })

  it('does not bypass the shared token with a generic system UI stack', () => {
    const genericSystemStack =
      /font-family\s*:\s*(?:-apple-system|BlinkMacSystemFont|system-ui|ui-sans-serif|['"]Segoe UI['"])/
    const violations = styleSources(sourceDirectory)
      .filter(({ source }) => genericSystemStack.test(source))
      .map(({ file }) => file.slice(sourceDirectory.length + 1))

    expect(violations).toEqual([])
  })
})
