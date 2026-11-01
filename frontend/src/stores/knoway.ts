import { defineStore } from 'pinia'

import type {
  KnowayCoordinates,
  KnowayLocation,
  KnowayQuote,
  KnowayRide,
  KnowayState,
  KnowayStateUpdate,
} from '@/types/knoway'
import { isKnowayRideTerminal } from '@/types/knoway'
import { nuiCall, type NuiResponse } from '@/utils/nui'

export const useKnowayStore = defineStore('knoway', {
  state: () => ({
    activeRide: null as KnowayRide | null,
    available: false,
    currency: '$',
    error: '',
    hasLoaded: false,
    isLoading: false,
    isActionPending: false,
    quote: null as KnowayQuote | null,
    refundPolicy: { beforeStart: true, afterStart: false, technical: true },
    snapshotVersion: 0,
  }),
  getters: {
    hasActiveRide: (state): boolean =>
      !!state.activeRide && !isKnowayRideTerminal(state.activeRide.status),
  },
  actions: {
    applyUpdate(update: KnowayStateUpdate): void {
      this.snapshotVersion += 1
      if (update.activeRide !== undefined) this.activeRide = update.activeRide
      if (update.available !== undefined) this.available = update.available
      if (update.currency !== undefined) this.currency = update.currency
      if (update.refundPolicy !== undefined)
        this.refundPolicy = update.refundPolicy
      if (this.activeRide) this.quote = null
    },
    async refreshState(): Promise<void> {
      if (this.isActionPending || this.isLoading) return
      const version = this.snapshotVersion
      const response = await nuiCall<KnowayState>('knoway:bootstrap')
      if (version !== this.snapshotVersion || this.isActionPending) return
      if (response.success && response.data) this.applyUpdate(response.data)
    },
    async bootstrap(): Promise<boolean> {
      this.isLoading = true
      try {
        const response = await nuiCall<KnowayState>('knoway:bootstrap')
        if (!response.success || !response.data) {
          this.error = response.error ?? 'request_failed'
          return false
        }
        this.applyUpdate(response.data)
        this.quote = null
        this.hasLoaded = true
        this.error = ''
        return true
      } finally {
        this.isLoading = false
      }
    },
    async createQuote(destination: KnowayLocation): Promise<boolean> {
      if (this.isActionPending || this.hasActiveRide) return false
      this.isActionPending = true
      this.quote = null
      try {
        const response = await nuiCall<KnowayQuote>('knoway:quote', {
          destination,
        })
        if (!response.success || !response.data) {
          this.error = response.error ?? 'request_failed'
          return false
        }
        if (this.hasActiveRide) return false
        this.activeRide = null
        this.quote = response.data
        this.error = ''
        return true
      } finally {
        this.isActionPending = false
      }
    },
    async requestRide(): Promise<boolean> {
      if (this.isActionPending || this.hasActiveRide || !this.quote)
        return false
      if (this.quote.expiresAt <= Date.now() / 1000) {
        this.quote = null
        this.error = 'quote_expired'
        return false
      }
      return this.performAction('request', { quoteId: this.quote.id })
    },
    async performAction(
      action: 'request' | 'start' | 'cancel',
      payload?: Record<string, unknown>,
    ): Promise<boolean> {
      if (this.isActionPending) return false
      if (action !== 'request' && !this.activeRide) return false
      this.isActionPending = true
      this.snapshotVersion += 1
      try {
        const response = await nuiCall<KnowayStateUpdate>(
          `knoway:${action}`,
          payload ?? { rideId: this.activeRide!.id },
        )
        if (response.data) this.applyUpdate(response.data)
        if (!response.success) {
          this.error = response.error ?? 'request_failed'
          if (response.error === 'quote_expired') this.quote = null
          return false
        }
        if (action === 'request') this.quote = null
        this.error = ''
        return true
      } finally {
        this.isActionPending = false
      }
    },
    clearQuote(): void {
      this.quote = null
      this.error = ''
    },
    dismissRide(): void {
      if (this.hasActiveRide) return
      this.activeRide = null
      this.quote = null
      this.error = ''
    },
    async getLocation(
      source: 'player' | 'waypoint',
    ): Promise<NuiResponse<{ coords: KnowayCoordinates }>> {
      const response = await nuiCall<{ coords: KnowayCoordinates }>(
        source === 'player'
          ? 'knoway:get-player-coords'
          : 'knoway:get-waypoint',
      )
      this.error = response.success ? '' : (response.error ?? 'request_failed')
      return response
    },
  },
})
