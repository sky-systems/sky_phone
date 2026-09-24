export const MAX_DISPLAY_FRAME_BYTES = 64_000
export const DISPLAY_WIDTH = 360
export const DISPLAY_HEIGHT = 780

/** Reject other formats and oversized JPEG headers before the browser decodes pixels. */
export function validDisplayFrame(value: unknown): value is string {
  if (
    typeof value !== 'string' ||
    value.length < 100 ||
    value.length > MAX_DISPLAY_FRAME_BYTES ||
    !/^data:image\/jpeg;base64,\/9j\/[A-Za-z0-9+/=]+$/.test(value)
  )
    return false
  try {
    const header = atob(value.slice(23, 23 + 4096))
    let offset = 2
    while (offset + 8 < header.length && header.charCodeAt(offset) === 255) {
      const marker = header.charCodeAt(offset + 1)
      const length =
        header.charCodeAt(offset + 2) * 256 + header.charCodeAt(offset + 3)
      if (marker === 192 || marker === 194) {
        const height =
          header.charCodeAt(offset + 5) * 256 + header.charCodeAt(offset + 6)
        const width =
          header.charCodeAt(offset + 7) * 256 + header.charCodeAt(offset + 8)
        return width === DISPLAY_WIDTH && height === DISPLAY_HEIGHT
      }
      if (length < 2) return false
      offset += 2 + length
    }
  } catch {
    return false
  }
  return false
}
