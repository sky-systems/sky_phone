export type PagesCategory =
  | 'recommendation'
  | 'wanted'
  | 'service'
  | 'event'
  | 'place'
  | 'community'
  | 'citymarkt'

export type PagesImage = {
  gradient: string
  media_id: string
  sort_order: number
}

export type PagesPost = {
  author_name: string
  body: string
  category: PagesCategory
  citymarkt_listing_id: string | null
  citymarkt_price: number | string | null
  created_at: string
  district: string | null
  id: string
  image: string | null
  images: PagesImage[]
  is_liked: boolean | number
  is_owner: boolean | number
  is_saved: boolean | number
  like_count: number
  source_type: 'personal' | 'citymarkt'
  title: string
}

export type PagesPostDraft = {
  body: string
  category: Exclude<PagesCategory, 'citymarkt'>
  district: string
  images: Array<{ id: string }>
  title: string
}

export type PagesPage = {
  hasMore: boolean
  items: PagesPost[]
  offset: number
}
