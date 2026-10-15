import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const styles = readFileSync(
  new URL('../assets/main.css', import.meta.url),
  'utf8',
)
const source = readFileSync(
  new URL('./PhoneLockScreen.vue', import.meta.url),
  'utf8',
)

describe('PhoneLockScreen notification theme contract', () => {
  it('uses the dedicated Lock Screen wallpaper preference', () => {
    expect(source).toContain('settings.lockWallpaperImageUrl')
    expect(source).toContain('settings.lockWallpaper')
    expect(source).not.toContain('settings.wallpaperImageUrl')
  })

  it('uses explicit light and dark notification material tokens', () => {
    expect(styles).toMatch(
      /\.lock-screen\s*\{[^}]*--lock-notification-background:\s*rgb\(38 36 40 \/ 20%\)[^}]*--lock-notification-color:\s*#fff/s,
    )
    expect(styles).toMatch(
      /\.phone-app--light \.lock-screen\s*\{[^}]*--lock-notification-background:\s*rgb\(247 247 248 \/ 56%\)[^}]*--lock-notification-color:\s*#111[^}]*--lock-notification-muted:\s*rgb\(0 0 0 \/ 55%\)/s,
    )
  })

  it('applies the adaptive tokens to cards, metadata, focus and clear all', () => {
    expect(styles).toMatch(
      /\.lock-screen__notification\s*\{[^}]*color:\s*var\(--lock-notification-color\)[^}]*background-color:\s*var\(--lock-notification-background\)[^}]*text-shadow:\s*var\(--lock-notification-text-shadow\)/s,
    )
    expect(styles).toMatch(
      /\.lock-screen__notifications-clear\s*\{[^}]*--sky-button-glass-text:\s*#fff/s,
    )
    expect(styles).toContain('color: var(--lock-notification-muted);')
    expect(styles).toContain(
      'outline: 2px solid var(--lock-notification-focus);',
    )
  })
})
