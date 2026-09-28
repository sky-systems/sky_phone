import { readFileSync } from 'node:fs'
import { test, expect } from '@playwright/test'

function generalLocale(language) {
  const source = readFileSync(
    new URL(`../../sky_phone/config/locales/${language}.lua`, import.meta.url),
    'utf8',
  )
  const body = source
    .split('            configurator = {')[1]
    .split('                context = ')[0]
  return JSON.parse(
    `{${body
      .replace(/^(\s*)(\w+) = /gm, '$1"$2": ')
      .replace(/,\s*([}\]])/g, '$1')
      .replace(/,\s*$/, '')}}`,
  )
}

async function openConfigurator(page, mode = 'dark', language = 'en') {
  await page.goto('/?apiPort=3098#/apps/phone')
  await expect(page.locator('.app-window .sky-app-page')).toBeVisible()
  await page.evaluate(
    async ({ mode, language, locale }) => {
      const { usePhoneStore } = await import('/src/stores/phone.ts')
      const phone = usePhoneStore()
      phone.preferences.settings.appearanceMode = mode
      phone.setLocale(
        language,
        { AdminPanel: { configurator: locale } },
        phone.fallbackLocales,
      )
      window.postMessage({ type: 'admin:open' }, '*')
    },
    { mode, language, locale: generalLocale(language) },
  )
  await page.locator('.admin-panel-rail__configurator').click()
  await expect(page.locator('.admin-general-settings')).toBeVisible()
}

for (const [mode, language, width, height] of [
  ['light', 'en', 1280, 800],
  ['dark', 'de', 1920, 1080],
]) {
  test(`General page remains readable at ${width} in ${mode}/${language}`, async ({
    page,
  }, testInfo) => {
    await page.setViewportSize({ width, height })
    await openConfigurator(page, mode, language)
    const general = page.locator('.admin-general-settings')
    await expect(general.locator('[data-config-path]')).toHaveCount(20)
    await expect(general).not.toContainText('AdminPanel.configurator')
    await expect(
      general.getByRole('heading', {
        name: language === 'de' ? 'Geräte & SIM-Karten' : 'Devices & SIM cards',
      }),
    ).toBeVisible()
    expect(
      await general.evaluate(
        (element) => element.scrollWidth <= element.clientWidth,
      ),
    ).toBe(true)
    await page.screenshot({ path: testInfo.outputPath('general.png') })
    const keys = general.locator('[data-config-path="Phone.Keybind"]')
    await keys.scrollIntoViewIfNeeded()
    await page.screenshot({ path: testInfo.outputPath('keys.png') })
    for (const button of await keys.getByRole('button').all()) {
      const bounds = await button.boundingBox()
      expect(bounds.height).toBeGreaterThanOrEqual(44)
    }
  })
}

