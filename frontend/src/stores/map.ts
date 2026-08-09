import { defineStore } from 'pinia'

import type { CreateMapMarker, MapMarker } from '@/types/map'
import { nuiCall, type NuiResponse } from '@/utils/nui'

export const useMapStore = defineStore('map', {
  state: () => ({
    error: '',
    isLoading: false,
    markers: [] as MapMarker[],
  }),
  actions: {
    async load(): Promise<boolean> {
      this.isLoading = true
      const response = await nuiCall<MapMarker[]>('map:markers')
      this.isLoading = false
      if (response.success && response.data) {
        this.markers = response.data
        this.error = ''
        return true
      }
      this.error = response.error ?? 'request_failed'
      return false
    },
    async create(marker: CreateMapMarker): Promise<NuiResponse<MapMarker>> {
      this.isLoading = true
      const response = await nuiCall<MapMarker>('map:create-marker', marker)
      this.isLoading = false
      if (response.success && response.data) {
        this.markers.push(response.data)
        this.error = ''
      } else {
        this.error = response.error ?? 'request_failed'
      }
      return response
    },
    async remove(id: string): Promise<NuiResponse> {
      this.isLoading = true
      const response = await nuiCall('map:delete-marker', { id })
      this.isLoading = false
      if (response.success) {
        this.markers = this.markers.filter((marker) => marker.id !== id)
        this.error = ''
      } else {
        this.error = response.error ?? 'request_failed'
      }
      return response
    },
  },
})
