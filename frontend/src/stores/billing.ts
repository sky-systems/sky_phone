import { defineStore } from 'pinia'

import type {
  BillingDirection,
  BillingFilter,
  BillingListResult,
  BillingOverview,
  InvoiceDetail,
  InvoiceSummary,
} from '@/types/billing'
import { nuiCall, type NuiResponse } from '@/utils/nui'

export const useBillingStore = defineStore('billing', {
  state: () => ({
    detail: null as InvoiceDetail | null,
    error: '',
    hasMore: false,
    invoices: [] as InvoiceSummary[],
    isLoading: false,
    isLoadingMore: false,
    isPaying: false,
    nextOffset: 0,
    overview: null as BillingOverview | null,
  }),
  actions: {
    async loadOverview(
      direction: BillingDirection = 'inbox',
    ): Promise<boolean> {
      this.isLoading = true
      const response = await nuiCall<BillingOverview>('billing:overview', {
        direction,
      })
      this.isLoading = false
      if (response.success && response.data) {
        this.overview = response.data
        this.error = ''
        return true
      }
      this.error = response.error ?? 'request_failed'
      return false
    },
    async loadInvoices(
      direction: BillingDirection,
      filter: BillingFilter,
      search = '',
      append = false,
    ): Promise<boolean> {
      if (append && (!this.hasMore || this.isLoadingMore)) return false
      if (append) this.isLoadingMore = true
      else this.isLoading = true
      const response = await nuiCall<BillingListResult>('billing:list', {
        direction,
        filter,
        offset: append ? this.nextOffset : 0,
        search,
      })
      this.isLoading = false
      this.isLoadingMore = false
      if (response.success && response.data) {
        this.invoices = append
          ? [...this.invoices, ...response.data.invoices]
          : response.data.invoices
        this.hasMore = response.data.hasMore
        this.nextOffset = response.data.nextOffset
        this.error = ''
        return true
      }
      this.error = response.error ?? 'request_failed'
      return false
    },
    async loadDetail(id: string): Promise<boolean> {
      this.isLoading = true
      const response = await nuiCall<InvoiceDetail>('billing:detail', { id })
      this.isLoading = false
      if (response.success && response.data) {
        this.detail = response.data
        this.error = ''
        if (response.data.isUnread) {
          await this.markRead(id)
          this.detail.isUnread = false
        }
        return true
      }
      this.error = response.error ?? 'request_failed'
      return false
    },
    async markRead(id: string): Promise<void> {
      const response = await nuiCall<{ unreadCount: number }>(
        'billing:markRead',
        {
          id,
        },
      )
      if (response.success && response.data && this.overview) {
        this.overview.unreadCount = response.data.unreadCount
      }
    },
    async pay(invoice: InvoiceDetail): Promise<NuiResponse<InvoiceDetail>> {
      this.isPaying = true
      const response = await nuiCall<InvoiceDetail>('billing:pay', {
        id: invoice.id,
        amount: invoice.amount,
        amountPaid: invoice.amountPaid ?? 0,
      })
      this.isPaying = false
      if (response.success && response.data) {
        this.detail = response.data
        await this.loadOverview()
      } else {
        this.error = response.error ?? 'payment_failed'
      }
      return response
    },
    async dispute(id: string): Promise<NuiResponse<InvoiceDetail>> {
      const response = await nuiCall<InvoiceDetail>('billing:dispute', { id })
      if (response.success && response.data) {
        this.detail = response.data
        await this.loadOverview()
      } else {
        this.error = response.error ?? 'dispute_unavailable'
      }
      return response
    },
    reset(): void {
      this.detail = null
      this.error = ''
      this.hasMore = false
      this.invoices = []
      this.nextOffset = 0
      this.overview = null
    },
  },
})
