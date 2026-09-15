import { validDisplayFrame } from '@/utils/displayFrame'
import './display.css'

const screen = document.querySelector<HTMLImageElement>('#screen')!
let latest = 0
let timeout: ReturnType<typeof setTimeout> | undefined
window.addEventListener('message', (event: MessageEvent) => {
  const data = event.data
  if (
    data?.type !== 'frame' ||
    !Number.isSafeInteger(data.sequence) ||
    data.sequence <= latest ||
    !validDisplayFrame(data.jpeg)
  )
    return
  latest = data.sequence
  screen.src = data.jpeg
  clearTimeout(timeout)
  timeout = setTimeout(() => screen.removeAttribute('src'), 3000)
})
