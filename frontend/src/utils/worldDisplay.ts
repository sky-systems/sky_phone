import { captureDisplay } from './captureDisplay'
import { nuiCall } from '@/utils/nui'

import { MAX_DISPLAY_FRAME_BYTES, validDisplayFrame } from './displayFrame'

/** Capture only the primary phone's visible screen, never the desktop/game. */
export function installWorldDisplayCapture() {
  let token: number | null = null
  let sequence = 0
  let running = false
  let disposed = false
  let warned = false
  const onMessage = (event: MessageEvent) => {
    if (event.data?.type !== 'phone:world-display') return
    const next = event.data.token
    token = Number.isSafeInteger(next) && next > 0 ? next : null
  }
  window.addEventListener('message', onMessage)
  const timer = window.setInterval(async () => {
    if (disposed || running || token === null) return
    const screen = document.querySelector<HTMLElement>(
      '.phone-resolution-wrapper--primary .phone-screen',
    )
    if (!screen || screen.clientWidth === 0) return
    const current = token
    running = true
    try {
      const canvas = await captureDisplay(screen)
      let jpeg = canvas.toDataURL('image/jpeg', 0.65)
      if (jpeg.length > MAX_DISPLAY_FRAME_BYTES)
        jpeg = canvas.toDataURL('image/jpeg', 0.35)
      if (disposed || token !== current || !validDisplayFrame(jpeg)) return
      await nuiCall('worldDisplay:frame', {
        token: current,
        sequence: ++sequence,
        jpeg,
      })
      warned = false
    } catch (error) {
      if (!warned)
        console.warn('[sky_phone] World display capture failed:', error)
      warned = true
    } finally {
      running = false
    }
  }, 500)
  return () => {
    disposed = true
    token = null
    window.clearInterval(timer)
    window.removeEventListener('message', onMessage)
  }
}
