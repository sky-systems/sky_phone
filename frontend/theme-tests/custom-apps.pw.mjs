import { test, expect } from '@playwright/test'
import { auditTheme } from './audit.mjs'

async function register(page, mode, options = {}) {
  await page.goto('/?apiPort=3098#/apps/phone')
  await expect(page.locator('.app-window .sky-app-page')).toBeVisible()
  await page.waitForTimeout(800)
  await page.evaluate(
    async ({ mode, options }) => {
      const { usePhoneStore } = await import('/src/stores/phone.ts')
      const { useAppCatalogStore } = await import('/src/stores/app-catalog.ts')
      const phone = usePhoneStore()
      phone.setLocale('en', {}, {})
      phone.preferences.settings.appearanceMode = mode
      useAppCatalogStore().replaceCatalog({
        apps: [
          {
            id: 'test-external',
            name: 'External test',
            developer: 'Example studio',
            description: 'A real external app description.',
            ownerResource: 'example',
            icon: 'https://apps.example.test/icon.png',
            ui: 'https://apps.example.test/index.html',
            ...options,
          },
        ],
      })
    },
    { mode, options },
  )
}

for (const mode of ['light', 'dark']) {
  test(`external metadata and installation errors: ${mode}`, async ({
    page,
  }, testInfo) => {
    await page.route('https://apps.example.test/**', (route) =>
      route.fulfill({
        contentType: 'image/svg+xml',
        body: '<svg xmlns="http://www.w3.org/2000/svg" width="200" height="400"><rect width="200" height="400" fill="#555"/></svg>',
      }),
    )
    await page.route('**/api/custom-app:install', (route) =>
      route.fulfill({ json: { success: false, error: 'insufficient_funds' } }),
    )
    await register(page, mode, {
      store: {
        price: 500,
        rating: 4.5,
        size: 2560,
        screenshots: [
          'https://apps.example.test/one.png',
          'https://apps.example.test/two.png',
        ],
        banner: {
          imageUrl: 'https://apps.example.test/banner.png',
          background: '#555',
        },
      },
    })
    await page.evaluate(async () => {
      const { default: router } = await import('/src/router/index.ts')
      await router.push(
        '/apps/app-store?easyShareKind=link&easyShareId=test-external',
      )
    })
    const detail = page.locator('.store-detail')
    await expect(detail).toContainText('A real external app description.')
    await expect(detail).toContainText('2.5 MB')
    await expect(detail).toContainText('4.5')
    await expect(detail.locator('.store-detail__external-preview')).toHaveCount(
      2,
    )
    await expect(detail.locator('.store-detail__whats-new')).toHaveCount(0)
    await expect(detail.locator('.store-detail__action')).toHaveText('$ 500')
    const report = await page.evaluate(auditTheme, {
      selector: '.store-detail',
      mode,
    })
    expect(report.issues).toEqual([])
    await testInfo.attach(`external-store-${mode}`, {
      body: await page
        .locator('.phone-device')
        .screenshot({
          path: testInfo.outputPath(`external-store-${mode}.png`),
        }),
      contentType: 'image/png',
    })
    await detail.locator('.store-detail__action').click()
    await expect(
      page.getByText('App could not be installed', { exact: true }),
    ).toBeVisible({ timeout: 10000 })
    const installed = await page.evaluate(async () => {
      const { useAppStoreStore } = await import('/src/stores/app-store.ts')
      return useAppStoreStore().claimedApps.includes('test-external')
    })
    expect(installed).toBe(false)
  })
}

test('authorization blocks frame execution and function-only apps execute without an iframe', async ({
  page,
}) => {
  let denied = true
  const lifecycle = []
  await page.route('**/api/custom-app:authorize', (route) =>
    route.fulfill({
      json: denied
        ? { success: false, error: 'app_job_denied' }
        : { success: true },
    }),
  )
  await page.route('**/api/custom-app:lifecycle', (route) => {
    lifecycle.push(route.request().postDataJSON())
    return route.fulfill({ json: { success: true } })
  })
  await register(page, 'light', { defaultInstalled: true })
  await page.evaluate(async () => {
    const { default: router } = await import('/src/router/index.ts')
    await router.push('/apps/test-external')
  })
  await expect(page.getByText('App unavailable', { exact: true })).toBeVisible()
  await expect(page.locator('.custom-app-frame')).toHaveCount(0)
  expect(lifecycle).toEqual([])
  denied = false
  await page.evaluate(async () => {
    const { default: router } = await import('/src/router/index.ts')
    await router.push('/')
    const { useAppCatalogStore } = await import('/src/stores/app-catalog.ts')
    useAppCatalogStore().replaceCatalog({
      apps: [
        {
          id: 'action-app',
          name: 'Action app',
          ownerResource: 'example',
          icon: 'https://apps.example.test/icon.png',
          ui: '',
          launchMode: 'action',
          defaultInstalled: true,
        },
      ],
    })
    await router.push('/apps/action-app')
  })
  await expect
    .poll(() => lifecycle.map((event) => event.event))
    .toEqual(['open', 'close'])
  await expect(page.locator('.custom-app-frame')).toHaveCount(0)
})
