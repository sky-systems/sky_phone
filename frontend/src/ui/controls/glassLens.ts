export type GlassLens = {
  displacementMap: string
  height: number
  highlightMap: string
  scale: number
  width: number
}

const lensCache = new Map<string, GlassLens>()

/** Convex rounded glass: a flat centre and a curved, refracting bezel. */
export function buildGlassLensPixels(
  width: number,
  height: number,
  radius: number,
) {
  const bezel = Math.max(1, Math.min(12, radius * 0.6))
  const thickness = Math.min(10, bezel * 0.85)
  const scale = thickness * 3
  const displacement = new Uint8ClampedArray(width * height * 4)
  const highlight = new Uint8ClampedArray(displacement.length)

  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const index = (y * width + x) * 4
      displacement.set([128, 128, 128, 255], index)
      const dx = x + 0.5 - width / 2
      const dy = y + 0.5 - height / 2
      const qx = Math.abs(dx) - (width / 2 - radius)
      const qy = Math.abs(dy) - (height / 2 - radius)
      const ox = Math.max(qx, 0)
      const oy = Math.max(qy, 0)
      const cornerDistance = Math.hypot(ox, oy)
      const distance = radius - cornerDistance - Math.min(Math.max(qx, qy), 0)
      if (distance < 0 || distance >= bezel) continue

      const nx =
        cornerDistance > 0
          ? (ox / cornerDistance) * Math.sign(dx)
          : qx > qy
            ? Math.sign(dx)
            : 0
      const ny =
        cornerDistance > 0
          ? (oy / cornerDistance) * Math.sign(dy)
          : qy >= qx
            ? Math.sign(dy)
            : 0
      const t = Math.max(0.001, distance / bezel)
      const surface = Math.pow(1 - Math.pow(1 - t, 4), 0.25)
      const slope = Math.pow(1 - t, 3) / Math.pow(1 - Math.pow(1 - t, 4), 0.75)
      const incident = Math.atan(slope)
      const refracted = Math.asin(Math.sin(incident) / 1.5)
      const shift =
        Math.tan(incident - refracted) * thickness * (0.35 + 0.65 * surface)
      // feDisplacementMap samples at p + scale * (channel - 0.5).
      displacement[index] = 127.5 - (nx * shift * 255) / scale
      displacement[index + 1] = 127.5 - (ny * shift * 255) / scale

      const facing = nx * -0.6 + ny * -0.8
      const light =
        0.2 +
        0.8 * Math.pow(Math.max(0, facing), 4) +
        0.3 * Math.pow(Math.max(0, -facing), 6)
      const rim = Math.pow(1 - t, 6)
      highlight.set([255, 255, 255, Math.round(255 * light * rim * 0.8)], index)
    }
  }
  return { displacement, highlight, scale }
}

export function createGlassLens(
  width: number,
  height: number,
  radius: number,
): GlassLens | null {
  const key = `${width}:${height}:${radius}`
  const cached = lensCache.get(key)
  if (cached) return cached
  const canvas = document.createElement('canvas')
  canvas.width = width
  canvas.height = height
  const context = canvas.getContext('2d')
  if (!context) {
    console.warn(
      '[Sky UI] Cannot create the glass displacement map: 2D canvas is unavailable.',
    )
    return null
  }
  const pixels = buildGlassLensPixels(width, height, radius)
  const frame = context.createImageData(width, height)
  frame.data.set(pixels.displacement)
  context.putImageData(frame, 0, 0)
  const displacementMap = canvas.toDataURL()
  frame.data.set(pixels.highlight)
  context.putImageData(frame, 0, 0)
  const lens = {
    displacementMap,
    highlightMap: canvas.toDataURL(),
    scale: pixels.scale,
    width,
    height,
  }
  if (lensCache.size >= 32) lensCache.delete(lensCache.keys().next().value!)
  lensCache.set(key, lens)
  return lens
}