test('General and detail views share edits; key capture cancels, validates OEM keys and saves', async ({
  page,
}) => {
  let configuration
  let rejectSave = true
  await page.route('**/admin:configurator', async (route) => {
    if (!configuration) {
      configuration = (await (await route.fetch()).json()).data
      const fields = configuration.sections.flatMap((section) => section.fields)
      Object.assign(fields.find((field) => field.path === 'Phone').value, {
        Unique: true,
        Keybind: 'F1',
      })
      fields.find((field) => field.path === 'Sim').value.Enabled = true
    }
    await route.fulfill({ json: { success: true, data: configuration } })
  })
  await page.route('**/admin:save-configurator', async (route) => {
    if (rejectSave) {
      rejectSave = false
      await route.fulfill({ json: { success: false, error: 'request_failed' } })
      return
    }
    const payload = route.request().postDataJSON()
    expect(payload.revision).toBe(configuration.revision)
    for (const change of payload.changes) {
      const field = configuration.sections
        .flatMap((section) => section.fields)
        .find(
          (entry) => entry.scope === change.scope && entry.path === change.path,
        )
      field.value = change.value
    }
    configuration.revision += 1
    await route.fulfill({ json: { success: true, data: configuration } })
  })
  await openConfigurator(page)
  const general = page.locator('.admin-general-settings')
  const unique = general.locator('[data-config-path="Phone.Unique"]')
  await unique.getByRole('switch').press('Space')
  await general
    .locator('[data-config-path="Sim.Enabled"]')
    .getByRole('switch')
    .press('Space')
  const key = general.locator('[data-config-path="Phone.Keybind"]')
  await key.getByRole('button', { name: 'Record key' }).click()
  await page.keyboard.press('Escape')
  await expect(general).toBeVisible()
  await expect(key.getByRole('combobox')).toHaveValue('F1')
  await key.getByRole('button', { name: 'Record key' }).click()
  await page.keyboard.press('Control+k')
  await expect(key.getByRole('status')).toContainText('cannot be mapped safely')
  await expect(key.getByRole('combobox')).toHaveValue('F1')
  await page.keyboard.down('Control')
  await page.keyboard.down('Shift')
  await page.keyboard.up('Control')
  await page.keyboard.up('Shift')
  await expect(key.getByRole('status')).toContainText('cannot be mapped safely')
  await expect(key.getByRole('combobox')).toHaveValue('F1')
  await page.evaluate(() =>
    window.dispatchEvent(
      new KeyboardEvent('keydown', {
        key: 'ü',
        code: 'BracketLeft',
        keyCode: 186,
        bubbles: true,
        cancelable: true,
      }),
    ),
  )
  await expect(key.getByRole('combobox')).toHaveValue('OEM_1')
  await key.getByRole('switch').press('Space')
  await expect(key.getByRole('combobox')).toBeDisabled()
  await key.getByRole('switch').press('Space')
  await expect(key.getByRole('combobox')).toHaveValue('OEM_1')

  await page
    .locator('.admin-panel-config-sections button')
    .filter({ has: page.locator('strong', { hasText: /^Phone$/ }) })
    .click()
  await expect(
    page.locator('.admin-config-keybind').getByRole('combobox'),
  ).toHaveValue('OEM_1')
  await page
    .locator('.admin-panel-config-sections button')
    .filter({ has: page.locator('strong', { hasText: /^General$/ }) })
    .click()
  await expect(unique.getByRole('switch')).not.toBeChecked()
  const failedSave = page.waitForResponse((response) =>
    response.url().includes('admin:save-configurator'),
  )
  await page.getByRole('button', { name: 'Save changes', exact: true }).click()
  await failedSave
  await expect(
    page.getByRole('button', { name: 'Save changes', exact: true }),
  ).toBeEnabled()
  await expect(unique.getByRole('switch')).not.toBeChecked()
  await expect(key.getByRole('combobox')).toHaveValue('OEM_1')
  const save = page.waitForRequest((request) =>
    request.url().includes('admin:save-configurator'),
  )
  await page.getByRole('button', { name: 'Save changes', exact: true }).click()
  const payload = (await save).postDataJSON()
  const phoneChange = payload.changes.find((entry) => entry.path === 'Phone')
  expect(phoneChange.value.Unique).toBe(false)
  expect(phoneChange.value.Keybind).toBe('OEM_1')
  expect(
    payload.changes.find((entry) => entry.path === 'Sim').value.Enabled,
  ).toBe(false)
  await expect(
    page.getByRole('button', { name: 'Save changes', exact: true }),
  ).toBeDisabled()
  await page.reload()
  await expect(page.locator('.app-window .sky-app-page')).toBeVisible()
  await page.evaluate(() => window.postMessage({ type: 'admin:open' }, '*'))
  await page.locator('.admin-panel-rail__configurator').click()
  await expect(
    page.locator('[data-config-path="Phone.Unique"]').getByRole('switch'),
  ).not.toBeChecked()
  await expect(
    page.locator('[data-config-path="Phone.Keybind"]').getByRole('combobox'),
  ).toHaveValue('OEM_1')
})

test('a failed configurator request can be retried', async ({ page }) => {
  await page.route('**/admin:configurator', (route) =>
    route.fulfill({ json: { success: false, error: 'forbidden' } }),
  )
  await page.goto('/?apiPort=3098#/apps/phone')
  await expect(page.locator('.app-window .sky-app-page')).toBeVisible()
  await page.evaluate(() => window.postMessage({ type: 'admin:open' }, '*'))
  await page.locator('.admin-panel-rail__configurator').click()
  await expect(page.locator('.admin-panel-config-error')).toBeVisible()
  await page.unroute('**/admin:configurator')
  await page.getByRole('button', { name: 'Retry', exact: true }).click()
  await expect(page.locator('.admin-general-settings')).toBeVisible()
})

test('file mode keeps General visible but locks every editor', async ({
  page,
}) => {
  await page.route('**/admin:configurator', async (route) => {
    const response = await route.fetch()
    const payload = await response.json()
    payload.data.enabled = false
    await route.fulfill({ response, json: payload })
  })
  await openConfigurator(page)
  await expect(
    page.getByText('SQL configuration is not active', { exact: true }),
  ).toBeVisible()
  for (const control of await page
    .locator('.admin-general-settings')
    .locator('input, select, button')
    .all())
    await expect(control).toBeDisabled()
})
