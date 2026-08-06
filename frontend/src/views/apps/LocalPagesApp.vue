<script setup lang="ts">
import {
  ArrowLeft,
  Bookmark,
  Camera,
  ChevronLeft,
  ChevronRight,
  Compass,
  Heart,
  MapPin,
  Plus,
  Search,
  Send,
  Store,
  Trash2,
  UserRound,
  X,
} from 'lucide-vue-next'
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'

import CityMarktSelect from '@/components/citymarkt/CityMarktSelect.vue'
import { useAccountStore } from '@/stores/account'
import { useMediaStore } from '@/stores/media'
import { usePagesStore } from '@/stores/pages'
import { usePhoneStore } from '@/stores/phone'
import type { PagesCategory, PagesPost } from '@/types/pages'

type Screen = 'main' | 'detail' | 'compose'
type Tab = 'feed' | 'create' | 'profile'

const phone = usePhoneStore()
const account = useAccountStore()
const media = useMediaStore()
const pages = usePagesStore()
const router = useRouter()
const screen = ref<Screen>('main')
const tab = ref<Tab>('feed')
const profileMode = ref<'own' | 'saved'>('own')
const selected = ref<PagesPost | null>(null)
const galleryIndex = ref(0)
const search = ref('')
const category = ref<string>('all')
const feedback = ref('')
const draft = ref({
  body: '',
  category: 'recommendation' as Exclude<PagesCategory, 'citymarkt'>,
  district: 'los_santos',
  images: [] as string[],
  title: '',
})

const categoryIds: PagesCategory[] = [
  'recommendation', 'wanted', 'service', 'event', 'place', 'community', 'citymarkt',
]
const composeCategoryIds = categoryIds.filter((item) => item !== 'citymarkt')
const districts = ['los_santos', 'vinewood', 'vespucci', 'south_los_santos', 'sandy_shores', 'paleto_bay', 'blaine_county']
const categoryOptions = computed(() => [
  { label: phone.t('Apps.localPages.allCategories'), value: 'all' },
  ...categoryIds.map((value) => ({ label: label('categories', value), value })),
])
const composeCategoryOptions = computed(() => composeCategoryIds.map((value) => ({
  label: label('categories', value), value,
})))
const districtOptions = computed(() => districts.map((value) => ({
  label: phone.t(`Apps.citymarkt.districts.${value}`), value,
})))
const displayedPosts = computed(() => tab.value === 'profile'
  ? (profileMode.value === 'own' ? pages.ownItems : pages.savedItems)
  : pages.items)
const isAuthenticated = computed(() => Boolean(account.email))
const selectedPhotos = computed(() => draft.value.images
  .map((id) => media.photos.find((photo) => photo.id === id))
  .filter((photo) => photo !== undefined))
const canPublish = computed(() => {
  const title = draft.value.title.trim().length
  const body = draft.value.body.trim().length
  return title >= 5 && title <= 80 && body >= 10 && body <= 1500
})

function label(group: string, value: string): string {
  return phone.t(`Apps.localPages.${group}.${value}`)
}

function relativeDate(value: string): string {
  const elapsed = Math.max(0, Date.now() - new Date(value.replace(' ', 'T')).getTime())
  const hours = Math.max(1, Math.floor(elapsed / 3_600_000))
  return hours < 24
    ? phone.t('Apps.localPages.hoursAgo', { count: String(hours) })
    : phone.t('Apps.localPages.daysAgo', { count: String(Math.floor(hours / 24)) })
}

function showFeedback(key: string): void {
  feedback.value = phone.t(key)
  window.setTimeout(() => { feedback.value = '' }, 2600)
}

async function loadFeed(): Promise<void> {
  await pages.load({ category: category.value, search: search.value })
}

async function selectTab(next: Tab): Promise<void> {
  if (next === 'create') {
    if (!isAuthenticated.value) {
      tab.value = 'profile'
      return
    }
    screen.value = 'compose'
    return
  }
  tab.value = next
  screen.value = 'main'
  if (next === 'profile' && isAuthenticated.value) await pages.loadProfile()
}

