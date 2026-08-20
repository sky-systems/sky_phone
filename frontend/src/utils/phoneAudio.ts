type PhoneAudioVolumeListener = (volume: number) => void

const mediaElements = new Map<HTMLMediaElement, boolean>()
const mediaLocalVolumes = new WeakMap<HTMLMediaElement, number>()
const volumeListeners = new Set<PhoneAudioVolumeListener>()

let documentListenerReferences = 0
let outputVolume = 1

function clampVolume(volume: number): number {
  return Math.max(0, Math.min(1, Number.isFinite(volume) ? volume : 0))
}

function applyMediaVolume(element: HTMLMediaElement): void {
  const localVolume = mediaLocalVolumes.get(element) ?? element.volume
  const nextVolume = clampVolume(localVolume * outputVolume)
  if (Math.abs(element.volume - nextVolume) < 0.001) return
  element.volume = nextVolume
}

function onMediaVolumeChange(event: Event): void {
  const element = event.currentTarget as HTMLMediaElement
  const currentLocalVolume = mediaLocalVolumes.get(element) ?? element.volume
  const expectedVolume = clampVolume(currentLocalVolume * outputVolume)
  if (Math.abs(element.volume - expectedVolume) < 0.001) return
  mediaLocalVolumes.set(element, clampVolume(element.volume))
  applyMediaVolume(element)
}

function onMediaPlay(event: Event): void {
  if (event.target instanceof HTMLMediaElement) {
    trackPhoneMediaElement(event.target, false)
  }
}

function trackPhoneMediaElement<T extends HTMLMediaElement>(
  element: T,
  persistent: boolean,
): T {
  if (mediaElements.has(element)) {
    if (persistent) mediaElements.set(element, true)
    return element
  }
  mediaElements.set(element, persistent)
  mediaLocalVolumes.set(element, clampVolume(element.volume))
  element.addEventListener('volumechange', onMediaVolumeChange)
  applyMediaVolume(element)
  return element
}

export function getPhoneOutputVolume(): number {
  return outputVolume
}

export function installPhoneAudioController(): () => void {
  documentListenerReferences += 1
  if (documentListenerReferences === 1) {
    document.addEventListener('play', onMediaPlay, true)
    document
      .querySelectorAll<HTMLMediaElement>('audio, video')
      .forEach((element) => trackPhoneMediaElement(element, false))
  }

  return () => {
    documentListenerReferences = Math.max(0, documentListenerReferences - 1)
    if (documentListenerReferences === 0) {
      document.removeEventListener('play', onMediaPlay, true)
    }
  }
}

export function registerPhoneMediaElement<T extends HTMLMediaElement>(
  element: T,
): T {
  return trackPhoneMediaElement(element, true)
}

export function setPhoneOutputVolume(volume: number): void {
  outputVolume = clampVolume(volume)
  for (const [element, persistent] of mediaElements) {
    if (!persistent && !element.isConnected && element.paused) {
      element.removeEventListener('volumechange', onMediaVolumeChange)
      mediaElements.delete(element)
      continue
    }
    applyMediaVolume(element)
  }
  for (const listener of volumeListeners) listener(outputVolume)
}

export function subscribePhoneOutputVolume(
  listener: PhoneAudioVolumeListener,
): () => void {
  volumeListeners.add(listener)
  return () => volumeListeners.delete(listener)
}
