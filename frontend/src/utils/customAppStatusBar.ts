import { colorLuminance } from '@/utils/colorContrast'

const darkForegroundLuminance = colorLuminance([17, 17, 17])

export function customAppStatusBarLight(background: unknown): boolean | null {
  if (typeof background !== 'string') return null
  const hex = /^#([\da-f]{3}|[\da-f]{6})$/i.exec(background)
  const rgb =
    /^rgb(?:a)?\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*(?:,\s*1(?:\.0*)?\s*)?\)$/.exec(
      background,
    )
  let channels: number[]
  if (hex) {
    const value =
      hex[1]!.length === 3
        ? Array.from(hex[1]!, (digit) => digit.repeat(2)).join('')
        : hex[1]!
    channels = [0, 2, 4].map((offset) =>
      parseInt(value.slice(offset, offset + 2), 16),
    )
  } else if (rgb) {
    channels = rgb.slice(1, 4).map(Number)
    if (
      channels.some(
        (channel) => !Number.isFinite(channel) || channel < 0 || channel > 255,
      )
    )
      return null
  } else {
    return null
  }
  const luminance = colorLuminance(channels)
  const whiteContrast = 1.05 / (luminance + 0.05)
  const darkContrast = (luminance + 0.05) / (darkForegroundLuminance + 0.05)
  return whiteContrast >= darkContrast
}