async function openPost(post: PagesPost): Promise<void> {
  const response = await pages.get(post.id)
  if (!response.success || !response.data) return
  selected.value = response.data
  galleryIndex.value = 0
  screen.value = 'detail'
}

function togglePhoto(id: string): void {
  const index = draft.value.images.indexOf(id)
  if (index >= 0) draft.value.images.splice(index, 1)
  else if (draft.value.images.length < 6) draft.value.images.push(id)
  else showFeedback('Apps.localPages.photoLimit')
}

function capturePhoto(): void {
  if (draft.value.images.length >= 6) {
    showFeedback('Apps.localPages.photoLimit')
    return
  }
  draft.value.images.push(media.capture().id)
}

async function publish(): Promise<void> {
  if (!canPublish.value) {
    showFeedback('Apps.localPages.errors.invalid_post')
    return
  }
  const response = await pages.create({
    body: draft.value.body.trim(),
    category: draft.value.category,
    district: draft.value.district,
    images: draft.value.images.map((id) => ({ id })),
    title: draft.value.title.trim(),
  })
  if (!response.success) {
    showFeedback(`Apps.localPages.errors.${response.error ?? 'default'}`)
    return
  }
  draft.value = { body: '', category: 'recommendation', district: 'los_santos', images: [], title: '' }
  tab.value = 'feed'
  screen.value = 'main'
  showFeedback('Apps.localPages.published')
}

async function react(kind: 'like' | 'save'): Promise<void> {
  if (!selected.value || !isAuthenticated.value) {
    showFeedback('Apps.localPages.errors.not_authenticated')
    return
  }
  const active = kind === 'like' ? !Boolean(selected.value.is_liked) : !Boolean(selected.value.is_saved)
  if (await pages.react(selected.value.id, kind, active)) {
    if (kind === 'like') {
      selected.value.like_count = Math.max(0, selected.value.like_count + (active ? 1 : -1))
      selected.value.is_liked = active
    } else selected.value.is_saved = active
  }
}

async function removePost(): Promise<void> {
  if (!selected.value || !(await pages.remove(selected.value.id))) return
  selected.value = null
  screen.value = 'main'
  await pages.loadProfile()
  showFeedback('Apps.localPages.deleted')
}

function moveGallery(direction: number): void {
  if (!selected.value?.images.length) return
  galleryIndex.value = (galleryIndex.value + direction + selected.value.images.length) % selected.value.images.length
}

function openCityMarktListing(): void {
  if (!selected.value?.citymarkt_listing_id) return
  void router.push({
    path: '/apps/citymarkt',
    query: { listingId: selected.value.citymarkt_listing_id },
  })
}

onMounted(() => void loadFeed())
</script>

