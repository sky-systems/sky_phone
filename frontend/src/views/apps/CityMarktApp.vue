<script setup lang="ts">
import {
  ArrowLeft,
  Bell,
  BriefcaseBusiness,
  CarFront,
  ChevronRight,
  CirclePlus,
  Gift,
  Hammer,
  Heart,
  House,
  ImagePlus,
  Inbox,
  Laptop,
  MapPin,
  MessageCircle,
  MoreHorizontal,
  Search,
  Send,
  Shirt,
  Tag,
  UserRound,
  Wrench,
  X,
} from 'lucide-vue-next'
import { computed, onMounted, ref } from 'vue'

import { useAccountStore } from '@/stores/account'
import { useMarketplaceStore } from '@/stores/marketplace'
import { useMediaStore } from '@/stores/media'
import { usePhoneStore } from '@/stores/phone'
import type {
  MarketplaceCategory,
  MarketplaceChat,
  MarketplaceCondition,
  MarketplaceListing,
  MarketplaceListingDraft,
  MarketplaceListingSummary,
  MarketplacePriceType,
} from '@/types/marketplace'

type Tab = 'discover' | 'search' | 'sell' | 'inbox' | 'profile'
type Screen = 'main' | 'detail' | 'sell' | 'chat' | 'report'

const phone = usePhoneStore()
const account = useAccountStore()
const marketplace = useMarketplaceStore()
const media = useMediaStore()
const tab = ref<Tab>('discover')
const screen = ref<Screen>('main')
const selectedListing = ref<MarketplaceListing | null>(null)
const selectedChat = ref<MarketplaceChat | null>(null)
const search = ref('')
const category = ref<MarketplaceCategory | 'all'>('all')
const district = ref('all')
const sort = ref('newest')
const profileMode = ref<'own' | 'favorites'>('own')
const message = ref('')
const firstMessage = ref('')
const feedback = ref('')
const sellStep = ref(1)
const submitting = ref(false)
const selectedPhotoIds = ref<string[]>([])
const reportReason = ref('spam')
const reportDetails = ref('')
const editing = ref<{ id: string; revision: number } | null>(null)
const draft = ref({
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
const conditions: MarketplaceCondition[] = ['new', 'very_good', 'used', 'defective']
const priceTypes: MarketplacePriceType[] = ['fixed', 'negotiable', 'free']
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
const canContinueSell = computed(() => {
  if (sellStep.value === 1) return selectedPhotoIds.value.length > 0
  if (sellStep.value === 2)
    return draft.value.title.trim().length >= 5 && draft.value.description.trim().length >= 20
  if (sellStep.value === 3)
    return draft.value.priceType === 'free' || Number(draft.value.price) > 0
  return true
})

function label(group: string, value: string): string {
  return phone.t(`Apps.citymarkt.${group}.${value}`)
}

function formatPrice(item: { price: number | string | null; price_type: MarketplacePriceType }): string {
  if (item.price_type === 'free') return phone.t('Apps.citymarkt.free')
  const value = Number(item.price ?? 0)
  const formatted = new Intl.NumberFormat(phone.lang, { maximumFractionDigits: 0 }).format(value)
  return item.price_type === 'negotiable'
    ? phone.t('Apps.citymarkt.negotiablePrice', { price: formatted })
    : phone.t('Apps.citymarkt.money', { price: formatted })
}

function relativeDate(value: string): string {
  const timestamp = new Date(value.replace(' ', 'T')).getTime()
  const hours = Math.max(1, Math.floor((Date.now() - timestamp) / 3_600_000))
  if (hours < 24) return phone.t('Apps.citymarkt.hoursAgo', { count: String(hours) })
  return phone.t('Apps.citymarkt.daysAgo', { count: String(Math.floor(hours / 24)) })
}

function setFeedback(key: string): void {
  feedback.value = phone.t(key)
  window.setTimeout(() => {
    feedback.value = ''
  }, 2600)
}

async function loadFeed(): Promise<void> {
  await marketplace.load({
    category: category.value,
    district: district.value,
    search: search.value,
    sort: sort.value,
  })
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
  if (next === 'inbox' && isAuthenticated.value) await marketplace.loadInquiries()
  if (next === 'profile' && isAuthenticated.value) {
    await Promise.all([marketplace.loadOwn(), marketplace.load({ favorites: true })])
  }
}

async function openListing(item: MarketplaceListingSummary): Promise<void> {
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
  if (index >= 0) selectedPhotoIds.value.splice(index, 1)
  else if (selectedPhotoIds.value.length < 6) selectedPhotoIds.value.push(id)
}

function resetSell(): void {
  editing.value = null
  sellStep.value = 1
  selectedPhotoIds.value = []
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
  editing.value = { id: selectedListing.value.id, revision: selectedListing.value.revision }
  selectedPhotoIds.value = selectedListing.value.images.map((image) => image.media_id)
  draft.value = {
    category: selectedListing.value.category,
    condition: selectedListing.value.item_condition,
    description: selectedListing.value.description,
    district: selectedListing.value.district ?? 'los_santos',
    price: selectedListing.value.price === null ? '' : String(selectedListing.value.price),
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
    ? await marketplace.update(editing.value.id, editing.value.revision, listingDraft())
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
    screen.value = 'chat'
    await Promise.all([marketplace.loadInquiries(), marketplace.loadCounts()])
  }
}

async function sendChatMessage(): Promise<void> {
  if (!selectedChat.value || !message.value.trim()) return
  const body = message.value
  message.value = ''
  const response = await marketplace.sendMessage({ body, inquiryId: selectedChat.value.inquiry.id })
  if (response.success) {
    const refreshed = await marketplace.getInquiry(selectedChat.value.inquiry.id)
    if (refreshed.data) selectedChat.value = refreshed.data
  } else setFeedback(`Apps.citymarkt.errors.${response.error ?? 'default'}`)
}

async function setListingStatus(status: string, inquiryId?: string): Promise<void> {
  const listingId = selectedListing.value?.id ?? selectedChat.value?.inquiry.listing_id
  if (!listingId) return
  if (await marketplace.setStatus(listingId, status, inquiryId)) {
    setFeedback('Apps.citymarkt.statusChanged')
    if (selectedListing.value) {
      const response = await marketplace.get(listingId)
      if (response.data) selectedListing.value = response.data
    }
    if (selectedChat.value) {
      const response = await marketplace.getInquiry(selectedChat.value.inquiry.id)
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
  await loadFeed()
  if (isAuthenticated.value) await marketplace.loadCounts()
})
</script>

<template>
  <main class="citymarkt" :class="{ 'citymarkt--light': !phone.isDarkMode }">
    <header v-if="screen === 'main'" class="citymarkt__header">
      <div>
        <span class="citymarkt__brand"><Tag :size="14" /> CityMarkt</span>
        <h1>{{ phone.t(`Apps.citymarkt.tabs.${tab}`) }}</h1>
      </div>
      <button
        v-if="isAuthenticated"
        class="citymarkt__round"
        type="button"
        :aria-label="phone.t('Apps.citymarkt.tabs.inbox')"
        @click="selectTab('inbox')"
      >
        <Bell :size="18" />
        <i v-if="marketplace.counts.unread" />
      </button>
    </header>

    <section v-if="screen === 'main'" class="citymarkt__content">
      <template v-if="tab === 'discover' || tab === 'search'">
        <form class="citymarkt__search" @submit.prevent="loadFeed">
          <Search :size="17" />
          <input v-model="search" :placeholder="phone.t('Apps.citymarkt.searchPlaceholder')" />
          <button v-if="search" type="button" @click="search = ''; loadFeed()"><X :size="15" /></button>
        </form>

        <div v-if="tab === 'discover'" class="citymarkt__categories">
          <button
            v-for="item in categories"
            :key="item.id"
            :class="{ active: category === item.id }"
            type="button"
            @click="category = category === item.id ? 'all' : item.id; loadFeed()"
          >
            <span><component :is="item.icon" :size="19" /></span>
            {{ label('categories', item.id) }}
          </button>
        </div>

        <div v-else class="citymarkt__filters">
          <select v-model="category" @change="loadFeed">
            <option value="all">{{ phone.t('Apps.citymarkt.allCategories') }}</option>
            <option v-for="item in categories" :key="item.id" :value="item.id">
              {{ label('categories', item.id) }}
            </option>
          </select>
          <select v-model="district" @change="loadFeed">
            <option value="all">{{ phone.t('Apps.citymarkt.allDistricts') }}</option>
            <option v-for="item in districts" :key="item" :value="item">
              {{ label('districts', item) }}
            </option>
          </select>
          <select v-model="sort" @change="loadFeed">
            <option value="newest">{{ phone.t('Apps.citymarkt.sortNewest') }}</option>
            <option value="price_asc">{{ phone.t('Apps.citymarkt.sortPriceAsc') }}</option>
            <option value="price_desc">{{ phone.t('Apps.citymarkt.sortPriceDesc') }}</option>
          </select>
        </div>

        <div class="citymarkt__section-title">
          <div><strong>{{ phone.t('Apps.citymarkt.freshOffers') }}</strong><small>{{ marketplace.items.length }} {{ phone.t('Apps.citymarkt.offers') }}</small></div>
        </div>
        <div v-if="marketplace.isLoading" class="citymarkt__empty">{{ phone.t('Common.loading') }}</div>
        <div v-else-if="!displayItems.length" class="citymarkt__empty">
          <Search :size="32" /><strong>{{ phone.t('Apps.citymarkt.noListings') }}</strong><span>{{ phone.t('Apps.citymarkt.noListingsBody') }}</span>
        </div>
        <div v-else class="citymarkt__grid">
          <button v-for="item in displayItems" :key="item.id" type="button" @click="openListing(item)">
            <span class="citymarkt__card-image" :style="{ background: item.image ?? '#303238' }">
              <i v-if="item.status === 'reserved'">{{ phone.t('Apps.citymarkt.status.reserved') }}</i>
              <Heart v-if="item.is_favorite" :size="15" fill="currentColor" />
            </span>
            <strong>{{ formatPrice(item) }}</strong>
            <span>{{ item.title }}</span>
            <small><MapPin :size="11" /> {{ item.district ? label('districts', item.district) : phone.t('Apps.citymarkt.noDistrict') }} · {{ relativeDate(item.created_at) }}</small>
          </button>
        </div>
      </template>

      <template v-else-if="tab === 'inbox'">
        <div v-if="!isAuthenticated" class="citymarkt__auth"><UserRound :size="40" /><h2>{{ phone.t('Apps.citymarkt.signInTitle') }}</h2><p>{{ phone.t('Apps.citymarkt.signInBody') }}</p></div>
        <div v-else-if="!marketplace.inquiries.length" class="citymarkt__empty"><MessageCircle :size="36" /><strong>{{ phone.t('Apps.citymarkt.noMessages') }}</strong><span>{{ phone.t('Apps.citymarkt.noMessagesBody') }}</span></div>
        <div v-else class="citymarkt__inquiries">
          <button v-for="item in marketplace.inquiries" :key="item.id" type="button" @click="openChat(item.id)">
            <span :style="{ background: item.image ?? '#303238' }" />
            <div><strong>{{ item.other_name }}</strong><b>{{ item.title }}</b><small>{{ item.last_message }}</small></div>
            <i v-if="Number(item.unread)">{{ item.unread }}</i><ChevronRight :size="16" />
          </button>
        </div>
      </template>

      <template v-else-if="tab === 'profile'">
        <div v-if="!isAuthenticated" class="citymarkt__auth"><UserRound :size="40" /><h2>{{ phone.t('Apps.citymarkt.signInTitle') }}</h2><p>{{ phone.t('Apps.citymarkt.signInBody') }}</p></div>
        <template v-else>
          <div class="citymarkt__profile"><span>{{ account.email.charAt(0).toUpperCase() }}</span><div><strong>{{ account.email.split('@')[0] }}</strong><small>{{ account.email }}</small></div></div>
          <div class="citymarkt__segmented"><button :class="{ active: profileMode === 'own' }" @click="profileMode = 'own'">{{ phone.t('Apps.citymarkt.myListings') }} ({{ marketplace.counts.active }})</button><button :class="{ active: profileMode === 'favorites' }" @click="profileMode = 'favorites'">{{ phone.t('Apps.citymarkt.favorites') }}</button></div>
          <div v-if="!displayItems.length" class="citymarkt__empty"><Tag :size="34" /><strong>{{ phone.t('Apps.citymarkt.noProfileListings') }}</strong></div>
          <div v-else class="citymarkt__list">
            <button v-for="item in displayItems" :key="item.id" @click="openListing(item)"><span :style="{ background: item.image ?? '#303238' }" /><div><strong>{{ item.title }}</strong><b>{{ formatPrice(item) }}</b><small>{{ label('status', item.status) }}</small></div><ChevronRight :size="17" /></button>
          </div>
        </template>
      </template>
    </section>

    <section v-else-if="screen === 'detail' && selectedListing" class="citymarkt__detail">
      <div class="citymarkt__top-actions"><button @click="screen = 'main'"><ArrowLeft :size="19" /></button><div><button v-if="!selectedListing.is_owner" @click="toggleFavorite"><Heart :size="19" :fill="selectedListing.is_favorite ? 'currentColor' : 'none'" /></button><button v-if="!selectedListing.is_owner" @click="screen = 'report'"><MoreHorizontal :size="20" /></button></div></div>
      <div class="citymarkt__hero" :style="{ background: selectedListing.images[0]?.gradient ?? '#303238' }"><span>{{ selectedListing.images.length }} {{ phone.t('Apps.citymarkt.photos') }}</span></div>
      <div class="citymarkt__detail-body">
        <div class="citymarkt__price-row"><div><h2>{{ formatPrice(selectedListing) }}</h2><span v-if="selectedListing.status !== 'active'">{{ label('status', selectedListing.status) }}</span></div><small>{{ relativeDate(selectedListing.created_at) }}</small></div>
        <h1>{{ selectedListing.title }}</h1>
        <p class="citymarkt__meta"><MapPin :size="14" /> {{ selectedListing.district ? label('districts', selectedListing.district) : phone.t('Apps.citymarkt.noDistrict') }} · {{ label('conditions', selectedListing.item_condition) }}</p>
        <p class="citymarkt__description">{{ selectedListing.description }}</p>
        <div class="citymarkt__seller"><span>{{ selectedListing.seller_name.charAt(0).toUpperCase() }}</span><div><strong>{{ selectedListing.seller_name }}</strong><small>{{ selectedListing.seller_active }} {{ phone.t('Apps.citymarkt.activeListings') }}</small></div></div>
        <p v-if="selectedListing.phone_number" class="citymarkt__phone">{{ phone.t('Apps.citymarkt.phone') }}: {{ selectedListing.phone_number }}</p>
        <template v-if="selectedListing.is_owner">
          <div class="citymarkt__owner-actions"><button v-if="selectedListing.status !== 'sold' && selectedListing.status !== 'removed'" @click="editListing">{{ phone.t('Apps.citymarkt.edit') }}</button><button v-if="selectedListing.status === 'reserved' || selectedListing.status === 'expired'" @click="setListingStatus('active')">{{ phone.t('Apps.citymarkt.makeActive') }}</button><button v-if="selectedListing.status === 'active' || selectedListing.status === 'reserved'" @click="setListingStatus('sold')">{{ phone.t('Apps.citymarkt.markSold') }}</button><button v-if="selectedListing.status !== 'sold' && selectedListing.status !== 'removed'" class="danger" @click="setListingStatus('removed')">{{ phone.t('Apps.citymarkt.remove') }}</button></div>
        </template>
        <template v-else-if="isAuthenticated">
          <div class="citymarkt__composer"><textarea v-model="firstMessage" maxlength="1000" :placeholder="phone.t('Apps.citymarkt.messagePlaceholder')" /><button :disabled="!firstMessage.trim()" @click="sendFirstMessage"><MessageCircle :size="17" />{{ phone.t('Apps.citymarkt.contactSeller') }}</button></div>
        </template>
        <div v-else class="citymarkt__inline-auth">{{ phone.t('Apps.citymarkt.signInToMessage') }}</div>
      </div>
    </section>

    <section v-else-if="screen === 'sell'" class="citymarkt__sell">
      <header><button @click="resetSell(); screen = 'main'; tab = 'discover'"><X :size="20" /></button><div><strong>{{ phone.t(editing ? 'Apps.citymarkt.editListing' : 'Apps.citymarkt.createListing') }}</strong><small>{{ phone.t('Apps.citymarkt.step', { current: String(sellStep), total: '4' }) }}</small></div><button :disabled="!canContinueSell || submitting" @click="sellStep < 4 ? sellStep++ : publish()">{{ sellStep < 4 ? phone.t('Apps.citymarkt.next') : phone.t(editing ? 'Apps.citymarkt.save' : 'Apps.citymarkt.publish') }}</button></header>
      <div class="citymarkt__progress"><i :style="{ width: `${sellStep * 25}%` }" /></div>
      <div class="citymarkt__sell-body">
        <template v-if="sellStep === 1"><ImagePlus :size="32" /><h2>{{ phone.t('Apps.citymarkt.addPhotos') }}</h2><p>{{ phone.t('Apps.citymarkt.addPhotosBody') }}</p><div class="citymarkt__photo-picker"><button v-for="photo in media.photos" :key="photo.id" :class="{ active: selectedPhotoIds.includes(photo.id) }" :style="{ background: photo.gradient }" @click="togglePhoto(photo.id)"><i>{{ selectedPhotoIds.indexOf(photo.id) + 1 }}</i></button></div></template>
        <template v-else-if="sellStep === 2"><h2>{{ phone.t('Apps.citymarkt.describeOffer') }}</h2><label>{{ phone.t('Apps.citymarkt.title') }}<input v-model="draft.title" maxlength="70" /></label><label>{{ phone.t('Apps.citymarkt.description') }}<textarea v-model="draft.description" maxlength="2000" /></label><label>{{ phone.t('Apps.citymarkt.category') }}<select v-model="draft.category"><option v-for="item in categories" :key="item.id" :value="item.id">{{ label('categories', item.id) }}</option></select></label><label>{{ phone.t('Apps.citymarkt.condition') }}<select v-model="draft.condition"><option v-for="item in conditions" :key="item" :value="item">{{ label('conditions', item) }}</option></select></label></template>
        <template v-else-if="sellStep === 3"><h2>{{ phone.t('Apps.citymarkt.priceAndPlace') }}</h2><label>{{ phone.t('Apps.citymarkt.priceType') }}<select v-model="draft.priceType"><option v-for="item in priceTypes" :key="item" :value="item">{{ label('priceTypes', item) }}</option></select></label><label v-if="draft.priceType !== 'free'">{{ phone.t('Apps.citymarkt.price') }}<input v-model="draft.price" inputmode="numeric" type="number" min="1" /></label><label>{{ phone.t('Apps.citymarkt.district') }}<select v-model="draft.district"><option v-for="item in districts" :key="item" :value="item">{{ label('districts', item) }}</option></select></label><label class="citymarkt__switch"><input v-model="draft.showPhone" type="checkbox" /><span />{{ phone.t('Apps.citymarkt.showPhone') }}</label></template>
        <template v-else><h2>{{ phone.t('Apps.citymarkt.preview') }}</h2><div class="citymarkt__preview-image" :style="{ background: media.photos.find((photo) => photo.id === selectedPhotoIds[0])?.gradient }" /><strong class="citymarkt__preview-price">{{ formatPrice({ price: draft.price, price_type: draft.priceType }) }}</strong><h3>{{ draft.title }}</h3><p>{{ draft.description }}</p><small><MapPin :size="13" /> {{ label('districts', draft.district) }}</small></template>
      </div>
      <button v-if="sellStep > 1" class="citymarkt__previous" @click="sellStep--">{{ phone.t('Apps.citymarkt.previous') }}</button>
    </section>

    <section v-else-if="screen === 'chat' && selectedChat" class="citymarkt__chat">
      <header><button @click="screen = 'main'; tab = 'inbox'"><ArrowLeft :size="19" /></button><div><strong>{{ selectedChat.inquiry.seller_account_id === selectedChat.accountId ? selectedChat.inquiry.buyer_name : selectedChat.inquiry.seller_name }}</strong><small>{{ selectedChat.inquiry.title }}</small></div></header>
      <div class="citymarkt__chat-listing"><div><strong>{{ formatPrice(selectedChat.inquiry) }}</strong><span>{{ selectedChat.inquiry.title }}</span></div><i>{{ label('status', selectedChat.inquiry.status) }}</i></div>
      <div class="citymarkt__messages"><article v-for="item in selectedChat.messages" :key="item.id" :class="{ own: item.sender_account_id === selectedChat.accountId }"><p>{{ item.body }}</p><small>{{ new Intl.DateTimeFormat(phone.lang, { hour: '2-digit', minute: '2-digit' }).format(new Date(item.created_at.replace(' ', 'T'))) }}</small></article></div>
      <button v-if="selectedChat.inquiry.seller_account_id === selectedChat.accountId && selectedChat.inquiry.status === 'active'" class="citymarkt__reserve" @click="setListingStatus('reserved', selectedChat.inquiry.id)">{{ phone.t('Apps.citymarkt.reserveForBuyer') }}</button>
      <form class="citymarkt__chat-composer" @submit.prevent="sendChatMessage"><input v-model="message" maxlength="1000" :placeholder="phone.t('Apps.citymarkt.writeMessage')" /><button :disabled="!message.trim()"><Send :size="17" /></button></form>
    </section>

    <section v-else-if="screen === 'report' && selectedListing" class="citymarkt__report">
      <header><button @click="screen = 'detail'"><ArrowLeft :size="19" /></button><strong>{{ phone.t('Apps.citymarkt.reportListing') }}</strong></header>
      <div><h2>{{ phone.t('Apps.citymarkt.reportWhy') }}</h2><select v-model="reportReason"><option v-for="item in ['prohibited', 'fraud', 'spam', 'offensive', 'other']" :key="item" :value="item">{{ label('reportReasons', item) }}</option></select><textarea v-model="reportDetails" maxlength="500" :placeholder="phone.t('Apps.citymarkt.reportDetails')" /><button @click="submitReport">{{ phone.t('Apps.citymarkt.sendReport') }}</button><button class="secondary" @click="blockSeller">{{ phone.t('Apps.citymarkt.blockSeller') }}</button></div>
    </section>

    <nav v-if="screen === 'main'" class="citymarkt__tabbar">
      <button v-for="item in tabs" :key="item.id" :class="{ active: tab === item.id, sell: item.id === 'sell' }" @click="selectTab(item.id)"><span><component :is="item.icon" :size="item.id === 'sell' ? 23 : 20" /><i v-if="item.id === 'inbox' && marketplace.counts.unread">{{ marketplace.counts.unread }}</i></span>{{ phone.t(`Apps.citymarkt.tabs.${item.id}`) }}</button>
    </nav>
    <Transition name="toast"><div v-if="feedback" class="citymarkt__toast">{{ feedback }}</div></Transition>
  </main>
</template>

<style scoped>
.citymarkt{--yellow:#ffc928;--ink:#171816;--panel:#242522;--muted:#a6a89f;position:absolute;inset:0;padding:48px 0 25px;overflow:hidden;background:#151613;color:#f8f8f4;font-family:Inter,system-ui,sans-serif}.citymarkt--light{--ink:#fff;--panel:#f1f1ed;--muted:#71736c;background:#fafaf7;color:#161714}.citymarkt button,.citymarkt input,.citymarkt textarea,.citymarkt select{font:inherit}.citymarkt button{color:inherit}.citymarkt__header{height:64px;padding:6px 16px 8px;display:flex;align-items:center;justify-content:space-between}.citymarkt__brand{display:flex;align-items:center;gap:4px;color:var(--yellow);font-size:10px;font-weight:900;letter-spacing:.08em;text-transform:uppercase}.citymarkt__header h1{margin:1px 0 0;font-size:25px;line-height:1}.citymarkt__round,.citymarkt__top-actions button{position:relative;width:34px;height:34px;border:0;border-radius:50%;display:grid;place-items:center;background:var(--panel)}.citymarkt__round i{position:absolute;top:5px;right:5px;width:6px;height:6px;border-radius:50%;background:#ff453a}.citymarkt__content{height:calc(100% - 64px - 58px);padding:0 14px 18px;overflow-y:auto;scrollbar-width:none}.citymarkt__search{height:38px;padding:0 10px;display:flex;align-items:center;gap:7px;border-radius:12px;background:var(--panel);color:var(--muted)}.citymarkt__search input{min-width:0;flex:1;border:0;outline:0;background:transparent;color:inherit;font-size:13px}.citymarkt__search button{padding:0;border:0;background:none}.citymarkt__categories{margin:12px -14px 2px;padding:0 14px 7px;display:flex;gap:10px;overflow-x:auto;scrollbar-width:none}.citymarkt__categories button{width:61px;flex:none;padding:0;border:0;background:none;color:var(--muted);font-size:9px;white-space:nowrap}.citymarkt__categories button span{width:42px;height:42px;margin:0 auto 4px;border-radius:13px;display:grid;place-items:center;background:var(--panel);color:#efb911}.citymarkt__categories button.active span{background:var(--yellow);color:#171816}.citymarkt__filters{margin-top:10px;display:grid;grid-template-columns:1fr 1fr;gap:6px}.citymarkt__filters select{min-width:0;padding:8px;border:0;border-radius:9px;background:var(--panel);color:inherit;font-size:10px}.citymarkt__filters select:last-child{grid-column:1/-1}.citymarkt__section-title{margin:11px 1px 8px}.citymarkt__section-title div{display:flex;align-items:end;justify-content:space-between}.citymarkt__section-title strong{font-size:15px}.citymarkt__section-title small{color:var(--muted);font-size:9px}.citymarkt__grid{display:grid;grid-template-columns:1fr 1fr;gap:13px 9px}.citymarkt__grid>button{min-width:0;padding:0;border:0;text-align:left;background:none}.citymarkt__card-image{position:relative;height:112px;margin-bottom:6px;display:block;border-radius:12px;background-size:cover!important;box-shadow:inset 0 0 0 1px #ffffff16}.citymarkt__card-image>i{position:absolute;left:6px;bottom:6px;padding:3px 6px;border-radius:6px;background:#161714d8;color:#fff;font-size:8px;font-style:normal;font-weight:800}.citymarkt__card-image>svg{position:absolute;top:7px;right:7px;padding:5px;box-sizing:content-box;border-radius:50%;background:#161714bb;color:#ffd02e}.citymarkt__grid button>strong{display:block;font-size:13px}.citymarkt__grid button>span:not(.citymarkt__card-image){display:block;overflow:hidden;font-size:11px;white-space:nowrap;text-overflow:ellipsis}.citymarkt__grid button>small,.citymarkt__preview-price+*+*+small{display:flex;align-items:center;gap:2px;overflow:hidden;color:var(--muted);font-size:8px;white-space:nowrap}.citymarkt__empty,.citymarkt__auth{min-height:260px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:7px;text-align:center;color:var(--muted)}.citymarkt__empty strong,.citymarkt__auth h2{margin:4px 0 0;color:inherit;font-size:16px}.citymarkt__empty span,.citymarkt__auth p{max-width:220px;margin:0;font-size:11px}.citymarkt__auth svg{color:var(--yellow)}.citymarkt__inquiries,.citymarkt__list{display:flex;flex-direction:column;gap:7px}.citymarkt__inquiries>button,.citymarkt__list>button{width:100%;padding:8px;border:0;border-radius:13px;display:flex;align-items:center;gap:9px;text-align:left;background:var(--panel)}.citymarkt__inquiries>button>span,.citymarkt__list>button>span{width:48px;height:48px;flex:none;border-radius:10px}.citymarkt__inquiries div,.citymarkt__list div{min-width:0;flex:1}.citymarkt__inquiries strong,.citymarkt__inquiries b,.citymarkt__inquiries small,.citymarkt__list strong,.citymarkt__list b,.citymarkt__list small{display:block;overflow:hidden;white-space:nowrap;text-overflow:ellipsis}.citymarkt__inquiries strong{font-size:12px}.citymarkt__inquiries b,.citymarkt__list b{font-size:10px}.citymarkt__inquiries small,.citymarkt__list small{color:var(--muted);font-size:9px}.citymarkt__inquiries i{min-width:17px;height:17px;padding:0 4px;border-radius:9px;display:grid;place-items:center;background:var(--yellow);color:#171816;font-size:9px;font-style:normal;font-weight:900}.citymarkt__profile{margin-bottom:12px;padding:12px;border-radius:15px;display:flex;align-items:center;gap:10px;background:linear-gradient(135deg,#3e3312,var(--panel))}.citymarkt__profile>span,.citymarkt__seller>span{width:44px;height:44px;border-radius:50%;display:grid;place-items:center;background:var(--yellow);color:#171816;font-size:19px;font-weight:900}.citymarkt__profile strong,.citymarkt__profile small{display:block}.citymarkt__profile small{color:var(--muted);font-size:9px}.citymarkt__segmented{margin-bottom:10px;padding:3px;border-radius:10px;display:flex;background:var(--panel)}.citymarkt__segmented button{flex:1;padding:6px;border:0;border-radius:8px;background:none;font-size:9px}.citymarkt__segmented button.active{background:var(--yellow);color:#171816;font-weight:800}.citymarkt__list strong{font-size:11px}.citymarkt__tabbar{position:absolute;right:0;bottom:22px;left:0;height:58px;padding:7px 7px 0;display:flex;justify-content:space-around;border-top:1px solid #ffffff12;background:#171815ed;backdrop-filter:blur(18px)}.citymarkt--light .citymarkt__tabbar{border-color:#00000012;background:#fafaf7ed}.citymarkt__tabbar button{width:54px;padding:0;border:0;display:flex;flex-direction:column;align-items:center;gap:2px;background:none;color:var(--muted);font-size:8px}.citymarkt__tabbar button>span{position:relative}.citymarkt__tabbar button.active{color:var(--yellow)}.citymarkt__tabbar button.sell span{width:37px;height:30px;margin-top:-4px;border-radius:10px;display:grid;place-items:center;background:var(--yellow);color:#171816}.citymarkt__tabbar button i{position:absolute;top:-5px;right:-9px;min-width:15px;height:15px;padding:0 3px;border-radius:8px;background:#ff453a;color:white;font-size:8px;font-style:normal}.citymarkt__detail,.citymarkt__sell,.citymarkt__chat,.citymarkt__report{position:absolute;inset:0;padding-top:46px;overflow:hidden;background:#151613}.citymarkt--light .citymarkt__detail,.citymarkt--light .citymarkt__sell,.citymarkt--light .citymarkt__chat,.citymarkt--light .citymarkt__report{background:#fafaf7}.citymarkt__top-actions{position:absolute;z-index:2;top:52px;right:12px;left:12px;display:flex;justify-content:space-between}.citymarkt__top-actions>div{display:flex;gap:6px}.citymarkt__hero{height:205px;background-size:cover!important;position:relative}.citymarkt__hero>span{position:absolute;right:10px;bottom:9px;padding:4px 7px;border-radius:7px;background:#151613c9;color:white;font-size:8px}.citymarkt__detail-body{height:calc(100% - 205px);padding:13px 15px 35px;overflow-y:auto}.citymarkt__price-row{display:flex;justify-content:space-between}.citymarkt__price-row h2{margin:0;font-size:22px}.citymarkt__price-row span{display:inline-block;padding:3px 7px;border-radius:6px;background:var(--yellow);color:#171816;font-size:8px;font-weight:900}.citymarkt__price-row>small{color:var(--muted);font-size:9px}.citymarkt__detail-body>h1{margin:8px 0 3px;font-size:18px}.citymarkt__meta{margin:0;display:flex;align-items:center;gap:3px;color:var(--muted);font-size:10px}.citymarkt__description{padding:13px 0;border-bottom:1px solid #ffffff15;font-size:11px;line-height:1.5;white-space:pre-wrap}.citymarkt__seller{padding:8px 0;display:flex;align-items:center;gap:9px}.citymarkt__seller>span{width:38px;height:38px;font-size:16px}.citymarkt__seller strong,.citymarkt__seller small{display:block}.citymarkt__seller small,.citymarkt__phone{color:var(--muted);font-size:9px}.citymarkt__composer textarea{width:100%;height:60px;padding:9px;border:1px solid #ffffff18;border-radius:11px;resize:none;background:var(--panel);color:inherit;font-size:10px}.citymarkt__composer button,.citymarkt__owner-actions button,.citymarkt__report>div button{width:100%;margin-top:7px;padding:10px;border:0;border-radius:11px;display:flex;align-items:center;justify-content:center;gap:5px;background:var(--yellow);color:#171816;font-size:10px;font-weight:900}.citymarkt__owner-actions{display:grid;grid-template-columns:1fr 1fr;gap:6px}.citymarkt__owner-actions button{margin:0}.citymarkt__owner-actions button.danger{background:#44221f;color:#ff796f}.citymarkt__inline-auth{padding:12px;border-radius:11px;background:var(--panel);color:var(--muted);text-align:center;font-size:10px}.citymarkt__sell>header,.citymarkt__chat>header,.citymarkt__report>header{height:54px;padding:5px 12px;display:flex;align-items:center;gap:8px;border-bottom:1px solid #ffffff12}.citymarkt__sell>header>button:first-child,.citymarkt__chat>header>button,.citymarkt__report>header>button{width:32px;height:32px;padding:0;border:0;border-radius:50%;display:grid;place-items:center;background:var(--panel)}.citymarkt__sell>header>div,.citymarkt__chat>header>div{flex:1}.citymarkt__sell>header strong,.citymarkt__sell>header small,.citymarkt__chat>header strong,.citymarkt__chat>header small{display:block}.citymarkt__sell>header small,.citymarkt__chat>header small{color:var(--muted);font-size:9px}.citymarkt__sell>header>button:last-child{padding:6px;border:0;background:none;color:var(--yellow);font-size:10px;font-weight:800}.citymarkt__sell>header>button:disabled{opacity:.35}.citymarkt__progress{height:3px;background:var(--panel)}.citymarkt__progress i{height:100%;display:block;background:var(--yellow);transition:width .25s}.citymarkt__sell-body{height:calc(100% - 83px);padding:20px 16px 58px;overflow-y:auto}.citymarkt__sell-body>svg{color:var(--yellow)}.citymarkt__sell-body h2{margin:7px 0 4px;font-size:21px}.citymarkt__sell-body>p{margin:0 0 13px;color:var(--muted);font-size:10px}.citymarkt__photo-picker{display:grid;grid-template-columns:repeat(3,1fr);gap:7px}.citymarkt__photo-picker button{aspect-ratio:1;border:2px solid transparent;border-radius:11px;background-size:cover!important}.citymarkt__photo-picker button.active{border-color:var(--yellow)}.citymarkt__photo-picker i{width:19px;height:19px;margin:5px;border-radius:50%;display:grid;place-items:center;background:var(--yellow);color:#171816;font-size:9px;font-style:normal;font-weight:900}.citymarkt__photo-picker button:not(.active) i{display:none}.citymarkt__sell-body label{margin-top:12px;display:block;color:var(--muted);font-size:9px;font-weight:700}.citymarkt__sell-body input:not([type=checkbox]),.citymarkt__sell-body textarea,.citymarkt__sell-body select,.citymarkt__report select,.citymarkt__report textarea{width:100%;margin-top:5px;padding:10px;border:1px solid #ffffff14;border-radius:10px;outline:0;background:var(--panel);color:inherit;font-size:11px}.citymarkt__sell-body textarea{height:105px;resize:none}.citymarkt__switch{display:flex!important;align-items:center;gap:8px}.citymarkt__switch input{display:none}.citymarkt__switch span{width:35px;height:20px;border-radius:12px;background:#484a45}.citymarkt__switch span:after{content:'';width:16px;height:16px;margin:2px;display:block;border-radius:50%;background:white;transition:transform .2s}.citymarkt__switch input:checked+span{background:var(--yellow)}.citymarkt__switch input:checked+span:after{transform:translateX(15px)}.citymarkt__preview-image{height:170px;margin:12px 0;border-radius:15px;background-size:cover!important}.citymarkt__preview-price{font-size:21px}.citymarkt__sell-body h3{margin:6px 0;font-size:16px}.citymarkt__sell-body>small{display:flex;gap:3px;color:var(--muted)}.citymarkt__previous{position:absolute;bottom:33px;left:16px;padding:7px;border:0;background:none;color:var(--muted);font-size:10px}.citymarkt__chat-listing{margin:8px 10px;padding:8px 10px;border-radius:11px;display:flex;align-items:center;justify-content:space-between;background:var(--panel)}.citymarkt__chat-listing strong,.citymarkt__chat-listing span{display:block;font-size:10px}.citymarkt__chat-listing i{padding:3px 6px;border-radius:6px;background:#3d3621;color:var(--yellow);font-size:8px;font-style:normal}.citymarkt__messages{height:calc(100% - 178px);padding:8px 12px;overflow-y:auto;display:flex;flex-direction:column;gap:7px}.citymarkt__messages article{max-width:80%;align-self:flex-start}.citymarkt__messages article.own{align-self:flex-end}.citymarkt__messages p{margin:0;padding:8px 10px;border-radius:12px 12px 12px 3px;background:var(--panel);font-size:10px;white-space:pre-wrap}.citymarkt__messages article.own p{border-radius:12px 12px 3px 12px;background:var(--yellow);color:#171816}.citymarkt__messages small{display:block;margin:2px 4px;color:var(--muted);font-size:7px;text-align:right}.citymarkt__chat-composer{position:absolute;right:8px;bottom:29px;left:8px;height:40px;padding:4px 4px 4px 10px;border-radius:14px;display:flex;background:var(--panel)}.citymarkt__chat-composer input{min-width:0;flex:1;border:0;outline:0;background:none;color:inherit;font-size:10px}.citymarkt__chat-composer button{width:32px;border:0;border-radius:11px;display:grid;place-items:center;background:var(--yellow);color:#171816}.citymarkt__reserve{position:absolute;right:12px;bottom:74px;padding:5px 8px;border:0;border-radius:7px;background:#3d3621;color:var(--yellow);font-size:8px}.citymarkt__report>header strong{font-size:14px}.citymarkt__report>div{padding:20px 16px}.citymarkt__report h2{font-size:19px}.citymarkt__report textarea{height:100px;resize:none}.citymarkt__report>div button.secondary{background:var(--panel);color:#ff796f}.citymarkt__toast{position:absolute;z-index:20;right:18px;bottom:92px;left:18px;padding:10px 12px;border-radius:11px;background:#f4f4ee;color:#171816;box-shadow:0 8px 30px #0007;font-size:10px;font-weight:800;text-align:center}.toast-enter-active,.toast-leave-active{transition:.2s}.toast-enter-from,.toast-leave-to{transform:translateY(8px);opacity:0}
.citymarkt__categories{margin-right:0;margin-left:0;padding-right:0;padding-left:0;display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:4px;overflow-x:visible}
.citymarkt__categories button{width:auto;min-width:0}
</style>
