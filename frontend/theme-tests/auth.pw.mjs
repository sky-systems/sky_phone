import { readFileSync, readdirSync, writeFileSync } from 'node:fs'
import { test, expect } from '@playwright/test'
import { auditTheme } from './audit.mjs'

const authApps = [
  'feather',
  'crewlink',
  'citymarkt',
  'local-pages',
  'picstagram',
  'skypic',
  'fliptok',
  'crypto',
  'mail',
  'settings',
  'flare',
  'calendar',
]

async function setMode(page, mode) {
  await page.evaluate(async (mode) => {
    const { usePhoneStore } = await import('/src/stores/phone.ts')
    usePhoneStore().preferences.settings.appearanceMode = mode
  }, mode)
  await page.waitForTimeout(300)
}

async function check(page, app, state, info) {
  for (const mode of ['light', 'dark']) {
    await setMode(page, mode)
    const report = await page.evaluate(auditTheme, {
      selector: '.app-window',
      mode,
    })
    writeFileSync(
      info.outputPath(`${app}-${state}-${mode}.json`),
      JSON.stringify(report, null, 2),
    )
    await info.attach(`${app}-${state}-${mode}`, {
      body: JSON.stringify(report, null, 2),
      contentType: 'application/json',
    })
    await page
      .locator('.phone-device')
      .screenshot({ path: info.outputPath(`${app}-${state}-${mode}.png`) })
    expect
      .soft(report.checked.length, `${app}: no measured auth text`)
      .toBeGreaterThan(3)
    expect.soft(report.issues, `${app} ${state} ${mode}`).toEqual([])
  }
}

