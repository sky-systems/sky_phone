import { defineStore } from 'pinia'

import type { GarageOverview, GarageValetState } from '@/types/garage'
import { nuiCall } from '@/utils/nui'

export const useGarageStore = defineStore('garage', {
  state: () => ({
    error: '',
    isLoading: false,
    isValetRequesting: false,
    overview: null as GarageOverview | null,
    valet: null as GarageValetState | null,
    valetError: '',
  }),
  actions: {
    async load(): Promise<boolean> {
      this.isLoading = true
      const response = await nuiCall<GarageOverview>('garage:vehicles')
      this.isLoading = false
      if (response.success && response.data) {
        this.overview = response.data
        this.error = ''
        return true
      }
      this.error = response.error ?? 'request_failed'
      return false
    },
    async syncValet(): Promise<void> {
      const response = await nuiCall<GarageValetState | null>(
        'garage:valet-state',
      )
      if (response.success) this.valet = response.data ?? null
    },
    async requestValet(plate: string): Promise<boolean> {
      this.isValetRequesting = true
      this.valetError = ''
      const response = await nuiCall<GarageValetState>('garage:valet-request', {
        plate,
      })
      this.isValetRequesting = false
      if (response.success && response.data) {
        this.valet = response.data
        return true
      }
      this.valetError = response.error ?? 'request_failed'
      return false
    },
    async cancelValet(): Promise<boolean> {
      this.isValetRequesting = true
      this.valetError = ''
      const response = await nuiCall<GarageValetState | null>(
        'garage:valet-cancel',
      )
      this.isValetRequesting = false
      if (response.success) {
        this.valet = response.data ?? null
        void this.load()
        return true
      }
      this.valetError = response.error ?? 'request_failed'
      return false
    },
    setValetState(state: GarageValetState | null): void {
      this.valet = state
      if (state?.status === 'delivered') void this.load()
    },
  },
})
