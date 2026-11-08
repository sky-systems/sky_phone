import { test, expect } from '@playwright/test'
import { auditTheme } from './audit.mjs'

for (const mode of ['light', 'dark']) {
  test(`banking provider accounts and committed-transfer warning (${mode})`, async ({
    page,
  }, info) => {
    await page.route('**/api/banking:overview', async (route) => {
      await route.fulfill({
        json: {
          success: true,
          data: {
            bank: 800,
            cash: 50,
            currency: '$',
            playerId: 1,
            playerName: 'Fixture customer',
            transactions: [],
            accounts: [
              {
                id: 'fixture-company',
                label: 'Fixture Ambulance',
                balance: 5000,
              },
            ],
            historyLimited: true,
            historyWarning: true,
          },
        },
      })
    })
    await page.goto('/?apiPort=3098#/apps/phone')
    await expect(page.locator('.app-window .sky-app-page')).toBeVisible()
    await page.waitForTimeout(800)
    await page.evaluate(async (value) => {
      const { usePhoneStore } = await import('/src/stores/phone.ts')
      usePhoneStore().preferences.settings.appearanceMode = value
      window.location.hash = '/apps/banking'
    }, mode)
    const account = page
      .locator('.banking-accounts')
      .getByText('Fixture Ambulance')
    await expect(account).toBeVisible()
    await expect(
      page.getByRole('status').filter({ hasText: 'The transfer completed' }),
    ).toBeInViewport()
    await page
      .locator('.phone-device')
      .screenshot({ path: info.outputPath(`banking-warning-${mode}.png`) })
    await account.scrollIntoViewIfNeeded()
    await expect(
      page.getByText('Company account', { exact: true }),
    ).toBeVisible()
    await expect(
      page.getByRole('status').filter({ hasText: 'The transfer completed' }),
    ).toBeVisible()
    const report = await page.evaluate(auditTheme, {
      selector: '.app-window',
      mode,
    })
    expect(report.issues).toEqual([])
    await page
      .locator('.phone-device')
      .screenshot({ path: info.outputPath(`banking-provider-${mode}.png`) })
  })
}
