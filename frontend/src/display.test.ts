import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

const jpeg =
  'data:image/jpeg;base64,' +
  btoa(
    String.fromCharCode(
      255,
      216,
      255,
      192,
      0,
      11,
      8,
      3,
      12,
      1,
      104,
      1,
      1,
      17,
      0,
      ...Array(90).fill(0),
    ),
  )
const makeBitmap = (width = 360, height = 780) => ({
  width,
  height,
  close: vi.fn(),
})
type Bitmap = ReturnType<typeof makeBitmap>
let receive: (event: MessageEvent) => Promise<void>
let now = 0
const drawImage = vi.fn()
const clearRect = vi.fn()
const decode = vi.fn<(blob: Blob) => Promise<Bitmap>>()
const message = (sequence: number, value: unknown = jpeg) =>
  receive({ data: { type: 'frame', sequence, jpeg: value } } as MessageEvent)

describe('spectator JPEG rendering boundary', () => {
  beforeEach(async () => {
    vi.resetModules()
    vi.clearAllMocks()
    vi.useFakeTimers()
    now = 0
    vi.stubGlobal('performance', { now: () => now })
    vi.stubGlobal('document', {
      querySelector: () => ({
        width: 0,
        height: 0,
        getContext: () => ({ drawImage, clearRect }),
        set src(_value: string) {
          throw new Error('Received frames must never become DOM URLs')
        },
      }),
    })
    vi.stubGlobal('window', {
      addEventListener: (_name: string, listener: typeof receive) => {
        receive = listener
      },
    })
    vi.stubGlobal('createImageBitmap', decode)
    vi.spyOn(console, 'warn').mockImplementation(() => undefined)
    decode.mockResolvedValue(makeBitmap())
    await import('./display')
  })
  afterEach(() => {
    vi.useRealTimers()
    vi.unstubAllGlobals()
    vi.restoreAllMocks()
  })

  it('decodes only JPEG bytes and releases the bitmap after painting', async () => {
    const bitmap = makeBitmap()
    decode.mockResolvedValue(bitmap)
    await message(1)
    const blob = decode.mock.calls[0]![0]
    expect(blob.type).toBe('image/jpeg')
    expect([...new Uint8Array(await blob.arrayBuffer())].slice(0, 4)).toEqual([
      255, 216, 255, 192,
    ])
    expect(drawImage).toHaveBeenCalledWith(bitmap, 0, 0)
    expect(bitmap.close).toHaveBeenCalledOnce()
    await vi.advanceTimersByTimeAsync(3000)
    expect(clearRect).toHaveBeenCalledWith(0, 0, 360, 780)
  })

  it('rejects executable schemes, external URLs, SVG, HTML and oversized frames before decoding', async () => {
    for (const value of [
      'javascript:alert(1)',
      'https://example.com/frame.jpg',
      '//example.com/frame.jpg',
      'data:text/html,<script>alert(1)</script>',
      'data:image/svg+xml;base64,' +
        btoa('<svg xmlns="http://www.w3.org/2000/svg" onload="alert(1)"/>'),
      'data:image/jpeg;base64,' +
        btoa('<html><script>alert(1)</script></html>'),
      jpeg + 'A'.repeat(64000),
      null,
      {},
    ])
      await message(1, value)
    expect(decode).not.toHaveBeenCalled()
    expect(drawImage).not.toHaveBeenCalled()
    expect(vi.getTimerCount()).toBe(0)
  })

  it('rejects invalid or repeated sequence numbers', async () => {
    for (const sequence of [
      0,
      -1,
      1.5,
      NaN,
      Infinity,
      Number.MAX_SAFE_INTEGER + 1,
    ])
      await message(sequence)
    expect(decode).not.toHaveBeenCalled()
    await message(2)
    await message(2)
    await message(1)
    expect(decode).toHaveBeenCalledOnce()
  })

  it('discards older frames that finish decoding after a newer frame', async () => {
    const old = makeBitmap(),
      fresh = makeBitmap()
    let finish!: (value: Bitmap) => void
    decode.mockImplementationOnce(
      () =>
        new Promise((resolve) => {
          finish = resolve
        }),
    )
    const pending = message(1)
    decode.mockResolvedValueOnce(fresh)
    await message(2)
    finish(old)
    await pending
    expect(drawImage).toHaveBeenCalledExactlyOnceWith(fresh, 0, 0)
    expect(old.close).toHaveBeenCalledOnce()
    expect(fresh.close).toHaveBeenCalledOnce()
  })

  it('does not redraw a stale screen when a slow decoder finishes after expiry', async () => {
    let finish!: (value: Bitmap) => void
    const bitmap = makeBitmap()
    decode.mockImplementationOnce(
      () =>
        new Promise((resolve) => {
          finish = resolve
        }),
    )
    const pending = message(1)
    now = 3001
    finish(bitmap)
    await pending
    expect(drawImage).not.toHaveBeenCalled()
    expect(bitmap.close).toHaveBeenCalledOnce()
    expect(vi.getTimerCount()).toBe(0)
  })

  it('checks decoded dimensions and releases rejected bitmaps', async () => {
    const bitmap = makeBitmap(720, 1560)
    decode.mockResolvedValue(bitmap)
    await message(1)
    expect(drawImage).not.toHaveBeenCalled()
    expect(bitmap.close).toHaveBeenCalledOnce()
    expect(vi.getTimerCount()).toBe(0)
  })

  it('handles corrupt JPEGs without prolonging the last valid screen and recovers', async () => {
    await message(1)
    await vi.advanceTimersByTimeAsync(2000)
    now = 2000
    decode.mockRejectedValueOnce(new Error('Invalid JPEG'))
    await expect(message(2)).resolves.toBeUndefined()
    await vi.advanceTimersByTimeAsync(1000)
    expect(clearRect).toHaveBeenCalledOnce()
    expect(console.warn).toHaveBeenCalledOnce()
    decode.mockResolvedValue(makeBitmap())
    now = 3000
    await message(3)
    expect(drawImage).toHaveBeenCalledTimes(2)
  })
})
