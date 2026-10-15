import { expect, test } from '@playwright/test'

async function openPhone(page) {
  await page.goto('/?apiPort=3098#/')
  await expect(page.locator('.phone-status-bar__time-button')).toBeVisible()
  await expect(page.locator('.page-indicator button')).toHaveCount(4)
}

async function lockPhone(page, protectedPhone = false) {
  await page.route('**/api/notifications:save', (route) =>
    route.fulfill({ json: { success: true } }),
  )
  await openPhone(page)
  await page.evaluate(async (protectedPhone) => {
    const { usePhoneStore } = await import('/src/stores/phone.ts')
    const { useNotificationsStore } = await import(
      '/src/stores/notifications.ts'
    )
    const phone = usePhoneStore()
    if (protectedPhone)
      phone.security = { enabled: true, length: 4, lockedUntil: 0 }
    useNotificationsStore().clearLockScreen()
    useNotificationsStore().hydrate(
      {
        version: 1,
        items: [
          {
            id: 'glass-billing',
            createdAt: Date.now() - 39 * 60_000,
            appId: 'billing',
            title: 'Billing',
            subtitle: 'Los Santos Customs',
            text: 'A new invoice for $1,850 is ready.',
            route: '/apps/billing',
          },
          {
            id: 'glass-companies',
            createdAt: Date.now() - 14 * 60_000,
            appId: 'companies',
            title: 'Companies',
            subtitle: 'Los Santos Customs',
            text: 'Your repair request has been accepted.',
            route: '/apps/companies',
          },
          {
            id: 'glass-message',
            createdAt: Date.now() - 2 * 60_000,
            appId: 'messages',
            title: 'Messages',
            subtitle: 'Alex Rivera',
            text: 'Meet us at the observatory after sunset.',
            route: '/apps/messages',
          },
        ],
      },
      phone.device.imei,
    )
  }, protectedPhone)
  await page.getByRole('button', { name: 'Lock phone', exact: true }).click()
  await expect(page.locator('.lock-screen')).toBeVisible()
  await expect(page.locator('.lock-screen__notification')).toHaveCount(3)
}

test('keeps status time, home bar, app spacing and page dots unframed', async ({
  page,
}) => {
  await openPhone(page)
  const geometry = await page.evaluate(() => {
    const time = document.querySelector('.phone-status-bar__time-button')
    const home = document.querySelector('.phone-home-indicator span')
    const grid = document.querySelector('.springboard-page--apps .app-grid')
    const dots = document.querySelector('.page-indicator')
    const dock = document.querySelector('.app-dock')
    return {
      timeBackground: getComputedStyle(time).backgroundColor,
      timePosition: getComputedStyle(time).position,
      home: [
        home.offsetWidth,
        home.offsetHeight,
        getComputedStyle(home).backgroundColor,
      ],
      gap: getComputedStyle(grid).gap,
      row: getComputedStyle(grid)
        .getPropertyValue('--springboard-grid-row')
        .trim(),
      dotsAboveDock:
        dots.getBoundingClientRect().bottom < dock.getBoundingClientRect().top,
      dotSizes: [...dots.querySelectorAll('button')].map((b) => [
        b.offsetWidth,
        b.offsetHeight,
      ]),
    }
  })
  expect(geometry.timeBackground).toBe('rgba(0, 0, 0, 0)')
  expect(geometry.timePosition).toBe('absolute')
  expect(geometry.home).toEqual([106, 4, 'rgb(255, 255, 255)'])
  expect(geometry.gap).toBe('12px 10px')
  expect(geometry.row).toBe('80px')
  expect(geometry.dotsAboveDock).toBe(true)
  expect(geometry.dotSizes).toEqual([
    [6, 6],
    [6, 6],
    [6, 6],
    [6, 6],
  ])
  await page.getByRole('button', { name: 'Page 3', exact: true }).click()
  await expect(
    page.getByRole('button', { name: 'Page 3', exact: true }),
  ).toHaveClass(/active/)
  await page.getByRole('button', { name: 'Page 2', exact: true }).press('Enter')
  await expect(
    page.getByRole('button', { name: 'Page 2', exact: true }),
  ).toHaveClass(/active/)
})

