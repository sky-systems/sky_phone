import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'

import { createSSRApp, h } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'

import SkyButton from './SkyButton.vue'

describe('SkyButton', () => {
  it('renders a native button with the requested variants', async () => {
    const html = await renderToString(
      createSSRApp({
        render: () =>
          h(
            SkyButton,
            { outline: true, rounded: true, tonal: true, type: 'submit' },
            () => 'Continue',
          ),
      }),
    )

    expect(html).toContain('<button')
    expect(html).toContain('type="submit"')
    expect(html).toContain('sky-button--outline')
    expect(html).toContain('sky-button--rounded')
    expect(html).toContain('sky-button--tonal')
    expect(html).toContain('Continue')
  })

  it('renders interactive liquid glass buttons through the shared glass surface', async () => {
    const html = await renderToString(
      createSSRApp({
        render: () =>
          h(SkyButton, { glass: true, rounded: true }, () => 'Edit'),
      }),
    )

    expect(html).toContain('sky-button--glass')
    expect(html).toContain('sky-glass')
    expect(html).toContain('sky-glass--interactive')

    const controls = readFileSync(
      fileURLToPath(new URL('../controls.css', import.meta.url)),
      'utf8',
    )
    expect(controls).toMatch(
      /\.sky-glass\.sky-button--glass\s*\{[^}]*background:\s*var\(--sky-glass[^}]*box-shadow:\s*var\(--sky-shadow-glass\)/s,
    )
    expect(controls).toMatch(
      /\.sky-glass--interactive\s*\{[^}]*-webkit-backdrop-filter:\s*blur\(18px\) saturate\(145%\);[^}]*backdrop-filter:\s*blur\(18px\) saturate\(145%\);/s,
    )
  })

  it('keeps focus and pressed feedback on the contextual accent', () => {
    const uiDirectory = fileURLToPath(new URL('..', import.meta.url))
    const controls = readFileSync(`${uiDirectory}/controls.css`, 'utf8')
    const buttonStyles = controls.slice(
      controls.indexOf('.sky-button:focus-visible'),
      controls.indexOf('.sky-badge'),
    )

    expect(buttonStyles).toMatch(
      /\.sky-button:focus-visible[\s\S]*?outline: 2px solid var\(--sky-app-accent, #007aff\)/,
    )
    expect(buttonStyles).toMatch(
      /\.sky-button--primary:active:not\(:disabled\)\s*\{\s*background: var\(--sky-app-accent, #007aff\);\s*filter: brightness\(0\.86\)/,
    )
    expect(buttonStyles).toMatch(
      /\.sky-button--tonal:active:not\(:disabled\)\s*\{\s*background: var\(--sky-app-accent-soft, rgba\(0, 122, 255, 0\.15\)\);\s*filter: brightness\(0\.92\)/,
    )
    expect(buttonStyles).not.toContain('--sky-app-accent-shade')
  })

  it('keeps outline text accented through hover and pressed states', () => {
    const uiDirectory = fileURLToPath(new URL('..', import.meta.url))
    const controls = readFileSync(`${uiDirectory}/controls.css`, 'utf8')
    const buttonStyles = controls.slice(
      controls.indexOf('.sky-button:focus-visible'),
      controls.indexOf('.sky-badge'),
    )

    expect(buttonStyles).not.toContain('.sky-button--outline:hover')
    expect(buttonStyles).toMatch(
      /\.sky-button--outline:active:not\(:disabled\)\s*\{[\s\S]*?background:\s*var\(--sky-app-accent-soft, rgba\(0, 122, 255, 0\.15\)\);[\s\S]*?color:\s*var\(--sky-app-accent, #007aff\);[\s\S]*?filter:\s*none;/,
    )
    expect(buttonStyles).toMatch(
      /\.sky-button--danger\.sky-button--outline:active:not\(:disabled\)\s*\{[\s\S]*?background:\s*var\(--sky-danger-soft, rgba\(220, 38, 38, 0\.14\)\);[\s\S]*?color:\s*var\(--sky-danger, #dc2626\);/,
    )
    expect(buttonStyles).toContain(
      'color var(--sky-transition-fast, 100ms) ease,',
    )
  })
})
