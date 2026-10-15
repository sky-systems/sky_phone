import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const appSource = readFileSync(new URL('../App.vue', import.meta.url), 'utf8')
const kitchenSinkSource = readFileSync(
  new URL('../views/development/SkyUiKitchenSinkView.vue', import.meta.url),
  'utf8',
)
const indicatorsSource = readFileSync(
  new URL('./PhoneStatusIndicators.vue', import.meta.url),
  'utf8',
)
const styles = readFileSync(
  new URL('../assets/main.css', import.meta.url),
  'utf8',
)

describe('phone status bar theme contract', () => {
  it('treats the Sky UI development catalog as app content', () => {
    expect(appSource).toContain(
      "'phone-screen--app': isAppRoute || isDevelopmentRoute",
    )
  })

  it('keeps the Kitchen Sink toggle and phone shell on one theme source', () => {
    expect(kitchenSinkSource).toMatch(
      /const dark = computed\(\{[\s\S]*?get: \(\) => phone\.isDarkMode,[\s\S]*?phone\.setPreference\('appearanceMode', value \? 'dark' : 'light'\)/,
    )
  })

  it('uses black in light app content and white in dark content', () => {
    expect(styles).toMatch(/\.phone-status-bar\s*\{[^}]*color:\s*#fff;/s)
    expect(styles).toMatch(
      /\.phone-screen--app \.phone-app--light \.phone-status-bar\s*\{\s*color:\s*#000;/,
    )
  })

  it('keeps status indicators legible on apps with fixed canvases', () => {
    expect(appSource).toContain("'phone-app--status-light'")
    expect(appSource).toContain("'phone-app--status-dark'")
    expect(styles).toMatch(
      /\.phone-screen--app \.phone-app--status-light \.phone-status-bar\s*\{[^}]*color:\s*#fff;/s,
    )
    expect(styles).toMatch(
      /\.phone-screen--app \.phone-app--status-dark \.phone-status-bar\s*\{[^}]*color:\s*#111;/s,
    )
  })

  it('keeps every status indicator bound to the inherited foreground', () => {
    expect(indicatorsSource).toMatch(
      /<SkyIcon\s+:icon="Plane"[\s\S]*?fill="currentColor"/,
    )
    expect(indicatorsSource).toMatch(
      /\.phone-status-indicators__signal\s*\{[^}]*fill:\s*currentColor;/s,
    )
    expect(indicatorsSource).toMatch(
      /\.phone-status-indicators__wifi\s*\{[^}]*stroke:\s*currentColor;/s,
    )
    expect(indicatorsSource).toMatch(
      /\.phone-status-indicators__wifi circle\s*\{[^}]*fill:\s*currentColor;/s,
    )
    expect(indicatorsSource).toMatch(
      /\.phone-status-indicators__battery\s*\{[^}]*fill:\s*currentColor;/s,
    )
    expect(indicatorsSource).toMatch(
      /\.phone-status-indicators__battery rect:first-child\s*\{[^}]*stroke:\s*currentColor;/s,
    )
  })
})
