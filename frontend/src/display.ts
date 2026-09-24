import {
  DISPLAY_HEIGHT,
  DISPLAY_WIDTH,
  validDisplayFrame,
} from '@/utils/displayFrame'
import './display.css'

const screen = document.querySelector<HTMLCanvasElement>('#screen')!
const context = screen.getContext('2d')!
screen.width = DISPLAY_WIDTH
screen.height = DISPLAY_HEIGHT
let latest = 0
let timeout: ReturnType<typeof setTimeout> | undefined
let warned = false
window.addEventListener('message', async (event: MessageEvent) => {
  const data = event.data
  if (
    data?.type !== 'frame' ||
    !Number.isSafeInteger(data.sequence) ||
    data.sequence <= latest ||
    !validDisplayFrame(data.jpeg)
  )
    return
  const sequence = data.sequence
  latest = sequence
  const received = performance.now()
  let bitmap: ImageBitmap | undefined
  try {
    // Decode JPEG bytes directly. Message values never become DOM URLs or HTML.
    const binary = atob(data.jpeg.slice(23))
    const bytes = Uint8Array.from(binary, (character) =>
      character.charCodeAt(0),
    )
    bitmap = await createImageBitmap(new Blob([bytes], { type: 'image/jpeg' }))
    const remaining = 3000 - (performance.now() - received)
    if (
      sequence !== latest ||
      remaining <= 0 ||
      bitmap.width !== DISPLAY_WIDTH ||
      bitmap.height !== DISPLAY_HEIGHT
    )
      return
    context.drawImage(bitmap, 0, 0)
    warned = false
    clearTimeout(timeout)
    timeout = setTimeout(
      () => context.clearRect(0, 0, DISPLAY_WIDTH, DISPLAY_HEIGHT),
      remaining,
    )
  } catch {
    if (!warned)
      console.warn('[sky_phone] Phone display JPEG could not be decoded.')
    warned = true
  } finally {
    bitmap?.close()
  }
})
