import { readFileSync } from 'node:fs'
import { test, expect } from '@playwright/test'
import { auditTheme } from './audit.mjs'

function germanLocale() {
  const source = readFileSync(
    new URL('../../sky_phone/config/locales/de.lua', import.meta.url),
    'utf8',
  )
  const match = source.match(/^( +)knoway = \{/m)
  const body = source
    .slice(match.index + match[0].length)
    .split(new RegExp(`\\r?\\n${match[1]}},`))[0]
  return JSON.parse(
    `{${body
      .replace(/^(\s*)(\w+) = /gm, '$1"$2": ')
      .replace(/,\s*([}\]])/g, '$1')
      .replace(/,\s*$/, '')}}`,
  )
}

for (const mode of ['light', 'dark']) {
  test(`KnoWay iOS ordering and ride lifecycle in ${mode}`, async ({
    page,
  }, testInfo) => {
    const errors = []
    page.on('pageerror', (error) => errors.push(error.message))
    await page.goto(
      `/?browserPreview&apiPort=3098&testScenario=knoway-${mode}#/apps/knoway`,
      { waitUntil: 'domcontentloaded' },
    )
    await expect(page.locator('.knoway-app')).toBeVisible()
    await page.evaluate(
      async ({ mode, locale }) => {
        const { usePhoneStore } = await import('/src/stores/phone.ts')
        const phone = usePhoneStore()
        phone.preferences.settings.appearanceMode = mode
        phone.setLocale(
          'de',
          { Apps: { knoway: locale } },
          phone.fallbackLocales,
        )
      },
      { mode, locale: germanLocale() },
    )
    await expect(page.locator('.knoway-map')).toBeVisible()
    await expect
      .poll(() =>
        page
          .locator('.knoway-map')
          .evaluate((element) => element.getBoundingClientRect().height),
      )
      .toBeGreaterThan(240)
    await expect(page.locator('.knoway-map-crosshair')).toHaveCount(0)
    await page.getByRole('button', { name: 'GPS-Wegpunkt übernehmen' }).click()
    await page.getByRole('button', { name: 'Festpreis anzeigen' }).click()
    await expect(
      page.getByRole('button', { name: /Fahrt bestellen/ }),
    ).toBeEnabled()
    await expect(page.getByText('Legion Square', { exact: true })).toBeVisible()
    await page
      .locator('.phone-device')
      .screenshot({ path: testInfo.outputPath(`knoway-${mode}-quote.png`) })
    const report = await page.evaluate(auditTheme, {
      selector: '.app-window',
      mode,
    })
    expect(report.issues).toEqual([])
    await page.getByRole('button', { name: /Fahrt bestellen/ }).click()
    await expect(
      page.getByRole('button', { name: 'Fahrt starten' }),
    ).toBeVisible({ timeout: 12000 })
    await page.evaluate(() => {
      window.postMessage(
        {
          type: 'cellular:update',
          data: {
            enabled: true,
            hasSignal: false,
            bars: 0,
            offlineApps: { knoway: false },
            onlineActions: {},
            appNamespaces: {},
            systemNamespaces: {
              ui: true,
              device: true,
              close: true,
              navigation: true,
            },
            cleanupActions: {
              'knoway:bootstrap': true,
              'knoway:start': true,
              'knoway:cancel': true,
            },
          },
        },
        '*',
      )
    })
    await expect(page.locator('.phone-no-signal')).toBeVisible()
    await expect(page.locator('.knoway-app')).toBeVisible()
    await page.getByRole('button', { name: 'Fahrt starten' }).click()
    await expect(
      page.getByRole('button', { name: 'Fahrt beenden' }),
    ).toBeVisible()
    await page
      .locator('.phone-device')
      .screenshot({ path: testInfo.outputPath(`knoway-${mode}-driving.png`) })
    await page.getByRole('button', { name: 'Home', exact: true }).click()
    await expect(page.locator('.app-window[data-app-id="knoway"]')).toHaveCount(
      0,
    )
    await page.evaluate(async () => {
      const { default: router } = await import('/src/router/index.ts')
      await router.push('/apps/knoway')
    })
    await expect(
      page.getByRole('button', { name: 'Fahrt beenden' }),
    ).toBeVisible()
    await expect(page.locator('.phone-no-signal')).toBeVisible()
    await page.getByRole('button', { name: 'Fahrt beenden' }).click()
    await expect(
      page.getByRole('button', { name: 'Neue Fahrt planen' }),
    ).toBeVisible()
    expect(errors).toEqual([])
  })
}
