export type PhoneViewportRect = {
  bottom: number
  height: number
  left: number
  right: number
  top: number
  width: number
}

export function phoneViewportRectContainsPoint(
  rect: PhoneViewportRect,
  x: number,
  y: number,
): boolean {
  return x >= rect.left && x <= rect.right && y >= rect.top && y <= rect.bottom
}

type RectMeasurement = Pick<
  DOMRectReadOnly,
  'height' | 'left' | 'top' | 'width'
>

export type PhoneViewportGeometry = {
  readonly scaleX: number
  readonly scaleY: number
  rect(element: Element): PhoneViewportRect
}

function positiveRatio(numerator: number, denominator: number): number {
  return Number.isFinite(numerator) &&
    Number.isFinite(denominator) &&
    numerator > 0 &&
    denominator > 0
    ? numerator / denominator
    : 1
}

export function normalizePhoneViewportRect(
  rawRect: RectMeasurement,
  rawCanvasRect: RectMeasurement,
  wrapperRect: RectMeasurement,
): PhoneViewportRect {
  const factorX = positiveRatio(wrapperRect.width, rawCanvasRect.width)
  const factorY = positiveRatio(wrapperRect.height, rawCanvasRect.height)
  const left = wrapperRect.left + (rawRect.left - rawCanvasRect.left) * factorX
  const top = wrapperRect.top + (rawRect.top - rawCanvasRect.top) * factorY
  const width = rawRect.width * factorX
  const height = rawRect.height * factorY

  return {
    bottom: top + height,
    height,
    left,
    right: left + width,
    top,
    width,
  }
}

export function readPhoneViewportGeometry(
  anchor: Element | null,
): PhoneViewportGeometry | null {
  const canvas = anchor?.closest<HTMLElement>('.phone-resolution-canvas')
  const wrapper = canvas?.closest<HTMLElement>('.phone-resolution-wrapper')
  if (!canvas || !wrapper) return null

  const rawCanvasRect = canvas.getBoundingClientRect()
  const wrapperRect = wrapper.getBoundingClientRect()

  return {
    scaleX: positiveRatio(wrapperRect.width, canvas.offsetWidth),
    scaleY: positiveRatio(wrapperRect.height, canvas.offsetHeight),
    rect(element: Element): PhoneViewportRect {
      return normalizePhoneViewportRect(
        element.getBoundingClientRect(),
        rawCanvasRect,
        wrapperRect,
      )
    },
  }
}
