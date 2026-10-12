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
  let screen: HTMLElement | null = null
  let dirty = true
  let jpeg: string | null = null
  let previouslyAnimated = false
  const invalidate = () => {
    dirty = true
  }
  const observer = new MutationObserver((records) => {
    if (
      records.some(
        (record) => !record.attributeName?.startsWith('data-sky-display-'),
      )
    )
      invalidate()
  })
  const screenEvents = [
    'scroll',
    'input',
    'change',
    'load',
    'seeked',
    'focusin',
    'focusout',
    'pointerover',
    'pointerout',
    'pointerdown',
    'pointerup',
    'keydown',
    'keyup',
  ] as const
  function observeScreen(next: HTMLElement | null): void {
    if (screen === next) return
    observer.disconnect()
    for (const event of screenEvents)
      screen?.removeEventListener(event, invalidate, true)
    screen = next
    jpeg = null
    dirty = true
    previouslyAnimated = false
    if (!screen) return
    observer.observe(screen, {
      attributes: true,
      characterData: true,
      childList: true,
      subtree: true,
    })
    for (const event of screenEvents)
      screen.addEventListener(event, invalidate, true)
  }
  const onMessage = (event: MessageEvent) => {
    if (event.data?.type !== 'phone:world-display') return
    const next = event.data.token
    const nextToken = Number.isSafeInteger(next) && next > 0 ? next : null
    if (token !== nextToken) {
      jpeg = null
      dirty = true
    }
    token = nextToken
    if (token === null) observeScreen(null)
  }
  window.addEventListener('message', onMessage)
  window.addEventListener('resize', invalidate)
  document.fonts.addEventListener('loadingdone', invalidate)
  const timer = window.setInterval(async () => {
    if (disposed || running || token === null) return
    observeScreen(
      document.querySelector<HTMLElement>(
        '.phone-resolution-wrapper--primary .phone-screen',
      ),
    )
    if (!screen || screen.clientWidth === 0) return
    const current = token
    // Canvas/video pixels and CSS animations can change without a DOM mutation.
    const animated =
      screen.querySelector('canvas') !== null ||
      [...screen.querySelectorAll('video')].some(
        (video) => !video.paused && !video.ended,
      ) ||
      screen
        .getAnimations({ subtree: true })
        .some((animation) => animation.playState === 'running')
    const needsCapture = dirty || animated || previouslyAnimated || !jpeg
    previouslyAnimated = animated
    running = true
    try {
      if (needsCapture) {
        dirty = false
        const canvas = await captureDisplay(screen)
        let frame = canvas.toDataURL('image/jpeg', 0.65)
        if (frame.length > MAX_DISPLAY_FRAME_BYTES)
          frame = canvas.toDataURL('image/jpeg', 0.35)
        if (disposed || token !== current) return
        if (!validDisplayFrame(frame)) {
          dirty = true
          return
        }
        jpeg = frame
      }
      if (disposed || token !== current) return
      // Keep the existing delivery cadence and viewer/publisher leases while
      // reusing unchanged pixels instead of cloning the DOM again.
      await nuiCall('worldDisplay:frame', {
        token: current,
        sequence: ++sequence,
        jpeg,
      })
      warned = false
    } catch (error) {
      dirty = true
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
    observeScreen(null)
    window.clearInterval(timer)
    window.removeEventListener('message', onMessage)
    window.removeEventListener('resize', invalidate)
    document.fonts.removeEventListener('loadingdone', invalidate)
  }
}