test('keeps compact, transparent and content controls distinct', async ({
  page,
}) => {
  await openPhone(page)
  await page.evaluate(async () => {
    const { createApp, h } = await import('/node_modules/.vite/deps/vue.js')
    const { SkyButton } = await import('/src/ui/index.ts')
    const host = document.createElement('div')
    host.id = 'control-geometry-fixture'
    document.body.append(host)
    createApp({
      render: () =>
        h('div', [
          h(
            SkyButton,
            { id: 'regular-action', inline: true },
            () => 'Continue',
          ),
          h(
            SkyButton,
            { id: 'small-action', small: true, inline: true },
            () => 'Add',
          ),
          h(
            SkyButton,
            { id: 'plain-action', variant: 'plain', inline: true },
            () => 'Cancel',
          ),
          h(SkyButton, {
            id: 'content-action',
            variant: 'content',
            style: { width: '6px', height: '6px' },
          }),
        ]),
    }).mount(host)
  })
  const controls = await page.evaluate(() =>
    Object.fromEntries(
      [...document.querySelectorAll('#control-geometry-fixture button')].map(
        (button) => [
          button.id,
          {
            height: button.offsetHeight,
            width: button.offsetWidth,
            background: getComputedStyle(button).backgroundColor,
          },
        ],
      ),
    ),
  )
  expect(controls['regular-action'].height).toBe(34)
  expect(controls['small-action'].height).toBe(28)
  expect(controls['plain-action'].background).toBe('rgba(0, 0, 0, 0)')
  expect(controls['content-action']).toEqual({
    height: 6,
    width: 6,
    background: 'rgba(0, 0, 0, 0)',
  })
})

for (const mode of ['light', 'dark']) {
  test(`lock screen keeps complete notification cards and a centered white home bar: ${mode}`, async ({
    page,
  }, testInfo) => {
    await lockPhone(page)
    await page.evaluate(async (appearanceMode) => {
      const { usePhoneStore } = await import('/src/stores/phone.ts')
      usePhoneStore().preferences.settings.appearanceMode = appearanceMode
    }, mode)
    await page.waitForTimeout(700)
    const layout = await page.evaluate(() => {
      const cards = [...document.querySelectorAll('.lock-screen__notification')]
      const bar = document.querySelector('.lock-screen__home-indicator')
      const lock = document.querySelector('.lock-screen')
      const barBox = bar.getBoundingClientRect(),
        lockBox = lock.getBoundingClientRect()
      return {
        cards: cards.map((card) => {
          const bounds = card.getBoundingClientRect()
          const row = card.parentElement.getBoundingClientRect()
          return {
            height: card.offsetHeight,
            fullRow: Math.abs(row.height - bounds.height) < 1,
            copyFits: [...card.querySelectorAll('strong, small, p')].every(
              (child) => child.getBoundingClientRect().bottom <= bounds.bottom,
            ),
            opacity: getComputedStyle(card).opacity,
          }
        }),
        home: [
          bar.offsetWidth,
          bar.offsetHeight,
          getComputedStyle(bar).backgroundColor,
        ],
        centered:
          Math.abs(
            (barBox.left + barBox.right) / 2 -
              (lockBox.left + lockBox.right) / 2,
          ) < 1,
        swipeBackground: getComputedStyle(
          document.querySelector('.lock-screen__swipe'),
        ).backgroundColor,
      }
    })
    expect(
      layout.cards.every(
        (card) =>
          card.height >= 78 &&
          card.fullRow &&
          card.copyFits &&
          card.opacity === '1',
      ),
    ).toBe(true)
    expect(layout.home).toEqual([106, 4, 'rgb(255, 255, 255)'])
    expect(layout.centered).toBe(true)
    expect(layout.swipeBackground).toBe('rgba(0, 0, 0, 0)')
    await page
      .locator('.phone-device')
      .screenshot({ path: testInfo.outputPath(`lockscreen-${mode}.png`) })
  })
}

