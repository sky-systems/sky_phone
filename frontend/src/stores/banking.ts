import { defineStore } from 'pinia'

import type { BankingAction, BankingOverview } from '@/types/banking'
import { nuiCall, type NuiResponse } from '@/utils/nui'

export const useBankingStore = defineStore('banking', {
  state: () => ({
    error: '',
    isLoading: false,
    overview: null as BankingOverview | null,
  }),
  actions: {
    async load(): Promise<boolean> {
      this.isLoading = true
      const response = await nuiCall<BankingOverview>('banking:overview')
      this.isLoading = false
      if (response.success && response.data) {
        this.overview = response.data
        this.error = ''
        return true
      }
      this.error = response.error ?? 'request_failed'
      return false
    },
    async perform(
      action: BankingAction,
      amount: number,
      target?: number,
    ): Promise<NuiResponse<BankingOverview>> {
      this.isLoading = true
      const response = await nuiCall<BankingOverview>(`banking:${action}`, {
        amount,
        ...(target === undefined ? {} : { target }),
      })
      this.isLoading = false
      if (response.success && response.data) {
        this.overview = response.data
        this.error = ''
      } else {
        this.error = response.error ?? 'request_failed'
      }
      return response
    },
  },
})
