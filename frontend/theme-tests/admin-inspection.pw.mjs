import { readFileSync } from 'node:fs'
import { test, expect } from '@playwright/test'

function adminLocale(language) {
  const source = readFileSync(
    new URL(`../../sky_phone/config/locales/${language}.lua`, import.meta.url),
    'utf8',
  ).split('        AdminPanel = {')[1]
  const section = (name) => {
    const body = source
      .split(`            ${name} = {`)[1]
      .split(/\r?\n            },/)[0]
    return JSON.parse(
      `{${body
        .replace(/^(\s*)(\w+) = /gm, '$1"$2": ')
        .replace(/\["([^"\]]+)"\] = /g, '"$1": ')
        .replace(/,\s*([}\]])/g, '$1')
        .replace(/,\s*$/, '')}}`,
    )
  }
  return {
    activity: section('activity'),
    social: section('social'),
    tabs: section('tabs'),
  }
}

async function openAdmin(page, language = 'en') {
  await page.goto('/?apiPort=3098#/apps/phone')
  await expect(page.locator('.app-window .sky-app-page')).toBeVisible()
  await page.evaluate(
    async ({ language, locale }) => {
      const { usePhoneStore } = await import('/src/stores/phone.ts')
      const phone = usePhoneStore()
      phone.setLocale(language, { AdminPanel: locale }, phone.fallbackLocales)
      window.postMessage({ type: 'admin:open' }, '*')
    },
    { language, locale: adminLocale(language) },
  )
  await expect
    .poll(() =>
      page.evaluate(async () => {
        const { useAdminStore } = await import('/src/stores/admin.ts')
        return useAdminStore().selectedPlayer?.source
      }),
    )
    .toBe(1)
}

test('activity follows player selection, keeps pagination IDs exact and offers recovery after a failed read', async ({
  page,
}) => {
  await openAdmin(page)
  let fail = true
  const requests = []
  await page.route('**/api/admin:phone-activity', async (route) => {
    const input = route.request().postDataJSON()
    requests.push(input)
    if (fail) {
      fail = false
      await route.fulfill({ json: { success: false, error: 'request_failed' } })
      return
    }
    const source = input.source ?? 1
    const items = input.beforeId
      ? []
      : [
          {
            id: '9007199254740993',
            actorName: `Player ${source}`,
            actorSource: source,
            imei: '123',
            phoneNumber: '5551',
            category: 'Feather',
            action: 'feather:create-post',
            status: 'created',
            details: { request: { body: `Activity for player ${source}` } },
            createdAt: '2026-10-31 12:00:00',
          },
        ]
    await route.fulfill({
      json: {
        success: true,
        data: { items, hasMore: !input.beforeId, nextBeforeId: items[0]?.id },
      },
    })
  })
  await page
    .getByRole('button', { name: 'Phone activity', exact: true })
    .click()
  const view = page.locator('.admin-activity')
  await expect(view.getByRole('button', { name: 'Try again' })).toBeVisible()
  await view.getByRole('button', { name: 'Try again' }).click()
  await expect(view).toContainText('Activity for player 1')
  await expect(view.locator('pre')).toHaveCount(0)
  await view.locator('.admin-activity__entry summary').click()
  await expect(view.locator('pre')).toContainText('Activity for player 1')
  await view.getByRole('button', { name: 'Load older activity' }).click()
  await expect.poll(() => requests.at(-1)?.beforeId).toBe('9007199254740993')
  await expect(view.locator('.admin-activity__entry')).toHaveCount(0)
  await view.getByRole('button', { name: 'Previous', exact: true }).click()
  await expect(view).toContainText('Activity for player 1')
  await expect(view.locator('pre')).toHaveCount(0)
  expect(requests.at(-1)?.beforeId).toBeUndefined()
  await page
    .locator('.admin-panel-player-list button')
    .filter({ hasText: 'Jordan Blake' })
    .click()
  await expect(view).toContainText('Activity for player 2')
  await expect(view).not.toContainText('Activity for player 1')
  await view.locator('select').first().selectOption('all')
  await expect.poll(() => requests.at(-1)?.source).toBeUndefined()
})

