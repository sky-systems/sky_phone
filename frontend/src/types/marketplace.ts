export type MarketplaceCategory =
  | 'vehicles'
  | 'property'
  | 'electronics'
  | 'clothing'
  | 'tools'
  | 'leisure'
  | 'services'
  | 'jobs'
  | 'wanted'
  | 'other'

export type MarketplaceCondition = 'new' | 'very_good' | 'used' | 'defective'
export type MarketplacePriceType = 'fixed' | 'negotiable' | 'free'
export type MarketplaceStatus = 'active' | 'reserved' | 'sold' | 'expired' | 'removed'
export type MarketplaceOfferStatus = 'pending' | 'accepted' | 'rejected' | 'countered'

export type MarketplaceImage = {
  gradient: string
  media_id: string
  sort_order: number
}

export type MarketplaceListingSummary = {
  category: MarketplaceCategory
  created_at: string
  district: string | null
  expires_at: string
  id: string
  image: string | null
  is_favorite: boolean | number
  item_condition: MarketplaceCondition
  price: number | string | null
  price_type: MarketplacePriceType
  seller_name: string
  status: MarketplaceStatus
  title: string
  updated_at: string
}

export type MarketplaceListing = MarketplaceListingSummary & {
  description: string
  images: MarketplaceImage[]
  is_owner: boolean
  phone_number: string | null
  reserved_account_id: number | null
  revision: number
  seller_active: number
  seller_since: string
  show_phone: boolean | number
}

export type MarketplaceListingDraft = {
  category: MarketplaceCategory
  condition: MarketplaceCondition
  description: string
  district: string
  images: Array<{ id: string }>
  price: number | null
  priceType: MarketplacePriceType
  showPhone: boolean
  title: string
}

export type MarketplaceInquirySummary = {
  buyer_account_id: number
  id: string
  image: string | null
  last_message: string | null
  listing_id: string
  other_name: string
  price: number | string | null
  price_type: MarketplacePriceType
  seller_account_id: number
  status: MarketplaceStatus
  title: string
  unread: number
  updated_at: string
}

export type MarketplaceMessage = {
  body: string
  created_at: string
  id: number
  read_at: string | null
  sender_account_id: number
}

export type MarketplaceOffer = {
  amount: number | string
  created_at: string
  id: number
  proposer_account_id: number
  read_at: string | null
  response_read_at: string | null
  status: MarketplaceOfferStatus
  updated_at: string
}

export type MarketplaceInquiry = {
  buyer_account_id: number
  buyer_name: string
  id: string
  listing_id: string
  offer_amount: number | string | null
  offer_id: number | null
  offer_proposer_account_id: number | null
  offer_revision: number
  offer_status: Exclude<MarketplaceOfferStatus, 'countered'> | null
  price: number | string | null
  price_type: MarketplacePriceType
  reserved_account_id: number | null
  seller_account_id: number
  seller_name: string
  status: MarketplaceStatus
  title: string
}

export type MarketplaceChat = {
  accountId: number
  inquiry: MarketplaceInquiry
  messages: MarketplaceMessage[]
  offers: MarketplaceOffer[]
}

export type MarketplaceCounts = { active: number; unread: number }
