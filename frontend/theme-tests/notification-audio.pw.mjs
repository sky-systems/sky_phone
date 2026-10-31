import { test, expect } from '@playwright/test'

for (const [tone, filename, duration] of [
  ['chime', 'glass.wav', 1.8],
  ['signal', 'triad.wav', 1.4],
  ['soft', 'ripple.wav', 1.4],
]) {
  for (const loop of [false, true]) {
    test(`recorded ${tone} audio plays, follows volume and releases media (loop=${loop})`, async ({
      page,
    }) => {
      const errors = []
      page.on('console', (message) => {
        if (
          message.type() === 'error' &&
          message.text().includes('[Phone audio]')
        )
          errors.push(message.text())
      })
      // Keep real production audio modules and files, without unrelated app/API startup.
      await page.route('**/notification-audio-test.html', (route) =>
        route.fulfill({
          contentType: 'text/html',
          body: '<!doctype html><html><body><button>Enable audio</button></body></html>',
        }),
      )
      await page.goto('/notification-audio-test.html')
      await page.getByRole('button', { name: 'Enable audio' }).click()
      await page.evaluate(
        async ({ tone, loop }) => {
          const { playPhoneTone } = await import('/src/utils/tones.ts')
          const { setPhoneOutputVolume } = await import(
            '/src/utils/phoneAudio.ts'
          )
          const NativeAudio = window.Audio
          window.__notificationPlayers = []
          window.Audio = function (...args) {
            const player = new NativeAudio(...args)
            window.__notificationPlayers.push(player)
            return player
          }
          setPhoneOutputVolume(0.5)
          window.__stopNotification = playPhoneTone(tone, 60, loop)
        },
        { tone, loop },
      )
      await expect
        .poll(() =>
          page.evaluate(
            () => window.__notificationPlayers[0]?.currentTime ?? 0,
          ),
        )
        .toBeGreaterThan(0)
      const playback = await page.evaluate(() => {
        const player = window.__notificationPlayers[0]
        return {
          src: player.getAttribute('src'),
          volume: player.volume,
          duration: player.duration,
          loop: player.loop,
          error: player.error?.message,
        }
      })
      expect(playback.src).toContain(`sounds/notifications/${filename}`)
      expect(playback.duration).toBeCloseTo(duration, 2)
      expect(playback.volume).toBeCloseTo(0.3, 3)
      expect(playback.loop).toBe(loop)
      expect(playback.error).toBeUndefined()

      await page.evaluate(async () => {
        const { setPhoneOutputVolume } = await import(
          '/src/utils/phoneAudio.ts'
        )
        setPhoneOutputVolume(0)
      })
      await expect
        .poll(() => page.evaluate(() => window.__notificationPlayers[0].volume))
        .toBe(0)
      if (loop) await page.evaluate(() => window.__stopNotification())
      // One-shots must release their source on natural completion as well.
      await expect
        .poll(() =>
          page.evaluate(() =>
            window.__notificationPlayers[0].getAttribute('src'),
          ),
        )
        .toBeNull()
      expect(
        await page.evaluate(() => window.__notificationPlayers[0].paused),
      ).toBe(true)
      await page.evaluate(async () => {
        window.__stopNotification()
        const { setPhoneOutputVolume } = await import(
          '/src/utils/phoneAudio.ts'
        )
        setPhoneOutputVolume(1)
      })
      expect(
        await page.evaluate(() => window.__notificationPlayers[0].volume),
      ).toBe(0)
      expect(errors).toEqual([])
    })
  }
}
