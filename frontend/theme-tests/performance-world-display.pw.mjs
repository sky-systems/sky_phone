import { expect, test } from '@playwright/test'

test('world display retains still pixels and follows text, scroll and canvas changes', async ({
  page,
}) => {
  const frames = []
  await page.route(
    (url) => url.pathname === '/perf-fixture',
    (route) =>
      route.fulfill({
        contentType: 'text/html',
        body: `<!doctype html><html><head></head><body>
        <div class="phone-resolution-wrapper--primary">
          <div class="phone-screen" style="width:360px;height:780px;background:white;color:black">
            <h1>Initial pixels</h1>
            <div id="scroll" style="height:80px;overflow:auto">
              <div style="height:400px;background:linear-gradient(red,blue)">Scroll pixels</div>
            </div>
          </div>
        </div>
      </body></html>`,
      }),
  )
  await page.route('**/perf-api/worldDisplay:frame', async (route) => {
    frames.push(route.request().postDataJSON())
    await route.fulfill({ json: { success: true } })
  })
  await page.goto('/perf-fixture?apiBase=/perf-api')
  await page.evaluate(async () => {
    const { installWorldDisplayCapture } = await import(
      '/src/utils/worldDisplay.ts'
    )
    window.disposeCapture = installWorldDisplayCapture()
    window.postMessage({ type: 'phone:world-display', token: 1 }, '*')
  })
  await expect.poll(() => frames.length).toBeGreaterThanOrEqual(3)
  const initial = frames[0].jpeg
  expect(frames[1].jpeg).toBe(initial)
  expect(frames[2].jpeg).toBe(initial)
  expect(frames[2].sequence).toBe(3)

  await page
    .locator('h1')
    .evaluate((element) => (element.textContent = 'Updated pixels'))
  await expect.poll(() => frames.at(-1)?.jpeg).not.toBe(initial)
  const text = frames.at(-1).jpeg
  await page.locator('#scroll').evaluate((element) => (element.scrollTop = 100))
  await expect.poll(() => frames.at(-1)?.jpeg).not.toBe(text)
  const scrolled = frames.at(-1).jpeg

  await page.evaluate(() => {
    const canvas = document.createElement('canvas')
    canvas.width = 100
    canvas.height = 100
    document.querySelector('.phone-screen').append(canvas)
    canvas.getContext('2d').fillRect(0, 0, 100, 100)
  })
  await expect.poll(() => frames.at(-1)?.jpeg).not.toBe(scrolled)
  const black = frames.at(-1).jpeg
  await page.locator('canvas').evaluate((canvas) => {
    const context = canvas.getContext('2d')
    context.fillStyle = 'green'
    context.fillRect(0, 0, 100, 100)
  })
  await expect.poll(() => frames.at(-1)?.jpeg).not.toBe(black)
  await page.evaluate(() => window.disposeCapture())
  const count = frames.length
  await page.waitForTimeout(1000)
  expect(frames).toHaveLength(count)
})
