import { test, expect } from '@playwright/test'

test('cellular reception blocks online apps and recovers while offline tools remain usable', async ({
  page,
}) => {
  await page.goto('/?apiPort=3098#/apps/phone')
  await expect(page.locator('.app-window .sky-app-page')).toBeVisible()
  await page.evaluate(async () => {
    window.postMessage(
      {
        type: 'cellular:update',
        data: {
          enabled: true,
          hasSignal: false,
          bars: 0,
          offlineApps: { phone: true, notes: true },
          onlineActions: { 'calls:dial': true },
          appNamespaces: { calls: 'phone', contacts: 'phone' },
          systemNamespaces: {
            ui: true,
            device: true,
            close: true,
            navigation: true,
          },
          cleanupActions: { 'calls:hangup': true },
        },
      },
      '*',
    )
    const { default: router } = await import('/src/router/index.ts')
    await router.push('/apps/feather')
  })
  await expect(
    page.locator('.app-window[data-app-id="feather"]'),
  ).toContainText('No signal')
  await expect(page.locator('.phone-no-signal')).toHaveText('No signal')
  await expect(page.locator('.app-window[data-app-id="phone"]')).toHaveCount(0)
  await page.screenshot({
    path: 'theme-test-results/cellular-no-signal.png',
    animations: 'disabled',
  })
  await page.evaluate(async () => {
    const { default: router } = await import('/src/router/index.ts')
    await router.push('/apps/notes')
  })
  await expect(
    page.locator('.app-window[data-app-id="notes"] .sky-app-page'),
  ).toBeVisible()
  await page.evaluate(async () => {
    const { cellular } = await import('/src/utils/cellular.ts')
    cellular.hasSignal = true
    cellular.bars = 4
    const { default: router } = await import('/src/router/index.ts')
    await router.push('/apps/feather')
  })
  await expect(
    page.locator('.app-window[data-app-id="feather"] .sky-app-page'),
  ).toBeVisible()
  await expect(page.locator('.phone-no-signal')).toHaveCount(0)
  await expect(
    page.locator('.app-window[data-app-id="feather"] .cellular-unavailable'),
  ).toHaveCount(0)
})

test('phonepanel searches and removes a post after confirmation', async ({
  page,
}) => {
  await page.goto('/?apiPort=3098#/apps/phone')
  await expect(page.locator('.app-window .sky-app-page')).toBeVisible()
  await page.evaluate(() => window.postMessage({ type: 'admin:open' }, '*'))
  await page.getByRole('button', { name: 'Social media', exact: true }).click()
  await expect(page.locator('.admin-social')).toContainText(
    'Preview moderation post for feather',
  )
  await page
    .locator('.admin-social')
    .getByRole('searchbox')
    .fill('missing post')
  await page
    .locator('.admin-social')
    .getByRole('button', { name: 'Search', exact: true })
    .click()
  await expect(page.locator('.admin-social')).toContainText(
    'No published posts found.',
  )
  await page
    .locator('.admin-social')
    .getByRole('searchbox')
    .fill('preview_author')
  await page
    .locator('.admin-social')
    .getByRole('button', { name: 'Search', exact: true })
    .click()
  await expect(page.locator('.admin-social')).toContainText(
    'Preview moderation post for feather',
  )
  await page.screenshot({
    path: 'theme-test-results/admin-social.png',
    animations: 'disabled',
  })
  await page
    .locator('.admin-social__post')
    .getByRole('button', { name: 'Delete post', exact: true })
    .click()
  await expect(
    page.getByRole('dialog', { name: 'Delete this post?' }),
  ).toBeVisible()
  await page
    .getByRole('dialog', { name: 'Delete this post?' })
    .getByRole('button', { name: 'Cancel', exact: true })
    .click()
  await expect(
    page.getByRole('dialog', { name: 'Delete this post?' }),
  ).toBeHidden()
  await expect(page.locator('.admin-social')).toContainText(
    'Preview moderation post for feather',
  )
  await page
    .locator('.admin-social__post')
    .getByRole('button', { name: 'Delete post', exact: true })
    .click()
  await page
    .getByRole('dialog', { name: 'Delete this post?' })
    .getByRole('button', { name: 'Delete post', exact: true })
    .click()
  await expect(page.locator('.admin-social')).toContainText(
    'No published posts found.',
  )
  for (const platform of ['fliptok', 'picstagram', 'weazel-news']) {
    await expect(
      page.getByRole('dialog', { name: 'Delete this post?' }),
    ).toBeHidden()
    await page
      .locator('.admin-social')
      .getByRole('combobox')
      .selectOption(platform)
    await expect(page.locator('.admin-social')).toContainText(
      'Preview moderation post for ' + platform,
    )
    await page
      .locator('.admin-social__post')
      .getByRole('button', { name: 'Delete post', exact: true })
      .click()
    await page
      .getByRole('dialog', { name: 'Delete this post?' })
      .getByRole('button', { name: 'Delete post', exact: true })
      .click()
    await expect(page.locator('.admin-social')).toContainText(
      'No published posts found.',
    )
  }
})