test('holding X keeps the menu and lock screen open after release; clearing is explicit', async ({
  page,
}) => {
  await lockPhone(page)
  const clear = page.locator('.lock-screen__notifications-clear')
  await clear.hover()
  await page.mouse.down()
  const menu = page.getByRole('menuitem', {
    name: 'Clear All Notifications',
    exact: true,
  })
  await expect(menu).toBeVisible()
  await page.mouse.up()
  await expect(menu).toBeVisible()
  expect(
    await menu.locator('.sky-dropdown__label').evaluate((label) => {
      const range = document.createRange()
      range.selectNodeContents(label)
      return {
        lines: range.getClientRects().length,
        fits: label.scrollWidth <= label.clientWidth,
      }
    }),
  ).toEqual({ lines: 1, fits: true })
  await expect(page.locator('.lock-screen')).toBeVisible()
  await expect(page.locator('.lock-screen__notification')).toHaveCount(3)
  await page.keyboard.press('Escape')
  await expect(menu).not.toBeVisible()
  await expect(page.locator('.lock-screen')).toBeVisible()
  await clear.press('Enter')
  await expect(menu).toBeVisible()
  await menu.click()
  await expect(page.locator('.lock-screen__notification')).toHaveCount(0)
  await expect(page.locator('.lock-screen')).toBeVisible()
})

for (const appearance of ['light', 'dark']) {
  test(`clear glass uses the supported material rather than its opaque fallback: ${appearance}`, async ({
    page,
  }) => {
    await lockPhone(page)
    await page.evaluate(async (appearance) => {
      const { usePhoneStore } = await import('/src/stores/phone.ts')
      usePhoneStore().preferences.settings.appearanceMode = appearance
      usePhoneStore().preferences.settings.graphicsMode = 'ultimate'
      usePhoneStore().preferences.settings.glassBlur = 6
    }, appearance)
    const buttons = page.locator(
      '.lock-screen__shortcut, .lock-screen__notifications-clear',
    )
    await expect(buttons).toHaveCount(3)
    for (const button of await buttons.all()) {
      await expect(button).toHaveClass(/sky-glass--refractive/)
    }
    await expect(buttons.first()).toHaveCSS(
      'background-color',
      'rgba(28, 28, 32, 0.12)',
    )
    const material = await buttons.evaluateAll((elements) =>
      elements.map((element) => ({
        background: getComputedStyle(element).backgroundColor,
        blur: getComputedStyle(element).backdropFilter,
        opacity: getComputedStyle(element).opacity,
        color: getComputedStyle(element).color,
        rim: getComputedStyle(element.querySelector('.sky-glass__rim'))
          .backgroundImage,
        rootFilter: getComputedStyle(element).filter,
        displacementScale: Number(
          element.querySelector('feDisplacementMap')?.getAttribute('scale'),
        ),
        iconFilter: getComputedStyle(element.querySelector('.sky-icon')).filter,
      })),
    )
    expect(material).toHaveLength(3)
    for (const control of material) {
      expect(control.background).toBe('rgba(28, 28, 32, 0.12)')
      expect(control.blur).toContain('url(')
      expect(control.blur).toContain('blur(6px)')
      expect(control.opacity).toBe('1')
      expect(control.color).toBe('rgb(255, 255, 255)')
      expect(control.rim).toContain('data:image/png')
      expect(control.rootFilter).toBe('none')
      expect(control.displacementScale).toBeGreaterThan(0)
      expect(control.iconFilter).toBe('none')
    }
    await page.evaluate(async () => {
      const { usePhoneStore } = await import('/src/stores/phone.ts')
      usePhoneStore().preferences.settings.graphicsMode = 'performance'
    })
    await expect
      .poll(() =>
        buttons.evaluateAll((elements) =>
          elements.map((element) => ({
            background: getComputedStyle(element).backgroundColor,
            blur: getComputedStyle(element).backdropFilter,
            rim: getComputedStyle(element.querySelector('.sky-glass__rim'))
              .display,
            opacity: getComputedStyle(element).opacity,
          })),
        ),
      )
      .toEqual(
        Array(3).fill({
          background: 'rgba(38, 38, 42, 0.78)',
          blur: 'none',
          rim: 'none',
          opacity: '1',
        }),
      )
  })
}