test('scoped social inspection shows accounts, media and removed state and preserves the search draft when selecting another player', async ({
  page,
}) => {
  await page.setViewportSize({ width: 1280, height: 720 })
  await openAdmin(page, 'de')
  const requests = []
  await page.route('**/api/admin:social-posts', async (route) => {
    const input = route.request().postDataJSON()
    requests.push(input)
    await route.fulfill({
      json: {
        success: true,
        data: {
          accounts: [
            {
              id: 'p1',
              handle: 'sample_user',
              displayName: 'Sample User',
              accountId: 1,
            },
          ],
          hasMore: false,
          items: [
            {
              id: 'post1',
              author: 'sample_user',
              displayName: 'Sample User',
              body: 'Full post caption',
              status: 'removed',
              createdAt: '2026-10-31 12:00:00',
              media: [
                {
                  type: 'photo',
                  url: 'https://media.example.test/admin-post.svg',
                },
              ],
            },
          ],
        },
      },
    })
  })
  await page.route('https://media.example.test/admin-post.svg', (route) =>
    route.fulfill({
      contentType: 'image/svg+xml',
      body: '<svg xmlns="http://www.w3.org/2000/svg" width="200" height="120"><rect width="200" height="120" fill="gray"/></svg>',
    }),
  )
  await page.getByRole('button', { name: 'Social Media', exact: true }).click()
  const view = page.locator('.admin-social')
  await expect(view).toContainText('Zugeordnete App-Accounts')
  await expect(view).toContainText('@sample_user')
  await expect(view).toContainText('Full post caption')
  await expect(view.getByRole('img', { name: 'Beitragsanhang' })).toBeVisible()
  await expect(
    view.getByRole('button', { name: 'Beitrag löschen' }),
  ).toBeDisabled()
  await expect.poll(() => requests.at(-1)?.targetSource).toBe(1)
  await view.locator('input[type="search"]').fill('unsubmitted draft')
  await page
    .locator('.admin-panel-player-list button')
    .filter({ hasText: 'Jordan Blake' })
    .click()
  await expect.poll(() => requests.at(-1)?.targetSource).toBe(2)
  await expect(view.locator('input[type="search"]')).toHaveValue(
    'unsubmitted draft',
  )
  await expect(view).not.toContainText('AdminPanel.social.')
  await expect(view).not.toContainText('AdminPanel.activity.states.')
})

test('a failed removal for the previous player cannot replace the new player view', async ({
  page,
}) => {
  await openAdmin(page)
  let releaseRemoval
  let removalStarted = false
  let releasePlayer
  let playerRequested = false
  await page.route('**/api/admin:player', async (route) => {
    const response = await route.fetch()
    playerRequested = true
    await new Promise((resolve) => {
      releasePlayer = resolve
    })
    await route.fulfill({ response })
  })
  await page.route('**/api/admin:social-posts', async (route) => {
    const input = route.request().postDataJSON()
    await route.fulfill({
      json: {
        success: true,
        data: {
          accounts: [],
          hasMore: false,
          items: [
            {
              id: `post-${input.targetSource}`,
              author: 'sample',
              body: `Player ${input.targetSource} post`,
              status: 'published',
              media: [],
              createdAt: '2026-10-31 12:00:00',
            },
          ],
        },
      },
    })
  })
  await page.route('**/api/admin:delete-social-post', async (route) => {
    removalStarted = true
    await new Promise((resolve) => {
      releaseRemoval = resolve
    })
    await route.fulfill({ json: { success: false, error: 'not_authorized' } })
  })
  await page.getByRole('button', { name: 'Social media', exact: true }).click()
  const view = page.locator('.admin-social')
  await expect(view).toContainText('Player 1 post')
  // A previously requested player can finish loading while the delete dialog is open.
  await page
    .locator('.admin-panel-player-list button')
    .filter({ hasText: 'Jordan Blake' })
    .click()
  await expect.poll(() => playerRequested).toBe(true)
  await view.getByRole('button', { name: 'Delete post', exact: true }).click()
  await page
    .getByRole('dialog', { name: 'Delete this post?' })
    .getByRole('button', { name: 'Delete post', exact: true })
    .click()
  await expect.poll(() => removalStarted).toBe(true)
  releasePlayer()
  await expect(view).toContainText('Player 2 post')
  releaseRemoval()
  await expect(
    page.getByRole('dialog', { name: 'Delete this post?' }),
  ).toBeHidden()
  await expect(
    view
      .locator('.admin-social__post')
      .getByRole('button', { name: 'Delete post', exact: true }),
  ).toBeEnabled()
  await expect(view.locator('.sky-empty-state--danger')).toHaveCount(0)
  await expect(view).not.toContainText('Player 1 post')
})

test('social retry requests the failed next page instead of reloading the current page', async ({
  page,
}) => {
  await openAdmin(page)
  const requestedPages = []
  let failNext = true
  await page.route('**/api/admin:social-posts', async (route) => {
    const input = route.request().postDataJSON()
    requestedPages.push(input.page)
    if (input.page === 1 && failNext) {
      failNext = false
      await route.fulfill({ json: { success: false, error: 'request_failed' } })
      return
    }
    await route.fulfill({
      json: {
        success: true,
        data: {
          accounts: [],
          hasMore: input.page === 0,
          items: [
            {
              id: `post-${input.page}`,
              author: 'sample',
              body: `Social page ${input.page + 1}`,
              status: 'published',
              media: [],
              createdAt: '2026-10-31 12:00:00',
            },
          ],
        },
      },
    })
  })
  await page.getByRole('button', { name: 'Social media', exact: true }).click()
  const view = page.locator('.admin-social')
  await expect(view).toContainText('Social page 1')
  await view.getByRole('button', { name: 'Next', exact: true }).click()
  await expect(
    view.getByRole('button', { name: 'Try again', exact: true }),
  ).toBeVisible()
  await expect(view).toContainText('Social page 1')
  await view.getByRole('button', { name: 'Try again', exact: true }).click()
  await expect(view).toContainText('Social page 2')
  await expect(view).not.toContainText('Social page 1')
  expect(requestedPages).toEqual([0, 1, 1])
})
