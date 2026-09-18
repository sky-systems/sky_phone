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
  const pixel = (target) =>
    target
      .locator('#screen')
      .evaluate((canvas) => [
        ...canvas.getContext('2d').getImageData(180, 390, 1, 1).data,
      ])
  await expect.poll(async () => (await pixel(first))[3]).toBe(255)
  expect(
    await first
      .locator('#screen')
      .evaluate((canvas) => [canvas.width, canvas.height]),
  ).toEqual([360, 780])
  expect(await pixel(second)).toEqual([0, 0, 0, 0])
  const displayed = await pixel(first)
  await first.evaluate(() =>
    window.postMessage(
      { type: 'frame', sequence: 2, jpeg: 'https://example.com/steal' },
      '*',
    ),
  )
  expect(await pixel(first)).toEqual(displayed)
  await expect(first.locator('#screen')).not.toHaveAttribute('src')
  await first.screenshot({ path: testInfo.outputPath('spectator.png') })
  await expect.poll(() => pixel(first), { timeout: 5000 }).toEqual([0, 0, 0, 0])

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

test('spectator rejects URL and executable payloads without navigation or requests', async ({
  page,
}) => {
  await page.goto('/display.html')
  const requests = [],
    errors = []
  page.on('request', (request) => requests.push(request.url()))
  page.on('pageerror', (error) => errors.push(error.message))
  const originalUrl = page.url()
  await page.evaluate(() => {
    const payloads = [
      'javascript:window.displayInjected=true',
      'https://example.com/frame.jpg',
      '//example.com/frame.jpg',
      'data:text/html,<script>window.displayInjected=true</script>',
      'data:image/svg+xml;base64,' +
        btoa(
          '<svg xmlns="http://www.w3.org/2000/svg" onload="window.displayInjected=true"/>',
        ),
      'data:image/jpeg;base64,' +
        btoa('<html><script>window.displayInjected=true</script></html>'),
    ]
    for (const jpeg of payloads)
      window.postMessage({ type: 'frame', sequence: 99, jpeg }, '*')
    const source = document.createElement('canvas')
    source.width = 360
    source.height = 780
    const context = source.getContext('2d')
    context.fillStyle = '#00ff00'
    context.fillRect(0, 0, 360, 780)
    // Rejected payloads must not advance the sequence watermark.
    window.postMessage(
      { type: 'frame', sequence: 1, jpeg: source.toDataURL('image/jpeg') },
      '*',
    )
  })
  await expect
    .poll(() =>
      page
        .locator('#screen')
        .evaluate((canvas) => [
          ...canvas.getContext('2d').getImageData(180, 390, 1, 1).data,
        ]),
    )
    .toEqual([0, 255, 1, 255])
  expect(await page.evaluate(() => Boolean(window.displayInjected))).toBe(false)
  expect(page.url()).toBe(originalUrl)
  expect(requests).toEqual([])
  expect(errors).toEqual([])
  await expect(
    page.locator('[src]:not(script), iframe, object, embed'),
  ).toHaveCount(0)
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
