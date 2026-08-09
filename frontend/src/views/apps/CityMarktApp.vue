<script setup lang="ts">
import {
  ArrowLeft,
  BadgeDollarSign,
  BriefcaseBusiness,
  Camera,
  CarFront,
  ChevronRight,
  CirclePlus,
  Gift,
  Hammer,
  Heart,
  House,
  ImageOff,
  ImagePlus,
  Images,
  Inbox,
  Laptop,
  LayoutGrid,
  MapPin,
  MessageCircle,
  MoreHorizontal,
  Rows3,
  Search,
  Send,
  Share2,
  Shirt,
  Tag,
  UserRound,
  Wrench,
  X,
} from 'lucide-vue-next'
import {
  kBadge,
  kButton,
  kFab,
  kGlass,
  kIcon,
  kNavbar,
  kPage,
  kSearchbar,
  kTabbar,
  kTabbarLink,
  kToolbarPane,
} from 'konsta/vue'
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import CityMarktSelect from '@/components/citymarkt/CityMarktSelect.vue'
import CityMarktGallery from '@/components/citymarkt/CityMarktGallery.vue'
import CityMarktOfferCard from '@/components/citymarkt/CityMarktOfferCard.vue'
import { useAccountStore } from '@/stores/account'
import { useMarketplaceStore } from '@/stores/marketplace'
import { useMessageMediaStore } from '@/stores/messageMedia'
import { usePagesStore } from '@/stores/pages'
import { usePhoneStore } from '@/stores/phone'
import { parseDatabaseDate, type DatabaseDateValue } from '@/utils/date'
import type {
  MarketplaceCategory,
  MarketplaceChat,
  MarketplaceCondition,
  MarketplaceListing,
  MarketplaceListingDraft,
  MarketplaceListingSummary,
  MarketplaceMessage,
  MarketplaceOffer,
  MarketplacePriceType,
} from '@/types/marketplace'

const glassActionColors = {
  bgIos: 'bg-ios-light-glass/75 dark:bg-ios-dark-glass/75',
  activeBgIos: 'active:bg-white/90 dark:active:bg-white/20',
  textIos: 'text-black/80 dark:text-white/80',
}
const yellowGlassActionColors = {
  ...glassActionColors,
  textIos: 'text-primary',
}

type Tab = 'discover' | 'search' | 'sell' | 'inbox' | 'profile'
type Screen = 'main' | 'detail' | 'sell' | 'chat' | 'report'
type ChatTimelineItem =
  | {
      createdAt: DatabaseDateValue
      key: string
      kind: 'message'
      value: MarketplaceMessage
    }
  | {
      createdAt: DatabaseDateValue
      isCounter: boolean
      key: string
      kind: 'offer'
      value: MarketplaceOffer
    }
type SelectedPhoto = { background: string; id: string }
type SellDraft = {
  category: MarketplaceCategory
  condition: MarketplaceCondition
  description: string
  district: string
  price: string
  priceType: MarketplacePriceType
  showPhone: boolean
  title: string
}
type MediaContext = {
  draft: SellDraft
  editing: { id: string; revision: number } | null
  photos: SelectedPhoto[]
  sellStep: number
}

const phone = usePhoneStore()
const route = useRoute()
const router = useRouter()
const account = useAccountStore()
const marketplace = useMarketplaceStore()
const messageMedia = useMessageMediaStore()
const pages = usePagesStore()
const tab = ref<Tab>('discover')
const screen = ref<Screen>('main')
const selectedListing = ref<MarketplaceListing | null>(null)
const selectedChat = ref<MarketplaceChat | null>(null)
const search = ref('')
const listingLayout = ref<'compact' | 'wide'>('compact')
const category = ref<MarketplaceCategory | 'all'>('all')
const district = ref('all')
const sort = ref('newest')
const profileMode = ref<'own' | 'favorites'>('own')
const message = ref('')
const firstMessage = ref('')
const offerAmount = ref('')
const offerPanelOpen = ref(false)
const offerSubmitting = ref(false)
const feedback = ref('')
const sellStep = ref(1)
const submitting = ref(false)
const selectedPhotoIds = ref<string[]>([])
const pickedPhotos = ref<SelectedPhoto[]>([])
const reportReason = ref('spam')
const reportDetails = ref('')
const editing = ref<{ id: string; revision: number } | null>(null)
const listingTextLimits = {
  description: { maximum: 2000, minimum: 20 },
  title: { maximum: 70, minimum: 5 },
} as const
const draft = ref<SellDraft>({
  category: 'vehicles' as MarketplaceCategory,
  condition: 'used' as MarketplaceCondition,
  description: '',
  district: 'los_santos',
  price: '',
  priceType: 'fixed' as MarketplacePriceType,
  showPhone: false,
  title: '',
})

const categories = [
  { icon: CarFront, id: 'vehicles' },
  { icon: House, id: 'property' },
  { icon: Laptop, id: 'electronics' },
  { icon: Shirt, id: 'clothing' },
  { icon: Wrench, id: 'tools' },
  { icon: Gift, id: 'leisure' },
  { icon: Hammer, id: 'services' },
  { icon: BriefcaseBusiness, id: 'jobs' },
  { icon: Search, id: 'wanted' },
  { icon: MoreHorizontal, id: 'other' },
] as const
const districts = [
  'los_santos',
  'vinewood',
  'vespucci',
  'south_los_santos',
  'sandy_shores',
  'paleto_bay',
  'blaine_county',
]
const conditions: MarketplaceCondition[] = [
  'new',
  'very_good',
  'used',
  'defective',
]
const priceTypes: MarketplacePriceType[] = ['fixed', 'negotiable', 'free']
const categoryOptions = computed(() => [
  { label: phone.t('Apps.citymarkt.allCategories'), value: 'all' },
  ...categories.map((item) => ({
    label: label('categories', item.id),
    value: item.id,
  })),
])
const districtOptions = computed(() => [
  { label: phone.t('Apps.citymarkt.allDistricts'), value: 'all' },
  ...districts.map((item) => ({
    label: label('districts', item),
    value: item,
  })),
])
const sortOptions = computed(() => [
  { label: phone.t('Apps.citymarkt.sortNewest'), value: 'newest' },
  { label: phone.t('Apps.citymarkt.sortPriceAsc'), value: 'price_asc' },
  { label: phone.t('Apps.citymarkt.sortPriceDesc'), value: 'price_desc' },
])
const sellCategoryOptions = computed(() =>
  categories.map((item) => ({
    label: label('categories', item.id),
    value: item.id,
  })),
)
const conditionOptions = computed(() =>
  conditions.map((item) => ({ label: label('conditions', item), value: item })),
)
const priceTypeOptions = computed(() =>
  priceTypes.map((item) => ({ label: label('priceTypes', item), value: item })),
)
const sellDistrictOptions = computed(() =>
  districts.map((item) => ({ label: label('districts', item), value: item })),
)
const reportReasonOptions = computed(() =>
  ['prohibited', 'fraud', 'spam', 'offensive', 'other'].map((item) => ({
    label: label('reportReasons', item),
    value: item,
  })),
)
const tabs = [
  { icon: House, id: 'discover' },
  { icon: Search, id: 'search' },
  { icon: CirclePlus, id: 'sell' },
  { icon: Inbox, id: 'inbox' },
  { icon: UserRound, id: 'profile' },
] as const

const isAuthenticated = computed(() => account.email !== '')
const displayItems = computed(() => {
  if (tab.value === 'profile') {
    return profileMode.value === 'own'
      ? marketplace.ownItems
      : marketplace.items.filter((item) => Boolean(item.is_favorite))
  }
  return marketplace.items
})
const draftImages = computed(() =>
  selectedPhotoIds.value.flatMap((id, index) => {
    const photo = pickedPhotos.value.find((item) => item.id === id)
    return photo
      ? [
          {
            gradient: photo.background,
            media_id: photo.id,
            sort_order: index + 1,
          },
        ]
      : []
  }),
)
const chatTimeline = computed<ChatTimelineItem[]>(() => {
  if (!selectedChat.value) return []
  const messages: ChatTimelineItem[] = selectedChat.value.messages.map(
    (item) => ({
      createdAt: item.created_at,
      key: `message-${item.id}`,
      kind: 'message',
      value: item,
    }),
  )
  const offers: ChatTimelineItem[] = (selectedChat.value.offers ?? []).map(
    (item, index) => ({
      createdAt: item.created_at,
      isCounter: index > 0,
      key: `offer-${item.id}`,
      kind: 'offer',
      value: item,
    }),
  )
  return [...messages, ...offers].sort(
    (left, right) =>
      parseDatabaseDate(left.createdAt).getTime() -
      parseDatabaseDate(right.createdAt).getTime(),
  )
})
const canMakeOffer = computed(() => {
  if (
    !selectedChat.value ||
    !['active', 'reserved'].includes(selectedChat.value.inquiry.status)
  ) {
    return false
  }
  const inquiry = selectedChat.value.inquiry
  if (inquiry.offer_status === 'accepted') return false
  if (inquiry.offer_status === 'pending') {
    return (
      Number(inquiry.offer_proposer_account_id) !== selectedChat.value.accountId
    )
  }
  return Number(inquiry.buyer_account_id) === selectedChat.value.accountId
})
const offerButtonLabel = computed(() =>
  selectedChat.value?.inquiry.offer_status === 'pending'
    ? phone.t('Apps.citymarkt.negotiateOffer')
    : phone.t('Apps.citymarkt.makeOffer'),
)
const canContinueSell = computed(() => {
  if (sellStep.value === 1) return true
  if (sellStep.value === 2)
    return (
      draft.value.title.trim().length >= listingTextLimits.title.minimum &&
      draft.value.description.trim().length >=
        listingTextLimits.description.minimum
    )
  if (sellStep.value === 3)
    return draft.value.priceType === 'free' || Number(draft.value.price) > 0
  return true
})

function label(group: string, value: string): string {
  return phone.t(`Apps.citymarkt.${group}.${value}`)
}

function formatPrice(item: {
  price: number | string | null
  price_type: MarketplacePriceType
}): string {
  if (item.price_type === 'free') return phone.t('Apps.citymarkt.free')
  const value = Number(item.price ?? 0)
  const formatted = new Intl.NumberFormat(phone.lang, {
    maximumFractionDigits: 0,
  }).format(value)
  return item.price_type === 'negotiable'
    ? phone.t('Apps.citymarkt.negotiablePrice', { price: formatted })
    : phone.t('Apps.citymarkt.money', { price: formatted })
}

function relativeDate(value: DatabaseDateValue): string {
  const timestamp = parseDatabaseDate(value).getTime()
  const hours = Math.max(1, Math.floor((Date.now() - timestamp) / 3_600_000))
  if (hours < 24)
    return phone.t('Apps.citymarkt.hoursAgo', { count: String(hours) })
  return phone.t('Apps.citymarkt.daysAgo', {
    count: String(Math.floor(hours / 24)),
  })
}

function messageTime(value: DatabaseDateValue): string {
  return new Intl.DateTimeFormat(phone.lang, {
    hour: '2-digit',
    hourCycle: 'h23',
    minute: '2-digit',
  }).format(parseDatabaseDate(value))
}

function setFeedback(key: string): void {
  feedback.value = phone.t(key)
  window.setTimeout(() => {
    feedback.value = ''
  }, 2600)
}

async function shareToLocalPages(): Promise<void> {
  if (!selectedListing.value) return
  const response = await pages.shareCityMarkt(selectedListing.value.id)
  setFeedback(
    response.success
      ? 'Apps.localPages.cityMarktShared'
      : `Apps.localPages.errors.${response.error ?? 'default'}`,
  )
}

