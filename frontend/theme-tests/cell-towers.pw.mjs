import { readFileSync } from 'node:fs'
import { test, expect } from '@playwright/test'

function localeBranch(language, start, end) {
  const source = readFileSync(
    new URL(`../../sky_phone/config/locales/${language}.lua`, import.meta.url),
    'utf8',
  )
  const body = source.split(start)[1].split(end)[0]
  return JSON.parse(
    `{${body
      .replace(/^(\s*)(\w+) = /gm, '$1"$2": ')
      .replace(/,\s*([}\]])/g, '$1')
      .replace(/,\s*$/, '')}}`,
  )
}

for (const [language, mode] of [
  ['en', 'light'],
  ['de', 'dark'],
]) {
  test(`physical towers and current location in ${language}/${mode}`, async ({
    page,
  }, testInfo) => {
    const cellular = localeBranch(
      language,
      '        Cellular = {',
      /\r?\n        },\r?\n        FaceId/,
    )
    const configurator = localeBranch(
      language,
      '            configurator = {',
      /\r?\n            },/,
    )
    const errors = []
    page.on('pageerror', (error) => errors.push(error.message))
    await page.goto('/?apiPort=3098#/apps/phone')
    await expect(page.locator('.app-window .sky-app-page')).toBeVisible()
    await page.evaluate(
      async ({ language, mode, cellular, configurator }) => {
        const { usePhoneStore } = await import('/src/stores/phone.ts')
        const phone = usePhoneStore()
        phone.preferences.settings.appearanceMode = mode
        phone.setLocale(
          language,
          { Cellular: cellular, AdminPanel: { configurator } },
          phone.fallbackLocales,
        )
        window.postMessage({ type: 'admin:open' }, '*')
      },
      { language, mode, cellular, configurator },
    )
    await page.locator('.admin-panel-rail__configurator').click()
    const sections = page.locator('.admin-panel-config-sections button')
    await sections
      .filter({ has: page.locator('strong', { hasText: cellular.group }) })
      .click()
    const panel = page.locator('.admin-panel-window')
    await page
      .getByRole('tab', { name: new RegExp(cellular.labels.Props) })
      .click()
    await expect(panel).toContainText(cellular.labels.PropsEnabled)
    await expect(panel).toContainText(cellular.help.RepairJobs)
    const destructible = panel.getByRole('checkbox', {
      name: new RegExp(cellular.labels.Destructible),
    })
    await expect(destructible).toBeChecked()
    await destructible.uncheck()
    await expect(destructible).not.toBeChecked()
    await expect(panel).toContainText(cellular.help.Destructible)
    const repairItem = panel.getByRole('textbox', {
      name: new RegExp(cellular.labels.RepairItem),
    })
    await expect(repairItem).toHaveValue('radiotowerparts')
    await repairItem.fill('custom_radio_parts')
    await expect(repairItem).toHaveValue('custom_radio_parts')
    await expect(panel).toContainText(cellular.help.RepairItem)
    await panel
      .locator('.config-structured-editor__section-toggle')
      .filter({
        has: page.locator('strong', {
          hasText: new RegExp(`^${cellular.labels.Models}$`),
        }),
      })
      .click()
    await expect(panel).toContainText(cellular.labels.TowerModel)
    const mastModel = panel.getByRole('textbox', {
      name: new RegExp(cellular.labels.TowerModel),
    })
    await mastModel.fill('customer_cell_tower')
    await expect(mastModel).toHaveValue('customer_cell_tower')
    await expect(panel).not.toContainText('Cellular.')
    await page
      .getByRole('tab', { name: new RegExp(`^${cellular.labels.Towers}`) })
      .click()
    await panel
      .locator('.config-structured-editor__section-toggle')
      .first()
      .click()
    await panel
      .locator('.config-structured-editor__section-toggle')
      .filter({
        has: page.locator('strong', {
          hasText: new RegExp(`^${cellular.labels.Coords}$`),
        }),
      })
      .click()
    const locationButton = panel.getByRole('button', {
      name: cellular.useCurrentLocation,
    })
    await expect(locationButton).toBeVisible()
    let release
    const pending = new Promise((resolve) => {
      release = resolve
    })
    await page.route('**/configurator:get-player-coords', async (route) => {
      expect(route.request().postDataJSON().grounded).toBe(true)
      await pending
      await route.fulfill({
        json: {
          success: true,
          data: { coords: { x: 123, y: 456, z: 78 }, heading: 90 },
        },
      })
    })
    await locationButton.click()
    await expect(
      panel.getByRole('button', { name: cellular.locationLoading }),
    ).toBeDisabled()
    release()
    const coordinateEditor = panel
      .locator('.config-structured-editor')
      .filter({
        has: page.getByRole('button', { name: cellular.useCurrentLocation }),
      })
      .last()
    await expect(coordinateEditor.getByRole('spinbutton').nth(0)).toHaveValue(
      '123',
    )
    await expect(coordinateEditor.getByRole('spinbutton').nth(1)).toHaveValue(
      '456',
    )
    await expect(coordinateEditor.getByRole('spinbutton').nth(2)).toHaveValue(
      '78',
    )
    await page.unroute('**/configurator:get-player-coords')
    await page.route('**/configurator:get-player-coords', (route) =>
      route.fulfill({ json: { success: false, error: 'ground_unavailable' } }),
    )
    await locationButton.click()
    await expect(panel.getByRole('alert')).toContainText(
      cellular.locationFailed,
    )
    await expect(coordinateEditor.getByRole('spinbutton').nth(0)).toHaveValue(
      '123',
    )
    await expect(panel).not.toContainText('Cellular.help.')
    await panel.screenshot({
      path: testInfo.outputPath('cell-towers-location.png'),
    })
    expect(
      await panel.evaluate(
        (element) => element.scrollWidth <= element.clientWidth,
      ),
    ).toBe(true)
    expect(errors).toEqual([])
    await sections
      .filter({ has: page.locator('strong', { hasText: /^Companies$/ }) })
      .click()
    const companies = panel.locator('.admin-panel-config-field').filter({
      has: page.locator('code', { hasText: /^Companies\.Definitions$/ }),
    })
    await companies
      .locator('.config-structured-editor__section-toggle')
      .filter({ has: page.locator('strong', { hasText: /^Location$/ }) })
      .click()
    await page.unroute('**/configurator:get-player-coords')
    await page.route('**/configurator:get-player-coords', (route) => {
      expect(route.request().postDataJSON().grounded).toBe(false)
      return route.fulfill({
        json: {
          success: true,
          data: { coords: { x: 321, y: 654, z: 87 }, heading: 90 },
        },
      })
    })
    await companies
      .getByRole('button', { name: cellular.useCurrentLocation })
      .click()
    const companyCoordinates = companies
      .locator('.config-structured-editor')
      .filter({
        has: page.getByRole('button', { name: cellular.useCurrentLocation }),
      })
      .last()
    await expect(companyCoordinates.getByRole('spinbutton').nth(0)).toHaveValue(
      '321',
    )
    await expect(companyCoordinates.getByRole('spinbutton').nth(1)).toHaveValue(
      '654',
    )
    await expect(companyCoordinates.getByRole('spinbutton').nth(2)).toHaveValue(
      '87',
    )
    expect(errors).toEqual([])
  })
}
