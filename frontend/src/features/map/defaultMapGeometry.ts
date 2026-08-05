export type MapPoint = { x: number; y: number }

export const defaultMainlandCoordinates = {
  minX: -4015.07959,
  minY: -4146.092,
  width: 8837.37159,
  height: 12432.11,
  yFlipOffset: 4139.926,
}

const cayoMapCoordinates = {
  centerX: 4704.5,
  centerY: -5139.09,
  width: 1990.65,
  height: 1994.4,
}

const cayoTerritoryBounds = {
  maxX: 7542.07,
  minY: -7170.07,
}

export const defaultMapCoordinates = {
  minX: defaultMainlandCoordinates.minX,
  minY: defaultMainlandCoordinates.minY,
  width: cayoTerritoryBounds.maxX - defaultMainlandCoordinates.minX,
  height:
    defaultMainlandCoordinates.yFlipOffset -
    cayoTerritoryBounds.minY -
    defaultMainlandCoordinates.minY,
  yFlipOffset: defaultMainlandCoordinates.yFlipOffset,
}

const toDefaultMapLayerStyle = (bounds: {
  minX: number
  minY: number
  width: number
  height: number
}) => ({
  left: `${((bounds.minX - defaultMapCoordinates.minX) / defaultMapCoordinates.width) * 100}%`,
  top: `${((bounds.minY - defaultMapCoordinates.minY) / defaultMapCoordinates.height) * 100}%`,
  width: `${(bounds.width / defaultMapCoordinates.width) * 100}%`,
  height: `${(bounds.height / defaultMapCoordinates.height) * 100}%`,
})

export const defaultMainlandStyle = toDefaultMapLayerStyle(
  defaultMainlandCoordinates,
)
export const defaultCayoStyle = toDefaultMapLayerStyle({
  minX: cayoMapCoordinates.centerX - cayoMapCoordinates.width / 2,
  minY:
    defaultMapCoordinates.yFlipOffset -
    (cayoMapCoordinates.centerY + cayoMapCoordinates.height / 2),
  width: cayoMapCoordinates.width,
  height: cayoMapCoordinates.height,
})

export const clampDefaultMapPoint = (point: MapPoint): MapPoint => ({
  x: Math.max(
    defaultMapCoordinates.minX,
    Math.min(defaultMapCoordinates.minX + defaultMapCoordinates.width, point.x),
  ),
  y: Math.max(
    defaultMapCoordinates.yFlipOffset -
      defaultMapCoordinates.minY -
      defaultMapCoordinates.height,
    Math.min(
      defaultMapCoordinates.yFlipOffset - defaultMapCoordinates.minY,
      point.y,
    ),
  ),
})

export const defaultMapWorldToPercent = (point: MapPoint): MapPoint => ({
  x: (point.x - defaultMapCoordinates.minX) / defaultMapCoordinates.width,
  y:
    (defaultMapCoordinates.yFlipOffset - point.y - defaultMapCoordinates.minY) /
    defaultMapCoordinates.height,
})
