import { test, expect } from '@playwright/test'

// Use native browser WebRTC and real canvas tracks; only the FiveM signaling
// callback is simulated. Gameplay capture and ped rendering still need FiveM.
test('FaceTime exchanges video when signaling arrives before the peer roster', async ({
  page,
}) => {
  await page.route('**/realtime-native-test', (route) =>
    route.fulfill({
      contentType: 'text/html',
      body: '<!doctype html><title>WebRTC test</title>',
    }),
  )
  await page.goto('/realtime-native-test')
  const result = await page.evaluate(async () => {
    const { LiveConnection } = await import(
      '/src/features/realtime/connection.ts'
    )
    const config = {
      enabled: true,
      transport: 'p2p',
      videoCalls: true,
      picstagram: true,
      fliptok: true,
      edge: 160,
      nearbyAudio: false,
      iceServers: [],
      iceTransportPolicy: 'all',
      bitrate: 300000,
      fps: 15,
    }
    const room = (self) => ({
      id: 'native-call',
      kind: 'call',
      self,
      role: 'call',
      viewers: 0,
      transport: 'p2p',
      revision: 2,
      peers: [
        {
          id: self === 1 ? 2 : 1,
          role: 'call',
          sends: true,
          receives: true,
          gain: 1,
          tracks: [],
        },
      ],
    })
    const failures = [],
      videos = [],
      tracks = [],
      intervals = []
    const connections = new Map()
    const originalFetch = window.fetch
    let earlyOffer = false
    window.fetch = async (url, init) => {
      if (!String(url).endsWith('/realtime:signal'))
        return originalFetch(url, init)
      const { target, signal } = JSON.parse(init.body)
      if (target === 2 && signal.type === 'offer') earlyOffer = true
      // Deliver independently of callback completion, as NUI and net events do.
      void connections
        .get(target)
        .signal(target === 1 ? 2 : 1, signal)
        .catch((error) => failures.push(error.message))
      return Response.json({ success: true })
    }
    const waitFor = async (predicate) => {
      const until = performance.now() + 15000
      while (!predicate()) {
        if (failures.length || performance.now() > until)
          throw new Error(failures.join('; ') || 'Timed out waiting for video')
        await new Promise((resolve) => setTimeout(resolve, 25))
      }
    }
    try {
      for (const self of [1, 2]) {
        const canvas = document.createElement('canvas')
        canvas.width = 160
        canvas.height = 120
        const context = canvas.getContext('2d')
        const paint = () => {
          context.fillStyle = self === 1 ? '#ff453a' : '#0a84ff'
          context.fillRect(0, 0, 160, 120)
          context.fillStyle = '#fff'
          context.fillText(String(performance.now()), 10, 40)
        }
        paint()
        intervals.push(setInterval(paint, 66))
        const stream = canvas.captureStream(15)
        tracks.push(...stream.getTracks())
        connections.set(
          self,
          new LiveConnection(
            { ...room(self), peers: [], revision: 1 },
            config,
            stream,
            (_id, remote) => {
              if (!remote) return
              const video = document.createElement('video')
              video.muted = true
              video.autoplay = true
              video.srcObject = remote
              document.body.append(video)
              videos.push(video)
              void video.play().catch((error) => failures.push(error.message))
            },
            (error) => failures.push(error.message),
          ),
        )
        await connections.get(self).start()
      }
      await connections.get(1).update(room(1))
      await waitFor(() => earlyOffer)
      // Ensure the receiving connection handles the offer while peers is empty.
      await new Promise((resolve) => setTimeout(resolve, 150))
      await connections.get(2).update(room(2))
      await waitFor(
        () =>
          videos.length === 2 &&
          videos.every(
            (video) =>
              video.videoWidth === 160 &&
              video.videoHeight === 120 &&
              video.currentTime > 0.2,
          ),
      )
      return { received: videos.length, failures }
    } finally {
      connections.forEach((connection) => connection.close())
      tracks.forEach((track) => track.stop())
      intervals.forEach(clearInterval)
      videos.forEach((video) => {
        video.srcObject = null
        video.remove()
      })
      window.fetch = originalFetch
    }
  })
  expect(result).toEqual({ received: 2, failures: [] })
})
