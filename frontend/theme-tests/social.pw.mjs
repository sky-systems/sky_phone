import { test, expect } from '@playwright/test'
import { auditTheme } from './audit.mjs'

async function theme(page, mode) {
  await page.evaluate(async (mode) => {
    const { usePhoneStore } = await import('/src/stores/phone.ts')
    usePhoneStore().preferences.settings.appearanceMode = mode
  }, mode)
  await page.waitForTimeout(300)
}
async function colors(page, selector, mode, name, info) {
  await page.waitForTimeout(300)
  const result = await page.evaluate(auditTheme, { selector, mode })
  await info.attach(name, {
    body: JSON.stringify(result, null, 2),
    contentType: 'application/json',
  })
  await page
    .locator('.phone-device')
    .screenshot({ path: info.outputPath(`${name}.png`) })
  expect.soft(result.issues, `${name}: unreadable colors`).toEqual([])
}

for (const mode of ['light', 'dark']) {
  test(`Feather profile and editor in ${mode}`, async ({ page }, info) => {
    await page.goto('/?apiPort=3098#/apps/feather')
    await expect(page.locator('.feather-post').first()).toBeVisible()
    await theme(page, mode)
    const app = page.locator('.feather-app')
    await app.getByText('Profile', { exact: true }).click()
    await expect(app.locator('.feather-profile__identity')).toBeVisible()
    await colors(page, '.app-window', mode, 'feather-profile', info)
    await app.getByRole('button', { name: 'Edit profile', exact: true }).click()
    await expect(app.locator('.feather-edit')).toBeVisible()
    await colors(page, '.app-window', mode, 'feather-editor-empty', info)
    await app.locator('.feather-edit input').first().fill('Sky Theme Test')
    await colors(page, '.app-window', mode, 'feather-editor-filled', info)
  })

  for (const app of ['picstagram', 'fliptok']) {
    test(`${app} discovery, live avatars and composer in ${mode}`, async ({
      page,
    }, info) => {
      await page.goto(`/?apiPort=3098&realtimePreview=${app}&liveView=entry`)
      const root = page.locator(
        app === 'picstagram' ? '.picstagram-page' : '.fliptok-page',
      )
      await expect(page.locator('.profile-suggestions')).toHaveCount(0)
      await expect(root).toBeVisible()
      await page.waitForTimeout(1000)
      await theme(page, mode)
      await root
        .getByText(app === 'picstagram' ? 'Explore' : 'Discover', {
          exact: true,
        })
        .click()
      await expect(
        page.locator('.profile-suggestions button').first(),
      ).toBeVisible()
      await expect(
        page.locator('.profile-suggestions').getByText('Nova', { exact: true }),
      ).toBeVisible()
      await expect(page.locator('.realtime-live-avatar').first()).toBeVisible()
      await colors(page, '.realtime-preview', mode, `${app}-suggestions`, info)
      await page
        .locator('.profile-suggestions .realtime-live-avatar')
        .first()
        .click()
      await expect(page.locator('.live-broadcast--active')).toBeVisible()
      await expect(page.locator('.live-broadcast__chat')).toBeVisible()
      await page.locator('.live-broadcast__top > button').click()
      await page.getByRole('button', { name: 'Einstieg', exact: true }).click()
      await expect(root).toBeVisible()
      // The Plus entry is the only broadcast creation entry in either app.
      await expect(root.locator('header .live-entry')).toHaveCount(0)
      if (app === 'picstagram') {
        await root.getByText('Home', { exact: true }).click()
        await root.getByRole('link', { name: 'New Post', exact: true }).click()
      } else
        await root.getByRole('button', { name: 'Create', exact: true }).click()
      await root.getByRole('button', { name: 'Go live', exact: true }).click()
      const setup = root.locator('.live-setup')
      await expect(setup).toBeVisible()
      await colors(
        page,
        '.realtime-preview',
        mode,
        `${app}-live-setup-empty`,
        info,
      )
      await expect(
        setup.getByRole('button', { name: 'Go live', exact: true }),
      ).toBeDisabled()
      await setup.locator('input,textarea').first().fill('Abend in Los Santos')
      if (app === 'picstagram')
        await setup.locator('textarea').fill('Fragen und Eindrücke vom Strand')
      await colors(
        page,
        '.realtime-preview',
        mode,
        `${app}-live-setup-filled`,
        info,
      )
      await setup.getByRole('button', { name: 'Go live', exact: true }).click()
      await expect(page.locator('.live-broadcast--active')).toBeVisible()
      // Exercise the REAL app composer before switching to isolated preview roles.
      // Presence alone cannot detect a textbox hidden below an app tab bar.
      await page.waitForTimeout(500)
      const hosted = page.locator('.live-broadcast--active')
      const composer = hosted.locator('.live-broadcast__composer')
      const box = await composer.boundingBox()
      const appBox = await root.boundingBox()
      expect(box.y + box.height).toBeLessThan(appBox.y + appBox.height - 12)
      if (app === 'picstagram') {
        const navigation = await root.locator('.ps-navigation').boundingBox()
        expect(box.y + box.height).toBeLessThan(navigation.y)
      }
      await composer.locator('textarea').fill('Host in der echten App')
      await composer.getByRole('button', { name: 'Send', exact: true }).click()
      await expect(
        hosted.getByText('Host in der echten App', { exact: true }),
      ).toBeVisible()
      await page
        .locator('.phone-device')
        .screenshot({ path: info.outputPath(`${app}-host-in-app.png`) })
      for (const role of ['Sender', 'Zuschauer']) {
        await page.getByRole('button', { name: role, exact: true }).click()
        const live = page.locator('.live-broadcast--active')
        await expect(live).toBeVisible()
        await expect(live.locator('.live-broadcast__viewers')).toBeVisible()
        await live.locator('textarea').fill(`Hallo von ${role}`)
        await live.getByRole('button', { name: 'Send', exact: true }).click()
        await expect(
          live.getByText(`Hallo von ${role}`, { exact: true }),
        ).toBeVisible()
        await page
          .locator('.phone-device')
          .screenshot({ path: info.outputPath(`${app}-${role}.png`) })
      }
    })
  }
}

