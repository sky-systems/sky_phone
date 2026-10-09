import { readFileSync } from 'node:fs'
import { test, expect } from '@playwright/test'

function configuratorLocale(language) {
  const source = readFileSync(
    new URL(`../../sky_phone/config/locales/${language}.lua`, import.meta.url),
    'utf8',
  )
  const body = source
    .split('            configurator = {')[1]
    .split(/\r?\n            },/)[0]
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
    { mode, language, locale: configuratorLocale(language) },
  )
  await page.locator('.admin-panel-rail__configurator').click()
  await page
    .locator('.admin-panel-config-sections button')
    .filter({
      has: page.locator('strong', {
        hasText: language === 'de' ? /^Allgemein$/ : /^General$/,
      }),
    })
    .click()
  await expect(page.locator('.admin-general-settings')).toBeVisible()
}

for (const [mode, language, width, height] of [
  ['light', 'en', 1280, 800],
  ['dark', 'en', 1360, 860],
  ['dark', 'de', 1920, 1080],
  ['dark', 'en', 2560, 1440],
]) {
  test(`General matches panel controls at ${width} in ${mode}/${language}`, async ({
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
    await page.locator('.admin-panel-window').screenshot({
      path: testInfo.outputPath('general-panel.png'),
    })
    const generalStyle = await general.evaluate((element) => {
      const title = getComputedStyle(
        element.querySelector('.sky-settings-row__title'),
      )
      const description = getComputedStyle(
        element.querySelector('.sky-settings-row__description'),
      )
      const field = getComputedStyle(
        element.querySelector('.sky-field--control'),
      )
      const input = getComputedStyle(element.querySelector('.sky-field__input'))
      const toggle = getComputedStyle(
        element.querySelector('.sky-toggle--checked .sky-toggle__track'),
      )
      return {
        titleSize: title.fontSize,
        titleWeight: title.fontWeight,
        descriptionSize: description.fontSize,
        fieldRadius: field.borderRadius,
        fieldBackground: field.backgroundColor,
        fieldSize: input.fontSize,
        toggleWidth: toggle.width,
        toggleHeight: toggle.height,
        toggleBackground: toggle.backgroundColor,
        groupRadius: getComputedStyle(
          element.querySelector('.sky-settings-group__list'),
        ).borderRadius,
      }
    })
    for (const toggle of await general.getByRole('switch').all()) {
      const bounds = await toggle.boundingBox()
      expect(bounds.width).toBeGreaterThanOrEqual(44)
      expect(bounds.height).toBeGreaterThanOrEqual(44)
    }
    const keys = general.locator('[data-config-path="Phone.Keybind"]')
    await keys.scrollIntoViewIfNeeded()
    await page.screenshot({ path: testInfo.outputPath('keys.png') })
    for (const button of await keys.getByRole('button').all()) {
      const bounds = await button.boundingBox()
      expect(bounds.height).toBeGreaterThanOrEqual(44)
    }
    await page
      .locator('.admin-panel-config-sections button')
      .filter({ has: page.locator('strong', { hasText: /^Companies$/ }) })
      .click()
    const panelStyle = await page
      .locator('.admin-panel-config-fields')
      .evaluate((element) => {
        const title = getComputedStyle(
          element.querySelector('.admin-panel-config-field__copy strong'),
        )
        const description = getComputedStyle(
          element.querySelector('.admin-panel-config-field__copy small'),
        )
        const field = getComputedStyle(
          element.querySelector('.admin-panel-config-field > input'),
        )
        const toggle = getComputedStyle(
          element.querySelector('.admin-panel-config-toggle input:checked + i'),
        )
        return {
          titleSize: title.fontSize,
          titleWeight: title.fontWeight,
          descriptionSize: description.fontSize,
          fieldRadius: field.borderRadius,
          fieldBackground: field.backgroundColor,
          fieldSize: field.fontSize,
          toggleWidth: toggle.width,
          toggleHeight: toggle.height,
          toggleBackground: toggle.backgroundColor,
        }
      })
    const { groupRadius, ...generalControls } = generalStyle
    expect(generalControls).toEqual(panelStyle)
    expect(parseFloat(groupRadius)).toBeLessThanOrEqual(
      parseFloat(panelStyle.fieldRadius),
    )
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

for (const language of ['en', 'de']) {
  test(`phone control filters can be cleared, added and saved in ${language}`, async ({
    page,
  }, testInfo) => {
    let configuration
    await page.route('**/admin:configurator', async (route) => {
      configuration ??= (await (await route.fetch()).json()).data
      await route.fulfill({ json: { success: true, data: configuration } })
    })
    await page.route('**/admin:save-configurator', async (route) => {
      const payload = route.request().postDataJSON()
      expect(payload.changes).toHaveLength(1)
      expect(payload.changes[0].path).toBe('Phone')
      configuration.sections
        .flatMap((section) => section.fields)
        .find((field) => field.path === 'Phone').value =
        payload.changes[0].value
      configuration.revision += 1
      await route.fulfill({ json: { success: true, data: configuration } })
    })
    async function openControls() {
      await openConfigurator(page, 'dark', language)
      await page
        .locator('.admin-panel-config-sections button')
        .filter({ has: page.locator('strong', { hasText: /^Phone$/ }) })
        .click()
      await page
        .getByRole('tab', {
          name:
            language === 'de'
              ? /Blockierte GTA-Steuerungen/
              : /Blocked GTA controls/,
        })
        .click()
      return page.getByRole('tabpanel')
    }
    let editor = await openControls()
    await expect(editor.getByRole('spinbutton')).toHaveCount(11)
    await expect(editor).not.toContainText('AdminPanel.configurator')
    await expect(editor).toContainText(
      language === 'de' ? 'Waffenwechsel' : 'weapon switching',
    )
    await page
      .locator('.admin-panel-window')
      .screenshot({ path: testInfo.outputPath('blocked-controls.png') })
    for (let index = 0; index < 11; index += 1) {
      await editor.locator('.config-structured-editor__remove').first().click()
    }
    await expect(editor.getByRole('spinbutton')).toHaveCount(0)
    await editor
      .getByRole('button', {
        name: language === 'de' ? 'Zeile hinzufügen' : 'Add row',
      })
      .click()
    await editor.getByRole('spinbutton').fill('22')
    await editor.getByRole('spinbutton').press('Tab')
    const save = page.getByRole('button', { name: 'Save changes', exact: true })
    await save.click()
    await expect(save).toBeDisabled()
    editor = await openControls()
    await expect(editor.getByRole('spinbutton')).toHaveCount(1)
    await expect(editor.getByRole('spinbutton')).toHaveValue('22')
    await editor.locator('.config-structured-editor__remove').click()
    await save.click()
    await expect(save).toBeDisabled()
    editor = await openControls()
    await expect(editor.getByRole('spinbutton')).toHaveCount(0)
    await editor
      .getByRole('button', {
        name: language === 'de' ? 'Zeile hinzufügen' : 'Add row',
      })
      .click()
    await expect(editor.getByRole('spinbutton')).toHaveValue('0')
  })
}

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