async function loadFeed(): Promise<void> {
  await marketplace.load({
    category: category.value,
    district: district.value,
    search: search.value,
    sort: sort.value,
  })
}

function updateSearch(event: Event): void {
  search.value = (event.target as HTMLInputElement).value
}

function clearSearch(): void {
  search.value = ''
  void loadFeed()
}

function toggleCategory(value: MarketplaceCategory): void {
  category.value = category.value === value ? 'all' : value
  void loadFeed()
}

async function selectCategory(value: string): Promise<void> {
  category.value = value as MarketplaceCategory | 'all'
  await loadFeed()
}

async function selectDistrict(value: string): Promise<void> {
  district.value = value
  await loadFeed()
}

async function selectSort(value: string): Promise<void> {
  sort.value = value
  await loadFeed()
}

function selectDraftCategory(value: string): void {
  draft.value.category = value as MarketplaceCategory
}

function selectDraftCondition(value: string): void {
  draft.value.condition = value as MarketplaceCondition
}

function selectDraftPriceType(value: string): void {
  draft.value.priceType = value as MarketplacePriceType
}

function selectDraftDistrict(value: string): void {
  draft.value.district = value
}

function selectReportReason(value: string): void {
  reportReason.value = value
}

async function selectTab(next: Tab): Promise<void> {
  tab.value = next
  screen.value = 'main'
  if (next === 'sell') {
    if (isAuthenticated.value) screen.value = 'sell'
    else tab.value = 'profile'
    return
  }
  if (next === 'discover' || next === 'search') await loadFeed()
  if (next === 'inbox' && isAuthenticated.value)
    await marketplace.loadInquiries()
  if (next === 'profile' && isAuthenticated.value) {
    await Promise.all([
      marketplace.loadOwn(),
      marketplace.load({ favorites: true }),
    ])
  }
}

async function openListing(
  item: Pick<MarketplaceListingSummary, 'id'>,
): Promise<void> {
  const response = await marketplace.get(item.id)
  if (!response.success || !response.data) {
    setFeedback('Apps.citymarkt.errors.listing_not_found')
    return
  }
  selectedListing.value = response.data
  firstMessage.value = ''
  screen.value = 'detail'
}

async function toggleFavorite(): Promise<void> {
  if (!selectedListing.value || !isAuthenticated.value) return
  const next = !Boolean(selectedListing.value.is_favorite)
  if (await marketplace.favorite(selectedListing.value.id, next)) {
    selectedListing.value.is_favorite = next
  }
}

function togglePhoto(id: string): void {
  const index = selectedPhotoIds.value.indexOf(id)
  if (index >= 0) {
    selectedPhotoIds.value.splice(index, 1)
    pickedPhotos.value = pickedPhotos.value.filter((photo) => photo.id !== id)
  }
}

function openMediaApp(app: 'camera' | 'photos'): void {
  const remaining = 6 - selectedPhotoIds.value.length
  if (remaining < 1) {
    setFeedback('Apps.citymarkt.photoLimit')
    return
  }
  messageMedia.begin(
    'citymarkt:sell',
    'photo',
    '/apps/citymarkt?sell=1',
    app === 'photos' ? remaining : 1,
    {
      draft: { ...draft.value },
      editing: editing.value ? { ...editing.value } : null,
      photos: [...pickedPhotos.value],
      sellStep: sellStep.value,
    } satisfies MediaContext,
  )
  void router.push({
    path: `/apps/${app}`,
    query: { mediaAttachment: 'photo' },
  })
}

function resetSell(): void {
  editing.value = null
  sellStep.value = 1
  selectedPhotoIds.value = []
  pickedPhotos.value = []
  draft.value = {
    category: 'vehicles',
    condition: 'used',
    description: '',
    district: 'los_santos',
    price: '',
    priceType: 'fixed',
    showPhone: false,
    title: '',
  }
}

function editListing(): void {
  if (!selectedListing.value) return
  editing.value = {
    id: selectedListing.value.id,
    revision: selectedListing.value.revision,
  }
  selectedPhotoIds.value = selectedListing.value.images.map(
    (image) => image.media_id,
  )
  pickedPhotos.value = selectedListing.value.images.map((image) => ({
    background: image.gradient,
    id: image.media_id,
  }))
  draft.value = {
    category: selectedListing.value.category,
    condition: selectedListing.value.item_condition,
    description: selectedListing.value.description,
    district: selectedListing.value.district ?? 'los_santos',
    price:
      selectedListing.value.price === null
        ? ''
        : String(selectedListing.value.price),
    priceType: selectedListing.value.price_type,
    showPhone: Boolean(selectedListing.value.show_phone),
    title: selectedListing.value.title,
  }
  sellStep.value = 1
  screen.value = 'sell'
}

function listingDraft(): MarketplaceListingDraft {
  return {
    ...draft.value,
    images: selectedPhotoIds.value.map((id) => ({ id })),
    price: draft.value.priceType === 'free' ? null : Number(draft.value.price),
  }
}

async function publish(): Promise<void> {
  if (submitting.value) return
  submitting.value = true
  const response = editing.value
    ? await marketplace.update(
        editing.value.id,
        editing.value.revision,
        listingDraft(),
      )
    : await marketplace.create(listingDraft())
  submitting.value = false
  if (!response.success) {
    setFeedback(`Apps.citymarkt.errors.${response.error ?? 'default'}`)
    return
  }
  resetSell()
  tab.value = 'profile'
  profileMode.value = 'own'
  screen.value = 'main'
  setFeedback('Apps.citymarkt.published')
}

async function sendFirstMessage(): Promise<void> {
  if (!selectedListing.value || !firstMessage.value.trim()) return
  const response = await marketplace.sendMessage({
    body: firstMessage.value,
    listingId: selectedListing.value.id,
  })
  if (!response.success || !response.data) {
    setFeedback(`Apps.citymarkt.errors.${response.error ?? 'default'}`)
    return
  }
  const chatResponse = await marketplace.getInquiry(response.data.id)
  if (chatResponse.success && chatResponse.data) {
    selectedChat.value = chatResponse.data
    screen.value = 'chat'
  }
}

async function openChat(id: string): Promise<void> {
  const response = await marketplace.getInquiry(id)
  if (response.success && response.data) {
    selectedChat.value = response.data
    message.value = ''
    offerPanelOpen.value = false
    screen.value = 'chat'
    await Promise.all([marketplace.loadInquiries(), marketplace.loadCounts()])
  }
}

function isOfferActionable(offer: MarketplaceOffer): boolean {
  if (!selectedChat.value) return false
  return (
    offer.status === 'pending' &&
    Number(selectedChat.value.inquiry.offer_id) === Number(offer.id) &&
    Number(offer.proposer_account_id) !== selectedChat.value.accountId
  )
}

function openOfferPanel(): void {
  if (!selectedChat.value || !canMakeOffer.value) return
  const suggestedAmount = Number(
    selectedChat.value.inquiry.offer_amount ??
      selectedChat.value.inquiry.price ??
      0,
  )
  offerAmount.value = suggestedAmount > 0 ? String(suggestedAmount) : ''
  offerPanelOpen.value = true
}

async function refreshChat(): Promise<void> {
  if (!selectedChat.value) return
  const response = await marketplace.getInquiry(selectedChat.value.inquiry.id)
  if (response.success && response.data) selectedChat.value = response.data
}

async function submitOffer(): Promise<void> {
  if (!selectedChat.value || offerSubmitting.value) return
  const amount = Number(offerAmount.value)
  if (!Number.isInteger(amount) || amount < 1) {
    setFeedback('Apps.citymarkt.errors.invalid_offer')
    return
  }
  offerSubmitting.value = true
  const response = await marketplace.makeOffer(
    selectedChat.value.inquiry.id,
    amount,
  )
  offerSubmitting.value = false
  if (!response.success) {
    setFeedback(`Apps.citymarkt.errors.${response.error ?? 'default'}`)
    return
  }
  offerPanelOpen.value = false
  await refreshChat()
  setFeedback('Apps.citymarkt.offerSent')
}

async function respondOffer(action: 'accepted' | 'rejected'): Promise<void> {
  if (!selectedChat.value || offerSubmitting.value) return
  offerSubmitting.value = true
  const response = await marketplace.respondOffer(
    selectedChat.value.inquiry.id,
    action,
  )
  offerSubmitting.value = false
  if (!response.success) {
    setFeedback(`Apps.citymarkt.errors.${response.error ?? 'default'}`)
    return
  }
  await refreshChat()
  setFeedback(
    action === 'accepted'
      ? 'Apps.citymarkt.offerAccepted'
      : 'Apps.citymarkt.offerDeclined',
  )
}

async function sendChatMessage(): Promise<void> {
  if (!selectedChat.value || !message.value.trim()) return
  const body = message.value
  message.value = ''
  const response = await marketplace.sendMessage({
    body,
    inquiryId: selectedChat.value.inquiry.id,
  })
  if (response.success) {
    const refreshed = await marketplace.getInquiry(
      selectedChat.value.inquiry.id,
    )
    if (refreshed.data) selectedChat.value = refreshed.data
  } else setFeedback(`Apps.citymarkt.errors.${response.error ?? 'default'}`)
}

async function setListingStatus(
  status: string,
  inquiryId?: string,
): Promise<void> {
  const listingId =
    selectedListing.value?.id ?? selectedChat.value?.inquiry.listing_id
  if (!listingId) return
  if (await marketplace.setStatus(listingId, status, inquiryId)) {
    setFeedback('Apps.citymarkt.statusChanged')
    if (selectedListing.value) {
      const response = await marketplace.get(listingId)
      if (response.data) selectedListing.value = response.data
    }
    if (selectedChat.value) {
      const response = await marketplace.getInquiry(
        selectedChat.value.inquiry.id,
      )
      if (response.data) selectedChat.value = response.data
    }
  }
}

async function submitReport(): Promise<void> {
  if (!selectedListing.value) return
  const response = await marketplace.report(
    selectedListing.value.id,
    reportReason.value,
    reportDetails.value,
  )
  if (response.success) {
    screen.value = 'detail'
    setFeedback('Apps.citymarkt.reported')
  } else setFeedback(`Apps.citymarkt.errors.${response.error ?? 'default'}`)
}

async function blockSeller(): Promise<void> {
  if (!selectedListing.value) return
  if ((await marketplace.block(selectedListing.value.id)).success) {
    screen.value = 'main'
    selectedListing.value = null
    await loadFeed()
    setFeedback('Apps.citymarkt.blocked')
  }
}

onMounted(async () => {
  const selection = messageMedia.consumeMany<MediaContext>('citymarkt:sell')
  if (selection) {
    if (selection.context) {
      draft.value = selection.context.draft
      editing.value = selection.context.editing
      pickedPhotos.value = selection.context.photos
      sellStep.value = selection.context.sellStep
      selectedPhotoIds.value = selection.context.photos.map((photo) => photo.id)
    }
    for (const media of selection.media) {
      const id = String(media.id)
      if (
        selectedPhotoIds.value.includes(id) ||
        selectedPhotoIds.value.length >= 6
      )
        continue
      selectedPhotoIds.value.push(id)
      pickedPhotos.value.push({
        background: `url(${JSON.stringify(media.url)})`,
        id,
      })
    }
  }
  if (route.query.sell === '1') {
    tab.value = 'sell'
    screen.value = 'sell'
  }
  await loadFeed()
  if (isAuthenticated.value) await marketplace.loadCounts()
  if (typeof route.query.listingId === 'string') {
    await openListing({ id: route.query.listingId })
  }
})
</script>

