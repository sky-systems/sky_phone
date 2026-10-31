import { readFileSync } from 'node:fs'
import { test, expect } from '@playwright/test'
import { auditTheme } from './audit.mjs'

test('Flare creates a profile with six selected gallery photos', async ({
  page,
}) => {
  let profile = null
  let submitted
  await page.route('**/api/flare:bootstrap', (route) =>
    route.fulfill({
      json: {
        success: true,
        data: { profile, suggestions: [], likes: [], matches: [] },
      },
    }),
  )
  await page.route('**/api/flare:save-profile', async (route) => {
    submitted = route.request().postDataJSON()
    profile = {
      ...submitted,
      id: 77,
      discoverable: true,
      photoUrls: submitted.photoMediaIds.map(
        (id) => `https://cdn.example.test/${id}.jpg`,
      ),
    }
    await route.fulfill({
      json: {
        success: true,
        data: { profile, suggestions: [], likes: [], matches: [] },
      },
    })
  })
  await page.goto('/?apiPort=3098#/apps/flare', {
    waitUntil: 'domcontentloaded',
  })
  await page.getByLabel('Your name', { exact: true }).fill('Alex')
  await page.getByLabel('Age', { exact: true }).fill('27')
  await page
    .locator('.flare-onboarding-photo-actions')
    .getByRole('button', { name: /Choose.*Photos/i })
    .click()
  const tiles = page.locator('.gallery-tile')
  await expect(tiles.nth(5)).toBeVisible()
  for (let index = 0; index < 6; index++) await tiles.nth(index).click()
  await page.getByRole('link', { name: /^Done$/i }).click()
  await expect(page.locator('.flare-photo-slot')).toHaveCount(6)
  await expect(page.getByLabel('Your name', { exact: true })).toHaveValue(
    'Alex',
  )
  await expect(page.getByLabel('Age', { exact: true })).toHaveValue('27')
  await page.locator('.flare-profile-form__actions button').click()
  await expect(page.locator('.flare-tabbar')).toBeVisible()
  expect(submitted.name).toBe('Alex')
  expect(submitted.age).toBe(27)
  expect(submitted.photoMediaIds).toHaveLength(6)
  expect(new Set(submitted.photoMediaIds).size).toBe(6)
})

test('Flare restores the existing profile after signing out and back in', async ({
  page,
}, info) => {
  let signedIn = true
  let bootstrap
  let account
  const loginAttempts = []
  await page.route('**/api/flare:bootstrap', async (route) => {
    if (!bootstrap) bootstrap = await (await route.fetch()).json()
    await route.fulfill({
      json: signedIn
        ? bootstrap
        : { success: false, error: 'not_authenticated' },
    })
  })
  await page.route('**/api/account:logout', async (route) => {
    signedIn = false
    await route.fulfill({ json: { success: true } })
  })
  await page.route('**/api/account:login', async (route) => {
    const body = route.request().postDataJSON()
    loginAttempts.push(body)
    signedIn = body.email === account.email && body.password === 'FlareTest42!'
    await route.fulfill({
      json: signedIn
        ? { success: true, data: account }
        : { success: false, error: 'invalid_credentials' },
    })
  })
  await page.route('**/api/device:save', (route) =>
    route.fulfill({ json: { success: true, data: { revision: 1 } } }),
  )
  await page.goto('/?apiPort=3098#/apps/flare')
  await expect(page.locator('.flare-tabbar')).toBeVisible()
  account = await page.evaluate(async () => {
    const { useAccountStore } = await import('/src/stores/account.ts')
    const { email, devices } = useAccountStore()
    return { email, devices }
  })
  expect(bootstrap.data.profile).not.toBeNull()
  await page
    .locator('.flare-tabbar')
    .getByRole('button', { name: 'Profile', exact: true })
    .click()
  await page
    .locator('.flare-profile-controls')
    .getByRole('button', { name: 'Settings', exact: true })
    .click()
  await page
    .locator('.flare-settings')
    .getByRole('button', { name: /^Sign out$/i })
    .click()
  await page
    .getByRole('dialog')
    .getByRole('button', { name: /^Sign out$/i })
    .click()
  const form = page.locator('.flare-sign-in-form')
  await expect(form).toBeVisible()
  await expect(form.locator('button[type="submit"]')).toBeDisabled()
  await form.getByLabel('Sky Cloud Email').fill(account.email)
  await form.getByLabel('Password', { exact: true }).fill('WrongPassword!')
  await form.locator('button[type="submit"]').click()
  await expect(form.getByRole('alert')).toHaveText(
    'Email or password is incorrect.',
  )
  await expect(form.getByLabel('Sky Cloud Email')).toHaveValue(account.email)
  for (const mode of ['light', 'dark']) {
    await page.evaluate(async (mode) => {
      const { usePhoneStore } = await import('/src/stores/phone.ts')
      usePhoneStore().preferences.settings.appearanceMode = mode
    }, mode)
    await expect
      .poll(
        async () =>
          (await page.evaluate(auditTheme, { selector: '.app-window', mode }))
            .issues,
      )
      .toEqual([])
  }
  await page
    .locator('.phone-device')
    .screenshot({ path: info.outputPath('flare-sign-in.png') })
  await form.getByLabel('Password', { exact: true }).fill('FlareTest42!')
  await form.getByLabel('Password', { exact: true }).press('Enter')
  await expect(form).toHaveCount(0)
  await expect(page.locator('.flare-tabbar')).toBeVisible()
  expect(loginAttempts).toHaveLength(2)
  expect(
    await page.evaluate(async () => {
      const { useFlareStore } = await import('/src/stores/flare.ts')
      const { profile, matches, likes } = useFlareStore()
      return { profile, matches, likes }
    }),
  ).toEqual({
    profile: bootstrap.data.profile,
    matches: bootstrap.data.matches,
    likes: bootstrap.data.likes,
  })
  await page
    .locator('.flare-tabbar')
    .getByRole('button', { name: 'Profile', exact: true })
    .click()
  await expect(page.locator('.flare-profile-overview')).toContainText(
    bootstrap.data.profile.name,
  )
})

