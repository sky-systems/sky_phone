import { writeFile } from 'node:fs/promises'
import { test, expect } from '@playwright/test'
import { auditTheme } from './audit.mjs'

async function setMode(page, mode) {
  await page.evaluate(async (value) => {
    const { usePhoneStore } = await import('/src/stores/phone.ts')
    usePhoneStore().preferences.settings.appearanceMode = value
  }, mode)
  await page.waitForTimeout(250) // allow theme transitions to settle
}
async function audit(page, mode, name, testInfo) {
  const report = await page.evaluate(auditTheme, {
    selector: '.app-window',
    mode,
  })
  await writeFile(
    testInfo.outputPath(`${name}-${mode}.json`),
    JSON.stringify(report, null, 2),
  )
  await testInfo.attach(`${name}-${mode}-colors`, {
    body: JSON.stringify(report, null, 2),
    contentType: 'application/json',
  })
  await testInfo.attach(`${name}-${mode}`, {
    body: await page
      .locator('.phone-device')
      .screenshot({ path: testInfo.outputPath(`${name}-${mode}.png`) }),
    contentType: 'image/png',
  })
  expect
    .soft(
      report.checked.length + report.skipped.length,
      `${name}: no visible content`,
    )
    .toBeGreaterThan(0)
  const chrome = await page.evaluate(auditTheme, {
    selector: '.phone-status-bar',
    mode,
    checkPalette: false,
  })
  expect.soft(chrome.issues, `${name}: status bar colors`).toEqual([])
  expect
    .soft(
      report.issues,
      `${name} (${mode}): incorrect theme or unreadable colors`,
    )
    .toEqual([])
}

for (const initialMode of ['light', 'dark']) {
  test(`every registered app: ${initialMode} and live theme switch`, async ({
    page,
  }, testInfo) => {
    const errors = []
    page.on('pageerror', (error) => errors.push(error.message))
    await page.goto('/?apiPort=3098#/apps/phone')
    await expect(page.locator('.app-window .sky-app-page')).toBeVisible()
    await page.waitForTimeout(800) // bootstrap may restore the initial route
    const apps = await page.evaluate(async () => {
      const { PHONE_APPS } = await import('/src/config/apps.ts')
      return PHONE_APPS.filter(
        (app) => app.kind !== 'external' && !app.adminOnly,
      ).map((app) => ({ id: app.id, route: app.route }))
    })
    expect(apps.length).toBeGreaterThan(0)
    expect(new Set(apps.map((app) => app.id)).size).toBe(apps.length)
    await testInfo.attach('automatically-discovered-apps', {
      body: JSON.stringify(apps, null, 2),
      contentType: 'application/json',
    })
    for (const app of apps) {
      await test.step(app.id, async () => {
        await setMode(page, initialMode)
        await page.evaluate(async (route) => {
          const { default: router } = await import('/src/router/index.ts')
          await router.push(route)
        }, app.route)
        await expect(
          page.locator(`.app-window[data-app-id="${app.id}"]`),
        ).toBeVisible()
        await expect(page.locator('.app-loading')).toHaveCount(0)
        await page.waitForTimeout(500)
        await audit(page, initialMode, app.id, testInfo)
        const switchedMode = initialMode === 'light' ? 'dark' : 'light'
        await setMode(page, switchedMode)
        await audit(page, switchedMode, `${app.id}-switched`, testInfo)
      })
    }
    expect(errors, 'Uncaught errors while rendering registered apps').toEqual(
      [],
    )
  })
}

test('theme guard detects broken text, icons, inputs and page surfaces', async ({
  page,
}) => {
  await page.setContent(
    `<img aria-hidden="true" src="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg'/%3E" style="position:fixed;inset:0;width:100%;height:100%;pointer-events:none;z-index:2"><main class="app-window"><section class="sky-app-page" style="color-scheme:light;--sky-bg:white;--sky-text:black;background:black;color:white;width:400px;padding:20px"><p style="background:white;color:white">Broken white text</p><input value="Broken input" style="background:black;color:black"><p style="background:white;color:black">Readable control</p><button aria-label="Broken icon" style="background:white;color:white"><svg width="24" height="24" viewBox="0 0 24 24"><path stroke="currentColor" d="M2 12h20"/></svg></button><button aria-label="Readable layered icon" style="position:relative;color:white;background:white"><span style="position:absolute;inset:0;background:#b00000;pointer-events:none"></span><svg style="position:relative" width="24" height="24" viewBox="0 0 24 24"><path stroke="currentColor" d="M2 12h20"/></svg></button></section></main>`,
  )
  const report = await page.evaluate(auditTheme, {
    selector: '.app-window',
    mode: 'light',
  })
  expect(report.issues.some((issue) => issue.type === 'surface')).toBe(true)
  expect(
    report.issues.some((issue) => issue.text === 'Broken white text'),
  ).toBe(true)
  expect(report.issues.some((issue) => issue.kind === 'input')).toBe(true)
  expect(report.issues.some((issue) => issue.text === 'Broken icon')).toBe(true)
  expect(
    report.checked.some((item) => item.text === 'Readable layered icon'),
  ).toBe(true)
  expect(
    report.issues.some((issue) => issue.text === 'Readable layered icon'),
  ).toBe(false)
  expect(report.issues.some((issue) => issue.text === 'Readable control')).toBe(
    false,
  )
})
