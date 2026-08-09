import type { MapPoint } from '@/features/map/defaultMapGeometry'

export type MapMarkerColor = 'blue' | 'green' | 'orange' | 'purple' | 'red'

export type MapMarker = {
  color: MapMarkerColor
  coords: MapPoint & { z: number }
  id: string
  label: string
}

export type CreateMapMarker = Omit<MapMarker, 'id'>