test('incoming FaceTime offers video and audio answers; PMA capabilities stay honest', async ({
  page,
}, info) => {
  await page.goto('/?apiPort=3098&realtimePreview=call&liveView=incoming')
  const faceTime = page.getByRole('button', { name: 'FaceTime', exact: true })
  await expect(faceTime).toBeEnabled()
  await expect(faceTime).toHaveClass(/phone-call-action--answer/)
  await faceTime.click()
  await expect(page.locator('.facetime-call')).toBeVisible()
  await page
    .locator('.phone-device')
    .screenshot({ path: info.outputPath('facetime-connected.png') })
  await page.getByRole('button', { name: 'Eingehend', exact: true }).click()
  await page
    .getByRole('button', { name: 'Answer with audio', exact: true })
    .click()
  await expect(page.locator('.facetime-call')).toHaveCount(0)
  expect(
    await page.evaluate(async () => {
      const { useCallsStore } = await import('/src/stores/calls.ts')
      return useCallsStore().activeCall.video
    }),
  ).toBe(false)
  await page.getByRole('button', { name: 'PMA', exact: true }).click()
  await expect(
    page.getByRole('button', { name: 'Speaker', exact: true }),
  ).toBeEnabled()
  await expect(
    page.getByRole('button', { name: 'Mute', exact: true }),
  ).toBeEnabled()
})

for (const provider of ['pma', 'salty']) {
  for (const mode of ['light', 'dark']) {
    test(`${provider} audio buttons change state and color in ${mode}`, async ({
      page,
    }) => {
      await page.goto(
        `/?apiPort=3098&realtimePreview=call&liveView=${provider}`,
      )
      await expect(
        page.getByRole('button', { name: 'Mute', exact: true }),
      ).toBeVisible()
      await theme(page, mode)
      for (const name of ['Speaker', 'Mute']) {
        const button = page.getByRole('button', { name, exact: true })
        await expect(button).toBeEnabled()
        const before = await button.evaluate(
          (el) => getComputedStyle(el, '::before').backgroundColor,
        )
        await button.click()
        await expect(button).toHaveAttribute('aria-pressed', 'true')
        await expect
          .poll(() =>
            button.evaluate(
              (el) => getComputedStyle(el, '::before').backgroundColor,
            ),
          )
          .not.toBe(before)
        await button.click()
        await expect(button).toHaveAttribute('aria-pressed', 'false')
      }
      expect(
        await page.evaluate(async () => {
          const { useCallsStore } = await import('/src/stores/calls.ts')
          return useCallsStore().activeCall.state
        }),
      ).toBe('connected')
    })
  }
}