test('Flare onboarding keeps complete photo labels inside both buttons', async ({
  page,
}, info) => {
  await page.route('**/api/flare:bootstrap', (route) =>
    route.fulfill({
      json: {
        success: true,
        data: { profile: null, suggestions: [], likes: [], matches: [] },
      },
    }),
  )
  await page.goto('/?apiPort=3098#/apps/flare')
  const actions = page.locator('.flare-onboarding-photo-actions')
  await expect(actions).toBeVisible()
  for (const language of ['en', 'de']) {
    const source = readFileSync(
      new URL(
        `../../sky_phone/config/locales/${language}.lua`,
        import.meta.url,
      ),
      'utf8',
    ).split('            flare = {')[1]
    const labels = Object.fromEntries(
      ['choosePhotos', 'takePhoto'].map((key) => [
        key,
        source.match(new RegExp(`${key} = "([^"]+)"`))[1],
      ]),
    )
    await page.evaluate(
      async ({ language, labels }) => {
        const { usePhoneStore } = await import('/src/stores/phone.ts')
        const phone = usePhoneStore()
        phone.setLocale(
          language,
          { Apps: { flare: labels } },
          phone.fallbackLocales,
        )
      },
      { language, labels },
    )
    for (const label of Object.values(labels)) {
      const button = actions.getByRole('button', { name: label, exact: true })
      await expect(button).toBeVisible()
      const geometry = await button.evaluate((element) => {
        const button = element.getBoundingClientRect()
        const label = element.querySelector('span')
        const text = document.createRange()
        text.selectNodeContents(label)
        return {
          height: element.clientHeight,
          contained: [
            ...text.getClientRects(),
            element.querySelector('svg').getBoundingClientRect(),
          ].every(
            (rect) =>
              rect.left >= button.left &&
              rect.right <= button.right &&
              rect.top >= button.top &&
              rect.bottom <= button.bottom,
          ),
          unclipped:
            label.scrollHeight <= label.clientHeight &&
            label.scrollWidth <= label.clientWidth,
        }
      })
      expect(geometry.height).toBeGreaterThanOrEqual(40)
      expect(geometry.contained).toBe(true)
      expect(geometry.unclipped).toBe(true)
    }
    await page.locator('.phone-device').screenshot({
      path: info.outputPath(`flare-photo-actions-${language}.png`),
    })
  }
})