<template>
  <k-page
    component="main"
    class="citymarkt pb-safe-24"
    :class="{ 'citymarkt--light': !phone.isDarkMode }"
    :colors="{ bgIos: 'bg-transparent' }"
  >
    <k-navbar
      v-if="screen === 'main'"
      class="citymarkt-navbar"
      :subtitle="
        phone.t(
          tab === 'discover' ? 'Apps.citymarkt.eyebrow' : 'Apps.citymarkt.name',
        )
      "
      :title="
        phone.t(
          tab === 'discover'
            ? 'Apps.citymarkt.name'
            : `Apps.citymarkt.tabs.${tab}`,
        )
      "
    />

    <section v-if="screen === 'main'" class="citymarkt__content">
      <template v-if="tab === 'discover' || tab === 'search'">
        <k-searchbar
          component="form"
          :value="search"
          :placeholder="phone.t('Apps.citymarkt.searchPlaceholder')"
          @input="updateSearch"
          @clear="clearSearch"
          @submit.prevent="loadFeed"
        />

        <div v-if="tab === 'discover'" class="citymarkt__categories">
          <button
            v-for="item in categories"
            :key="item.id"
            :class="{ active: category === item.id }"
            type="button"
            @click="toggleCategory(item.id)"
          >
            <k-glass class="citymarkt__category-icon">
              <component :is="item.icon" :size="19" />
            </k-glass>
            {{ label('categories', item.id) }}
          </button>
        </div>

        <div v-else class="citymarkt__filters">
          <CityMarktSelect
            :model-value="category"
            :options="categoryOptions"
            @change="selectCategory"
          />
          <CityMarktSelect
            :model-value="district"
            :options="districtOptions"
            @change="selectDistrict"
          />
          <CityMarktSelect
            :model-value="sort"
            :options="sortOptions"
            @change="selectSort"
          />
        </div>

        <div class="citymarkt__section-title">
          <div>
            <strong>{{ phone.t('Apps.citymarkt.freshOffers') }}</strong>
            <span class="citymarkt__section-actions">
              <small>
                {{ marketplace.items.length }}
                {{ phone.t('Apps.citymarkt.offers') }}
              </small>
              <k-glass class="citymarkt-layout-toggle">
                <button
                  type="button"
                  :aria-label="
                    phone.t(
                      listingLayout === 'compact'
                        ? 'Apps.citymarkt.largeView'
                        : 'Apps.citymarkt.compactView',
                    )
                  "
                  :title="
                    phone.t(
                      listingLayout === 'compact'
                        ? 'Apps.citymarkt.largeView'
                        : 'Apps.citymarkt.compactView',
                    )
                  "
                  @click="
                    listingLayout =
                      listingLayout === 'compact' ? 'wide' : 'compact'
                  "
                >
                  <Rows3 v-if="listingLayout === 'compact'" :size="17" />
                  <LayoutGrid v-else :size="17" />
                </button>
              </k-glass>
            </span>
          </div>
        </div>
        <div v-if="marketplace.isLoading" class="citymarkt__empty">
          {{ phone.t('Common.loading') }}
        </div>
        <div v-else-if="!displayItems.length" class="citymarkt__empty">
          <Search :size="32" /><strong>{{
            phone.t('Apps.citymarkt.noListings')
          }}</strong
          ><span>{{ phone.t('Apps.citymarkt.noListingsBody') }}</span>
        </div>
        <div
          v-else
          class="citymarkt__grid"
          :class="{ 'citymarkt__grid--wide': listingLayout === 'wide' }"
        >
          <k-glass
            v-for="item in displayItems"
            :key="item.id"
            class="citymarkt-listing-card"
          >
            <button type="button" @click="openListing(item)">
              <span
                class="citymarkt__card-image"
              :class="{ 'citymarkt__card-image--empty': !item.image }"
              :style="{ background: item.image ?? undefined }"
            >
              <span v-if="!item.image" class="citymarkt__image-placeholder"
                ><ImageOff :size="20" /><small>{{
                  phone.t('Apps.citymarkt.noPhoto')
                }}</small></span
              >
              <i v-if="item.status === 'reserved'">{{
                phone.t('Apps.citymarkt.status.reserved')
              }}</i>
              <Heart v-if="item.is_favorite" :size="15" fill="currentColor" />
              </span>
              <span class="citymarkt-listing-card__body">
                <strong>{{ formatPrice(item) }}</strong>
                <span class="citymarkt-listing-card__title">{{ item.title }}</span>
                <small
              ><MapPin :size="11" />
              {{
                item.district
                  ? label('districts', item.district)
                  : phone.t('Apps.citymarkt.noDistrict')
              }}
              · {{ relativeDate(item.created_at) }}</small
                >
              </span>
            </button>
          </k-glass>
        </div>
      </template>

      <template v-else-if="tab === 'inbox'">
        <div v-if="!isAuthenticated" class="citymarkt__auth">
          <UserRound :size="40" />
          <h2>{{ phone.t('Apps.citymarkt.signInTitle') }}</h2>
          <p>{{ phone.t('Apps.citymarkt.signInBody') }}</p>
        </div>
        <div v-else-if="!marketplace.inquiries.length" class="citymarkt__empty">
          <MessageCircle :size="36" /><strong>{{
            phone.t('Apps.citymarkt.noMessages')
          }}</strong
          ><span>{{ phone.t('Apps.citymarkt.noMessagesBody') }}</span>
        </div>
        <div v-else class="citymarkt__inquiries citymarkt__glass-list">
          <k-glass v-for="item in marketplace.inquiries" :key="item.id">
            <button type="button" @click="openChat(item.id)">
              <span
                :class="{ 'citymarkt__thumb--empty': !item.image }"
                :style="{ background: item.image ?? undefined }"
                ><ImageOff v-if="!item.image" :size="17"
              /></span>
              <div>
                <strong>{{ item.other_name }}</strong
                ><b>{{ item.title }}</b
                ><small>{{ item.last_message }}</small>
              </div>
              <i v-if="Number(item.unread)">{{ item.unread }}</i
              ><ChevronRight :size="16" />
            </button>
          </k-glass>
        </div>
      </template>

      <template v-else-if="tab === 'profile'">
        <div v-if="!isAuthenticated" class="citymarkt__auth">
          <UserRound :size="40" />
          <h2>{{ phone.t('Apps.citymarkt.signInTitle') }}</h2>
          <p>{{ phone.t('Apps.citymarkt.signInBody') }}</p>
        </div>
        <template v-else>
          <k-glass class="citymarkt__glass-profile"
            ><span>{{ account.email.charAt(0).toUpperCase() }}</span>
            <div>
              <strong>{{ account.email.split('@')[0] }}</strong
              ><small>{{ account.email }}</small>
            </div></k-glass
          >
          <k-glass class="citymarkt__glass-segmented">
            <button
              type="button"
              :class="{ active: profileMode === 'own' }"
              @click="profileMode = 'own'"
            >
              <Tag :size="14" />
              {{ phone.t('Apps.citymarkt.myListings') }}
              <span>{{ marketplace.counts.active }}</span>
            </button>
            <button
              type="button"
              :class="{ active: profileMode === 'favorites' }"
              @click="profileMode = 'favorites'"
            >
              <Heart :size="14" />
              {{ phone.t('Apps.citymarkt.favorites') }}
              <span>{{ marketplace.items.length }}</span>
            </button>
          </k-glass>
          <div v-if="!displayItems.length" class="citymarkt__empty">
            <Tag :size="34" /><strong>{{
              phone.t('Apps.citymarkt.noProfileListings')
            }}</strong>
          </div>
          <div v-else class="citymarkt__list citymarkt__glass-list">
            <k-glass
              v-for="item in displayItems"
              :key="item.id"
              class="citymarkt-profile-listing"
              ><button type="button" @click="openListing(item)">
                <span
                  :class="{ 'citymarkt__thumb--empty': !item.image }"
                  :style="{ background: item.image ?? undefined }"
                  ><ImageOff v-if="!item.image" :size="17"
                /></span>
                <div class="citymarkt-profile-listing__body">
                  <b>{{ formatPrice(item) }}</b>
                  <strong>{{ item.title }}</strong>
                  <small>{{ label('status', item.status) }}</small>
                </div>
                <ChevronRight :size="17" /></button
            ></k-glass>
          </div>
        </template>
      </template>
    </section>

    <section
      v-else-if="screen === 'detail' && selectedListing"
      class="citymarkt__detail"
    >
      <div class="citymarkt__glass-actions">
        <k-fab
          component="button"
          type="button"
          :colors="yellowGlassActionColors"
          :aria-label="phone.t('Common.back')"
          @click="screen = 'main'"
          ><template #icon><ArrowLeft :size="19" /></template
        ></k-fab>
        <div>
          <k-fab
            v-if="!selectedListing.is_owner"
            component="button"
            type="button"
            :colors="glassActionColors"
            @click="toggleFavorite"
            ><template #icon
              ><Heart
                :size="19"
                :fill="
                  selectedListing.is_favorite ? 'currentColor' : 'none'
                " /></template
          ></k-fab>
          <k-fab
            v-if="!selectedListing.is_owner"
            component="button"
            type="button"
            :colors="glassActionColors"
            @click="screen = 'report'"
            ><template #icon><MoreHorizontal :size="20" /></template
          ></k-fab>
        </div>
      </div>
      <CityMarktGallery
        class="citymarkt__hero"
        :images="selectedListing.images"
        :empty-title="phone.t('Apps.citymarkt.noPhoto')"
        :empty-body="phone.t('Apps.citymarkt.noPhotoBody')"
        :previous-label="phone.t('Apps.citymarkt.previousPhoto')"
        :next-label="phone.t('Apps.citymarkt.nextPhoto')"
        :photo-label="phone.t('Apps.citymarkt.photo')"
      />
      <div class="citymarkt__detail-body">
        <div class="citymarkt__price-row">
          <div>
            <h2>{{ formatPrice(selectedListing) }}</h2>
            <span v-if="selectedListing.status !== 'active'">{{
              label('status', selectedListing.status)
            }}</span>
          </div>
          <small>{{ relativeDate(selectedListing.created_at) }}</small>
        </div>
        <h1>{{ selectedListing.title }}</h1>
        <p class="citymarkt__meta">
          <MapPin :size="14" />
          {{
            selectedListing.district
              ? label('districts', selectedListing.district)
              : phone.t('Apps.citymarkt.noDistrict')
          }}
          · {{ label('conditions', selectedListing.item_condition) }}
        </p>
        <p class="citymarkt__description">{{ selectedListing.description }}</p>
        <div class="citymarkt__seller">
          <span>{{ selectedListing.seller_name.charAt(0).toUpperCase() }}</span>
          <div>
            <strong>{{ selectedListing.seller_name }}</strong
            ><small
              >{{ selectedListing.seller_active }}
              {{ phone.t('Apps.citymarkt.activeListings') }}</small
            >
          </div>
        </div>
        <p v-if="selectedListing.phone_number" class="citymarkt__phone">
          {{ phone.t('Apps.citymarkt.phone') }}:
          {{ selectedListing.phone_number }}
        </p>
        <template v-if="selectedListing.is_owner">
          <button
            v-if="
              selectedListing.status === 'active' ||
              selectedListing.status === 'reserved'
            "
            class="citymarkt__pages-share"
            type="button"
            @click="shareToLocalPages"
          >
            <Share2 :size="17" /><span
              ><strong>{{ phone.t('Apps.localPages.cityMarktShare') }}</strong
              ><small>{{
                phone.t('Apps.localPages.cityMarktShareHint')
              }}</small></span
            >
          </button>
          <div class="citymarkt__owner-actions">
            <button
              v-if="
                selectedListing.status !== 'sold' &&
                selectedListing.status !== 'removed'
              "
              @click="editListing"
            >
              {{ phone.t('Apps.citymarkt.edit') }}</button
            ><button
              v-if="
                selectedListing.status === 'reserved' ||
                selectedListing.status === 'expired'
              "
              @click="setListingStatus('active')"
            >
              {{ phone.t('Apps.citymarkt.makeActive') }}</button
            ><button
              v-if="
                selectedListing.status === 'active' ||
                selectedListing.status === 'reserved'
              "
              @click="setListingStatus('sold')"
            >
              {{ phone.t('Apps.citymarkt.markSold') }}</button
            ><button
              v-if="
                selectedListing.status !== 'sold' &&
                selectedListing.status !== 'removed'
              "
              class="danger"
              @click="setListingStatus('removed')"
            >
              {{ phone.t('Apps.citymarkt.remove') }}
            </button>
          </div>
        </template>
        <template v-else-if="isAuthenticated">
          <div class="citymarkt__composer">
            <textarea
              v-model="firstMessage"
              maxlength="1000"
              :placeholder="phone.t('Apps.citymarkt.messagePlaceholder')"
            /><button
              :disabled="!firstMessage.trim()"
              @click="sendFirstMessage"
            >
              <MessageCircle :size="17" />{{
                phone.t('Apps.citymarkt.contactSeller')
              }}
            </button>
          </div>
        </template>
        <k-glass v-else class="citymarkt__glass-auth">{{
          phone.t('Apps.citymarkt.signInToMessage')
        }}</k-glass>
      </div>
    </section>

    <section v-else-if="screen === 'sell'" class="citymarkt__sell">
      <k-navbar
        class="citymarkt-create-navbar"
        center-title
        left-class="citymarkt-create-action citymarkt-create-action--close"
        right-class="citymarkt-create-action citymarkt-create-action--next"
        :title="phone.t(editing ? 'Apps.citymarkt.editListing' : 'Apps.citymarkt.createListing')"
        :subtitle="phone.t('Apps.citymarkt.step', { current: String(sellStep), total: '4' })"
      >
        <template #left>
          <button
            class="citymarkt-create-close"
            type="button"
            :aria-label="phone.t('Common.close')"
            @click="resetSell(); screen = 'main'; tab = 'discover'"
          >
            <X :size="20" />
          </button>
        </template>
        <template #right>
          <button
            class="citymarkt-create-next"
            type="button"
            :disabled="!canContinueSell || submitting"
            @click="sellStep < 4 ? sellStep++ : publish()"
          >
            {{
              sellStep < 4
                ? phone.t('Apps.citymarkt.next')
                : phone.t(editing ? 'Apps.citymarkt.save' : 'Apps.citymarkt.publish')
            }}
          </button>
        </template>
      </k-navbar>
      <div class="citymarkt__progress">
        <i :style="{ width: `${sellStep * 25}%` }" />
      </div>
      <div class="citymarkt__sell-body">
        <template v-if="sellStep === 1">
          <ImagePlus :size="32" />
          <h2>{{ phone.t('Apps.citymarkt.addPhotos') }}</h2>
          <p>{{ phone.t('Apps.citymarkt.addPhotosBody') }}</p>
          <div class="citymarkt__photo-actions">
            <k-glass>
              <button type="button" @click="openMediaApp('photos')">
                <span><Images :size="20" /></span>
                <strong>{{ phone.t('Apps.citymarkt.chooseGallery') }}</strong>
                <small>{{ phone.t('Apps.citymarkt.chooseGalleryBody') }}</small>
              </button>
            </k-glass>
            <k-glass>
              <button type="button" @click="openMediaApp('camera')">
                <span><Camera :size="20" /></span>
                <strong>{{ phone.t('Apps.citymarkt.takePhotos') }}</strong>
                <small>{{ phone.t('Apps.citymarkt.takePhotosBody') }}</small>
              </button>
            </k-glass>
          </div>
          <div class="citymarkt__selected-heading">
            <strong>{{ phone.t('Apps.citymarkt.selectedPhotos') }}</strong>
            <span>{{ selectedPhotoIds.length }} / 6</span>
          </div>
          <CityMarktGallery
            class="citymarkt__selection-gallery"
            :images="draftImages"
            :empty-title="phone.t('Apps.citymarkt.noPhoto')"
            :empty-body="phone.t('Apps.citymarkt.noPhotoOptional')"
            :previous-label="phone.t('Apps.citymarkt.previousPhoto')"
            :next-label="phone.t('Apps.citymarkt.nextPhoto')"
            :photo-label="phone.t('Apps.citymarkt.photo')"
          />
          <div v-if="draftImages.length" class="citymarkt__selected-strip">
            <button
              v-for="(photo, index) in draftImages"
              :key="photo.media_id"
              type="button"
              :style="{ background: photo.gradient }"
              :aria-label="
                phone.t('Apps.citymarkt.removePhoto', {
                  number: String(index + 1),
                })
              "
              @click="togglePhoto(photo.media_id)"
            >
              <i>{{ index + 1 }}</i
              ><X :size="12" />
            </button>
          </div>
        </template>
        <template v-else-if="sellStep === 2">
          <h2>{{ phone.t('Apps.citymarkt.describeOffer') }}</h2>
          <label>
            <span class="citymarkt__field-heading">
              <span>{{ phone.t('Apps.citymarkt.title') }}</span>
              <small
                :class="{
                  valid:
                    draft.title.trim().length >=
                    listingTextLimits.title.minimum,
                }"
                aria-live="polite"
                >{{
                  phone.t('Apps.citymarkt.characterCount', {
                    current: String(draft.title.trim().length),
                    maximum: String(listingTextLimits.title.maximum),
                  })
                }}
                ·
                {{
                  phone.t('Apps.citymarkt.minimumCharacters', {
                    minimum: String(listingTextLimits.title.minimum),
                  })
                }}</small
              >
            </span>
            <k-glass class="citymarkt__field-glass">
              <input
                v-model="draft.title"
                :maxlength="listingTextLimits.title.maximum"
              />
            </k-glass>
          </label>
          <label>
            <span class="citymarkt__field-heading">
              <span>{{ phone.t('Apps.citymarkt.description') }}</span>
              <small
                :class="{
                  valid:
                    draft.description.trim().length >=
                    listingTextLimits.description.minimum,
                }"
                aria-live="polite"
                >{{
                  phone.t('Apps.citymarkt.characterCount', {
                    current: String(draft.description.trim().length),
                    maximum: String(listingTextLimits.description.maximum),
                  })
                }}
                ·
                {{
                  phone.t('Apps.citymarkt.minimumCharacters', {
                    minimum: String(listingTextLimits.description.minimum),
                  })
                }}</small
              >
            </span>
            <k-glass class="citymarkt__field-glass citymarkt__field-glass--textarea">
              <textarea
                v-model="draft.description"
                :maxlength="listingTextLimits.description.maximum"
              />
            </k-glass>
          </label>
          <label
            >{{ phone.t('Apps.citymarkt.category')
            }}<CityMarktSelect
              class="citymarkt__form-select"
              :model-value="draft.category"
              :options="sellCategoryOptions"
              @change="selectDraftCategory"
          /></label>
          <label
            >{{ phone.t('Apps.citymarkt.condition')
            }}<CityMarktSelect
              class="citymarkt__form-select"
              :model-value="draft.condition"
              :options="conditionOptions"
              @change="selectDraftCondition"
          /></label>
        </template>
        <template v-else-if="sellStep === 3"
          ><h2>{{ phone.t('Apps.citymarkt.priceAndPlace') }}</h2>
          <label
            >{{ phone.t('Apps.citymarkt.priceType')
            }}<CityMarktSelect
              class="citymarkt__form-select"
              :model-value="draft.priceType"
              :options="priceTypeOptions"
              @change="selectDraftPriceType" /></label
          ><label v-if="draft.priceType !== 'free'"
            >{{ phone.t('Apps.citymarkt.price') }}
            <k-glass class="citymarkt__field-glass">
              <input
                v-model="draft.price"
                inputmode="numeric"
                type="number"
                min="1"
              />
            </k-glass></label
          ><label
            >{{ phone.t('Apps.citymarkt.district')
            }}<CityMarktSelect
              class="citymarkt__form-select"
              :model-value="draft.district"
              :options="sellDistrictOptions"
              @change="selectDraftDistrict" /></label
          ><label class="citymarkt__switch"
            ><input v-model="draft.showPhone" type="checkbox" /><span />{{
              phone.t('Apps.citymarkt.showPhone')
            }}</label
          ></template
        >
        <template v-else
          ><h2>{{ phone.t('Apps.citymarkt.preview') }}</h2>
          <CityMarktGallery
            class="citymarkt__preview-image"
            :images="draftImages"
            :empty-title="phone.t('Apps.citymarkt.noPhoto')"
            :empty-body="phone.t('Apps.citymarkt.noPhotoBody')"
            :previous-label="phone.t('Apps.citymarkt.previousPhoto')"
            :next-label="phone.t('Apps.citymarkt.nextPhoto')"
            :photo-label="phone.t('Apps.citymarkt.photo')"
          /><strong class="citymarkt__preview-price">{{
            formatPrice({ price: draft.price, price_type: draft.priceType })
          }}</strong>
          <h3>{{ draft.title }}</h3>
          <p>{{ draft.description }}</p>
          <small
            ><MapPin :size="13" />
            {{ label('districts', draft.district) }}</small
          ></template
        >
      </div>
      <k-glass
        v-if="sellStep > 1"
        component="button"
        class="citymarkt-create-back"
        type="button"
        @click="sellStep--"
      >
        <ArrowLeft :size="18" />
        {{ phone.t('Apps.citymarkt.previous') }}
      </k-glass>
    </section>

    <section
      v-else-if="screen === 'chat' && selectedChat"
      class="citymarkt__chat"
    >
      <header>
        <k-button
          component="button"
          clear
          rounded
          @click="screen = 'main'; tab = 'inbox'"
          ><ArrowLeft :size="19"
        /></k-button>
        <div>
          <strong>{{
            selectedChat.inquiry.seller_account_id === selectedChat.accountId
              ? selectedChat.inquiry.buyer_name
              : selectedChat.inquiry.seller_name
          }}</strong
          ><small>{{ selectedChat.inquiry.title }}</small>
        </div>
      </header>
      <k-glass class="citymarkt__glass-chat-listing"
        ><div>
          <strong>{{ formatPrice(selectedChat.inquiry) }}</strong
          ><span>{{ selectedChat.inquiry.title }}</span>
        </div>
        <i>{{ label('status', selectedChat.inquiry.status) }}</i></k-glass
      >
      <div class="citymarkt__messages">
        <template v-for="item in chatTimeline" :key="item.key">
          <article
            v-if="item.kind === 'message'"
            :class="{
              own: item.value.sender_account_id === selectedChat.accountId,
            }"
          >
            <p>{{ item.value.body }}</p>
            <small>{{ messageTime(item.value.created_at) }}</small>
          </article>
          <CityMarktOfferCard
            v-else
            :account-id="selectedChat.accountId"
            :actionable="isOfferActionable(item.value)"
            :is-counter="item.isCounter"
            :offer="item.value"
            @accept="respondOffer('accepted')"
            @counter="openOfferPanel"
            @reject="respondOffer('rejected')"
          />
        </template>
      </div>
      <form
        v-if="offerPanelOpen"
        class="citymarkt__offer-panel"
        @submit.prevent="submitOffer"
      >
        <header>
          <div>
            <small>{{ phone.t('Apps.citymarkt.offerFor') }}</small>
            <strong>{{ selectedChat.inquiry.title }}</strong>
          </div>
          <k-button
            component="button"
            clear
            rounded
            type="button"
            @click="offerPanelOpen = false"
            ><X :size="16"
          /></k-button>
        </header>
        <label>
          {{ phone.t('Apps.citymarkt.offerAmount') }}
          <span
            ><b>$</b
            ><input
              v-model="offerAmount"
              inputmode="numeric"
              min="1"
              type="number"
          /></span>
        </label>
        <button type="submit" :disabled="offerSubmitting || !offerAmount">
          <BadgeDollarSign :size="16" />{{
            phone.t('Apps.citymarkt.sendOffer')
          }}
        </button>
      </form>
      <div
        v-if="
          canMakeOffer ||
          (selectedChat.inquiry.seller_account_id === selectedChat.accountId &&
            selectedChat.inquiry.status === 'active')
        "
        class="citymarkt__chat-actions"
      >
        <button v-if="canMakeOffer" type="button" @click="openOfferPanel">
          <BadgeDollarSign :size="14" />{{ offerButtonLabel }}
        </button>
        <button
          v-if="
            selectedChat.inquiry.seller_account_id === selectedChat.accountId &&
            selectedChat.inquiry.status === 'active'
          "
          type="button"
          @click="setListingStatus('reserved', selectedChat.inquiry.id)"
        >
          {{ phone.t('Apps.citymarkt.reserveForBuyer') }}
        </button>
      </div>
      <form class="citymarkt__chat-composer" @submit.prevent="sendChatMessage">
        <input
          v-model="message"
          maxlength="1000"
          :placeholder="phone.t('Apps.citymarkt.writeMessage')"
        /><button :disabled="!message.trim()"><Send :size="17" /></button>
      </form>
    </section>

    <section
      v-else-if="screen === 'report' && selectedListing"
      class="citymarkt__report"
    >
      <header>
        <k-button component="button" clear rounded @click="screen = 'detail'"
          ><ArrowLeft :size="19" /></k-button
        ><strong>{{ phone.t('Apps.citymarkt.reportListing') }}</strong>
      </header>
      <div>
        <h2>{{ phone.t('Apps.citymarkt.reportWhy') }}</h2>
        <CityMarktSelect
          class="citymarkt__form-select"
          :model-value="reportReason"
          :options="reportReasonOptions"
          @change="selectReportReason"
        /><textarea
          v-model="reportDetails"
          maxlength="500"
          :placeholder="phone.t('Apps.citymarkt.reportDetails')"
        /><button @click="submitReport">
          {{ phone.t('Apps.citymarkt.sendReport') }}</button
        ><button class="secondary" @click="blockSeller">
          {{ phone.t('Apps.citymarkt.blockSeller') }}
        </button>
      </div>
    </section>

    <k-tabbar
      v-if="screen === 'main'"
      component="nav"
      icons
    labels
    class="bottom-0 left-0 fixed"
    inner-class="!w-full !max-w-none !gap-0 !px-1"
      :aria-label="phone.t('Apps.citymarkt.name')"
    >
      <k-toolbar-pane class="citymarkt__tab-pane">
        <k-tabbar-link
          v-for="item in tabs"
          :key="item.id"
          component="button"
          :active="tab === item.id"
          :link-props="{ class: 'citymarkt-tab-button', type: 'button' }"
          @click="selectTab(item.id)"
        >
          <template #label>
            <span class="citymarkt__tab-label">
              {{ phone.t(`Apps.citymarkt.tabs.${item.id}`) }}
            </span>
          </template>
          <template #icon>
            <span
              class="citymarkt__tab-icon"
              :class="{ 'citymarkt__tab-icon--create': item.id === 'sell' }"
            >
              <k-icon>
                <component :is="item.icon" :size="20" />
              </k-icon>
              <k-badge v-if="item.id === 'inbox' && marketplace.counts.unread">
                {{ marketplace.counts.unread }}
              </k-badge>
            </span>
          </template>
        </k-tabbar-link>
      </k-toolbar-pane>
    </k-tabbar>
    <Transition name="toast"
      ><div v-if="feedback" class="citymarkt__toast">
        {{ feedback }}
      </div></Transition
    >
  </k-page>