<template>
  <main class="pages" :class="{ 'pages--light': !phone.isDarkMode }">
    <template v-if="screen === 'main'">
      <header class="pages__header">
        <button type="button" :aria-label="phone.t('Common.back')" @click="router.push('/')"><ChevronLeft :size="21" /></button>
        <div><span>{{ phone.t('Apps.localPages.eyebrow') }}</span><h1>Local Pages</h1></div>
        <button type="button" :aria-label="phone.t('Apps.localPages.create')" @click="selectTab('create')"><Plus :size="21" /></button>
      </header>

      <section class="pages__content">
        <template v-if="tab === 'feed'">
          <div class="pages__hero"><div><small>{{ phone.t('Apps.localPages.cityPulse') }}</small><strong>{{ phone.t('Apps.localPages.heroTitle') }}</strong><span>{{ phone.t('Apps.localPages.heroBody') }}</span></div><MapPin :size="40" /></div>
          <form class="pages__search" @submit.prevent="loadFeed"><Search :size="17" /><input v-model="search" :placeholder="phone.t('Apps.localPages.searchPlaceholder')" /><button>{{ phone.t('Apps.localPages.search') }}</button></form>
          <CityMarktSelect :model-value="category" :options="categoryOptions" @change="(value) => { category = value; loadFeed() }" />
        </template>

        <template v-else>
          <div v-if="!isAuthenticated" class="pages__empty"><UserRound :size="42" /><strong>{{ phone.t('Apps.localPages.signInTitle') }}</strong><span>{{ phone.t('Apps.localPages.signInBody') }}</span></div>
          <template v-else>
            <div class="pages__profile"><span>{{ account.email.charAt(0).toUpperCase() }}</span><div><small>{{ phone.t('Apps.localPages.localCreator') }}</small><strong>@{{ account.email.split('@')[0] }}</strong><b>{{ pages.ownItems.length }} {{ phone.t('Apps.localPages.posts') }}</b></div></div>
            <div class="pages__segmented"><button :class="{ active: profileMode === 'own' }" @click="profileMode = 'own'">{{ phone.t('Apps.localPages.myPosts') }}</button><button :class="{ active: profileMode === 'saved' }" @click="profileMode = 'saved'">{{ phone.t('Apps.localPages.saved') }}</button></div>
          </template>
        </template>

        <div v-if="pages.isLoading" class="pages__empty">{{ phone.t('Common.loading') }}</div>
        <div v-else-if="isAuthenticated || tab === 'feed'" class="pages__feed">
          <button v-for="post in displayedPosts" :key="post.id" class="pages__post" @click="openPost(post)">
            <div class="pages__post-head"><span>{{ post.author_name.charAt(0).toUpperCase() }}</span><div><strong>@{{ post.author_name }}</strong><small><MapPin :size="10" /> {{ post.district ? phone.t(`Apps.citymarkt.districts.${post.district}`) : phone.t('Apps.localPages.allLosSantos') }} · {{ relativeDate(post.created_at) }}</small></div><i>{{ label('categories', post.category) }}</i></div>
            <div v-if="post.image" class="pages__cover" :style="{ background: post.image }"><b v-if="post.images.length > 1">1 / {{ post.images.length }}</b></div>
            <h2>{{ post.title }}</h2><p>{{ post.body }}</p>
            <div class="pages__post-foot"><span><Heart :size="14" :fill="post.is_liked ? 'currentColor' : 'none'" /> {{ post.like_count }}</span><span v-if="post.source_type === 'citymarkt'"><Store :size="14" /> CityMarkt</span><Bookmark :size="14" :fill="post.is_saved ? 'currentColor' : 'none'" /></div>
          </button>
          <div v-if="!displayedPosts.length" class="pages__empty"><Compass :size="38" /><strong>{{ phone.t('Apps.localPages.noPosts') }}</strong><span>{{ phone.t('Apps.localPages.noPostsBody') }}</span></div>
        </div>
      </section>

      <nav class="pages__tabbar">
        <button :class="{ active: tab === 'feed' }" @click="selectTab('feed')"><span><Compass :size="20" /></span>{{ phone.t('Apps.localPages.discover') }}</button>
        <button class="create" @click="selectTab('create')"><span><Plus :size="23" /></span>{{ phone.t('Apps.localPages.create') }}</button>
        <button :class="{ active: tab === 'profile' }" @click="selectTab('profile')"><span><UserRound :size="20" /></span>{{ phone.t('Apps.localPages.profile') }}</button>
      </nav>
    </template>

    <section v-else-if="screen === 'detail' && selected" class="pages__detail">
      <header><button @click="screen = 'main'"><ArrowLeft :size="20" /></button><strong>{{ phone.t('Apps.localPages.post') }}</strong><button v-if="selected.is_owner" class="danger" @click="removePost"><Trash2 :size="18" /></button><button v-else @click="react('save')"><Bookmark :size="18" :fill="selected.is_saved ? 'currentColor' : 'none'" /></button></header>
      <div class="pages__detail-scroll">
        <div v-if="selected.images.length" class="pages__gallery" :style="{ background: selected.images[galleryIndex]?.gradient }"><button v-if="selected.images.length > 1" @click="moveGallery(-1)"><ChevronLeft /></button><button v-if="selected.images.length > 1" @click="moveGallery(1)"><ChevronRight /></button><span>{{ galleryIndex + 1 }} / {{ selected.images.length }}</span></div>
        <article><div class="pages__author"><span>{{ selected.author_name.charAt(0).toUpperCase() }}</span><div><strong>@{{ selected.author_name }}</strong><small>{{ relativeDate(selected.created_at) }}</small></div><i>{{ label('categories', selected.category) }}</i></div><h1>{{ selected.title }}</h1><p>{{ selected.body }}</p><div class="pages__location"><MapPin :size="17" /><div><small>{{ phone.t('Apps.localPages.location') }}</small><strong>{{ selected.district ? phone.t(`Apps.citymarkt.districts.${selected.district}`) : phone.t('Apps.localPages.allLosSantos') }}</strong></div></div><button v-if="selected.source_type === 'citymarkt'" class="pages__market-link" @click="openCityMarktListing"><Store :size="18" /><span><small>{{ phone.t('Apps.localPages.sharedFrom') }}</small><strong>{{ phone.t('Apps.localPages.openCityMarkt') }}</strong></span><b v-if="selected.citymarkt_price">${{ Number(selected.citymarkt_price).toLocaleString() }}</b></button></article>
      </div>
      <div class="pages__detail-actions"><button :class="{ active: selected.is_liked }" @click="react('like')"><Heart :size="19" :fill="selected.is_liked ? 'currentColor' : 'none'" />{{ selected.like_count }} {{ phone.t('Apps.localPages.likes') }}</button><button @click="react('save')"><Bookmark :size="19" :fill="selected.is_saved ? 'currentColor' : 'none'" />{{ phone.t('Apps.localPages.save') }}</button></div>
    </section>

    <section v-else class="pages__compose">
      <header><button @click="screen = 'main'"><X :size="20" /></button><div><small>{{ phone.t('Apps.localPages.newPost') }}</small><strong>{{ phone.t('Apps.localPages.shareWithCity') }}</strong></div><button :disabled="!canPublish" @click="publish"><Send :size="16" />{{ phone.t('Apps.localPages.publish') }}</button></header>
      <div class="pages__compose-scroll">
        <label>{{ phone.t('Apps.localPages.title') }} <span :class="{ valid: draft.title.trim().length >= 5 }">{{ draft.title.trim().length }}/80 · {{ phone.t('Apps.citymarkt.minimumCharacters', { minimum: '5' }) }}</span><input v-model="draft.title" maxlength="80" :placeholder="phone.t('Apps.localPages.titlePlaceholder')" /></label>
        <label>{{ phone.t('Apps.localPages.body') }} <span :class="{ valid: draft.body.trim().length >= 10 }">{{ draft.body.trim().length }}/1500 · {{ phone.t('Apps.citymarkt.minimumCharacters', { minimum: '10' }) }}</span><textarea v-model="draft.body" maxlength="1500" :placeholder="phone.t('Apps.localPages.bodyPlaceholder')" /></label>
        <div class="pages__form-row"><label>{{ phone.t('Apps.localPages.category') }}<CityMarktSelect :model-value="draft.category" :options="composeCategoryOptions" @change="(value) => draft.category = value as typeof draft.category" /></label><label>{{ phone.t('Apps.localPages.location') }}<CityMarktSelect :model-value="draft.district" :options="districtOptions" @change="(value) => draft.district = value" /></label></div>
        <div class="pages__photo-title"><div><strong>{{ phone.t('Apps.localPages.photos') }}</strong><small>{{ draft.images.length }}/6 · {{ phone.t('Apps.localPages.optional') }}</small></div><button @click="capturePhoto"><Camera :size="16" />{{ phone.t('Apps.localPages.camera') }}</button></div>
        <div v-if="selectedPhotos.length" class="pages__selected"><button v-for="photo in selectedPhotos" :key="photo.id" :style="{ background: photo.gradient }" @click="togglePhoto(photo.id)"><X :size="14" /></button></div>
        <strong class="pages__gallery-label">{{ phone.t('Apps.localPages.gallery') }}</strong>
        <div class="pages__picker"><button v-for="photo in media.photos" :key="photo.id" :class="{ active: draft.images.includes(photo.id) }" :style="{ background: photo.gradient }" @click="togglePhoto(photo.id)"><i v-if="draft.images.includes(photo.id)">{{ draft.images.indexOf(photo.id) + 1 }}</i></button></div>
      </div>
    </section>
    <Transition name="toast"><div v-if="feedback" class="pages__toast">{{ feedback }}</div></Transition>
  </main>
