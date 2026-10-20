import { expect, test } from '@playwright/test'

test('SMS notifications display the receiving phone contact on the lock screen', async ({
  page,
}) => {
  await page.goto('/?apiPort=3098&lockScreenPreview=1')
  await expect(page.locator('.lock-screen')).toBeVisible()
  await page.evaluate(async () => {
    const { useNotificationsStore } = await import(
      '/src/stores/notifications.ts'
    )
    useNotificationsStore().clearLockScreen()
    for (const sender of ['Saved 100% Contact', '5550002']) {
      window.postMessage(
        {
          type: 'messages:new',
          data: {
            phoneNumber: sender === '5550002' ? sender : '5550001',
            sender,
            text: `New message from ${sender}`,
            title: 'Messages',
          },
        },
        '*',
      )
    }
  })
  const cards = page.locator('.lock-screen__notification')
  await expect(cards).toHaveCount(2)
  await expect(cards.locator('small')).toHaveText([
    '5550002',
    'Saved 100% Contact',
  ])
  await expect(cards.locator('p')).toHaveText([
    'New message from 5550002',
    'New message from Saved 100% Contact',
  ])
  await expect(page.locator('.lock-screen__notifications')).not.toContainText(
    '5550001',
  )
})
