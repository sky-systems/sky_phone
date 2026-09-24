import { toSvg } from 'html-to-image'
import { DISPLAY_WIDTH, DISPLAY_HEIGHT } from './displayFrame'

/** Preserve scroll offsets and live video without changing the visible phone layout. */
export async function captureDisplay(
  screen: HTMLElement,
): Promise<HTMLCanvasElement> {
  const scrolls: Array<{
    node: HTMLElement
    previous: string | null
    x: number
    y: number
  }> = []
  const videoParents: Array<{ node: HTMLElement; previous: string | null }> = []
  const videos: Array<{
    parent: number
    index: number
    jpeg: string
    style: string
  }> = []
  const capturedVideos = new Set<HTMLVideoElement>()
  let svgUrl: string
  try {
    for (const node of [screen, ...screen.querySelectorAll<HTMLElement>('*')]) {
      if (!node.scrollLeft && !node.scrollTop) continue
      const id = String(scrolls.length)
      scrolls.push({
        node,
        previous: node.getAttribute('data-sky-display-scroll'),
        x: node.scrollLeft,
        y: node.scrollTop,
      })
      node.setAttribute('data-sky-display-scroll', id)
    }
    for (const video of screen.querySelectorAll('video')) {
      if (video.readyState < 2 || !video.videoWidth || !video.parentElement)
        continue
      const parent = video.parentElement
      let parentIndex = videoParents.findIndex((entry) => entry.node === parent)
      if (parentIndex === -1) {
        parentIndex = videoParents.length
        videoParents.push({
          node: parent,
          previous: parent.getAttribute('data-sky-display-videos'),
        })
        parent.setAttribute('data-sky-display-videos', String(parentIndex))
      }
      const canvas = document.createElement('canvas')
      const scale = Math.min(
        1,
        DISPLAY_HEIGHT / Math.max(video.videoWidth, video.videoHeight),
      )
      canvas.width = Math.max(1, Math.round(video.videoWidth * scale))
      canvas.height = Math.max(1, Math.round(video.videoHeight * scale))
      canvas
        .getContext('2d')!
        .drawImage(video, 0, 0, canvas.width, canvas.height)
      const style = getComputedStyle(video)
      videos.push({
        parent: parentIndex,
        index: [...parent.children].indexOf(video),
        jpeg: canvas.toDataURL('image/jpeg', 0.7),
        style: [...style]
          .map((property) => `${property}:${style.getPropertyValue(property)};`)
          .join(''),
      })
      capturedVideos.add(video)
    }
    svgUrl = await toSvg(screen, {
      backgroundColor: '#08080a',
      preferredFontFormat: 'woff2',
      imagePlaceholder:
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      filter: (node) => {
        if (node instanceof HTMLIFrameElement) return false
        if (node instanceof HTMLVideoElement)
          return !capturedVideos.has(node) && Boolean(node.poster)
        return true
      },
      style: {
        transform: 'none',
        margin: '0',
        borderRadius: '0',
        clipPath: 'none',
      },
    })
  } finally {
    for (const { node, previous } of scrolls) {
      if (previous === null) node.removeAttribute('data-sky-display-scroll')
      else node.setAttribute('data-sky-display-scroll', previous)
    }
    for (const { node, previous } of videoParents) {
      if (previous === null) node.removeAttribute('data-sky-display-videos')
      else node.setAttribute('data-sky-display-videos', previous)
    }
  }
  if (scrolls.length || videos.length) {
    const doc = new DOMParser().parseFromString(
      decodeURIComponent(svgUrl.split(',').slice(1).join(',')),
      'image/svg+xml',
    )
    // Insert fresh pixels after embedding other resources. Sending video snapshots through
    // html-to-image's URL cache would retain a new large data URL for every video frame.
    for (const video of videos) {
      const parent = doc.querySelector(
        `[data-sky-display-videos="${video.parent}"]`,
      )
      if (!parent) continue
      const img = doc.createElementNS('http://www.w3.org/1999/xhtml', 'img')
      img.setAttribute('src', video.jpeg)
      img.setAttribute('style', video.style)
      parent.insertBefore(img, parent.children[video.index] ?? null)
    }
    for (const node of doc.querySelectorAll('[data-sky-display-videos]'))
      node.removeAttribute('data-sky-display-videos')
    for (const node of doc.querySelectorAll<HTMLElement>(
      '[data-sky-display-scroll]',
    )) {
      const position =
        scrolls[Number(node.getAttribute('data-sky-display-scroll'))]
      if (!position) continue
      // Transforms retain flex/grid layout and the original parent's clipping.
      for (const child of node.children) {
        if (!('style' in child)) continue
        const style = (child as HTMLElement).style
        if (style.position === 'fixed' || style.position === 'sticky') continue
        const existing = style.transform === 'none' ? '' : style.transform
        style.transform = `translate(${-position.x}px, ${-position.y}px) ${existing}`
      }
      node.removeAttribute('data-sky-display-scroll')
    }
    svgUrl =
      'data:image/svg+xml;charset=utf-8,' +
      encodeURIComponent(new XMLSerializer().serializeToString(doc))
  }
  const image = new Image()
  image.src = svgUrl
  await image.decode()
  const canvas = document.createElement('canvas')
  canvas.width = DISPLAY_WIDTH
  canvas.height = DISPLAY_HEIGHT
  canvas.getContext('2d')!.drawImage(image, 0, 0, DISPLAY_WIDTH, DISPLAY_HEIGHT)
  return canvas
}
