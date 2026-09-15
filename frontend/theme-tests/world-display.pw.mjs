import { test, expect } from '@playwright/test'
import { writeFile } from 'node:fs/promises'

test('captures the actual phone and isolates spectator pixels', async ({
  page,
  context,
}, testInfo) => {
  const frames = []
  await page.route('**/api/worldDisplay:frame', async (route) => {
    frames.push(route.request().postDataJSON())
    await route.fulfill({ json: { success: true } })
  })
  await page.goto('/?apiPort=3098#/apps/settings')
  await expect(
    page.locator('.phone-resolution-wrapper--primary .phone-screen'),
  ).toBeVisible()
  await page.evaluate(async () => {
    const { installWorldDisplayCapture } = await import(
      '/src/utils/worldDisplay.ts'
    )
    window.stopDisplayCapture = installWorldDisplayCapture()
    window.postMessage({ type: 'phone:world-display', token: 42 }, '*')
  })
  await expect.poll(() => frames.length, { timeout: 30000 }).toBeGreaterThan(0)
  const frame = frames[0]
  expect(frame.token).toBe(42)
  expect(frame.jpeg.length).toBeLessThanOrEqual(64000)
  const bytes = Buffer.from(frame.jpeg.split(',')[1], 'base64')
  await writeFile(testInfo.outputPath('captured-phone.jpg'), bytes)
  await testInfo.attach('captured-phone', {
    body: bytes,
    contentType: 'image/jpeg',
  })

  const first = await context.newPage()
  const second = await context.newPage()
  await first.goto('/display.html')
  await second.goto('/display.html')
  await first.evaluate(
    (jpeg) => window.postMessage({ type: 'frame', sequence: 1, jpeg }, '*'),
    frame.jpeg,
  )
  await expect
    .poll(() => first.locator('#screen').evaluate((img) => img.naturalWidth))
    .toBe(360)
  await expect
    .poll(() => first.locator('#screen').evaluate((img) => img.naturalHeight))
    .toBe(780)
  await expect(second.locator('#screen')).not.toHaveAttribute('src')
  await first.evaluate(() =>
    window.postMessage(
      { type: 'frame', sequence: 2, jpeg: 'https://example.com/steal' },
      '*',
    ),
  )
  await expect(first.locator('#screen')).toHaveAttribute('src', frame.jpeg)
  await first.screenshot({ path: testInfo.outputPath('spectator.png') })
  await expect(first.locator('#screen')).not.toHaveAttribute('src', {
    timeout: 5000,
  })

  await page.evaluate(() => {
    window.postMessage({ type: 'phone:world-display', token: false }, '*')
    window.stopDisplayCapture()
  })
  const stopped = frames.length
  await page.waitForTimeout(1100)
  expect(frames.length).toBe(stopped)
  await first.close()
  await second.close()
})

test('preserves the scrolled region without moving the live phone DOM', async ({
  page,
}) => {
  await page.goto('/?apiPort=3098#/apps/settings')
  await expect(
    page.locator('.phone-resolution-wrapper--primary .phone-screen'),
  ).toBeVisible()
  const result = await page.evaluate(async () => {
    const { captureDisplay } = await import('/src/utils/captureDisplay.ts')
    const root = document.createElement('div')
    root.style.cssText =
      'width:360px;height:780px;background:white;position:fixed;left:0;top:0'
    const scroller = document.createElement('div')
    scroller.style.cssText = 'height:300px;overflow:auto;width:360px'
    scroller.innerHTML =
      '<div style="height:300px;background:rgb(255,0,0)"></div><div style="height:300px;background:rgb(0,0,255)"></div>'
    root.append(scroller)
    document.body.append(root)
    scroller.scrollTop = 300
    const canvas = await captureDisplay(root)
    const pixel = [...canvas.getContext('2d').getImageData(100, 100, 1, 1).data]
    const preserved =
      scroller.scrollTop === 300 &&
      scroller.firstElementChild.style.transform === ''
    const cleaned = !scroller.hasAttribute('data-sky-display-scroll')
    root.remove()
    return { pixel, preserved, cleaned }
  })
  expect(result.pixel).toEqual([0, 0, 255, 255])
  expect(result.preserved).toBe(true)
  expect(result.cleaned).toBe(true)
})

test('captures a live video element and restores its poster', async ({
  page,
}) => {
  await page.goto('/?apiPort=3098#/apps/settings')
  await expect(
    page.locator('.phone-resolution-wrapper--primary .phone-screen'),
  ).toBeVisible()
  const result = await page.evaluate(async () => {
    const { captureDisplay } = await import('/src/utils/captureDisplay.ts')
    const source = document.createElement('canvas')
    source.width = 360
    source.height = 780
    source.getContext('2d').fillStyle = '#00ff00'
    source.getContext('2d').fillRect(0, 0, 360, 780)
    const stream = source.captureStream(5)
    const root = document.createElement('div')
    root.style.cssText =
      'width:360px;height:780px;position:fixed;left:0;top:0;background:black'
    const video = document.createElement('video')
    video.style.cssText = 'width:360px;height:780px;display:block'
    video.muted = true
    video.srcObject = stream
    root.append(video)
    document.body.append(root)
    await video.play()
    const canvas = await captureDisplay(root)
    const pixel = [...canvas.getContext('2d').getImageData(180, 390, 1, 1).data]
    const restored = video.poster === ''
    stream.getTracks().forEach((track) => track.stop())
    root.remove()
    return { pixel, restored }
  })
  expect(result.pixel[1]).toBeGreaterThan(240)
  expect(result.pixel[0]).toBeLessThan(15)
  expect(result.restored).toBe(true)
})