</template>

<style scoped>
.pages{--yellow:#ffd63e;--ink:#15191d;--panel:#20262c;--muted:#9ba4aa;position:absolute;inset:0;padding:47px 0 24px;overflow:hidden;background:#12171b;color:#f7f7f2;font-family:Inter,system-ui,sans-serif}.pages--light{--panel:#f0f0eb;--muted:#737a7d;background:#fbfbf6;color:#171b1e}.pages button,.pages input,.pages textarea{font:inherit;color:inherit}.pages button{border:0}.pages__header{height:65px;padding:6px 14px;display:grid;grid-template-columns:36px 1fr 36px;align-items:center}.pages__header>button,.pages__detail>header button{width:34px;height:34px;border-radius:11px;display:grid;place-items:center;background:var(--panel)}.pages__header>div{text-align:center}.pages__header span,.pages__compose header small{display:block;color:var(--yellow);font-size:8px;font-weight:900;letter-spacing:.11em;text-transform:uppercase}.pages__header h1{margin:0;font-size:22px;line-height:1.05}.pages__content{height:calc(100% - 65px - 59px);padding:0 13px 18px;overflow-y:auto;scrollbar-width:none}.pages__hero{height:105px;margin-bottom:10px;padding:15px;border-radius:17px;display:flex;align-items:center;justify-content:space-between;background:linear-gradient(125deg,#514005,#d99a00);color:#fff7d2;box-shadow:0 8px 22px #0003}.pages__hero div{max-width:210px}.pages__hero small,.pages__hero strong,.pages__hero span{display:block}.pages__hero small{font-size:8px;font-weight:900;letter-spacing:.1em;text-transform:uppercase}.pages__hero strong{margin:2px 0;font-size:18px}.pages__hero span{font-size:9px;line-height:1.35}.pages__hero>svg{color:var(--yellow);filter:drop-shadow(0 4px 6px #0005)}.pages__search{height:39px;margin-bottom:7px;padding:0 8px 0 10px;border-radius:11px;display:flex;align-items:center;gap:7px;background:var(--panel);color:var(--muted)}.pages__search input{min-width:0;flex:1;border:0;outline:0;background:none;font-size:11px}.pages__search button{padding:5px 8px;border-radius:7px;background:var(--yellow);color:#17191a;font-size:9px;font-weight:800}.pages__feed{padding-top:10px;display:flex;flex-direction:column;gap:12px}.pages__post{width:100%;padding:11px;border-radius:16px;text-align:left;background:var(--panel);box-shadow:0 5px 18px #0002}.pages__post-head{display:flex;align-items:center;gap:7px}.pages__post-head>span,.pages__profile>span,.pages__author>span{width:32px;height:32px;flex:none;border-radius:50%;display:grid;place-items:center;background:var(--yellow);color:#20231f;font-size:13px;font-weight:900}.pages__post-head>div{min-width:0;flex:1}.pages__post-head strong,.pages__post-head small{display:block}.pages__post-head strong{font-size:11px}.pages__post-head small{display:flex;align-items:center;gap:2px;overflow:hidden;color:var(--muted);font-size:8px;white-space:nowrap}.pages__post-head i,.pages__author i{padding:4px 6px;border-radius:7px;background:#ffd63e22;color:var(--yellow);font-size:7px;font-style:normal;font-weight:800}.pages__cover{height:138px;margin:9px 0;border-radius:12px;background-size:cover!important;position:relative}.pages__cover>b{position:absolute;right:7px;bottom:7px;padding:3px 6px;border-radius:6px;background:#111b;color:white;font-size:8px}.pages__cover--empty{display:flex;flex-direction:column;align-items:center;justify-content:center;gap:5px;background:linear-gradient(145deg,#262d32,#1a2024)!important;color:var(--muted);font-size:9px}.pages--light .pages__cover--empty{background:#e7e8e2!important}.pages__post h2{margin:0 0 3px;font-size:14px}.pages__post p{margin:0;display:-webkit-box;overflow:hidden;color:var(--muted);font-size:10px;line-height:1.4;-webkit-box-orient:vertical;-webkit-line-clamp:2}.pages__post-foot{margin-top:9px;padding-top:8px;border-top:1px solid #ffffff12;display:flex;align-items:center;gap:13px;color:var(--muted);font-size:9px}.pages__post-foot span{display:flex;align-items:center;gap:4px}.pages__post-foot svg:last-child{margin-left:auto}.pages__empty{min-height:230px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:6px;text-align:center;color:var(--muted)}.pages__empty strong{font-size:15px}.pages__empty span{max-width:220px;font-size:10px}.pages__profile{margin:3px 0 10px;padding:15px;border-radius:17px;display:flex;align-items:center;gap:10px;background:linear-gradient(125deg,#58450b,#262b2f)}.pages__profile>span{width:48px;height:48px;font-size:19px}.pages__profile small,.pages__profile strong,.pages__profile b{display:block}.pages__profile small{color:var(--yellow);font-size:8px;text-transform:uppercase}.pages__profile strong{font-size:16px}.pages__profile b{color:var(--muted);font-size:9px}.pages__segmented{padding:4px;border-radius:11px;display:flex;background:var(--panel)}.pages__segmented button{flex:1;padding:8px;border-radius:8px;background:none;font-size:10px}.pages__segmented button.active{background:var(--yellow);color:#17191a;font-weight:800}.pages__tabbar{position:absolute;right:0;bottom:22px;left:0;height:59px;padding:5px 35px 0;display:flex;align-items:center;justify-content:space-between;border-top:1px solid #ffffff13;background:#151a1eea;backdrop-filter:blur(15px)}.pages--light .pages__tabbar{background:#fbfbf6ec}.pages__tabbar button{width:55px;padding:0;display:flex;flex-direction:column;align-items:center;gap:2px;background:none;color:var(--muted);font-size:8px}.pages__tabbar button.active{color:var(--yellow)}.pages__tabbar .create span{width:44px;height:36px;margin-top:-17px;border-radius:13px;display:grid;place-items:center;background:var(--yellow);color:#17191a;box-shadow:0 5px 15px #0004}.pages__detail,.pages__compose{position:absolute;inset:0;padding-top:47px;background:#12171b}.pages--light .pages__detail,.pages--light .pages__compose{background:#fbfbf6}.pages__detail>header,.pages__compose>header{height:53px;padding:5px 13px;border-bottom:1px solid #ffffff12;display:flex;align-items:center;gap:8px}.pages__detail>header strong{flex:1;text-align:center;font-size:13px}.pages__detail>header .danger{color:#ff6961}.pages__detail-scroll{height:calc(100% - 105px);padding-bottom:64px;overflow-y:auto}.pages__gallery{height:235px;display:flex;align-items:center;justify-content:space-between;background-size:cover!important;position:relative}.pages__gallery button{width:32px;height:38px;margin:8px;border-radius:10px;display:grid;place-items:center;background:#101820aa;color:#fff}.pages__gallery>span{position:absolute;right:10px;bottom:9px;padding:4px 7px;border-radius:7px;background:#101820bb;color:#fff;font-size:8px}.pages__detail article{padding:13px 15px}.pages__author{display:flex;align-items:center;gap:8px}.pages__author>div{flex:1}.pages__author strong,.pages__author small{display:block}.pages__author strong{font-size:12px}.pages__author small{color:var(--muted);font-size:8px}.pages__detail h1{margin:14px 0 5px;font-size:20px}.pages__detail article>p{margin:0;color:var(--muted);font-size:11px;line-height:1.55;white-space:pre-wrap}.pages__location,.pages__market-link{margin-top:14px;padding:10px;border-radius:12px;display:flex;align-items:center;gap:8px;background:var(--panel)}.pages__location svg{color:var(--yellow)}.pages__location small,.pages__location strong,.pages__market-link small,.pages__market-link strong{display:block}.pages__location small,.pages__market-link small{color:var(--muted);font-size:8px}.pages__location strong,.pages__market-link strong{font-size:10px}.pages__market-link{width:100%;text-align:left}.pages__market-link>svg{color:var(--yellow)}.pages__market-link>span{flex:1}.pages__market-link>b{color:var(--yellow);font-size:11px}.pages__detail-actions{position:absolute;right:12px;bottom:30px;left:12px;height:43px;padding:4px;border-radius:14px;display:flex;gap:5px;background:var(--panel);box-shadow:0 7px 25px #0005}.pages__detail-actions button{flex:1;border-radius:10px;display:flex;align-items:center;justify-content:center;gap:5px;background:none;font-size:10px;font-weight:700}.pages__detail-actions button.active{color:#ff6473}.pages__compose>header>div{min-width:0;flex:1}.pages__compose>header strong{display:block;font-size:12px}.pages__compose>header>button{padding:7px;border-radius:10px;background:var(--panel)}.pages__compose>header>button:last-child{display:flex;align-items:center;gap:4px;background:var(--yellow);color:#17191a;font-size:9px;font-weight:800}.pages__compose>header>button:disabled{opacity:.35}.pages__compose-scroll{height:calc(100% - 53px);padding:15px 14px 35px;overflow-y:auto}.pages__compose-scroll label{display:block;margin-bottom:14px;color:var(--muted);font-size:10px;font-weight:700}.pages__compose-scroll label>span{float:right;color:#ff9c47;font-size:8px}.pages__compose-scroll label>span.valid{color:#59d889}.pages__compose input,.pages__compose textarea{width:100%;margin-top:5px;padding:11px;border:1px solid #ffffff13;border-radius:11px;outline:0;background:var(--panel);font-size:12px}.pages__compose textarea{height:116px;resize:none;line-height:1.45}.pages__form-row{display:grid;grid-template-columns:1fr 1fr;gap:7px}.pages__photo-title{margin:5px 0 8px;display:flex;align-items:center;justify-content:space-between}.pages__photo-title strong,.pages__photo-title small{display:block}.pages__photo-title strong,.pages__gallery-label{font-size:12px}.pages__photo-title small{color:var(--muted);font-size:8px}.pages__photo-title button{padding:7px 9px;border-radius:9px;display:flex;align-items:center;gap:4px;background:var(--yellow);color:#17191a;font-size:9px;font-weight:800}.pages__selected{margin-bottom:12px;display:grid;grid-template-columns:repeat(3,1fr);gap:6px}.pages__selected button,.pages__picker button{aspect-ratio:1;border-radius:10px;background-size:cover!important;position:relative}.pages__selected svg{position:absolute;top:5px;right:5px;padding:3px;box-sizing:content-box;border-radius:50%;background:#12171bcc;color:white}.pages__gallery-label{display:block;margin-bottom:7px}.pages__picker{display:grid;grid-template-columns:repeat(3,1fr);gap:6px}.pages__picker button{border:2px solid transparent}.pages__picker button.active{border-color:var(--yellow)}.pages__picker i{width:19px;height:19px;margin:4px;border-radius:50%;display:grid;place-items:center;background:var(--yellow);color:#17191a;font-size:9px;font-style:normal;font-weight:900}.pages__toast{position:absolute;z-index:20;right:17px;bottom:91px;left:17px;padding:11px;border-radius:11px;background:#fff6cf;color:#1b2023;box-shadow:0 8px 30px #0007;font-size:10px;font-weight:800;text-align:center}.toast-enter-active,.toast-leave-active{transition:.2s}.toast-enter-from,.toast-leave-to{transform:translateY(8px);opacity:0}
.pages__tabbar{height:58px;padding:7px 7px 0;justify-content:space-around;backdrop-filter:blur(18px)}
.pages--light .pages__tabbar{border-color:#00000012}
.pages__tabbar button{width:54px;gap:2px}
.pages__tabbar button>span{position:relative}
.pages__tabbar .create span{width:37px;height:30px;margin-top:-4px;border-radius:10px;box-shadow:none}
</style>
