import { expect, test } from '@playwright/test'

for (const dark of [false, true]) {
  test(
    'refracts rendered backdrop pixels with sharp foreground, resize and Performance cleanup: ' +
      (dark ? 'dark' : 'light'),
    async ({ page }, testInfo) => {
      await page.goto('/?apiPort=3098#/')
      await page.locator('.phone-status-bar__time-button').waitFor()
      await page.evaluate(async (dark) => {
        const { createApp, h, ref } = await import(
          '/node_modules/.vite/deps/vue.js'
        )
        const { SkyApp, SkyButton } = await import('/src/ui/index.ts')
        const effects = ref(true)
        const width = ref(280)
        window.glassOpticsWidth = width
        window.glassOpticsEffects = effects
        const host = document.createElement('div')
        host.id = 'glass-optics-fixture'
        document.body.append(host)
        const app = createApp({
          render: () =>
            h(
              SkyApp,
              {
                dark,
                glassEffects: effects.value,
                class: effects.value ? '' : 'phone-app--performance',
                style: {
                  position: 'fixed',
                  top: '80px',
                  left: '80px',
                  width: '600px',
                  height: '280px',
                  zIndex: 99999,
                  '--sky-user-glass-blur': '0px',
                  background:
                    'repeating-linear-gradient(90deg,#062c18 0px,#062c18 12px,#90efb0 12px,#90efb0 17px,#1c7944 17px,#1c7944 31px)',
                },
              },
              () =>
                h(
                  SkyButton,
                  {
                    id: 'optical-control',
                    glass: true,
                    highlight: false,
                    inline: true,
                    style: {
                      position: 'absolute',
                      left: '100px',
                      top: '100px',
                      width: width.value + 'px',
                      height: '72px',
                      borderRadius: '36px',
                    },
                  },
                  () =>
                    h('span', { id: 'optical-content' }, 'Sharp glass label'),
                ),
            ),
        })
        app.config.idPrefix = 'optics-'
        app.mount(host)
        await document.fonts.ready
      }, dark)
      const control = page.locator('#optical-control')
      await expect(control).toHaveClass(/sky-glass--refractive/)
      const optics = control.locator('feDisplacementMap')
      const scale = await optics.getAttribute('scale')
      expect(Number(scale)).toBeGreaterThan(0)
      const active = await control.screenshot()
      await optics.evaluate((element) => element.setAttribute('scale', '0'))
      const flat = await control.screenshot()
      expect(
        active.equals(flat),
        'The compositor must actually change backdrop pixels when displacement is enabled',
      ).toBe(false)
      await optics.evaluate(
        (element, scale) => element.setAttribute('scale', scale),
        scale,
      )
      await control.screenshot({
        path: testInfo.outputPath('glass-clear-0px.png'),
      })
      await control.evaluate((element) =>
        element.style.setProperty('--sky-user-glass-blur', '6px'),
      )
      await expect
        .poll(() =>
          control.evaluate(
            (element) => getComputedStyle(element).backdropFilter,
          ),
        )
        .toMatch(/^blur\(6px\) url\(/)
      const frosted = await control.screenshot({
        path: testInfo.outputPath('glass-frosted-6px.png'),
      })
      expect(
        active.equals(frosted),
        'The blur setting must change rendered backdrop pixels',
      ).toBe(false)
      await page.screenshot({
        path: testInfo.outputPath(
          'optics-' + (dark ? 'dark' : 'light') + '.png',
        ),
      })
      const content = await page
        .locator('#optical-content')
        .evaluate((element) => ({
          opacity: getComputedStyle(element).opacity,
          filter: getComputedStyle(element).filter,
          rootFilter: getComputedStyle(element.parentElement).filter,
        }))
      expect(content).toEqual({
        opacity: '1',
        filter: 'none',
        rootFilter: 'none',
      })
      await page.evaluate(() => {
        window.glassOpticsWidth.value = 420
      })
      await expect(control.locator('feImage')).toHaveAttribute('width', '420')
      await page.evaluate(() => {
        window.glassOpticsEffects.value = false
      })
      await expect(control.locator('feDisplacementMap')).toHaveCount(0)
      await expect
        .poll(() =>
          control.evaluate(
            (element) => getComputedStyle(element).backdropFilter,
          ),
        )
        .toBe('none')
      await expect(page.locator('#optical-content')).toHaveCSS('opacity', '1')
    },
  )
}

test('saves Glass Blur from Display settings, restores the value and disables the control in Performance mode', async ({
  page,
}, testInfo) => {
  // Each browser shares the mock server; keep preference mutations local to this test.
  let persistedSettings
  let settingsRevision = 1
  await page.route('**/api/development:bootstrap', async (route) => {
    const response = await route.fetch()
    const body = await response.json()
    const settings = body.data.device.data.settings
    if (persistedSettings) {
      settings.payload = persistedSettings
      settings.revision = settingsRevision
    } else {
      delete settings.payload.settings.glassBlur
      settings.payload.settings.graphicsMode = 'ultimate'
    }
    await route.fulfill({ json: body })
  })
  await page.route('**/api/device:save', async (route) => {
    const body = route.request().postDataJSON()
    if (body.namespace !== 'settings') return route.continue()
    persistedSettings = body.payload
    settingsRevision += 1
    await route.fulfill({
      json: { success: true, data: { revision: settingsRevision } },
    })
  })
  const saved = []
  page.on('request', (request) => {
    if (request.url().endsWith('/api/device:save')) {
      const body = request.postDataJSON()
      if (body.namespace === 'settings')
        saved.push(body.payload.settings.glassBlur)
    }
  })
  await page.goto('/?apiPort=3098#/apps/settings')
  await page.getByRole('button', { name: 'Appearance', exact: true }).click()
  const slider = page.getByRole('slider', { name: 'Glass Blur', exact: true })
  await expect(slider).toHaveValue('6')
  await slider.press('End')
  await slider.press('ArrowLeft')
  await expect(slider).toHaveValue('19.5')
  await expect.poll(() => saved.at(-1)).toBe(19.5)
  await expect(page.locator('.phone-app')).toHaveCSS(
    '--sky-user-glass-blur',
    '19.5px',
  )
  await page.reload()
  await page.getByRole('button', { name: 'Appearance', exact: true }).click()
  await expect(slider).toHaveValue('19.5')
  await page
    .getByRole('button', { name: 'Performance Mode', exact: true })
    .click()
  await expect(slider).toBeDisabled()
  await page.getByRole('button', { name: 'Ultimate Mode', exact: true }).click()
  await expect(slider).toBeEnabled()
  await slider.press('Home')
  await expect(slider).toHaveValue('0')
  await expect.poll(() => saved.at(-1)).toBe(0)
  await page.screenshot({
    path: testInfo.outputPath('glass-blur-settings.png'),
  })
})

for (const appearance of ['light', 'dark']) {
  test(
    'Crypto toolbar uses the shared refractive material and keeps navigation working: ' +
      appearance,
    async ({ page }, testInfo) => {
      await page.goto('/?apiPort=3098#/apps/crypto')
      await expect(page.locator('.phone-status-bar__time-button')).toBeVisible()
      await page.evaluate(async (appearance) => {
        const { usePhoneStore } = await import('/src/stores/phone.ts')
        usePhoneStore().preferences.settings.appearanceMode = appearance
        usePhoneStore().preferences.settings.graphicsMode = 'ultimate'
        usePhoneStore().preferences.settings.glassBlur = 6
      }, appearance)
      const toolbar = page.locator('.crypto-app .sky-segmented--navigation')
      await expect(toolbar).toHaveClass(
        /sky-glass--clear.*sky-glass--refractive/,
      )
      await expect
        .poll(() =>
          toolbar.evaluate(
            (element) => getComputedStyle(element).backdropFilter,
          ),
        )
        .toMatch(/^blur\(6px\) url\(/)
      await expect(toolbar.locator('feDisplacementMap')).toHaveCount(1)
      await expect(
        toolbar.getByRole('button', { name: 'Markets', exact: true }),
      ).toHaveCount(1)
      await toolbar
        .getByRole('button', { name: 'Markets', exact: true })
        .click()
      await expect(
        toolbar.getByRole('button', { name: 'Markets', exact: true }),
      ).toHaveAttribute('aria-pressed', 'true')
      await expect(toolbar.locator('.sky-segmented-button').first()).toHaveCSS(
        'opacity',
        '1',
      )
      await page.locator('.phone-device').screenshot({
        path: testInfo.outputPath('crypto-glass-' + appearance + '.png'),
      })
      await toolbar
        .getByRole('button', { name: 'Portfolio', exact: true })
        .click()
      await expect(
        toolbar.getByRole('button', { name: 'Portfolio', exact: true }),
      ).toHaveAttribute('aria-pressed', 'true')
    },
  )
}
