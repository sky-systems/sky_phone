import { defineStore } from 'pinia'

import type { BankingAction, BankingOverview } from '@/types/banking'
import { nuiCall, type NuiResponse } from '@/utils/nui'
import {
  allowManualReload,
  isReloadCooldownActive,
  RELOAD_COOLDOWN_ERROR,
} from '@/utils/reload-cooldown'

let activeOverviewLoad: Promise<boolean> | null = null
let queuedOverviewLoad: Promise<boolean> | null = null

export const useBankingStore = defineStore('banking', {
  state: () => ({
    error: '',
    cooldownUntil: 0,
    isLoading: false,
    overview: null as BankingOverview | null,
    pendingRequests: 0,
    requestGeneration: 0,
    reloadAttempts: [] as number[],
  }),
  actions: {
    async load(manualReload = false, ensureFresh = false): Promise<boolean> {
      if (activeOverviewLoad) {
        if (!ensureFresh) return activeOverviewLoad
        if (!queuedOverviewLoad) {
          const activeRequest = activeOverviewLoad
          const queuedRequest = activeRequest.then(
            () => this.load(),
            () => this.load(),
          )
          const trackedQueuedRequest = queuedRequest.finally(() => {
            queuedOverviewLoad = null
          })
          queuedOverviewLoad = trackedQueuedRequest
        }
        return queuedOverviewLoad
      }
      if (
        manualReload &&
        (isReloadCooldownActive(this) || !allowManualReload(this))
      ) {
        this.error = RELOAD_COOLDOWN_ERROR
        return false
      }
      const request = (async () => {
        const generation = ++this.requestGeneration
        this.pendingRequests += 1
        this.isLoading = true
        const response = await nuiCall<BankingOverview>(
          'banking:overview',
        ).finally(() => {
          this.pendingRequests = Math.max(0, this.pendingRequests - 1)
          this.isLoading = this.pendingRequests > 0
        })
        if (generation !== this.requestGeneration) return response.success
        if (response.success && response.data) {
          this.overview = response.data
          this.error = ''
          return true
        }
        this.error = response.error ?? 'request_failed'
        return false
      })()
      const trackedRequest = request.finally(() => {
        activeOverviewLoad = null
      })
      activeOverviewLoad = trackedRequest
      return trackedRequest
    },
    async perform(
      action: BankingAction,
      amount: number,
      phoneNumber?: string,
    ): Promise<NuiResponse<BankingOverview>> {
      const generation = ++this.requestGeneration
      this.pendingRequests += 1
      this.isLoading = true
      const response = await nuiCall<BankingOverview>(`banking:${action}`, {
        amount,
        ...(phoneNumber === undefined ? {} : { phoneNumber }),
      }).finally(() => {
        this.pendingRequests = Math.max(0, this.pendingRequests - 1)
        this.isLoading = this.pendingRequests > 0
      })
      if (generation !== this.requestGeneration) return response
      if (response.success) {
        if (response.data) this.overview = response.data
        this.error = ''
      } else {
        this.error = response.error ?? 'request_failed'
      }
      return response
    },
  },
})