for (const app of authApps) {
  test(`${app} account entry, registration and theme switch`, async ({
    page,
  }, info) => {
    // Authentication requests cannot create or modify even a fixture account.
    await page.route(
      /\/api\/[^/]+:(login|register|create-profile|auth)$/,
      (route) =>
        route.fulfill({
          json: { success: false, error: 'invalid_credentials' },
        }),
    )
    await page.goto(`/?apiPort=3098#/apps/${app}`)
    await expect(
      page.locator(`.app-window[data-app-id="${app}"]`),
    ).toBeVisible()
    await expect(page.locator('.app-loading')).toHaveCount(0)
    await page.waitForTimeout(900)
    const targetApp = page.locator('.app-window')
    if (app === 'citymarkt')
      await targetApp.getByText('Me', { exact: true }).click()
    if (app === 'local-pages')
      await targetApp.getByText('Profile', { exact: true }).click()
    await page.evaluate(async (app) => {
      if (
        ['feather', 'crewlink', 'citymarkt', 'local-pages', 'skypic'].includes(
          app,
        )
      ) {
        const { useAppAuthStore } = await import('/src/stores/app-auth.ts')
        useAppAuthStore().sessions[app] = false
      } else if (app === 'picstagram') {
        const { usePicstagramStore } = await import('/src/stores/picstagram.ts')
        usePicstagramStore().authenticated = false
      } else if (app === 'fliptok') {
        const { useFlipTokStore } = await import('/src/stores/fliptok.ts')
        useFlipTokStore().authenticated = false
      } else if (app === 'crypto') {
        const { useCryptoStore } = await import('/src/stores/crypto.ts')
        useCryptoStore().data.authenticated = false
      } else if (app === 'flare') {
        const { useFlareStore } = await import('/src/stores/flare.ts')
        useFlareStore().profile = null
      } else {
        const { useAccountStore } = await import('/src/stores/account.ts')
        useAccountStore().hydrate(null)
        if (app === 'mail') {
          const { useMailStore } = await import('/src/stores/mail.ts')
          await useMailStore().bootstrap('')
        }
      }
    }, app)
    const window = page.locator('.app-window')
    if (app === 'settings')
      await window.getByText('Sky Cloud', { exact: true }).first().click()
    if (app === 'calendar') {
      await expect(window.locator('.calendar__auth')).toBeVisible()
      await check(page, app, 'account-required', info)
      return
    }
    const authRoot = window.locator(
      {
        feather: '.feather-auth',
        crewlink: '.crewlink-auth',
        citymarkt: '.citymarkt-auth',
        'local-pages': '.pages__auth',
        picstagram: '.ps-auth',
        skypic: '.sp-auth',
        fliptok: '.fliptok-auth',
        crypto: '.auth-panel',
        mail: '.mail-auth',
        settings: '.settings-content--subpage',
        flare: '.flare-profile-form--onboarding',
      }[app],
    )
    await expect(authRoot).toBeVisible()
    await expect(authRoot.locator('input').first()).toBeVisible()
    await check(page, app, 'login-empty', info)
    const fields = window.locator(
      'input:not([readonly]):not([type="checkbox"]):not([type="radio"]),textarea',
    )
    for (const field of await fields.all())
      if (await field.isVisible())
        await field.fill(
          (await field.getAttribute('type')) === 'password'
            ? 'ThemeTest42!'
            : (await field.getAttribute('type')) === 'number'
              ? '27'
              : 'theme_test',
        )
    await check(page, app, 'login-filled', info)
    if (['flare', 'calendar'].includes(app)) return
    if (app === 'settings')
      await window.getByText('Register', { exact: true }).click()
    else if (app === 'mail')
      await window.getByRole('tab', { name: 'Register', exact: true }).click()
    else
      await window
        .locator('.sky-segmented')
        .getByRole('button', {
          name: /^(Register|Sign up|Create account|Create profile)$/i,
        })
        .click()
    await check(page, app, 'register-empty', info)
    for (const field of await fields.all())
      if (await field.isVisible())
        await field.fill(
          (await field.getAttribute('type')) === 'password'
            ? 'ThemeTest42!'
            : (await field.getAttribute('type')) === 'number'
              ? '27'
              : 'theme_test',
        )
    await check(page, app, 'register-filled', info)
    const submit = authRoot
      .locator(
        '.app-profile-auth__submit, .auth-submit, .mail-auth__submit, .settings-primary-action .sky-button, .fliptok-auth__form button[type=submit], .ps-auth-card > .sky-button',
      )
      .last()
    await expect(submit).toBeEnabled()
    await submit.click()
    await expect(
      page
        .locator(
          '.app-profile-auth__error, .auth-form .error, .sky-notification',
        )
        .first(),
    ).toBeVisible()
    await check(page, app, 'register-error', info)
  })
}

// A new standard auth form must receive an explicit entry-state fixture too.
test('all account-entry views have theme scenarios', () => {
  const directory = new URL('../src/views/apps/', import.meta.url)
  const discovered = readdirSync(directory).filter(
    (name) =>
      name.endsWith('App.vue') &&
      /const (?:authMode|accountMode) = ref|<AppProfileAuth|<CityMarktAuth|class="calendar__auth"|class="flare-profile-form--onboarding"/.test(
        readFileSync(new URL(name, directory), 'utf8'),
      ),
  )
  const covered = authApps.map((app) => app.replaceAll('-', ''))
  expect(
    discovered.filter(
      (name) => !covered.includes(name.replace('App.vue', '').toLowerCase()),
    ),
    'Add an auth entry fixture for each new account form',
  ).toEqual([])
})

test('Feather first profile setup follows both color modes', async ({
  page,
}, info) => {
  await page.goto('/?apiPort=3098#/apps/feather')
  await expect(page.locator('.feather-post').first()).toBeVisible()
  await page.evaluate(async () => {
    const { useFeatherStore } = await import('/src/stores/feather.ts')
    useFeatherStore().onboarded = false
    useFeatherStore().profile = null
  })
  await expect(page.locator('.feather-onboarding')).toBeVisible()
  await check(page, 'feather', 'profile-setup', info)
})
