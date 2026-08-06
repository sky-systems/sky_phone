import { defineStore } from 'pinia'

import type {
  MarketplaceChat,
  MarketplaceCounts,
  MarketplaceInquirySummary,
  MarketplaceListing,
  MarketplaceListingDraft,
  MarketplaceListingSummary,
} from '@/types/marketplace'
import { nuiCall, type NuiResponse } from '@/utils/nui'

type ListingPage = {
  hasMore: boolean
  items: MarketplaceListingSummary[]
  offset: number
}

export const useMarketplaceStore = defineStore('marketplace', {
  state: () => ({
    counts: { active: 0, unread: 0 } as MarketplaceCounts,
    inquiries: [] as MarketplaceInquirySummary[],
    isLoading: false,
    items: [] as MarketplaceListingSummary[],
    ownItems: [] as MarketplaceListingSummary[],
  }),
  actions: {
    async load(filters: Record<string, unknown> = {}): Promise<boolean> {
      this.isLoading = true
      const response = await nuiCall<ListingPage>('marketplace:list', filters)
      this.isLoading = false
      if (response.success && response.data) this.items = response.data.items
      return response.success
    },
    async get(id: string): Promise<NuiResponse<MarketplaceListing>> {
      return nuiCall<MarketplaceListing>('marketplace:get', { id })
    },
    async loadOwn(): Promise<boolean> {
      const response = await nuiCall<ListingPage>('marketplace:list-own')
      if (response.success && response.data) this.ownItems = response.data.items
      return response.success
    },
    async loadCounts(): Promise<void> {
      const response = await nuiCall<MarketplaceCounts>('marketplace:counts')
      if (response.success && response.data) this.counts = response.data
    },
    setCounts(counts: MarketplaceCounts): void {
      this.counts = counts
    },
    async create(draft: MarketplaceListingDraft): Promise<NuiResponse<{ id: string }>> {
      const response = await nuiCall<{ id: string }>('marketplace:create', draft)
      if (response.success) await Promise.all([this.load(), this.loadOwn(), this.loadCounts()])
      return response
    },
    async update(
      id: string,
      revision: number,
      draft: MarketplaceListingDraft,
    ): Promise<NuiResponse<{ revision: number }>> {
      const response = await nuiCall<{ revision: number }>('marketplace:update', {
        ...draft,
        id,
        revision,
      })
      if (response.success) await Promise.all([this.load(), this.loadOwn()])
      return response
    },
    async setStatus(id: string, status: string, inquiryId?: string): Promise<boolean> {
      const response = await nuiCall('marketplace:set-status', {
        id,
        inquiryId,
        status,
      })
      if (response.success) await Promise.all([this.load(), this.loadOwn(), this.loadCounts()])
      return response.success
    },
    async favorite(id: string, favorite: boolean): Promise<boolean> {
      const response = await nuiCall('marketplace:favorite', { favorite, id })
      if (response.success) {
        for (const item of [...this.items, ...this.ownItems]) {
          if (item.id === id) item.is_favorite = favorite
        }
      }
      return response.success
    },
    async loadInquiries(): Promise<boolean> {
      const response = await nuiCall<MarketplaceInquirySummary[]>('marketplace:list-inquiries')
      if (response.success && response.data) this.inquiries = response.data
      return response.success
    },
    async getInquiry(id: string): Promise<NuiResponse<MarketplaceChat>> {
      return nuiCall<MarketplaceChat>('marketplace:get-inquiry', { id })
    },
    async sendMessage(payload: {
      body: string
      inquiryId?: string
      listingId?: string
    }): Promise<NuiResponse<{ id: string }>> {
      const response = await nuiCall<{ id: string }>('marketplace:send-message', payload)
      if (response.success) await Promise.all([this.loadInquiries(), this.loadCounts()])
      return response
    },
    async makeOffer(
      inquiryId: string,
      amount: number,
    ): Promise<NuiResponse<{ id: number }>> {
      const response = await nuiCall<{ id: number }>('marketplace:make-offer', {
        amount,
        inquiryId,
      })
      if (response.success) await Promise.all([this.loadInquiries(), this.loadCounts()])
      return response
    },
    async respondOffer(
      inquiryId: string,
      action: 'accepted' | 'rejected',
    ): Promise<NuiResponse> {
      const response = await nuiCall('marketplace:respond-offer', { action, inquiryId })
      if (response.success) await Promise.all([this.loadInquiries(), this.loadCounts()])
      return response
    },
    report(id: string, reason: string, details = ''): Promise<NuiResponse> {
      return nuiCall('marketplace:report', { details, id, reason })
    },
    block(listingId: string, blocked = true): Promise<NuiResponse> {
      return nuiCall('marketplace:block', { blocked, listingId })
    },
  },
})