</template>

<style scoped>
.citymarkt{--yellow:#ffc928;--ink:#171816;--panel:#242522;--muted:#a6a89f;position:absolute;inset:0;padding:48px 0 25px;overflow:hidden;background:#151613;color:#f8f8f4;font-family:Inter,system-ui,sans-serif}.citymarkt--light{--ink:#fff;--panel:#f1f1ed;--muted:#71736c;background:#fafaf7;color:#161714}.citymarkt button,.citymarkt input,.citymarkt textarea,.citymarkt select{font:inherit}.citymarkt button{color:inherit}.citymarkt__header{height:64px;padding:6px 16px 8px;display:flex;align-items:center;justify-content:space-between}.citymarkt__brand{display:flex;align-items:center;gap:4px;color:var(--yellow);font-size:10px;font-weight:900;letter-spacing:.08em;text-transform:uppercase}.citymarkt__header h1{margin:1px 0 0;font-size:25px;line-height:1}.citymarkt__round,.citymarkt__top-actions button{position:relative;width:34px;height:34px;border:0;border-radius:50%;display:grid;place-items:center;background:var(--panel)}.citymarkt__round i{position:absolute;top:5px;right:5px;width:6px;height:6px;border-radius:50%;background:#ff453a}.citymarkt__content{height:calc(100% - 64px - 58px);padding:0 14px 18px;overflow-y:auto;scrollbar-width:none}.citymarkt__search{height:38px;padding:0 10px;display:flex;align-items:center;gap:7px;border-radius:12px;background:var(--panel);color:var(--muted)}.citymarkt__search input{min-width:0;flex:1;border:0;outline:0;background:transparent;color:inherit;font-size:13px}.citymarkt__search button{padding:0;border:0;background:none}.citymarkt__categories{margin:12px -14px 2px;padding:0 14px 7px;display:flex;gap:10px;overflow-x:auto;scrollbar-width:none}.citymarkt__categories button{width:61px;flex:none;padding:0;border:0;background:none;color:var(--muted);font-size:9px;white-space:nowrap}.citymarkt__categories button span{width:42px;height:42px;margin:0 auto 4px;border-radius:13px;display:grid;place-items:center;background:var(--panel);color:#efb911}.citymarkt__categories button.active span{background:var(--yellow);color:#171816}.citymarkt__filters{margin-top:10px;display:grid;grid-template-columns:1fr 1fr;gap:6px}.citymarkt__filters select{min-width:0;padding:8px;border:0;border-radius:9px;background:var(--panel);color:inherit;font-size:10px}.citymarkt__filters select:last-child{grid-column:1/-1}.citymarkt__section-title{margin:11px 1px 8px}.citymarkt__section-title div{display:flex;align-items:end;justify-content:space-between}.citymarkt__section-title strong{font-size:15px}.citymarkt__section-title small{color:var(--muted);font-size:9px}.citymarkt__grid{display:grid;grid-template-columns:1fr 1fr;gap:13px 9px}.citymarkt__grid>button{min-width:0;padding:0;border:0;text-align:left;background:none}.citymarkt__card-image{position:relative;height:112px;margin-bottom:6px;display:block;border-radius:12px;background-size:cover!important;box-shadow:inset 0 0 0 1px #ffffff16}.citymarkt__card-image>i{position:absolute;left:6px;bottom:6px;padding:3px 6px;border-radius:6px;background:#161714d8;color:#fff;font-size:8px;font-style:normal;font-weight:800}.citymarkt__card-image>svg{position:absolute;top:7px;right:7px;padding:5px;box-sizing:content-box;border-radius:50%;background:#161714bb;color:#ffd02e}.citymarkt__grid button>strong{display:block;font-size:13px}.citymarkt__grid button>span:not(.citymarkt__card-image){display:block;overflow:hidden;font-size:11px;white-space:nowrap;text-overflow:ellipsis}.citymarkt__grid button>small,.citymarkt__preview-price+*+*+small{display:flex;align-items:center;gap:2px;overflow:hidden;color:var(--muted);font-size:8px;white-space:nowrap}.citymarkt__empty,.citymarkt__auth{min-height:260px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:7px;text-align:center;color:var(--muted)}.citymarkt__empty strong,.citymarkt__auth h2{margin:4px 0 0;color:inherit;font-size:16px}.citymarkt__empty span,.citymarkt__auth p{max-width:220px;margin:0;font-size:11px}.citymarkt__auth svg{color:var(--yellow)}.citymarkt__inquiries,.citymarkt__list{display:flex;flex-direction:column;gap:7px}.citymarkt__inquiries>button,.citymarkt__list>button{width:100%;padding:8px;border:0;border-radius:13px;display:flex;align-items:center;gap:9px;text-align:left;background:var(--panel)}.citymarkt__inquiries>button>span,.citymarkt__list>button>span{width:48px;height:48px;flex:none;border-radius:10px}.citymarkt__inquiries div,.citymarkt__list div{min-width:0;flex:1}.citymarkt__inquiries strong,.citymarkt__inquiries b,.citymarkt__inquiries small,.citymarkt__list strong,.citymarkt__list b,.citymarkt__list small{display:block;overflow:hidden;white-space:nowrap;text-overflow:ellipsis}.citymarkt__inquiries strong{font-size:12px}.citymarkt__inquiries b,.citymarkt__list b{font-size:10px}.citymarkt__inquiries small,.citymarkt__list small{color:var(--muted);font-size:9px}.citymarkt__inquiries i{min-width:17px;height:17px;padding:0 4px;border-radius:9px;display:grid;place-items:center;background:var(--yellow);color:#171816;font-size:9px;font-style:normal;font-weight:900}.citymarkt__profile{margin-bottom:12px;padding:12px;border-radius:15px;display:flex;align-items:center;gap:10px;background:linear-gradient(135deg,#3e3312,var(--panel))}.citymarkt__profile>span,.citymarkt__seller>span{width:44px;height:44px;border-radius:50%;display:grid;place-items:center;background:var(--yellow);color:#171816;font-size:19px;font-weight:900}.citymarkt__profile strong,.citymarkt__profile small{display:block}.citymarkt__profile small{color:var(--muted);font-size:9px}.citymarkt__segmented{margin-bottom:10px;padding:3px;border-radius:10px;display:flex;background:var(--panel)}.citymarkt__segmented button{flex:1;padding:6px;border:0;border-radius:8px;background:none;font-size:9px}.citymarkt__segmented button.active{background:var(--yellow);color:#171816;font-weight:800}.citymarkt__list strong{font-size:11px}.citymarkt__tabbar{position:absolute;right:0;bottom:22px;left:0;height:58px;padding:7px 7px 0;display:flex;justify-content:space-around;border-top:1px solid #ffffff12;background:#171815ed;backdrop-filter:blur(18px)}.citymarkt--light .citymarkt__tabbar{border-color:#00000012;background:#fafaf7ed}.citymarkt__tabbar button{width:54px;padding:0;border:0;display:flex;flex-direction:column;align-items:center;gap:2px;background:none;color:var(--muted);font-size:8px}.citymarkt__tabbar button>span{position:relative}.citymarkt__tabbar button.active{color:var(--yellow)}.citymarkt__tabbar button.sell span{width:37px;height:30px;margin-top:-4px;border-radius:10px;display:grid;place-items:center;background:var(--yellow);color:#171816}.citymarkt__tabbar button i{position:absolute;top:-5px;right:-9px;min-width:15px;height:15px;padding:0 3px;border-radius:8px;background:#ff453a;color:white;font-size:8px;font-style:normal}.citymarkt__detail,.citymarkt__sell,.citymarkt__chat,.citymarkt__report{position:absolute;inset:0;padding-top:46px;overflow:hidden;background:#151613}.citymarkt--light .citymarkt__detail,.citymarkt--light .citymarkt__sell,.citymarkt--light .citymarkt__chat,.citymarkt--light .citymarkt__report{background:#fafaf7}.citymarkt__top-actions{position:absolute;z-index:2;top:52px;right:12px;left:12px;display:flex;justify-content:space-between}.citymarkt__top-actions>div{display:flex;gap:6px}.citymarkt__hero{height:205px;background-size:cover!important;position:relative}.citymarkt__hero>span{position:absolute;right:10px;bottom:9px;padding:4px 7px;border-radius:7px;background:#151613c9;color:white;font-size:8px}.citymarkt__detail-body{height:calc(100% - 205px);padding:13px 15px 35px;overflow-y:auto}.citymarkt__price-row{display:flex;justify-content:space-between}.citymarkt__price-row h2{margin:0;font-size:22px}.citymarkt__price-row span{display:inline-block;padding:3px 7px;border-radius:6px;background:var(--yellow);color:#171816;font-size:8px;font-weight:900}.citymarkt__price-row>small{color:var(--muted);font-size:9px}.citymarkt__detail-body>h1{margin:8px 0 3px;font-size:18px}.citymarkt__meta{margin:0;display:flex;align-items:center;gap:3px;color:var(--muted);font-size:10px}.citymarkt__description{padding:13px 0;border-bottom:1px solid #ffffff15;font-size:11px;line-height:1.5;white-space:pre-wrap}.citymarkt__seller{padding:8px 0;display:flex;align-items:center;gap:9px}.citymarkt__seller>span{width:38px;height:38px;font-size:16px}.citymarkt__seller strong,.citymarkt__seller small{display:block}.citymarkt__seller small,.citymarkt__phone{color:var(--muted);font-size:9px}.citymarkt__composer textarea{width:100%;height:60px;padding:9px;border:1px solid #ffffff18;border-radius:11px;resize:none;background:var(--panel);color:inherit;font-size:10px}.citymarkt__composer button,.citymarkt__owner-actions button,.citymarkt__report>div button{width:100%;margin-top:7px;padding:10px;border:0;border-radius:11px;display:flex;align-items:center;justify-content:center;gap:5px;background:var(--yellow);color:#171816;font-size:10px;font-weight:900}.citymarkt__owner-actions{display:grid;grid-template-columns:1fr 1fr;gap:6px}.citymarkt__owner-actions button{margin:0}.citymarkt__owner-actions button.danger{background:#44221f;color:#ff796f}.citymarkt__inline-auth{padding:12px;border-radius:11px;background:var(--panel);color:var(--muted);text-align:center;font-size:10px}.citymarkt__sell>header,.citymarkt__chat>header,.citymarkt__report>header{height:54px;padding:5px 12px;display:flex;align-items:center;gap:8px;border-bottom:1px solid #ffffff12}.citymarkt__sell>header>button:first-child,.citymarkt__chat>header>button,.citymarkt__report>header>button{width:32px;height:32px;padding:0;border:0;border-radius:50%;display:grid;place-items:center;background:var(--panel)}.citymarkt__sell>header>div,.citymarkt__chat>header>div{flex:1}.citymarkt__sell>header strong,.citymarkt__sell>header small,.citymarkt__chat>header strong,.citymarkt__chat>header small{display:block}.citymarkt__sell>header small,.citymarkt__chat>header small{color:var(--muted);font-size:9px}.citymarkt__sell>header>button:last-child{padding:6px;border:0;background:none;color:var(--yellow);font-size:10px;font-weight:800}.citymarkt__sell>header>button:disabled{opacity:.35}.citymarkt__progress{height:3px;background:var(--panel)}.citymarkt__progress i{height:100%;display:block;background:var(--yellow);transition:width .25s}.citymarkt__sell-body{height:calc(100% - 83px);padding:20px 16px 58px;overflow-y:auto}.citymarkt__sell-body>svg{color:var(--yellow)}.citymarkt__sell-body h2{margin:7px 0 4px;font-size:21px}.citymarkt__sell-body>p{margin:0 0 13px;color:var(--muted);font-size:10px}.citymarkt__photo-picker{display:grid;grid-template-columns:repeat(3,1fr);gap:7px}.citymarkt__photo-picker button{aspect-ratio:1;border:2px solid transparent;border-radius:11px;background-size:cover!important}.citymarkt__photo-picker button.active{border-color:var(--yellow)}.citymarkt__photo-picker i{width:19px;height:19px;margin:5px;border-radius:50%;display:grid;place-items:center;background:var(--yellow);color:#171816;font-size:9px;font-style:normal;font-weight:900}.citymarkt__photo-picker button:not(.active) i{display:none}.citymarkt__sell-body label{margin-top:12px;display:block;color:var(--muted);font-size:9px;font-weight:700}.citymarkt__sell-body input:not([type=checkbox]),.citymarkt__sell-body textarea,.citymarkt__sell-body select,.citymarkt__report select,.citymarkt__report textarea{width:100%;margin-top:5px;padding:10px;border:1px solid #ffffff14;border-radius:10px;outline:0;background:var(--panel);color:inherit;font-size:11px}.citymarkt__sell-body textarea{height:105px;resize:none}.citymarkt__switch{display:flex!important;align-items:center;gap:8px}.citymarkt__switch input{display:none}.citymarkt__switch span{width:35px;height:20px;border-radius:12px;background:#484a45}.citymarkt__switch span:after{content:'';width:16px;height:16px;margin:2px;display:block;border-radius:50%;background:white;transition:transform .2s}.citymarkt__switch input:checked+span{background:var(--yellow)}.citymarkt__switch input:checked+span:after{transform:translateX(15px)}.citymarkt__preview-image{height:170px;margin:12px 0;border-radius:15px;background-size:cover!important}.citymarkt__preview-price{font-size:21px}.citymarkt__sell-body h3{margin:6px 0;font-size:16px}.citymarkt__sell-body>small{display:flex;gap:3px;color:var(--muted)}.citymarkt__previous{position:absolute;bottom:33px;left:16px;padding:7px;border:0;background:none;color:var(--muted);font-size:10px}.citymarkt__chat-listing{margin:8px 10px;padding:8px 10px;border-radius:11px;display:flex;align-items:center;justify-content:space-between;background:var(--panel)}.citymarkt__chat-listing strong,.citymarkt__chat-listing span{display:block;font-size:10px}.citymarkt__chat-listing i{padding:3px 6px;border-radius:6px;background:#3d3621;color:var(--yellow);font-size:8px;font-style:normal}.citymarkt__messages{height:calc(100% - 178px);padding:8px 12px;overflow-y:auto;display:flex;flex-direction:column;gap:7px}.citymarkt__messages article{max-width:80%;align-self:flex-start}.citymarkt__messages article.own{align-self:flex-end}.citymarkt__messages p{margin:0;padding:8px 10px;border-radius:12px 12px 12px 3px;background:var(--panel);font-size:10px;white-space:pre-wrap}.citymarkt__messages article.own p{border-radius:12px 12px 3px 12px;background:var(--yellow);color:#171816}.citymarkt__messages small{display:block;margin:2px 4px;color:var(--muted);font-size:7px;text-align:right}.citymarkt__chat-composer{position:absolute;right:8px;bottom:29px;left:8px;height:40px;padding:4px 4px 4px 10px;border-radius:14px;display:flex;background:var(--panel)}.citymarkt__chat-composer input{min-width:0;flex:1;border:0;outline:0;background:none;color:inherit;font-size:10px}.citymarkt__chat-composer button{width:32px;border:0;border-radius:11px;display:grid;place-items:center;background:var(--yellow);color:#171816}.citymarkt__reserve{position:absolute;right:12px;bottom:74px;padding:5px 8px;border:0;border-radius:7px;background:#3d3621;color:var(--yellow);font-size:8px}.citymarkt__report>header strong{font-size:14px}.citymarkt__report>div{padding:20px 16px}.citymarkt__report h2{font-size:19px}.citymarkt__report textarea{height:100px;resize:none}.citymarkt__report>div button.secondary{background:var(--panel);color:#ff796f}.citymarkt__toast{position:absolute;z-index:20;right:18px;bottom:92px;left:18px;padding:10px 12px;border-radius:11px;background:#f4f4ee;color:#171816;box-shadow:0 8px 30px #0007;font-size:10px;font-weight:800;text-align:center}.toast-enter-active,.toast-leave-active{transition:.2s}.toast-enter-from,.toast-leave-to{transform:translateY(8px);opacity:0}
.citymarkt{--color-primary:var(--yellow);position:relative;height:100%;padding:0;background:#151613!important}.citymarkt--light{background:#fafaf7!important}.citymarkt-navbar{--k-safe-area-top:46px;position:absolute;z-index:5;top:0;right:0;left:0}.citymarkt__content{position:absolute;inset:0;height:auto;padding:108px 14px 112px}.citymarkt__navbar-action,.citymarkt__tab-icon{position:relative;display:grid;place-items:center}.citymarkt__navbar-action>.k-badge{position:absolute;top:-7px;right:-9px;pointer-events:none}.citymarkt__tab-icon>.k-badge{position:absolute;top:-7px;right:-11px;pointer-events:none}.citymarkt button.k-link{color:var(--color-primary)}
.citymarkt__categories{margin-right:0;margin-left:0;padding-right:0;padding-left:0;display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:4px;overflow-x:visible}
.citymarkt__categories button{width:auto;min-width:0}
.citymarkt__filters .citymarkt-select:last-child{grid-column:1/-1}
.citymarkt__segmented{padding:4px;gap:4px;border:1px solid #ffffff0b;border-radius:12px}
.citymarkt__segmented button{min-height:36px;padding:8px 7px;border-radius:9px;display:flex;align-items:center;justify-content:center;gap:5px;font-size:11px;font-weight:700;transition:background .18s ease,color .18s ease,transform .18s ease}
.citymarkt__segmented button:active{transform:scale(.98)}
.citymarkt__segmented button svg{flex:none}
.citymarkt__segmented button span{min-width:19px;height:19px;padding:0 5px;border-radius:10px;display:grid;place-items:center;background:#ffffff10;font-size:9px;font-weight:900}
.citymarkt__segmented button.active span{background:#17181626}
:global(.citymarkt--light) .citymarkt__segmented{border-color:#0000000b}
:global(.citymarkt--light) .citymarkt__segmented button span{background:#0000000b}
.citymarkt__messages{position:absolute;top:158px;right:0;bottom:116px;left:0;height:auto}
.citymarkt__messages .citymarkt-offer{width:92%;max-width:92%}
.citymarkt__chat-actions{position:absolute;right:9px;bottom:75px;left:9px;display:flex;gap:5px}
.citymarkt__chat-actions button{min-height:34px;flex:1;padding:6px 8px;border:1px solid #ffc92831;border-radius:11px;display:flex;align-items:center;justify-content:center;gap:4px;background:#3d3621;color:var(--yellow);font-size:8px;font-weight:900}
.citymarkt__offer-panel{position:absolute;z-index:6;right:9px;bottom:75px;left:9px;padding:11px;border:1px solid #ffc92840;border-radius:15px;background:#292a27;box-shadow:0 14px 35px #000b}
.citymarkt__offer-panel header{display:flex;align-items:flex-start;justify-content:space-between;gap:8px}.citymarkt__offer-panel header div{min-width:0}.citymarkt__offer-panel header small,.citymarkt__offer-panel header strong{display:block}.citymarkt__offer-panel header small{color:var(--yellow);font-size:8px;font-weight:900;text-transform:uppercase}.citymarkt__offer-panel header strong{overflow:hidden;font-size:12px;white-space:nowrap;text-overflow:ellipsis}.citymarkt__offer-panel header button{width:27px;height:27px;flex:none;padding:0;border:0;border-radius:9px;display:grid;place-items:center;background:#ffffff0b}.citymarkt__offer-panel label{margin-top:9px;display:block;color:var(--muted);font-size:8px;font-weight:800}.citymarkt__offer-panel label>span{height:39px;margin-top:4px;padding:0 10px;border:1px solid #ffffff16;border-radius:11px;display:flex;align-items:center;gap:5px;background:#151613}.citymarkt__offer-panel label b{color:var(--yellow);font-size:16px}.citymarkt__offer-panel input{min-width:0;flex:1;border:0;outline:0;background:none;color:inherit;font-size:16px;font-weight:900}.citymarkt__offer-panel>button{width:100%;min-height:36px;margin-top:8px;border:0;border-radius:11px;display:flex;align-items:center;justify-content:center;gap:5px;background:var(--yellow);color:#171816;font-size:9px;font-weight:900}.citymarkt__offer-panel>button:disabled{opacity:.45}
:global(.citymarkt--light) .citymarkt__offer-panel{background:#fff;box-shadow:0 14px 35px #0003}:global(.citymarkt--light) .citymarkt__offer-panel label>span{border-color:#00000012;background:#f4f4ef}
.citymarkt__form-select{margin-top:5px}
.citymarkt__card-image--empty{background:linear-gradient(145deg,#2b2d28,#1e201d)!important}.citymarkt__image-placeholder{position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:4px;color:var(--muted)}.citymarkt__image-placeholder small{font-size:7px;font-weight:700}.citymarkt__thumb--empty{display:grid!important;place-items:center;background:linear-gradient(145deg,#2b2d28,#1e201d)!important;color:var(--muted)}
.citymarkt__photo-actions{display:grid;grid-template-columns:1fr 1fr;gap:8px}.citymarkt__photo-actions>button{min-width:0;padding:11px 9px;border:1px solid #ffffff12;border-radius:14px;display:flex;flex-direction:column;align-items:flex-start;text-align:left;background:var(--panel)}.citymarkt__photo-actions>button>span{width:34px;height:34px;margin-bottom:8px;border-radius:11px;display:grid;place-items:center;background:#3d3621;color:var(--yellow)}.citymarkt__photo-actions strong{font-size:10px}.citymarkt__photo-actions small{margin-top:2px;color:var(--muted);font-size:7px;line-height:1.35}.citymarkt__selected-heading{margin:15px 1px 7px;display:flex;align-items:center;justify-content:space-between}.citymarkt__selected-heading strong{font-size:11px}.citymarkt__selected-heading span{padding:3px 6px;border-radius:7px;background:var(--panel);color:var(--yellow);font-size:8px;font-weight:900}.citymarkt__selection-gallery{height:142px;border-radius:14px}.citymarkt__selected-strip{margin-top:7px;display:flex;gap:6px;overflow-x:auto;scrollbar-width:none}.citymarkt__selected-strip button{position:relative;width:46px;height:46px;flex:none;border:1px solid #ffffff1d;border-radius:9px;background-position:center!important;background-size:cover!important}.citymarkt__selected-strip button i{position:absolute;left:3px;bottom:3px;width:15px;height:15px;border-radius:50%;display:grid;place-items:center;background:var(--yellow);color:#171816;font-size:7px;font-style:normal;font-weight:900}.citymarkt__selected-strip button svg{position:absolute;top:3px;right:3px;padding:2px;box-sizing:content-box;border-radius:50%;background:#11120fc7;color:#fff}
.citymarkt__photo-source{position:absolute;z-index:8;inset:46px 0 0;padding:14px 14px 33px;background:#151613}.citymarkt--light .citymarkt__photo-source{background:#fafaf7}.citymarkt__photo-source>header{height:52px;display:flex;align-items:center;gap:8px}.citymarkt__photo-source>header>div{min-width:0;flex:1}.citymarkt__photo-source>header small,.citymarkt__photo-source>header strong{display:block}.citymarkt__photo-source>header small{color:var(--yellow);font-size:8px;font-weight:900;text-transform:uppercase}.citymarkt__photo-source>header strong{font-size:18px}.citymarkt__photo-source>header>span{padding:4px 7px;border-radius:8px;background:var(--panel);color:var(--yellow);font-size:8px;font-weight:900}.citymarkt__photo-source>header>button{width:31px;height:31px;padding:0;border:0;border-radius:50%;display:grid;place-items:center;background:var(--panel)}.citymarkt__photo-source>.citymarkt__photo-picker{max-height:calc(100% - 58px);padding-bottom:12px;overflow-y:auto;scrollbar-width:none}.citymarkt__photo-source .citymarkt__photo-picker button{position:relative;background-position:center!important}.citymarkt__capture{height:calc(100% - 52px);display:flex;flex-direction:column;align-items:center}.citymarkt__viewfinder{position:relative;width:100%;min-height:305px;overflow:hidden;border-radius:18px;background-position:center!important;background-size:cover!important;box-shadow:inset 0 0 0 1px #ffffff1c}.citymarkt__viewfinder:after{content:'';position:absolute;inset:0;background:linear-gradient(180deg,#0001,#00000038)}.citymarkt__viewfinder>i{position:absolute;z-index:2;width:25px;height:25px;border-color:#fff;border-style:solid}.citymarkt__viewfinder .corner-tl{top:18px;left:18px;border-width:2px 0 0 2px}.citymarkt__viewfinder .corner-tr{top:18px;right:18px;border-width:2px 2px 0 0}.citymarkt__viewfinder .corner-bl{bottom:18px;left:18px;border-width:0 0 2px 2px}.citymarkt__viewfinder .corner-br{right:18px;bottom:18px;border-width:0 2px 2px 0}.citymarkt__camera-flash{position:absolute;z-index:4;inset:0;background:#fff;opacity:0;pointer-events:none;transition:opacity .12s}.citymarkt__camera-flash.active{opacity:.9}.citymarkt__capture p{max-width:230px;margin:9px 0;color:var(--muted);font-size:8px;text-align:center}.citymarkt__shutter{width:58px;height:58px;padding:0;border:5px solid #f5f5ee;border-radius:50%;display:grid;place-items:center;background:var(--yellow);color:#171816;box-shadow:0 0 0 2px #ffffff42}.citymarkt__preview-image{overflow:hidden}
:global(.citymarkt--light) .citymarkt__card-image--empty,:global(.citymarkt--light) .citymarkt__thumb--empty{background:linear-gradient(145deg,#ecece7,#dedfd8)!important}:global(.citymarkt--light) .citymarkt__photo-actions>button{border-color:#00000010}:global(.citymarkt--light) .citymarkt__selected-strip button{border-color:#00000018}
.citymarkt__sell>header strong{font-size:13px}.citymarkt__sell>header small{font-size:10px}.citymarkt__sell>header>button:last-child{font-size:11px}.citymarkt__sell-body h2{font-size:23px;line-height:1.15}.citymarkt__sell-body>p{font-size:11px;line-height:1.45}.citymarkt__sell-body label{font-size:10.5px}.citymarkt__sell-body input:not([type=checkbox]),.citymarkt__sell-body textarea{padding:11px 12px;font-size:12px}.citymarkt__sell-body input:not([type=checkbox]){min-height:41px}.citymarkt__sell-body textarea{line-height:1.4}.citymarkt__switch{font-size:10.5px!important}.citymarkt__previous{font-size:11px}.citymarkt__photo-actions strong{font-size:11px}.citymarkt__photo-actions small{font-size:8.5px;line-height:1.4}.citymarkt__selected-heading strong{font-size:12px}.citymarkt__selected-heading span{font-size:9px}.citymarkt__sell-body h3{font-size:18px}.citymarkt__sell-body>small{font-size:10px}.citymarkt__sell :deep(.citymarkt-select__trigger){height:41px;padding:0 12px;font-size:12px}.citymarkt__sell :deep(.citymarkt-select__menu button){min-height:35px;padding:8px;font-size:11px}.citymarkt__sell :deep(.citymarkt-gallery__empty strong){font-size:13px}.citymarkt__sell :deep(.citymarkt-gallery__empty small){font-size:9px;line-height:1.4}
.citymarkt__field-heading{display:flex;align-items:center;justify-content:space-between;gap:8px}.citymarkt__field-heading>small{color:#ff9c72;font-size:8.5px;font-weight:850;white-space:nowrap;transition:color .18s ease}.citymarkt__field-heading>small.valid{color:#62dc8e}
.citymarkt__pages-share{width:100%;margin:4px 0 8px;padding:10px 12px;border:1px solid #ffc92855;border-radius:12px;display:flex;align-items:center;gap:8px;text-align:left;background:#ffc92816;color:var(--yellow)!important}.citymarkt__pages-share span{flex:1}.citymarkt__pages-share strong,.citymarkt__pages-share small{display:block}.citymarkt__pages-share strong{font-size:10px}.citymarkt__pages-share small{color:var(--muted);font-size:8px}

/* Keep marketplace copy readable at the physical phone scale. */
.citymarkt__brand{font-size:12px}
.citymarkt__categories button{font-size:10.5px}
.citymarkt__filters select,.citymarkt__section-title small{font-size:12px}
.citymarkt__card-image>i,.citymarkt__hero>span,.citymarkt__price-row span,.citymarkt__chat-listing i,.citymarkt__reserve{font-size:10.5px}
.citymarkt__grid button>span:not(.citymarkt__card-image){font-size:13px}
.citymarkt__grid button>small,.citymarkt__preview-price+*+*+small{font-size:11.5px}
.citymarkt__empty span,.citymarkt__auth p,.citymarkt__description{font-size:13px}
.citymarkt__inquiries strong,.citymarkt__list strong{font-size:14px}
.citymarkt__inquiries b,.citymarkt__list b,.citymarkt__profile small,.citymarkt__price-row>small,.citymarkt__seller small,.citymarkt__phone{font-size:11.5px}
.citymarkt__inquiries small,.citymarkt__list small{font-size:11px}
.citymarkt__inquiries i,.citymarkt__tabbar button i,.citymarkt__photo-picker i,.citymarkt__selected-strip button i{font-size:10px}
.citymarkt__tabbar button{font-size:10.5px}
.citymarkt__meta,.citymarkt__inline-auth,.citymarkt__toast{font-size:12px}
.citymarkt__composer textarea,.citymarkt__chat-composer input{font-size:13px}
.citymarkt__composer button,.citymarkt__owner-actions button,.citymarkt__report>div button{font-size:13px}
.citymarkt__sell>header small,.citymarkt__chat>header small,.citymarkt__sell>header>button:last-child{font-size:12px}
.citymarkt__sell-body>p,.citymarkt__sell-body label,.citymarkt__switch,.citymarkt__previous,.citymarkt__sell-body>small{font-size:12px!important}
.citymarkt__sell-body input:not([type=checkbox]),.citymarkt__sell-body textarea,.citymarkt__sell-body select,.citymarkt__report select,.citymarkt__report textarea{font-size:13px}
.citymarkt__chat-listing strong,.citymarkt__chat-listing span,.citymarkt__messages p{font-size:13px}
.citymarkt__messages small{font-size:10.5px}
.citymarkt__segmented button span{font-size:10.5px}
.citymarkt__chat-actions button,.citymarkt__offer-panel>button{font-size:12px}
.citymarkt__offer-panel header small,.citymarkt__offer-panel label{font-size:11.5px}
.citymarkt__offer-panel header strong{font-size:14px}
.citymarkt__image-placeholder small,.citymarkt__photo-actions small,.citymarkt__capture p{font-size:11.5px}
.citymarkt__photo-actions strong,.citymarkt__selected-heading strong{font-size:13px}
.citymarkt__selected-heading span,.citymarkt__photo-source>header small,.citymarkt__photo-source>header>span{font-size:11px}
.citymarkt__field-heading>small{font-size:10.5px}
.citymarkt__pages-share strong{font-size:12.5px}
.citymarkt__pages-share small{font-size:11px}
.citymarkt__sell :deep(.citymarkt-select__trigger){font-size:13px}
.citymarkt__sell :deep(.citymarkt-select__menu button){font-size:12px}
.citymarkt__sell :deep(.citymarkt-gallery__empty small){font-size:11.5px}
.citymarkt__tab-pane {
  width: 100% !important;
  max-width: none;
  margin-right: auto;
  margin-left: auto;
  flex: none;
  gap: 2px;
  padding: 0 4px;
}
.citymarkt__category-icon {
  width: 42px;
  height: 42px;
  margin: 0 auto 4px;
  border-radius: 9999px;
  display: grid;
  place-items: center;
  color: var(--yellow);
  transition:
    filter 0.18s ease,
    transform 0.18s ease;
}
.citymarkt__categories button {
  transition:
    color 0.18s ease,
    transform 0.18s ease;
}
.citymarkt__categories button:hover .citymarkt__category-icon {
  filter: brightness(1.15);
  transform: translateY(-2px);
}
.citymarkt__categories button.active {
  color: #fff;
  font-weight: 800;
}
.citymarkt__categories button.active .citymarkt__category-icon {
  filter: brightness(1.22);
  transform: scale(1.06);
}
:global(.citymarkt--light) .citymarkt__categories button.active {
  color: #171816;
}
.citymarkt__glass-actions {
  position: absolute;
  z-index: 2;
  top: 52px;
  right: 12px;
  left: 12px;
  display: flex;
  justify-content: space-between;
}
.citymarkt__glass-actions > div {
  display: flex;
  gap: 6px;
}
.citymarkt__glass-list > .k-glass {
  width: 100%;
  flex: none;
  border-radius: 13px;
}
.citymarkt__glass-list > .k-glass > button {
  width: 100%;
  padding: 8px;
  border: 0;
  display: flex;
  align-items: center;
  gap: 9px;
  text-align: left;
  background: transparent;
}
.citymarkt__glass-list > .k-glass > button > span {
  width: 48px;
  height: 48px;
  flex: none;
  border-radius: 10px;
}
.citymarkt__grid {
  gap: 10px;
  align-items: start;
}
.citymarkt__section-actions {
  display: flex;
  align-items: center;
  gap: 8px;
}
.citymarkt-layout-toggle {
  width: 36px;
  height: 36px;
  flex: none;
  border-radius: 9999px;
  overflow: hidden;
}
.citymarkt-layout-toggle > button {
  width: 100%;
  height: 100%;
  padding: 0;
  border: 0;
  display: grid;
  place-items: center;
  background: transparent;
  color: inherit;
}
.citymarkt-listing-card {
  min-width: 0;
  border-radius: 16px;
  overflow: hidden;
  transition:
    filter 0.18s ease,
    transform 0.18s ease;
}
.citymarkt-listing-card:hover {
  filter: brightness(1.08);
  transform: translateY(-2px);
}
.citymarkt-listing-card > button {
  width: 100%;
  min-width: 0;
  padding: 0;
  border: 0;
  display: block;
  overflow: hidden;
  background: transparent;
  text-align: left;
}
.citymarkt-listing-card .citymarkt__card-image {
  height: 108px;
  margin: 0;
  border-radius: 0;
  display: block;
}
.citymarkt-listing-card__body {
  min-width: 0;
  padding: 9px 10px 10px;
  display: block;
}
.citymarkt-listing-card__body > strong {
  display: block;
  overflow: hidden;
  font-size: 15px;
  line-height: 18px;
  white-space: nowrap;
  text-overflow: ellipsis;
}
.citymarkt-listing-card__title {
  min-height: 31px;
  margin-top: 2px;
  display: -webkit-box;
  overflow: hidden;
  font-size: 12px;
  line-height: 15px;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
}
.citymarkt-listing-card__body > small {
  min-width: 0;
  margin-top: 7px;
  display: flex;
  align-items: center;
  gap: 3px;
  overflow: hidden;
  color: var(--muted);
  font-size: 9.5px;
  line-height: 12px;
  white-space: nowrap;
  text-overflow: ellipsis;
}
.citymarkt__grid--wide {
  grid-template-columns: minmax(0, 1fr);
}
.citymarkt__grid--wide .citymarkt-listing-card > button {
  display: grid;
  grid-template-columns: 116px minmax(0, 1fr);
}
.citymarkt__grid--wide .citymarkt-listing-card .citymarkt__card-image {
  width: 116px;
  height: 116px;
}
.citymarkt__grid--wide .citymarkt-listing-card__body {
  min-height: 116px;
  padding: 12px;
  display: flex;
  flex-direction: column;
}
.citymarkt__grid--wide .citymarkt-listing-card__title {
  min-height: 0;
  margin-top: 4px;
  font-size: 13px;
  line-height: 16px;
}
.citymarkt__grid--wide .citymarkt-listing-card__body > small {
  margin-top: auto;
}
.citymarkt-profile-listing > button {
  min-height: 76px;
  padding: 8px !important;
}
.citymarkt-profile-listing > button > span {
  width: 60px !important;
  height: 60px !important;
  background-position: center !important;
  background-size: cover !important;
}
.citymarkt-profile-listing__body > b {
  display: block;
  overflow: hidden;
  font-size: 14px;
  line-height: 17px;
  white-space: nowrap;
  text-overflow: ellipsis;
}
.citymarkt-profile-listing__body > strong {
  margin-top: 1px;
  font-size: 12px;
  line-height: 15px;
}
.citymarkt-profile-listing__body > small {
  width: fit-content;
  margin-top: 4px;
  padding: 2px 6px;
  border-radius: 9999px;
  background: #ffffff10;
  font-size: 9px;
  line-height: 13px;
}
:global(.citymarkt--light) .citymarkt-profile-listing__body > small {
  background: #0000000c;
}
.citymarkt__glass-profile {
  margin-bottom: 12px;
  padding: 12px;
  border-radius: 15px;
  display: flex;
  align-items: center;
  gap: 10px;
}
.citymarkt__glass-profile > span {
  width: 44px;
  height: 44px;
  border-radius: 50%;
  display: grid;
  place-items: center;
  background: var(--yellow);
  color: #171816;
  font-size: 19px;
  font-weight: 900;
}
.citymarkt__glass-profile strong,
.citymarkt__glass-profile small {
  display: block;
}
.citymarkt__glass-profile small {
  color: var(--muted);
  font-size: 11.5px;
}
.citymarkt__glass-segmented {
  margin-bottom: 10px;
  padding: 4px;
  border-radius: 12px;
  display: flex;
  gap: 4px;
}
.citymarkt__glass-segmented button {
  min-height: 36px;
  flex: 1;
  padding: 8px 7px;
  border: 0;
  border-radius: 9px;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 5px;
  background: transparent;
  font-size: 11px;
  font-weight: 700;
}
.citymarkt__glass-segmented button.active {
  background: var(--yellow);
  color: #171816;
}
.citymarkt__glass-segmented button span {
  min-width: 19px;
  height: 19px;
  padding: 0 5px;
  border-radius: 10px;
  display: grid;
  place-items: center;
  background: #ffffff10;
  font-size: 10.5px;
  font-weight: 900;
}
.citymarkt__glass-auth {
  padding: 12px;
  border-radius: 11px;
  color: var(--muted);
  text-align: center;
  font-size: 12px;
}
.citymarkt__photo-actions > .k-glass {
  min-width: 0;
  border-radius: 14px;
}
.citymarkt__photo-actions > .k-glass > button {
  width: 100%;
  padding: 11px 9px;
  border: 0;
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  text-align: left;
  background: transparent;
}
.citymarkt__photo-actions > .k-glass > button > span {
  width: 34px;
  height: 34px;
  margin-bottom: 8px;
  border-radius: 11px;
  display: grid;
  place-items: center;
  color: var(--yellow);
}
.citymarkt__glass-chat-listing {
  margin: 8px 10px;
  padding: 8px 10px;
  border-radius: 11px;
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.citymarkt__glass-chat-listing strong,
.citymarkt__glass-chat-listing span {
  display: block;
  font-size: 13px;
}
.citymarkt__glass-chat-listing i {
  padding: 3px 6px;
  border-radius: 6px;
  color: var(--yellow);
  font-size: 10.5px;
  font-style: normal;
}
.citymarkt-create-navbar {
  --k-safe-area-top: 46px;
  position: absolute;
  z-index: 5;
  top: 0;
  right: 0;
  left: 0;
}
.citymarkt-create-action {
  height: 44px;
  border-radius: 9999px;
}
.citymarkt-create-action--close {
  width: 44px;
}
.citymarkt-create-action--next {
  min-width: 58px;
}
.citymarkt-create-close,
.citymarkt-create-next {
  width: 100%;
  height: 44px;
  padding: 0;
  border: 0;
  appearance: none;
  background: transparent;
  color: inherit;
}
.citymarkt-create-close {
  display: grid;
  place-items: center;
}
.citymarkt-create-next {
  min-width: 58px;
  padding: 0 13px;
  display: grid;
  place-items: center;
  font-size: 12px;
  font-weight: 800;
}
.citymarkt-create-next:disabled {
  opacity: 0.38;
}
.citymarkt__sell > .citymarkt__progress {
  position: absolute;
  z-index: 4;
  top: 101px;
  right: 0;
  left: 0;
  background: transparent;
}
.citymarkt__sell > .citymarkt__sell-body {
  position: absolute;
  top: 104px;
  right: 0;
  bottom: 0;
  left: 0;
  height: auto;
}
.citymarkt__field-glass {
  min-height: 44px;
  margin-top: 5px;
  border-radius: 9999px;
  overflow: hidden;
}
.citymarkt__field-glass--textarea {
  min-height: 112px;
  border-radius: 18px;
}
.citymarkt__field-glass > input,
.citymarkt__field-glass > textarea {
  width: 100%;
  min-height: 44px;
  margin: 0 !important;
  padding: 11px 14px !important;
  border: 0 !important;
  outline: 0;
  background: transparent !important;
  color: inherit;
  font-size: 13px !important;
}
.citymarkt__field-glass > textarea {
  min-height: 112px;
  resize: none;
  line-height: 1.4;
}
.citymarkt-create-back {
  position: absolute;
  z-index: 6;
  bottom: 32px;
  left: 16px;
  height: 44px;
  padding: 0 15px;
  border: 0;
  border-radius: 9999px;
  display: flex;
  align-items: center;
  gap: 7px;
  appearance: none;
  color: inherit;
  font-size: 12px;
  font-weight: 700;
}
.citymarkt__photo-picker button.active {
  border-color: transparent;
  filter: brightness(1.08);
  transform: scale(0.98);
}
.citymarkt__chat-actions button,
.citymarkt__offer-panel,
.citymarkt__pages-share {
  border-color: transparent;
}

.citymarkt__tab-label {
  display: block;
  max-width: 52px;
  overflow: hidden;
  font-size: 9.5px;
  line-height: 12px;
  text-overflow: ellipsis;
  white-space: nowrap;
}
:global(.citymarkt__tab-pane) {
  width: 100% !important;
  max-width: none;
  margin-right: auto;
  margin-left: auto;
  flex: none;
}
:global(.citymarkt-tab-button) {
  width: auto !important;
  min-width: 0 !important;
  flex: 1 1 0 !important;
  padding-right: 3px !important;
  padding-left: 3px !important;
}
.citymarkt__tab-icon--create {
  width: 38px;
  height: 30px;
  margin-top: -4px;
  border-radius: 10px;
  background: var(--yellow);
  color: #171816;
  box-shadow: 0 4px 12px #00000030;
}
</style>