test('notification age updates in place, changes language and keeps its date after reload', async ({
  page,
}, testInfo) => {
  await page.clock.install({ time: new Date('2026-10-15T16:00:00Z') })
  let persisted
  page.on('request', (request) => {
    if (request.url().endsWith('/api/notifications:save'))
      persisted = request.postDataJSON().payload
  })
  await lockPhone(page)
  const firstTime = page
    .locator('.lock-screen__notification-heading time')
    .last()
  await expect(firstTime).toHaveText('39 min. ago')
  const originalDate = await firstTime.getAttribute('datetime')
  await page.clock.fastForward(60_000)
  await expect(firstTime).toHaveText('40 min. ago')
  await page.evaluate(async () => {
    const { usePhoneStore } = await import('/src/stores/phone.ts')
    usePhoneStore().lang = 'de'
  })
  await expect(firstTime).toHaveText('Vor 40 Min.')
  const geometry = await firstTime.evaluate((time) => ({
    font: getComputedStyle(time).fontSize,
    oneLine:
      time.getBoundingClientRect().height <=
      parseFloat(getComputedStyle(time).lineHeight) + 1,
    fits:
      time.getBoundingClientRect().right <=
      time.closest('.lock-screen__notification').getBoundingClientRect().right -
        8,
  }))
  expect(geometry).toEqual({ font: '13px', oneLine: true, fits: true })
  await page
    .locator('.phone-device')
    .screenshot({ path: testInfo.outputPath('notification-age-de.png') })
  await page.evaluate(async () => {
    const { useNotificationsStore } = await import(
      '/src/stores/notifications.ts'
    )
    const { usePhoneStore } = await import('/src/stores/phone.ts')
    // Persist the current history through the real store before reloading.
    useNotificationsStore().hydrate(null, usePhoneStore().device.imei)
  })
  await expect.poll(() => persisted?.items?.length).toBe(3)
  const saved = persisted
  await page.reload()
  await expect(page.locator('.phone-status-bar__time-button')).toBeVisible()
  await page.evaluate(async (payload) => {
    const { useNotificationsStore } = await import(
      '/src/stores/notifications.ts'
    )
    const { usePhoneStore } = await import('/src/stores/phone.ts')
    useNotificationsStore().clearLockScreen()
    useNotificationsStore().hydrate(payload, usePhoneStore().device.imei)
    usePhoneStore().lang = 'de'
  }, saved)
  await page.locator('.phone-status-bar__time-button').click()
  await expect(firstTime).toHaveText('Vor 40 Min.')
  await expect(firstTime).toHaveAttribute('datetime', originalDate)
})

test('Ultimate applies supported blur, Performance and unsupported clients keep opaque content', async ({
  page,
}) => {
  await lockPhone(page)
  async function mode(graphicsMode, backdrop) {
    await page.evaluate(
      async ({ graphicsMode, backdrop }) => {
        const { usePhoneStore } = await import('/src/stores/phone.ts')
        usePhoneStore().preferences.settings.graphicsMode = graphicsMode
        document.documentElement.dataset.skyBackdrop = String(backdrop)
      },
      { graphicsMode, backdrop },
    )
    return page
      .locator('.lock-screen__notification')
      .first()
      .evaluate((card) => ({
        filter: getComputedStyle(card).backdropFilter,
        opacity: getComputedStyle(card).opacity,
        textOpacity: getComputedStyle(card.querySelector('p')).opacity,
        background: getComputedStyle(card).backgroundColor,
      }))
  }
  const ultimate = await mode('ultimate', true)
  expect(ultimate.filter).toContain('blur(')
  for (const settings of [
    ['performance', true],
    ['ultimate', false],
  ]) {
    const flat = await mode(...settings)
    expect(flat.filter).toBe('none')
    expect(flat.opacity).toBe('1')
    expect(flat.textOpacity).toBe('1')
    expect(flat.background).not.toBe('rgba(0, 0, 0, 0)')
  }
})

