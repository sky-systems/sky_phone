import {
  defaultMapCoordinates,
  defaultMapWorldToPercent,
} from '@/features/map/defaultMapGeometry'
import type { CityWarnArea, CityWarnCategory } from '@/types/citywarn'

export const DEFAULT_CITYWARN_COLORS: Record<CityWarnCategory, string> = {
  public_safety: '#d97706',
  police: '#2563eb',
  fire: '#dc2626',
  medical: '#059669',
  infrastructure: '#7c3aed',
  evacuation: '#0891b2',
}

export function parseCityWarnColors(
  value: unknown,
): Record<CityWarnCategory, string> {
  const colors = { ...DEFAULT_CITYWARN_COLORS }
  if (!value || typeof value !== 'object') return colors
  for (const category of Object.keys(colors) as CityWarnCategory[]) {
    const color = (value as Record<string, unknown>)[category]
    if (typeof color === 'string' && /^#[\da-f]{6}$/i.test(color))
      colors[category] = color
  }
  return colors
}

export function cityWarnColorStyle(color: string): Record<string, string> {
  const channels = [1, 3, 5].map((offset) =>
    parseInt(color.slice(offset, offset + 2), 16),
  )
  const luminance = channels.reduce((sum, channel, index) => {
    const value = channel / 255
    const linear =
      value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4
    return sum + linear * [0.2126, 0.7152, 0.0722][index]!
  }, 0)
  const foreground = luminance > 0.179 ? '#000000' : '#ffffff'
  return {
    '--category': color,
    '--category-foreground': foreground,
    '--category-ink': luminance > 0.179 ? '#111827' : color,
    '--category-soft': `rgb(${channels.map((value) => Math.round(value * 0.12 + 255 * 0.88)).join(', ')})`,
    '--category-area': `rgba(${channels.join(', ')}, 0.26)`,
  }
}

export function cityWarnMapPosition(
  area: CityWarnArea,
): Record<string, string> | null {
  if (
    area.centerX === null ||
    area.centerY === null ||
    !Number.isFinite(area.centerX) ||
    !Number.isFinite(area.centerY)
  )
    return null
  const point = defaultMapWorldToPercent({ x: area.centerX, y: area.centerY })
  return { left: `${point.x * 100}%`, top: `${point.y * 100}%` }
}

export function cityWarnMapArea(
  area: CityWarnArea,
): Record<string, string> | null {
  if (area.type === 'city')
    return { inset: '1%', borderRadius: 'var(--sky-radius-control)' }
  const position = cityWarnMapPosition(area)
  if (!position || area.type !== 'radius' || !area.radius || area.radius <= 0)
    return null
  return {
    ...position,
    width: `${((area.radius * 2) / defaultMapCoordinates.width) * 100}%`,
    height: `${((area.radius * 2) / defaultMapCoordinates.height) * 100}%`,
    transform: 'translate(-50%, -50%)',
  }
}