test('redacts locked notifications, keeps failed unlocks private and shows sender after a successful unlock', async ({
  page,
}) => {
  await lockPhone(page, true)
  const cards = page.locator('.lock-screen__notification-copy')
  await expect(cards.filter({ hasText: 'Text message' })).toHaveCount(1)
  await expect(cards.filter({ hasText: 'Alex Rivera' })).toHaveCount(0)
  let attempts = 0
  await page.route('**/api/security:unlock', (route) => {
    attempts += 1
    return route.fulfill({
      json:
        route.request().postDataJSON().passcode === '1234'
          ? { success: true }
          : { success: false, error: 'incorrect_passcode' },
    })
  })
  await page.locator('.lock-screen__swipe').click()
  const pin = page.locator('.passcode-screen')
  await expect(pin).toBeVisible()
  await pin.press('0')
  await pin.press('0')
  await pin.press('0')
  await pin.press('0')
  await expect(pin).toContainText('Incorrect passcode')
  await expect(cards.filter({ hasText: 'Alex Rivera' })).toHaveCount(0)
  for (const digit of ['1', '2', '3', '4']) await pin.press(digit)
  await expect(pin).not.toBeVisible()
  await expect(page.locator('.lock-screen')).not.toBeVisible()
  await page
    .getByRole('button', { name: 'Notification Center', exact: true })
    .click()
  await expect(page.locator('.lock-screen')).toBeVisible()
  await expect(cards.filter({ hasText: 'Alex Rivera' })).toHaveCount(1)
  await expect(
    cards.filter({ hasText: 'observatory after sunset' }),
  ).toHaveCount(1)
  await expect(cards.filter({ hasText: 'Messages' })).toHaveCount(0)
  expect(attempts).toBe(2)
  await expect(page.locator('.lock-screen__lock')).toHaveAttribute(
    'style',
    /lock-open|--sky-icon-source/,
  )
  await page.getByRole('button', { name: 'Lock phone', exact: true }).click()
  await expect(cards.filter({ hasText: 'Text message' })).toHaveCount(1)
  await expect(cards.filter({ hasText: 'Alex Rivera' })).toHaveCount(0)
})

test('keeps the status time centered beside the physical notch with opaque white indicators', async ({
  page,
}) => {
  await lockPhone(page)
  const layout = await page.evaluate(() => {
    const bar = document.querySelector('.lock-screen .phone-status-bar')
    const time = bar.querySelector('.phone-status-bar__time')
    const indicators = bar.querySelector('.phone-status-indicators')
    const range = document.createRange()
    range.selectNodeContents(time)
    const t = range.getBoundingClientRect(),
      i = indicators.getBoundingClientRect(),
      b = bar.getBoundingClientRect()
    const scale = b.width / bar.offsetWidth
    const availableLeftWidth = (b.width - 108 * scale) / 2
    return {
      horizontalOffset: Math.abs(
        (t.left + t.right) / 2 - (b.left + availableLeftWidth / 2),
      ),
      verticalOffset: Math.abs((t.top + t.bottom) / 2 - (i.top + i.bottom) / 2),
      font: getComputedStyle(time).fontSize,
      color: getComputedStyle(time).color,
      opacity: getComputedStyle(indicators).opacity,
      disabled: !!bar.querySelector('[disabled]'),
      lockSize: document.querySelector('.lock-screen__lock').offsetWidth,
    }
  })
  expect(layout.horizontalOffset).toBeLessThan(1)
  expect(layout.verticalOffset).toBeLessThan(1)
  expect(layout.font).toBe('17px')
  expect(layout.color).toBe('rgb(255, 255, 255)')
  expect(layout.opacity).toBe('1')
  expect(layout.disabled).toBe(false)
  expect(layout.lockSize).toBe(22)
})

test('saves the Lock Screen date format from General and restores it after reload', async ({
  page,
}) => {
  const savedFormats = []
  page.on('request', (request) => {
    if (request.url().endsWith('/api/device:save')) {
      const body = request.postDataJSON()
      if (body.namespace === 'settings')
        savedFormats.push(body.payload.settings.lockScreenDateFormat)
    }
  })
  await openPhone(page)
  await page.evaluate(async () => {
    const { default: router } = await import('/src/router/index.ts')
    await router.push('/apps/settings')
  })
  await page
    .getByRole('button', { name: 'General Settings', exact: true })
    .click()
  await page.getByRole('button', { name: /^Full / }).click()
  await expect.poll(() => savedFormats.includes('long')).toBe(true)
  await page.reload()
  await expect(page.locator('.phone-status-bar__time-button')).toBeVisible()
  await page.evaluate(async () => {
    const { default: router } = await import('/src/router/index.ts')
    await router.push('/apps/settings')
  })
  await page
    .getByRole('button', { name: 'General Settings', exact: true })
    .click()
  await expect(page.getByRole('button', { name: /^Full / })).toHaveAttribute(
    'aria-pressed',
    'true',
  )
  await page.getByRole('button', { name: /^Abbreviated / }).click()
  await expect.poll(() => savedFormats.at(-1)).toBe('short')
})
