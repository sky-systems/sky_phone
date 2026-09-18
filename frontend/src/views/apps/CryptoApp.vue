<script setup lang="ts">
import {
  ArrowDownLeft,
  ArrowUpRight,
  BellRing,
  ChartCandlestick,
  ChartNoAxesCombined,
  CheckCircle2,
  ChevronRight,
  Copy,
  Eye,
  EyeOff,
  Fingerprint,
  History,
  KeyRound,
  LockKeyhole,
  LogOut,
  Mail,
  Settings2,
  Send,
  Share2,
  ShieldCheck,
  Sparkles,
  UserRound,
  WalletCards,
} from 'lucide-vue-next'
import { computed, onMounted, onUnmounted, ref, watch } from 'vue'
import cryptoHeaderLogo from '@/assets/img/app-icons/crypto-header-logo.webp'
import CryptoLogo from '@/components/crypto/CryptoLogo.vue'
import { useAccountStore } from '@/stores/account'
import { useCryptoStore } from '@/stores/crypto'
import { useEasyShareStore } from '@/stores/easyshare'
import { usePhoneStore } from '@/stores/phone'
import type {
  CryptoActivity,
  CryptoMarket,
  CryptoRecipient,
  CryptoSide,
} from '@/types/crypto'
import {
  SkyAppPage,
  SkyButton,
  SkyCard,
  SkyDialog,
  SkyDialogButton,
  SkyEmptyState,
  SkyField,
  SkyLink,
  SkyNavbar,
  SkyPillNavigation,
  SkyScrollArea,
  SkySegmented,
  SkySegmentedButton,
  SkySheet,
  SkySpinner,
  SkyStatusCard,
  SkyToggle,
} from '@/ui'
import { copyText } from '@/utils/clipboard'

type Tab = 'portfolio' | 'markets' | 'activity' | 'profile'
type Sheet = 'trade' | 'deposit' | 'withdraw' | 'profile' | 'send' | null
type ChartPeriod = '1D' | '1W' | '1M' | '6M' | '1Y'

const CHART_PERIODS: ChartPeriod[] = ['1D', '1W', '1M', '6M', '1Y']
const CHART_PERIOD_CONFIG: Record<
  ChartPeriod,
  { duration: number; samples: number }
> = {
  '1D': { duration: 86_400_000, samples: 16 },
  '1W': {
    duration: 7 * 86_400_000,
    samples: 24,
  },
  '1M': {
    duration: 30 * 86_400_000,
    samples: 32,
  },
  '6M': {
    duration: 183 * 86_400_000,
    samples: 40,
  },
  '1Y': {
    duration: 365 * 86_400_000,
    samples: 48,
  },
}
const crypto = useCryptoStore()
const account = useAccountStore()
const easyShare = useEasyShareStore()
const phone = usePhoneStore()
let marketPreviewTimer: number | undefined
const tab = ref<Tab>('portfolio')
const authMode = ref<'login' | 'register'>('login')
const activityFilter = ref<'all' | 'trades' | 'wallet'>('all')
const detail = ref<CryptoMarket | null>(null)
const sheet = ref<Sheet>(null)
const selectedMarket = ref<CryptoMarket | null>(null)
const side = ref<CryptoSide>('buy')
const handle = ref('')
const password = ref('')
const amount = ref('')
const financialPassword = ref('')
const showPassword = ref(false)
const formError = ref('')
const profileHandle = ref('')
const profileCurrentPassword = ref('')
const profileNewPassword = ref('')
const priceAlerts = ref(true)
const confirmations = ref(true)
const hideBalances = ref(false)
const saved = ref(false)
const period = ref<ChartPeriod>('1D')
const transferWalletKey = ref('')
const transferMarketId = ref('')
const transferQuantity = ref('')
const transferPassword = ref('')
const transferRecipient = ref<CryptoRecipient | null>(null)
const walletKeyCopied = ref(false)
const logoutDialogOpen = ref(false)
const logoutSubmitting = ref(false)

const locale = computed(() => phone.lang || 'de')
const authenticated = computed(() => crypto.data?.authenticated === true)
const profile = computed(() => crypto.data?.profile ?? null)
const markets = computed(() => crypto.data?.markets ?? [])
const holdings = computed(() => crypto.data?.holdings ?? [])
const activities = computed(() =>
  (crypto.data?.activity ?? []).filter(
    (item) =>
      activityFilter.value === 'all' ||
      (activityFilter.value === 'trades'
        ? ['buy', 'sell'].includes(item.type)
        : ['deposit', 'withdrawal', 'transfer_in', 'transfer_out'].includes(
            item.type,
          )),
  ),
)
const transferMarket = computed(() => market(transferMarketId.value))
const transferHolding = computed(() =>
  holdings.value.find((item) => item.assetId === transferMarketId.value),
)
const investedValue = computed(() =>
  Math.max(
    0,
    Number(crypto.data?.portfolioValue ?? 0) -
      Number(crypto.data?.cashBalance ?? 0),
  ),
)
const portfolioCostBasis = computed(() =>
  holdings.value.reduce(
    (sum, holding) =>
      sum + Number(holding.quantity) * Number(holding.averagePrice),
    0,
  ),
)
const portfolioProfitLoss = computed(
  () => investedValue.value - portfolioCostBasis.value,
)
const portfolioProfitPercent = computed(() =>
  portfolioCostBasis.value > 0
    ? (portfolioProfitLoss.value / portfolioCostBasis.value) * 100
    : 0,
)
const portfolioChart = computed(() => {
  const width = 320
  const height = 126
  const startX = 18
  const currentX = 224
  const forecastEndX = 306
  const sampleCount = 10
  const weightedMarkets = holdings.value
    .map((holding) => ({
      cost: Number(holding.quantity) * Number(holding.averagePrice),
      market: markets.value.find((item) => item.id === holding.assetId),
    }))
    .filter((item): item is { cost: number; market: CryptoMarket } =>
      Boolean(item.market?.sparkline.length),
    )
  const totalWeight =
    weightedMarkets.reduce((sum, item) => sum + item.cost, 0) || 1
  const reference = Array.from({ length: sampleCount }, (_, index) =>
    weightedMarkets.reduce((sum, item) => {
      const sourceIndex = Math.round(
        (index / (sampleCount - 1)) * (item.market.sparkline.length - 1),
      )
      return (
        sum + item.market.sparkline[sourceIndex] * (item.cost / totalWeight)
      )
    }, 0),
  )
  const currentProfit = portfolioProfitLoss.value
  const referenceEnd = reference[reference.length - 1] ?? 0.5
  const amplitude = Math.max(
    portfolioCostBasis.value * 0.045,
    Math.abs(currentProfit) * 0.38,
    40,
  )
  const historyValues = reference.map(
    (value) => currentProfit + (value - referenceEnd) * amplitude,
  )
  historyValues[historyValues.length - 1] = currentProfit

  const recentMomentum =
    currentProfit - (historyValues[historyValues.length - 3] ?? currentProfit)
  const forecastValues = [
    currentProfit,
    currentProfit + recentMomentum * 0.42,
    currentProfit + recentMomentum * 0.58 + amplitude * 0.035,
    currentProfit + recentMomentum * 0.48 - amplitude * 0.018,
  ]
  const extent = Math.max(
    50,
    ...historyValues.map((value) => Math.abs(value)),
    ...forecastValues.map((value) => Math.abs(value)),
  )
  const scale = Math.ceil((extent * 1.18) / 50) * 50
  const chartTop = 15
  const chartBottom = height - 16
  const chartRange = chartBottom - chartTop
  const y = (value: number) =>
    chartTop + ((scale - value) / (scale * 2)) * chartRange
  const historyPoints = historyValues
    .map(
      (value, index) =>
        `${
          startX + index * ((currentX - startX) / (historyValues.length - 1))
        },${y(value)}`,
    )
    .join(' ')
  const forecastPoints = forecastValues
    .map(
      (value, index) =>
        `${
          currentX +
          index * ((forecastEndX - currentX) / (forecastValues.length - 1))
        },${y(value)}`,
    )
    .join(' ')

  return {
    currentX,
    currentY: y(currentProfit),
    forecastPoints,
    height,
    historyPoints,
    labelY: Math.max(3, Math.min(height - 29, y(currentProfit) - 27)),
    scale,
    width,
    zeroY: y(0),
  }
})
const cashShare = computed(() => {
  const total = Number(crypto.data?.portfolioValue ?? 0)
  return total > 0
    ? Math.min(100, (Number(crypto.data?.cashBalance ?? 0) / total) * 100)
    : 0
})
const topMover = computed(
  () =>
    [...markets.value].sort(
      (first, second) => second.changePercent - first.changePercent,
    )[0],
)
const detailHolding = computed(() =>
  holdings.value.find((item) => item.assetId === detail.value?.id),
)
const selectedHolding = computed(() =>
  holdings.value.find((item) => item.assetId === selectedMarket.value?.id),
)
const detailChart = computed(() => {
  const left = 52
  const right = 307
  const top = 14
  const bottom = 137
  const config = CHART_PERIOD_CONFIG[period.value]
  const selected = detail.value

  if (!selected) {
    return {
      areaPoints: '',
      changePercent: 0,
      marker: { labelY: top, x: right, y: bottom },
      points: '',
      xTicks: [],
      yTicks: [],
    }
  }

  const currentPrice = Number(selected.price)
  const history = (selected.priceHistory ?? [])
    .map(Number)
    .filter((value) => Number.isFinite(value) && value > 0)
  const values = (
    history.length ? history : [currentPrice, currentPrice]
  ).slice(-config.samples)
  if (values.length === 1) values.unshift(values[0])
  const startPrice = values[0] ?? currentPrice
  values[values.length - 1] = currentPrice

  const minimum = Math.min(...values)
  const maximum = Math.max(...values)
  const padding = Math.max((maximum - minimum) * 0.16, currentPrice * 0.012)
  const axisMinimum = Math.max(0, minimum - padding)
  const axisMaximum = maximum + padding
  const axisRange = Math.max(axisMaximum - axisMinimum, currentPrice * 0.02)
  const x = (ratio: number) => left + ratio * (right - left)
  const y = (value: number) =>
    top + ((axisMaximum - value) / axisRange) * (bottom - top)
  const linePoints = values
    .map((value, index) => `${x(index / (values.length - 1))},${y(value)}`)
    .join(' ')
  const markerY = y(currentPrice)

  return {
    areaPoints: `${left},${bottom} ${linePoints} ${right},${bottom}`,
    changePercent: ((currentPrice - startPrice) / startPrice) * 100,
    marker: {
      labelY: markerY < 31 ? markerY + 19 : markerY - 10,
      x: right,
      y: markerY,
    },
    points: linePoints,
    xTicks: Array.from({ length: 5 }, (_, index) => {
      const ratio = index / 4
      return {
        label: chartTimeLabel(period.value, ratio, config.duration),
        x: x(ratio),
      }
    }),
    yTicks: Array.from({ length: 4 }, (_, index) => {
      const ratio = index / 3
      const value = axisMaximum - axisRange * ratio
      return { label: chartMoney(value), value, y: y(value) }
    }),
  }
})
const estimatedTradeValue = computed(
  () => Number(amount.value || 0) * Number(selectedMarket.value?.price || 0),
)

function t(key: string) {
  return phone.t(`Apps.crypto.${key}`)
}
function money(value: string | number) {
  const numericValue = Number(value) || 0
  const absolute = Math.abs(numericValue)
  return new Intl.NumberFormat(locale.value, {
    currency: 'USD',
    maximumFractionDigits: absolute > 0 && absolute < 1 ? 4 : 2,
    minimumFractionDigits: 2,
    style: 'currency',
  }).format(numericValue)
}
function signedMoney(value: number) {
  const formatted = money(Math.abs(value))
  if (value > 0) return `+${formatted}`
  if (value < 0) return `−${formatted}`
  return formatted
}
function privateMoney(value: string | number) {
  return profile.value?.hideBalances ? '••••••' : money(value)
}
function privateSignedMoney(value: number) {
  return profile.value?.hideBalances ? '••••••' : signedMoney(value)
}
function quantity(value: string) {
  return new Intl.NumberFormat(locale.value, {
    maximumFractionDigits: 6,
  }).format(Number(value) || 0)
}
function compact(value: string | number) {
  return new Intl.NumberFormat(locale.value, {
    maximumFractionDigits: 2,
    notation: 'compact',
  }).format(Number(value) || 0)
}
function chartMoney(value: number) {
  const absolute = Math.abs(value)
  return new Intl.NumberFormat(locale.value, {
    currency: 'USD',
    maximumFractionDigits:
      absolute >= 1_000 ? 0 : absolute >= 1 ? 2 : absolute >= 0.01 ? 3 : 5,
    notation: absolute >= 1_000_000 ? 'compact' : 'standard',
    style: 'currency',
  }).format(value)
}
function chartTimeLabel(
  selectedPeriod: ChartPeriod,
  ratio: number,
  duration: number,
) {
  const date = new Date(Date.now() - duration * (1 - ratio))
  const options: Intl.DateTimeFormatOptions =
    selectedPeriod === '1D'
      ? { hour: '2-digit', minute: '2-digit' }
      : selectedPeriod === '1W'
        ? { weekday: 'short' }
        : selectedPeriod === '1M'
          ? { day: '2-digit', month: '2-digit' }
          : { month: 'short' }

  return new Intl.DateTimeFormat(locale.value, options).format(date)
}
function points(values: number[], width = 320, height = 110) {
  return values
    .map(
      (value, index) =>
        `${index * (width / Math.max(1, values.length - 1))},${height - 7 - value * (height - 14)}`,
    )
    .join(' ')
}
function market(id?: string) {
  return markets.value.find((item) => item.id === id)
}
function allocation(value: string) {
  const total = Number(crypto.data?.portfolioValue ?? 0)
  return total > 0 ? Math.min(100, (Number(value) / total) * 100) : 0
}
function errorText(code: string) {
  const value = t(`errors.${code}`)
  return value.startsWith('Apps.crypto.') ? t('errors.default') : value
}
function setTab(next: Tab) {
  detail.value = null
  tab.value = next
}
function openMarket(next: CryptoMarket) {
  detail.value = next
  period.value = '1D'
}
function openTrade(next: CryptoMarket, nextSide: CryptoSide = 'buy') {
  selectedMarket.value = next
  side.value = nextSide
  amount.value = ''
  formError.value = ''
  crypto.pendingQuote = null
  sheet.value = 'trade'
}
function selectTradeSide(next: CryptoSide) {
  if (side.value === next) return
  side.value = next
  crypto.pendingQuote = null
  formError.value = ''
}
function openSettlement(next: 'deposit' | 'withdraw') {
  sheet.value = next
  amount.value = ''
  financialPassword.value = ''
  formError.value = ''
}
function openSend() {
  transferWalletKey.value = ''
  transferMarketId.value = holdings.value[0]?.assetId ?? ''
  transferQuantity.value = ''
  transferPassword.value = ''
  transferRecipient.value = null
  formError.value = ''
  sheet.value = 'send'
}
function openProfileEditor() {
  profileHandle.value = profile.value?.handle ?? ''
  profileCurrentPassword.value = ''
  profileNewPassword.value = ''
  formError.value = ''
  saved.value = false
  sheet.value = 'profile'
}
function closeSheet() {
  sheet.value = null
  crypto.pendingQuote = null
  profileCurrentPassword.value = ''
  profileNewPassword.value = ''
  transferRecipient.value = null
  transferPassword.value = ''
}

async function submitAuth() {
  formError.value = ''
  const success =
    authMode.value === 'register'
      ? await crypto.register(handle.value.trim(), password.value)
      : await crypto.login(password.value)
  if (!success) formError.value = errorText(crypto.error)
  else password.value = ''
}
async function resolveTransferRecipient() {
  formError.value = ''
  transferRecipient.value = null
  const recipient = await crypto.resolveRecipient(transferWalletKey.value)
  if (!recipient) formError.value = errorText(crypto.error)
  else {
    transferWalletKey.value = recipient.walletKey
    transferRecipient.value = recipient
  }
}
async function submitTransfer() {
  formError.value = ''
  if (
    !transferRecipient.value ||
    transferRecipient.value.walletKey !== transferWalletKey.value ||
    !transferMarket.value ||
    !/^\d+(?:\.\d{1,6})?$/.test(transferQuantity.value)
  ) {
    formError.value = t('errors.invalid_transfer')
    return
  }
  const success = await crypto.transfer({
    marketId: transferMarket.value.id,
    password: transferPassword.value,
    quantity: transferQuantity.value,
    walletKey: transferRecipient.value.walletKey,
  })
  if (!success) formError.value = errorText(crypto.error)
  else closeSheet()
}
function copyWalletKey() {
  if (!profile.value?.walletKey) return
  walletKeyCopied.value = copyText(profile.value.walletKey)
  if (walletKeyCopied.value) {
    globalThis.setTimeout(() => (walletKeyCopied.value = false), 1800)
  }
}
function shareWalletKey() {
  if (!profile.value?.walletKey) return
  easyShare.open({
    appId: 'crypto',
    copyText: `${t('profile.shareText')}\n${profile.value.walletKey}`,
    id: profile.value.walletKey,
    kind: 'text',
    subtitle: `@${profile.value.handle}`,
    title: t('profile.shareTitle'),
  })
}
function activityValue(item: CryptoActivity) {
  if (item.type === 'transfer_in' || item.type === 'transfer_out') {
    return `${quantity(item.quantity ?? '0')} ${market(item.marketId)?.symbol ?? ''}`
  }
  return privateMoney(item.amount)
}
function activityIsDebit(item: CryptoActivity) {
  return ['buy', 'withdrawal', 'transfer_out'].includes(item.type)
}
async function submitSettlement() {
  if (sheet.value !== 'deposit' && sheet.value !== 'withdraw') return
  if (!/^\d+$/.test(amount.value) || Number(amount.value) <= 0) {
    formError.value = t('errors.invalid_amount')
    return
  }
  if (
    !(await crypto.settle(sheet.value, amount.value, financialPassword.value))
  )
    formError.value = errorText(crypto.error)
  else closeSheet()
}
async function requestQuote() {
  if (!selectedMarket.value || !/^\d+(?:\.\d{1,6})?$/.test(amount.value)) {
    formError.value = t('errors.invalid_quantity')
    return
  }
  if (
    !(await crypto.quote(selectedMarket.value.id, side.value, amount.value))
      .success
  )
    formError.value = errorText(crypto.error)
}
async function executeQuote() {
  if (!(await crypto.executeQuote())) formError.value = errorText(crypto.error)
  else closeSheet()
}
async function saveProfile() {
  saved.value = false
  formError.value = ''
  const success = await crypto.updateProfile({
    handle: profileHandle.value.trim(),
    hideBalances: hideBalances.value,
    currentPassword: profileCurrentPassword.value,
    newPassword: profileNewPassword.value,
    priceAlerts: priceAlerts.value,
    tradeConfirmations: confirmations.value,
  })
  if (!success) formError.value = errorText(crypto.error)
  else {
    closeSheet()
    saved.value = true
  }
}
async function savePreferences() {
  saved.value = false
  formError.value = ''
  const success = await crypto.updateProfile({
    handle: profile.value?.handle ?? '',
    hideBalances: hideBalances.value,
    currentPassword: '',
    newPassword: '',
    priceAlerts: priceAlerts.value,
    tradeConfirmations: confirmations.value,
  })
  if (!success) formError.value = errorText(crypto.error)
  else saved.value = true
}
async function signOut() {
  if (logoutSubmitting.value) return
  logoutSubmitting.value = true
  closeSheet()
  try {
    await crypto.logout()
    if (!authenticated.value) {
      logoutDialogOpen.value = false
      tab.value = 'portfolio'
    }
  } finally {
    logoutSubmitting.value = false
  }
}

watch(
  () => account.email,
  (email) => {
    if (!email || handle.value) return
    handle.value = (email.split('@')[0] ?? '')
      .replace(/[^a-zA-Z0-9._]/g, '')
      .slice(0, 20)
  },
  { immediate: true },
)
watch(
  profile,
  (value) => {
    if (!value) return
    profileHandle.value = value.handle
    priceAlerts.value = value.priceAlerts
    confirmations.value = value.tradeConfirmations
    hideBalances.value = value.hideBalances
  },
  { immediate: true },
)
watch(amount, () => {
  if (sheet.value === 'trade' && crypto.pendingQuote) {
    crypto.pendingQuote = null
    formError.value = ''
  }
})
watch(transferWalletKey, () => {
  if (
    transferRecipient.value?.walletKey !== transferWalletKey.value.toUpperCase()
  ) {
    transferRecipient.value = null
  }
})
watch(
  () => crypto.data?.registered,
  (registered) => {
    if (!authenticated.value) authMode.value = registered ? 'login' : 'register'
  },
  { immediate: true },
)
watch(markets, (value) => {
  if (detail.value) {
    detail.value =
      value.find((market) => market.id === detail.value?.id) ?? null
  }
  if (selectedMarket.value) {
    selectedMarket.value =
      value.find((market) => market.id === selectedMarket.value?.id) ?? null
  }
})
function scheduleDevelopmentMarketTick() {
  if (!import.meta.env.DEV) return
  marketPreviewTimer = window.setTimeout(
    async () => {
      await crypto.previewMarketTick()
      scheduleDevelopmentMarketTick()
    },
    4500 + Math.random() * 2500,
  )
}
onMounted(async () => {
  await crypto.load()
  scheduleDevelopmentMarketTick()
})
onUnmounted(() => {
  if (marketPreviewTimer !== undefined) window.clearTimeout(marketPreviewTimer)
})
</script>

<template>
  <SkyAppPage
    class="crypto-app"
    accent="#31d6aa"
    accent-soft="rgba(49,214,170,.16)"
    dark
  >
    <SkyNavbar
      v-if="authenticated"
      :key="
        detail ? `detail-${detail.id}` : `page-${authenticated ? tab : 'auth'}`
      "
      class="vault-navbar"
      :class="{
        'vault-navbar--profile': authenticated && tab === 'profile' && !detail,
      }"
      :title="detail?.symbol ?? (authenticated ? t(`tabs.${tab}`) : t('name'))"
      :show-back="Boolean(detail)"
      back-appearance="surface"
      :back-label="t('marketDetail.back')"
      @back="detail = null"
    >
      <template #title>
        <span
          v-if="!detail && (!authenticated || tab === 'portfolio')"
          class="vault-header-brand"
        >
          <img class="vault-header-logo" :src="cryptoHeaderLogo" alt="" />
          <span>{{ t('name') }}</span>
        </span>
        <span v-else-if="detail" class="vault-detail-title">
          <CryptoLogo class="vault-detail-logo" :market="detail" />
          <span>
            <b>{{ detail.symbol }}</b>
            <small>{{ detail.name }}</small>
          </span>
        </span>
        <strong v-else class="vault-section-title">
          {{ t(`tabs.${tab}`) }}
        </strong>
      </template>
      <template v-if="authenticated && tab === 'profile' && !detail" #right>
        <SkyLink
          component="button"
          class="profile-signout"
          type="button"
          :aria-label="t('logout')"
          :title="t('logout')"
          @click="logoutDialogOpen = true"
        >
          <LogOut :size="14" />
          <span>{{ t('logout') }}</span>
        </SkyLink>
      </template>
    </SkyNavbar>

    <SkyScrollArea
      v-if="crypto.isLoading && !crypto.data"
      key="loading"
      class="state vault-view"
      padded
      ><SkySpinner />
      <p>{{ t('loading') }}</p></SkyScrollArea
    >
    <template v-else-if="!authenticated">
      <SkyScrollArea key="auth" class="auth vault-view" padded>
        <div class="auth-shell">
          <div class="auth-hero">
            <span class="auth-hero__mark">
              <img :src="cryptoHeaderLogo" alt="" />
            </span>
            <h2>
              {{
                t(
                  authMode === 'login'
                    ? 'auth.loginTitle'
                    : 'auth.registerTitle',
                )
              }}
            </h2>
          </div>
          <section class="auth-panel">
            <SkySegmented
              class="auth-mode"
              strong
              :active-index="authMode === 'login' ? 0 : 1"
              :item-count="2"
              ><SkySegmentedButton
                :active="authMode === 'login'"
                @click="authMode = 'login'"
                >{{ t('auth.login') }}</SkySegmentedButton
              ><SkySegmentedButton
                :active="authMode === 'register'"
                @click="authMode = 'register'"
                >{{ t('auth.register') }}</SkySegmentedButton
              ></SkySegmented
            >
            <div class="auth-account">
              <span><Mail :size="20" /></span>
              <div>
                <small>{{ t('auth.accountEmail') }}</small>
                <strong>{{ account.email || t('auth.accountMissing') }}</strong>
              </div>
              <ShieldCheck :size="17" />
            </div>
            <form class="form auth-form" @submit.prevent="submitAuth">
              <SkyField
                v-if="authMode === 'register'"
                v-model="handle"
                class="auth-field"
                :label="t('auth.handle')"
                :placeholder="t('auth.handlePlaceholder')"
                autocomplete="username"
                maxlength="20"
                outline
                ><template #leading><UserRound :size="18" /></template
              ></SkyField>
              <SkyField
                v-model="password"
                class="auth-field"
                :label="t('auth.password')"
                :type="showPassword ? 'text' : 'password'"
                :placeholder="t('auth.passwordPlaceholder')"
                :autocomplete="
                  authMode === 'login' ? 'current-password' : 'new-password'
                "
                maxlength="72"
                outline
                ><template #leading><LockKeyhole :size="18" /></template
                ><template #trailing
                  ><button
                    class="visibility"
                    type="button"
                    @click="showPassword = !showPassword"
                  >
                    <EyeOff v-if="showPassword" :size="18" /><Eye
                      v-else
                      :size="18"
                    /></button></template
              ></SkyField>
              <p v-if="authMode === 'register'" class="auth-password-hint">
                {{ t('auth.ruleLength') }} · {{ t('auth.ruleMixed') }} ·
                {{ t('auth.ruleNumber') }} · {{ t('auth.ruleSpecial') }}
              </p>
              <p v-if="formError" class="error">{{ formError }}</p>
              <SkyButton block large class="auth-submit" type="submit">{{
                t(
                  authMode === 'login'
                    ? 'auth.loginAction'
                    : 'auth.registerAction',
                )
              }}</SkyButton>
            </form>
          </section>
        </div>
      </SkyScrollArea>
    </template>

    <SkyScrollArea
      v-else-if="detail"
      :key="`detail-${detail.id}`"
      class="vault-view vault-detail-scroll"
      with-tabbar
      padded
    >
      <section class="detail-head">
        <CryptoLogo class="coin large" :market="detail" />
        <p>{{ detail.symbol }} · {{ detail.name }}</p>
        <strong>{{ money(detail.price) }}</strong
        ><em :class="detailChart.changePercent >= 0 ? 'up' : 'down'"
          >{{ detailChart.changePercent >= 0 ? '▲' : '▼' }}
          {{ Math.abs(detailChart.changePercent).toFixed(2) }}% ·
          {{ period === '1D' ? t('marketDetail.today') : period }}</em
        >
      </section>
      <SkyCard class="big-chart"
        ><svg
          :key="`${detail.id}-${period}`"
          class="detail-chart"
          viewBox="0 0 320 180"
          preserveAspectRatio="none"
          role="img"
          :aria-label="`${detail.symbol} · ${period}`"
        >
          <defs>
            <linearGradient id="fill" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0" stop-color="#31d6aa" stop-opacity=".4" />
              <stop offset="1" stop-color="#31d6aa" stop-opacity="0" />
            </linearGradient>
          </defs>
          <g class="detail-chart__grid">
            <line
              v-for="tick in detailChart.yTicks"
              :key="tick.y"
              x1="52"
              :y1="tick.y"
              x2="307"
              :y2="tick.y"
            />
            <line
              v-for="tick in detailChart.xTicks"
              :key="tick.x"
              :x1="tick.x"
              y1="14"
              :x2="tick.x"
              y2="137"
            />
          </g>
          <g class="detail-chart__axis">
            <text
              v-for="tick in detailChart.yTicks"
              :key="tick.label"
              x="47"
              :y="tick.y + 3"
              text-anchor="end"
            >
              {{ tick.label }}
            </text>
            <text
              v-for="(tick, index) in detailChart.xTicks"
              :key="tick.label"
              :x="tick.x"
              y="158"
              :text-anchor="
                index === 0 ? 'start' : index === 4 ? 'end' : 'middle'
              "
            >
              {{ tick.label }}
            </text>
          </g>
          <polygon :points="detailChart.areaPoints" fill="url(#fill)" />
          <polyline :points="detailChart.points" />
          <g class="detail-chart__marker">
            <line
              :x1="detailChart.marker.x"
              y1="14"
              :x2="detailChart.marker.x"
              y2="137"
            />
            <circle
              :cx="detailChart.marker.x"
              :cy="detailChart.marker.y"
              r="4.5"
            />
            <text
              :x="detailChart.marker.x - 7"
              :y="detailChart.marker.labelY"
              text-anchor="end"
            >
              {{ chartMoney(Number(detail.price)) }}
            </text>
          </g>
        </svg>
        <div class="periods">
          <button
            v-for="value in CHART_PERIODS"
            :key="value"
            :class="{ active: period === value }"
            :aria-pressed="period === value"
            @click="period = value"
          >
            {{ value }}
          </button>
        </div></SkyCard
      >
      <p class="detail-copy">{{ t('marketDetail.description') }}</p>
      <h2 class="title">{{ t('marketDetail.investment') }}</h2>
      <SkyCard class="investment"
        ><small>{{ t('marketDetail.totalValue') }}</small
        ><strong>{{ privateMoney(detailHolding?.value ?? '0') }}</strong>
        <div>
          <CryptoLogo class="coin" :market="detail" /><span
            ><b>{{ detail.name }}</b
            ><small
              >{{ quantity(detailHolding?.quantity ?? '0') }}
              {{ detail.symbol }}</small
            ></span
          ><span
            ><b>{{ privateMoney(detailHolding?.value ?? '0') }}</b
            ><small
              >{{ t('portfolio.avg') }}
              {{ money(detailHolding?.averagePrice ?? detail.price) }}</small
            ></span
          >
        </div></SkyCard
      >
      <h2 class="title">{{ t('marketDetail.statistics') }}</h2>
      <SkyCard class="stats"
        ><div>
          <span>{{ t('marketDetail.high24h') }}</span
          ><b>{{ money(detail.high24h) }}</b>
        </div>
        <div>
          <span>{{ t('marketDetail.low24h') }}</span
          ><b>{{ money(detail.low24h) }}</b>
        </div>
        <div>
          <span>{{ t('marketDetail.supply') }}</span
          ><b>{{ compact(detail.issuedSupply) }} {{ detail.symbol }}</b>
        </div>
        <div>
          <span>{{ t('marketDetail.liquidity') }}</span
          ><b>{{ compact(detail.treasuryAvailable) }} {{ detail.symbol }}</b>
        </div></SkyCard
      >
    </SkyScrollArea>

    <SkyScrollArea
      v-else
      :key="`tab-${tab}`"
      class="vault-view"
      with-tabbar
      padded
    >
      <template v-if="tab === 'portfolio'">
        <section class="portfolio-shell">
          <div class="portfolio-glow" />
          <div class="portfolio-topline">
            <span
              ><ShieldCheck :size="13" />{{ t('portfolio.performance') }}</span
            >
            <span class="forecast-pill">{{ t('portfolio.forecast') }}</span>
          </div>
          <div class="portfolio-value">
            <strong :class="portfolioProfitLoss >= 0 ? 'up' : 'down'">
              {{ privateSignedMoney(portfolioProfitLoss) }}
            </strong>
            <span :class="portfolioProfitPercent >= 0 ? 'up' : 'down'">
              {{ portfolioProfitPercent >= 0 ? '↗' : '↘' }}
              {{ Math.abs(portfolioProfitPercent).toFixed(2) }}%
              <small>{{ t('portfolio.return') }}</small>
            </span>
          </div>
          <div
            class="portfolio-chart"
            role="img"
            :aria-label="t('portfolio.chartLabel')"
          >
            <div class="portfolio-chart__legend">
              <span><i />{{ t('portfolio.history') }}</span>
              <span
                ><i class="is-forecast" />{{ t('portfolio.forecast') }}</span
              >
            </div>
            <svg
              :viewBox="`0 0 ${portfolioChart.width} ${portfolioChart.height}`"
              aria-hidden="true"
            >
              <rect
                class="portfolio-chart__forecast-zone"
                :x="portfolioChart.currentX"
                y="0"
                :width="portfolioChart.width - portfolioChart.currentX"
                :height="portfolioChart.height"
              />
              <line
                class="portfolio-chart__grid"
                x1="18"
                y1="15"
                x2="306"
                y2="15"
              />
              <line
                class="portfolio-chart__zero"
                x1="18"
                :y1="portfolioChart.zeroY"
                x2="306"
                :y2="portfolioChart.zeroY"
              />
              <line
                class="portfolio-chart__grid"
                x1="18"
                :y1="portfolioChart.height - 16"
                x2="306"
                :y2="portfolioChart.height - 16"
              />
              <line
                class="portfolio-chart__boundary"
                :x1="portfolioChart.currentX"
                y1="4"
                :x2="portfolioChart.currentX"
                :y2="portfolioChart.height - 8"
              />
              <polyline
                class="portfolio-history"
                :points="portfolioChart.historyPoints"
              />
              <polyline
                class="portfolio-forecast"
                :points="portfolioChart.forecastPoints"
              />
              <circle
                class="portfolio-current-dot"
                :cx="portfolioChart.currentX"
                :cy="portfolioChart.currentY"
                r="4.5"
              />
              <g
                class="portfolio-current-label"
                :transform="`translate(${portfolioChart.currentX - 48} ${portfolioChart.labelY})`"
              >
                <rect width="96" height="20" rx="10" />
                <text x="48" y="13" text-anchor="middle">
                  {{ t('portfolio.current') }}
                </text>
              </g>
              <text class="portfolio-scale-label" x="18" y="10">
                {{ privateSignedMoney(portfolioChart.scale) }}
              </text>
              <text
                class="portfolio-scale-label"
                x="18"
                :y="portfolioChart.height - 3"
              >
                {{ privateSignedMoney(-portfolioChart.scale) }}
              </text>
            </svg>
          </div>
          <div class="portfolio-metrics">
            <div>
              <small>{{ t('portfolio.cash') }}</small>
              <b>{{ privateMoney(crypto.data?.cashBalance ?? '0') }}</b>
            </div>
            <i />
            <div>
              <small>{{ t('portfolio.invested') }}</small>
              <b>{{ privateMoney(investedValue) }}</b>
            </div>
          </div>
        </section>
        <div class="quick">
          <button @click="setTab('markets')">
            <span><ChartNoAxesCombined :size="20" /></span>
            <b>{{ t('quick.trade') }}</b></button
          ><button @click="openSettlement('deposit')">
            <span><ArrowDownLeft :size="20" /></span>
            <b>{{ t('actions.deposit') }}</b></button
          ><button @click="openSettlement('withdraw')">
            <span><ArrowUpRight :size="20" /></span>
            <b>{{ t('actions.withdraw') }}</b></button
          ><button @click="openSend">
            <span><Send :size="20" /></span>
            <b>{{ t('quick.send') }}</b>
          </button>
        </div>
        <SkyCard class="allocation-card">
          <div class="allocation-copy">
            <span><WalletCards :size="19" /></span>
            <div>
              <small>{{ t('portfolio.allocation') }}</small>
              <b
                >{{ Math.round(100 - cashShare) }}%
                {{ t('portfolio.inMarket') }}</b
              >
            </div>
            <strong>{{ Math.round(cashShare) }}%</strong>
          </div>
          <div class="allocation-track">
            <i :style="{ width: `${Math.max(3, 100 - cashShare)}%` }" />
          </div>
        </SkyCard>
        <div class="heading">
          <h2>{{ t('portfolio.holdings') }}</h2>
          <em>{{ holdings.length }} {{ t('portfolio.assets') }}</em>
        </div>
        <SkyEmptyState
          v-if="!holdings.length"
          :title="t('portfolio.empty')"
          :description="t('portfolio.emptyBody')"
        /><button
          v-for="holding in holdings"
          v-else
          :key="holding.assetId"
          class="row asset-row"
          @click="openMarket(market(holding.assetId)!)"
        >
          <CryptoLogo class="coin" :market="market(holding.assetId)!" /><span
            ><b>{{ market(holding.assetId)?.name }}</b
            ><small
              >{{ quantity(holding.quantity) }}
              {{ market(holding.assetId)?.symbol }}</small
            ><i class="asset-allocation"
              ><i
                :style="{
                  width: `${allocation(holding.value)}%`,
                }" /></i></span
          ><span
            ><b>{{ privateMoney(holding.value) }}</b
            ><small
              :class="
                (market(holding.assetId)?.changePercent ?? 0) >= 0
                  ? 'up'
                  : 'down'
              "
              >{{ market(holding.assetId)?.changePercent.toFixed(2) }}%</small
            ></span
          ><ChevronRight :size="17" />
        </button>
        <SkyStatusCard
          tone="neutral"
          :title="t('portfolio.insightTitle')"
          :subtitle="t('portfolio.insightBody')"
          ><template #icon><Sparkles :size="19" /></template
        ></SkyStatusCard>
      </template>

      <template v-else-if="tab === 'markets'">
        <div class="market-head">
          <span
            ><small>{{ t('markets.eyebrow') }}</small>
            <h2>{{ t('markets.title') }}</h2></span
          ><em>{{ t('markets.live') }}</em>
        </div>
        <button
          v-if="topMover"
          class="featured-market"
          @click="openMarket(topMover)"
        >
          <div class="featured-market__top">
            <CryptoLogo class="coin large" :market="topMover" />
            <span>
              <small>{{ t('markets.movers') }}</small>
              <b>{{ topMover.name }}</b>
              <em>{{ topMover.symbol }}</em>
            </span>
            <ChevronRight :size="18" />
          </div>
          <div class="featured-market__quote">
            <strong>{{ money(topMover.price) }}</strong>
            <span :class="topMover.changePercent >= 0 ? 'up' : 'down'">
              {{ topMover.changePercent >= 0 ? '↗' : '↘' }}
              {{ Math.abs(topMover.changePercent).toFixed(2) }}%
            </span>
          </div>
          <svg viewBox="0 0 320 74" preserveAspectRatio="none">
            <polyline :points="points(topMover.sparkline, 320, 70)" />
          </svg>
          <div class="featured-market__stats">
            <span
              ><small>{{ t('marketDetail.high24h') }}</small
              ><b>{{ money(topMover.high24h) }}</b></span
            >
            <span
              ><small>{{ t('marketDetail.low24h') }}</small
              ><b>{{ money(topMover.low24h) }}</b></span
            >
          </div>
        </button>
        <div class="heading market-list-heading">
          <h2>{{ t('portfolio.assets') }}</h2>
          <em>{{ markets.length }} {{ t('markets.live') }}</em>
        </div>
        <div class="market-grid market-grid--advanced">
          <button
            v-for="item in markets"
            :key="item.id"
            @click="openMarket(item)"
          >
            <div class="market-tile__top">
              <CryptoLogo class="coin" :market="item" />
              <span
                ><b>{{ item.symbol }}</b
                ><small>{{ item.name }}</small></span
              >
              <em :class="item.changePercent >= 0 ? 'up' : 'down'">
                {{ item.changePercent >= 0 ? '+' : ''
                }}{{ item.changePercent.toFixed(2) }}%
              </em>
            </div>
            <div class="market-tile__price">
              <b>{{ money(item.price) }}</b>
              <small>{{ t('markets.today') }}</small>
            </div>
            <svg viewBox="0 0 150 52" preserveAspectRatio="none">
              <polyline :points="points(item.sparkline, 150, 50)" />
            </svg>
          </button>
        </div>
        <SkyCard class="movers"
          ><div class="heading">
            <h2>{{ t('markets.movers') }}</h2>
            <em>{{ t('markets.today') }}</em>
          </div>
          <button
            v-for="item in [...markets]
              .sort((a, b) => b.changePercent - a.changePercent)
              .slice(0, 5)"
            :key="item.id"
            @click="openMarket(item)"
          >
            <CryptoLogo class="coin" :market="item" /><span
              ><b>{{ item.name }}</b
              ><small>{{ item.symbol }} · {{ t('markets.today') }}</small></span
            ><span
              ><b>{{ money(item.price) }}</b
              ><small :class="item.changePercent >= 0 ? 'up' : 'down'"
                >{{ item.changePercent >= 0 ? '+' : ''
                }}{{ item.changePercent.toFixed(2) }}%</small
              ></span
            >
          </button></SkyCard
        >
        <SkyStatusCard
          tone="accent"
          :title="t('markets.noticeTitle')"
          :subtitle="t('markets.notice')"
        />
      </template>

      <template v-else-if="tab === 'activity'">
        <section class="activity-overview">
          <div class="activity-head activity-dashboard">
            <div class="activity-dashboard__copy">
              <p><History :size="14" />{{ t('activity.volume') }}</p>
              <strong>{{ privateMoney(profile?.totalVolume ?? '0') }}</strong>
              <span class="activity-trade-count"
                ><i />{{ profile?.totalTrades }}
                {{ t('activity.completedTrades') }}</span
              >
            </div>
            <div class="activity-status">
              <span class="activity-status__icon">
                <ShieldCheck :size="19" />
              </span>
              <b>{{ t('statuses.completed') }}</b>
            </div>
          </div>
          <div class="activity-filter-panel">
            <SkySegmented
              class="activity-filters"
              strong
              rounded
              :aria-label="t('activity.title')"
              :active-index="
                activityFilter === 'all'
                  ? 0
                  : activityFilter === 'trades'
                    ? 1
                    : 2
              "
              :item-count="3"
              ><SkySegmentedButton
                :active="activityFilter === 'all'"
                @click="activityFilter = 'all'"
                ><span class="activity-filter-content"
                  ><History :size="15" /><span>{{
                    t('activity.filters.all')
                  }}</span></span
                ></SkySegmentedButton
              ><SkySegmentedButton
                :active="activityFilter === 'trades'"
                @click="activityFilter = 'trades'"
                ><span class="activity-filter-content"
                  ><ChartNoAxesCombined :size="15" /><span>{{
                    t('activity.filters.trades')
                  }}</span></span
                ></SkySegmentedButton
              ><SkySegmentedButton
                :active="activityFilter === 'wallet'"
                @click="activityFilter = 'wallet'"
                ><span class="activity-filter-content"
                  ><WalletCards :size="15" /><span>{{
                    t('activity.filters.wallet')
                  }}</span></span
                ></SkySegmentedButton
              ></SkySegmented
            >
          </div>
        </section>
        <div class="heading activity-title">
          <h2>{{ t('activity.title') }}</h2>
          <em>{{ activities.length }}</em>
        </div>
        <SkyEmptyState
          v-if="!activities.length"
          :title="t('activity.empty')"
          :description="t('activity.emptyBody')"
        />
        <div
          v-for="item in activities"
          v-else
          :key="item.id"
          class="row static activity-row"
        >
          <span :class="['activity-icon', `activity-icon--${item.type}`]">
            <ArrowDownLeft v-if="item.type === 'deposit'" :size="18" />
            <ArrowUpRight v-else-if="item.type === 'withdrawal'" :size="18" />
            <Send v-else-if="item.type === 'transfer_out'" :size="18" />
            <KeyRound v-else-if="item.type === 'transfer_in'" :size="18" />
            <ChartNoAxesCombined v-else :size="18" /> </span
          ><span
            ><b>{{ t(`activityTypes.${item.type}`) }}</b
            ><small
              >{{ market(item.marketId)?.symbol ?? t('activity.cash') }} ·
              {{
                new Intl.DateTimeFormat(locale, {
                  dateStyle: 'medium',
                  timeStyle: 'short',
                }).format(item.createdAt)
              }}</small
            ></span
          ><span
            ><b :class="activityIsDebit(item) ? 'down' : 'up'"
              >{{ activityIsDebit(item) ? '−' : '+'
              }}{{ activityValue(item) }}</b
            ><small>{{ t(`statuses.${item.status}`) }}</small></span
          >
          <i class="timeline-dot" />
        </div>
      </template>

      <template v-else>
        <section class="profile-card">
          <div class="profile-card__mesh" />
          <div class="profile-card__top">
            <span class="profile-avatar">{{
              profile?.handle.slice(0, 2).toUpperCase()
            }}</span>
            <span class="profile-status"><i />{{ t('profile.verified') }}</span>
          </div>
          <div class="profile-card__identity">
            <span>
              <h2>@{{ profile?.handle }}</h2>
              <p><ShieldCheck :size="15" />{{ t('profile.verified') }}</p>
            </span>
            <SkyButton
              class="profile-edit-button"
              rounded
              small
              @click="openProfileEditor"
            >
              <Settings2 :size="15" />{{ t('profile.edit') }}
            </SkyButton>
          </div>
          <div class="profile-card__id">
            <small>VAULTX ID</small>
            <b>{{ profile?.id.slice(0, 8).toUpperCase() }}</b>
            <Fingerprint :size="26" />
          </div>
        </section>
        <SkyCard class="wallet-key-card" :content-wrap="false">
          <div class="wallet-key-card__content">
            <span class="wallet-key-card__icon"><KeyRound :size="20" /></span>
            <span>
              <small>{{ t('profile.walletKey') }}</small>
              <b>{{ profile?.walletKey }}</b>
              <em>{{ t('profile.walletKeyBody') }}</em>
            </span>
          </div>
          <div class="wallet-key-card__actions">
            <SkyButton variant="secondary" tonal @click="copyWalletKey">
              <CheckCircle2 v-if="walletKeyCopied" :size="16" />
              <Copy v-else :size="16" />
              <span>{{
                t(walletKeyCopied ? 'profile.copied' : 'profile.copyKey')
              }}</span>
            </SkyButton>
            <SkyButton @click="shareWalletKey">
              <Share2 :size="16" /><span>{{ t('profile.shareKey') }}</span>
            </SkyButton>
          </div>
        </SkyCard>
        <div class="profile-stats profile-stats--premium">
          <div>
            <b>{{ profile?.totalTrades }}</b
            ><small>{{ t('profile.trades') }}</small>
          </div>
          <div>
            <b>{{ privateMoney(profile?.totalVolume ?? '0') }}</b
            ><small>{{ t('profile.volume') }}</small>
          </div>
          <div>
            <b>{{
              profile
                ? new Intl.DateTimeFormat(locale, {
                    month: 'short',
                    year: 'numeric',
                  }).format(profile.createdAt)
                : '—'
            }}</b>
            <small>{{ t('profile.memberSince') }}</small>
          </div>
        </div>
        <SkyCard class="security-overview" :content-wrap="false">
          <div class="security-score">
            <ShieldCheck :size="22" /><b>100</b><small>/100</small>
          </div>
          <span
            ><small>{{ t('profile.securityTitle') }}</small
            ><b>{{ t('profile.verified') }}</b
            ><em>{{ t('profile.securityBody') }}</em></span
          >
        </SkyCard>
        <h2 class="title">{{ t('profile.preferences') }}</h2>
        <SkyCard class="settings"
          ><label
            ><span
              ><BellRing :size="18" /><span
                ><b>{{ t('profile.priceAlerts') }}</b
                ><small>{{ t('profile.priceAlertsBody') }}</small></span
              ></span
            ><SkyToggle
              v-model="priceAlerts"
              @change="savePreferences" /></label
          ><label
            ><span
              ><Fingerprint :size="18" /><span
                ><b>{{ t('profile.confirmations') }}</b
                ><small>{{ t('profile.confirmationsBody') }}</small></span
              ></span
            ><SkyToggle
              v-model="confirmations"
              @change="savePreferences" /></label
          ><label
            ><span
              ><EyeOff :size="18" /><span
                ><b>{{ t('profile.hideBalances') }}</b
                ><small>{{ t('profile.hideBalancesBody') }}</small></span
              ></span
            ><SkyToggle
              v-model="hideBalances"
              @change="savePreferences" /></label
        ></SkyCard>
        <p v-if="saved" class="profile-feedback success">
          <ShieldCheck :size="15" />{{ t('profile.saved') }}
        </p>
        <p v-if="formError" class="profile-feedback error">{{ formError }}</p>
      </template>
    </SkyScrollArea>

    <div
      v-if="authenticated && detail"
      class="detail-trade-dock"
      role="group"
      :aria-label="t('trade.actions')"
    >
      <SkyButton
        large
        class="detail-trade-action detail-trade-action--buy"
        @click="openTrade(detail, 'buy')"
      >
        <span><ArrowDownLeft :size="19" /></span>
        <span>
          <b>{{ t('trade.buy') }}</b>
          <small>{{ t('trade.buyBody') }}</small>
        </span>
      </SkyButton>
      <SkyButton
        large
        variant="secondary"
        class="detail-trade-action detail-trade-action--sell"
        @click="openTrade(detail, 'sell')"
      >
        <span><ArrowUpRight :size="19" /></span>
        <span>
          <b>{{ t('trade.sell') }}</b>
          <small>{{ t('trade.sellBody') }}</small>
        </span>
      </SkyButton>
    </div>

    <SkyPillNavigation
      v-if="authenticated && !detail"
      layout="full"
      :label="t('navigation')"
      ><SkySegmented navigation
        ><SkySegmentedButton
          :active="tab === 'portfolio'"
          @click="setTab('portfolio')"
          ><WalletCards :size="19" /><span>{{
            t('tabs.portfolio')
          }}</span></SkySegmentedButton
        ><SkySegmentedButton
          :active="tab === 'markets'"
          @click="setTab('markets')"
          ><ChartNoAxesCombined :size="19" /><span>{{
            t('tabs.markets')
          }}</span></SkySegmentedButton
        ><SkySegmentedButton
          :active="tab === 'activity'"
          @click="setTab('activity')"
          ><History :size="19" /><span>{{
            t('tabs.activity')
          }}</span></SkySegmentedButton
        ><SkySegmentedButton
          :active="tab === 'profile'"
          @click="setTab('profile')"
          ><UserRound :size="19" /><span>{{
            t('tabs.profile')
          }}</span></SkySegmentedButton
        ></SkySegmented
      ></SkyPillNavigation
    >

    <SkySheet
      :opened="sheet !== null"
      swipe-to-close
      grabber-clickable
      :grabber-label="phone.t('Common.close')"
      @backdropclick="closeSheet"
      @escape="closeSheet"
      @grabberclick="closeSheet"
      @swipeclose="closeSheet"
      ><div
        v-if="sheet"
        class="sheet"
        :class="{
          'sheet--profile': sheet === 'profile',
          'sheet--settlement': sheet === 'deposit' || sheet === 'withdraw',
        }"
      >
        <header class="sheet-header" data-sky-sheet-drag-handle>
          <div class="sheet-heading">
            <span
              class="sheet-icon"
              :class="{
                'sheet-icon--crypto': sheet === 'trade' && selectedMarket,
              }"
            >
              <CryptoLogo
                v-if="sheet === 'trade' && selectedMarket"
                class="sheet-crypto-logo"
                :market="selectedMarket"
              />
              <ArrowDownLeft v-else-if="sheet === 'deposit'" :size="19" />
              <ArrowUpRight v-else-if="sheet === 'withdraw'" :size="19" />
              <Send v-else-if="sheet === 'send'" :size="19" />
              <UserRound v-else :size="19" />
            </span>
            <span>
              <small>{{
                sheet === 'trade' && selectedMarket
                  ? selectedMarket.name
                  : sheet === 'profile'
                    ? t('profile.account')
                    : sheet === 'send'
                      ? t('transfer.subtitle')
                      : t('activity.cash')
              }}</small>
              <h2>
                {{
                  sheet === 'trade'
                    ? `${t(`trade.${side}`)} ${selectedMarket?.symbol}`
                    : sheet === 'profile'
                      ? t('profile.editTitle')
                      : sheet === 'send'
                        ? t('transfer.title')
                        : t(`actions.${sheet}`)
                }}
              </h2>
            </span>
          </div>
        </header>
        <template v-if="sheet === 'trade' && selectedMarket">
          <div class="sheet-market-summary">
            <span>
              <small>{{ t('trade.marketPrice') }}</small>
              <b>{{ money(selectedMarket.price) }}</b>
            </span>
            <em :class="selectedMarket.changePercent >= 0 ? 'up' : 'down'">
              {{ selectedMarket.changePercent >= 0 ? '↗' : '↘' }}
              {{ Math.abs(selectedMarket.changePercent).toFixed(2) }}%
            </em>
          </div>
          <SkySegmented
            class="trade-side-selector"
            strong
            rounded
            :item-count="2"
            :active-index="side === 'buy' ? 0 : 1"
            ><SkySegmentedButton
              :active="side === 'buy'"
              @click="selectTradeSide('buy')"
              ><ArrowDownLeft :size="16" />{{
                t('trade.buy')
              }}</SkySegmentedButton
            ><SkySegmentedButton
              :active="side === 'sell'"
              @click="selectTradeSide('sell')"
              ><ArrowUpRight :size="16" />{{
                t('trade.sell')
              }}</SkySegmentedButton
            ></SkySegmented
          >
          <div class="trade-entry-card">
            <SkyField
              v-model="amount"
              class="sheet-field"
              :error="Boolean(formError)"
              :label="t('trade.quantity')"
              placeholder="0.000000"
              inputmode="decimal"
              outline
              ><template #leading><ChartCandlestick :size="18" /></template
            ></SkyField>
            <div class="trade-entry-meta">
              <span>
                <small>{{ t('trade.available') }}</small>
                <b v-if="side === 'buy'">{{
                  privateMoney(crypto.data?.cashBalance ?? '0')
                }}</b>
                <b v-else>
                  {{ quantity(selectedHolding?.quantity ?? '0') }}
                  {{ selectedMarket.symbol }}
                </b>
              </span>
              <span>
                <small>{{ t('trade.estimated') }}</small>
                <b>{{ money(estimatedTradeValue) }}</b>
              </span>
            </div>
          </div>
          <div v-if="!crypto.pendingQuote" class="trade-protection">
            <ShieldCheck :size="18" />
            <span>
              <b>{{ t('trade.protected') }}</b>
              <small>{{ t('trade.protectedBody') }}</small>
            </span>
          </div>
          <SkyCard
            v-if="crypto.pendingQuote"
            class="quote"
            :content-wrap="false"
          >
            <div class="quote-heading">
              <span>
                <small>{{ t('trade.review') }}</small>
                <b>{{ t(`trade.${side}`) }} {{ selectedMarket.symbol }}</b>
              </span>
              <ShieldCheck :size="18" />
            </div>
            <div>
              <span>{{ t('trade.price') }}</span
              ><b>{{ money(crypto.pendingQuote.price) }}</b>
            </div>
            <div>
              <span>{{ t('trade.gross') }}</span
              ><b>{{ money(crypto.pendingQuote.gross) }}</b>
            </div>
            <div>
              <span>{{ t('trade.fee') }}</span
              ><b>{{ money(crypto.pendingQuote.fee) }}</b>
            </div>
            <div>
              <span>{{ t('trade.total') }}</span
              ><b>{{ money(crypto.pendingQuote.net) }}</b>
            </div>
            <small class="quote-expiry">{{ t('trade.quoteExpiry') }}</small>
          </SkyCard>
          <p v-if="formError" class="error">{{ formError }}</p>
          <SkyButton
            block
            large
            class="trade-submit"
            :class="`trade-submit--${side}`"
            @click="crypto.pendingQuote ? executeQuote() : requestQuote()"
            >{{
              t(crypto.pendingQuote ? 'trade.confirm' : 'trade.getQuote')
            }}</SkyButton
          > </template
        ><template v-else-if="sheet === 'send'">
          <div class="transfer-intro">
            <span><KeyRound :size="19" /></span>
            <div>
              <b>{{ t('transfer.keyTitle') }}</b
              ><small>{{ t('transfer.keyBody') }}</small>
            </div>
          </div>
          <div class="transfer-key-entry">
            <SkyField
              v-model="transferWalletKey"
              class="sheet-field"
              :label="t('transfer.walletKey')"
              placeholder="VX-0000-0000-0000-0000"
              maxlength="22"
              autocomplete="off"
              outline
              ><template #leading><KeyRound :size="17" /></template
            ></SkyField>
            <SkyButton
              class="transfer-resolve"
              @click="resolveTransferRecipient"
            >
              {{ t('transfer.verify') }}
            </SkyButton>
          </div>
          <div v-if="transferRecipient" class="transfer-recipient">
            <span><CheckCircle2 :size="20" /></span>
            <div>
              <small>{{ t('transfer.verifiedRecipient') }}</small
              ><b>@{{ transferRecipient.handle }}</b
              ><em>{{ transferRecipient.walletKey }}</em>
            </div>
          </div>
          <div class="transfer-assets">
            <small>{{ t('transfer.asset') }}</small>
            <div>
              <button
                v-for="holding in holdings"
                :key="holding.assetId"
                :class="{ active: transferMarketId === holding.assetId }"
                @click="transferMarketId = holding.assetId"
              >
                <CryptoLogo :market="market(holding.assetId)!" />
                <span
                  ><b>{{ market(holding.assetId)?.symbol }}</b
                  ><small>{{ quantity(holding.quantity) }}</small></span
                >
              </button>
            </div>
          </div>
          <SkyField
            v-model="transferQuantity"
            class="sheet-field"
            :label="t('transfer.quantity')"
            placeholder="0.000000"
            inputmode="decimal"
            outline
            ><template #trailing
              ><b>{{ transferMarket?.symbol }}</b></template
            ><template #leading><Send :size="18" /></template
          ></SkyField>
          <div class="transfer-balance">
            <span>{{ t('transfer.available') }}</span>
            <b
              >{{ quantity(transferHolding?.quantity ?? '0') }}
              {{ transferMarket?.symbol }}</b
            >
          </div>
          <SkyField
            v-model="transferPassword"
            class="sheet-field"
            :label="t('transfer.password')"
            type="password"
            autocomplete="current-password"
            outline
            ><template #leading><LockKeyhole :size="17" /></template
          ></SkyField>
          <div class="trade-protection">
            <ShieldCheck :size="17" />
            <span
              ><b>{{ t('transfer.protected') }}</b
              ><small>{{ t('transfer.protectedBody') }}</small></span
            >
          </div>
          <p v-if="formError" class="error">{{ formError }}</p>
          <SkyButton
            block
            large
            class="transfer-submit"
            @click="submitTransfer"
          >
            <Send :size="17" />{{ t('transfer.confirm') }}
          </SkyButton> </template
        ><template v-else-if="sheet === 'profile'">
          <p class="sheet-copy">{{ t('profile.editBody') }}</p>
          <form class="profile-edit-sheet" @submit.prevent="saveProfile">
            <div class="profile-edit-fields">
              <SkyField
                v-model="profileHandle"
                class="sheet-field profile-edit-field"
                :error="Boolean(formError)"
                :label="t('auth.handle')"
                maxlength="20"
                autocomplete="username"
                outline
                ><template #leading><UserRound :size="18" /></template
              ></SkyField>
              <SkyField
                v-model="profileCurrentPassword"
                class="sheet-field profile-edit-field"
                :error="Boolean(formError)"
                :label="t('profile.currentPassword')"
                :placeholder="t('profile.currentPasswordPlaceholder')"
                type="password"
                autocomplete="current-password"
                outline
                ><template #leading><LockKeyhole :size="18" /></template
              ></SkyField>
              <SkyField
                v-model="profileNewPassword"
                class="sheet-field profile-edit-field"
                :error="Boolean(formError)"
                :label="t('profile.newPassword')"
                :placeholder="t('profile.newPasswordPlaceholder')"
                type="password"
                autocomplete="new-password"
                outline
                ><template #leading><Fingerprint :size="18" /></template
              ></SkyField>
            </div>
            <div class="profile-edit-note">
              <ShieldCheck :size="17" />
              <span>{{ t('profile.passwordSecurity') }}</span>
            </div>
            <p v-if="formError" class="error">{{ formError }}</p>
            <SkyButton block large class="profile-save-button" type="submit">
              <ShieldCheck :size="18" />
              <span>{{ t('profile.saveChanges') }}</span>
            </SkyButton>
          </form>
        </template>
        <template v-else>
          <form class="settlement-form" @submit.prevent="submitSettlement">
            <div class="settlement-intro">
              <span><ShieldCheck :size="18" /></span>
              <p class="sheet-copy settlement-copy">
                {{
                  t(
                    sheet === 'deposit'
                      ? 'settlement.depositBody'
                      : 'settlement.withdrawBody',
                  )
                }}
              </p>
            </div>
            <div class="settlement-fields">
              <SkyField
                v-model="amount"
                class="sheet-field settlement-field"
                :error="Boolean(formError)"
                :label="t('settlement.amount')"
                placeholder="0"
                inputmode="numeric"
                outline
                ><template #leading><WalletCards :size="18" /></template
              ></SkyField>
              <SkyField
                v-model="financialPassword"
                class="sheet-field settlement-field"
                :error="Boolean(formError)"
                :label="t('auth.password')"
                type="password"
                autocomplete="current-password"
                outline
                ><template #leading><LockKeyhole :size="18" /></template
              ></SkyField>
            </div>
            <p v-if="formError" class="error settlement-error">
              {{ formError }}
            </p>
            <SkyButton block large class="settlement-submit" type="submit">
              <ShieldCheck :size="18" />
              <span>{{ t('settlement.confirm') }}</span>
            </SkyButton>
          </form>
        </template>
      </div></SkySheet
    >
    <SkyDialog
      :opened="logoutDialogOpen"
      role="alertdialog"
      @backdropclick="!logoutSubmitting && (logoutDialogOpen = false)"
      @escape="!logoutSubmitting && (logoutDialogOpen = false)"
    >
      <template #title>{{ t('logoutConfirm.title') }}</template>
      <p>{{ t('logoutConfirm.body') }}</p>
      <template #buttons>
        <SkyDialogButton
          :disabled="logoutSubmitting"
          @click="logoutDialogOpen = false"
        >
          {{ t('logoutConfirm.cancel') }}
        </SkyDialogButton>
        <SkyDialogButton
          strong
          class="vault-logout-confirm"
          :disabled="logoutSubmitting"
          @click="signOut"
        >
          {{
            t(
              logoutSubmitting
                ? 'logoutConfirm.signingOut'
                : 'logoutConfirm.confirm',
            )
          }}
        </SkyDialogButton>
      </template>
    </SkyDialog>
  </SkyAppPage>
</template>

<style scoped>
.crypto-app {
  --card: #11151b;
  --muted: rgba(225, 234, 240, 0.58);
  color: #f8fbfd;
  background:
    radial-gradient(
      circle at 50% -10%,
      rgba(42, 91, 105, 0.25),
      transparent 33%
    ),
    #05070b;
}
.vault-logout-confirm {
  color: #fff;
  background: #c4475c;
}
.state,
.auth {
  display: grid;
  align-content: center;
  gap: 18px;
  min-height: 100%;
  text-align: center;
}
.auth-hero {
  display: grid;
  justify-items: center;
  gap: 6px;
}
.profile-head > span {
  display: grid;
  place-items: center;
  width: 68px;
  height: 68px;
  border-radius: 22px;
  color: #04110e;
  background: linear-gradient(145deg, #6ff5cd, #3d8fff);
  box-shadow: 0 18px 45px rgba(49, 214, 170, 0.18);
}
.auth-hero h2,
.auth-hero small {
  margin: 0;
}
.auth-hero h2 {
  font-size: 23px;
  line-height: 1.15;
}
.auth-hero small {
  max-width: 260px;
  color: var(--muted);
  font-size: 11px;
  line-height: 1.45;
}
.auth {
  align-content: center;
  justify-items: center;
  min-height: 0;
  flex: 1 1 auto;
  padding-top: 18px !important;
  padding-bottom: 22px !important;
}
.auth-shell {
  display: grid;
  gap: 18px;
  width: 100%;
  max-width: 338px;
}
.auth-panel {
  padding: 14px;
  text-align: left;
  background: #0b1118;
  border: 1px solid rgba(255, 255, 255, 0.075);
  border-radius: 22px;
  box-shadow:
    0 20px 46px rgba(0, 0, 0, 0.3),
    inset 0 1px rgba(255, 255, 255, 0.04);
}
.auth-mode {
  min-height: 48px;
  margin-bottom: 14px;
  padding: 3px;
  background: rgba(255, 255, 255, 0.045);
  border-radius: 14px;
}
.auth-mode :deep(.sky-segmented-button) {
  min-height: 42px;
  color: rgba(255, 255, 255, 0.52);
  font-size: 13px;
  font-weight: 800;
}
.auth-mode :deep(.sky-segmented-button--active) {
  color: #fff;
}
.auth-form {
  gap: 12px;
}
.auth-password-hint {
  margin: -3px 4px 0;
  color: rgba(255, 255, 255, 0.58);
  font-size: 11px;
  line-height: 15px;
}
.auth-account {
  display: grid;
  grid-template-columns: 40px minmax(0, 1fr) 18px;
  gap: 11px;
  align-items: center;
  min-height: 64px;
  margin-bottom: 12px;
  padding: 10px 13px;
  color: #f8fbfd;
  background: rgba(101, 251, 210, 0.055);
  border: 1px solid rgba(101, 251, 210, 0.15);
  border-radius: 17px;
}
.auth-account > span {
  display: grid;
  width: 40px;
  height: 40px;
  place-items: center;
  color: var(--vault-mint);
  background: rgba(101, 251, 210, 0.09);
  border-radius: 12px;
}
.auth-account > div {
  display: grid;
  gap: 3px;
  min-width: 0;
}
.auth-account small {
  color: rgba(255, 255, 255, 0.52);
  font-size: 11px;
  font-weight: 750;
}
.auth-account strong {
  overflow: hidden;
  font-size: 14px;
  line-height: 1.2;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.auth-account > svg {
  color: var(--vault-mint);
}
.auth-field {
  min-height: 68px;
  margin: 0;
  padding: 0 14px;
  color: #f8fbfd;
  background: #080d13;
  border-radius: 17px;
  box-shadow: inset 0 1px rgba(255, 255, 255, 0.035);
}
.auth-field:focus-within {
  background: #091119;
  box-shadow:
    0 0 0 3px rgba(101, 251, 210, 0.06),
    inset 0 1px rgba(255, 255, 255, 0.05);
}
.auth-field :deep(.sky-field__media) {
  display: grid;
  width: 40px;
  height: 40px;
  place-items: center;
  justify-content: center;
  margin-right: 11px;
  padding: 0;
  color: var(--vault-mint);
  background: rgba(101, 251, 210, 0.07);
  border: 1px solid rgba(101, 251, 210, 0.12);
  border-radius: 11px;
}
.auth-field :deep(.sky-field__inner) {
  padding: 11px 0 9px;
}
.auth-field :deep(.sky-field__label) {
  margin-top: 0;
  color: rgba(255, 255, 255, 0.56);
  font-size: 11px;
  font-weight: 750;
}
.auth-field :deep(.sky-field__label-text) {
  top: 0;
  margin: 0;
  padding: 0;
  background: transparent;
}
.auth-field :deep(.sky-field__control) {
  margin: -2px 0 0;
}
.auth-field :deep(.sky-field__input) {
  height: 33px;
  min-height: 33px;
  color: #fff;
  font-size: 16px;
  font-weight: 700;
  line-height: 21px;
}
.auth-field :deep(.sky-field__input::placeholder) {
  color: rgba(255, 255, 255, 0.28);
}
.auth-field :deep(.sky-field__border) {
  inset: 0;
  border-color: rgba(255, 255, 255, 0.12);
  border-radius: 17px;
}
.auth-field:focus-within :deep(.sky-field__border) {
  border-color: rgba(101, 251, 210, 0.56);
}
.auth-submit {
  min-height: 54px;
  margin-top: 3px;
  color: #06110e;
  font-size: 14px;
  font-weight: 900;
  border: 1px solid rgba(101, 251, 210, 0.48);
  border-radius: 12px;
  background: var(--vault-mint);
  box-shadow: none;
}
.form {
  display: grid;
  gap: 13px;
  text-align: left;
}
.hint,
.success {
  display: flex;
  gap: 7px;
  align-items: center;
  color: var(--muted);
  font-size: 13px;
}
.success,
.up {
  color: #31d6aa !important;
}
.error,
.down {
  color: #ff5c70 !important;
}
.visibility {
  display: grid;
  place-items: center;
  width: 44px;
  height: 44px;
  color: inherit;
  background: none;
  border: 0;
}
.portfolio {
  display: grid;
  justify-items: center;
  min-height: 225px;
  text-align: center;
}
.portfolio p {
  display: flex;
  gap: 5px;
  align-items: center;
  margin: 15px 0 0;
  color: var(--muted);
  font-size: 12px;
}
.portfolio > strong {
  margin: 7px 0 2px;
  font-size: 38px;
  letter-spacing: -0.05em;
}
.portfolio em,
.detail-head em {
  font-size: 13px;
  font-style: normal;
}
.portfolio svg {
  width: calc(100% + 32px);
  height: 100px;
  margin-top: 8px;
}
.portfolio polyline,
.big-chart polyline,
.market-grid polyline {
  fill: none;
  stroke: #dffff6;
  stroke-width: 3;
  stroke-linecap: round;
  stroke-linejoin: round;
  vector-effect: non-scaling-stroke;
  filter: drop-shadow(0 0 7px rgba(49, 214, 170, 0.45));
}
.quick {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 6px;
  margin-bottom: 20px;
}
.quick button {
  display: grid;
  justify-items: center;
  gap: 6px;
  padding: 0;
  color: #eef3f5;
  font-size: 11px;
  background: none;
  border: 0;
}
.quick button span {
  display: grid;
  place-items: center;
  width: 48px;
  height: 48px;
  border-radius: 17px;
  background: #242a33;
}
.cash {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 20px;
  padding: 15px;
  background: linear-gradient(135deg, #172026, #101419);
}
.cash > svg {
  color: #49e4b2;
}
.cash span {
  display: grid;
  flex: 1;
}
.cash small {
  color: var(--muted);
}
.heading,
.market-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin: 0 2px 10px;
}
.heading h2,
.market-head h2,
.title {
  margin: 0;
  font-size: 18px;
}
.heading button {
  display: grid;
  place-items: center;
  width: 40px;
  height: 40px;
  color: #fff;
  background: none;
  border: 0;
}
.title {
  margin: 23px 2px 11px;
}
.row {
  display: grid;
  grid-template-columns: 42px 1fr auto 18px;
  gap: 10px;
  align-items: center;
  width: 100%;
  margin-bottom: 8px;
  padding: 11px 12px;
  color: #fff;
  text-align: left;
  background: var(--card);
  border: 1px solid rgba(255, 255, 255, 0.05);
  border-radius: 18px;
}
.row.static {
  grid-template-columns: 42px 1fr auto;
}
.row span:last-of-type {
  text-align: right;
}
.row b,
.row small {
  display: block;
}
.row small {
  margin-top: 3px;
  color: var(--muted);
  font-size: 11px;
}
.coin,
.activity-icon {
  display: grid;
  place-items: center;
  width: 38px;
  height: 38px;
  border-radius: 13px;
  color: #fff;
  font-weight: 900;
}
.activity-icon {
  color: #49e4b2;
  background: rgba(49, 214, 170, 0.12);
}
.market-head small {
  color: #49e4b2;
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 0.1em;
  text-transform: uppercase;
}
.market-head em,
.heading em {
  color: #49e4b2;
  font-size: 11px;
  font-style: normal;
}
.market-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;
  margin-bottom: 18px;
}
.market-grid button {
  display: grid;
  min-height: 188px;
  padding: 15px;
  color: #fff;
  text-align: left;
  background: var(--card);
  border: 1px solid rgba(255, 255, 255, 0.05);
  border-radius: 21px;
}
.market-grid button > small {
  margin-top: 9px;
  color: var(--muted);
}
.market-grid button > b {
  font-size: 18px;
}
.market-grid em {
  font-size: 12px;
  font-style: normal;
}
.market-grid svg {
  align-self: end;
  width: 100%;
  height: 48px;
}
.market-grid polyline {
  stroke: #31d6aa;
  stroke-width: 2;
}
.movers {
  padding: 8px 12px;
  margin-bottom: 15px;
  background: var(--card);
}
.movers button {
  display: grid;
  grid-template-columns: 42px 1fr auto;
  gap: 10px;
  align-items: center;
  width: 100%;
  padding: 10px 2px;
  color: #fff;
  text-align: left;
  background: none;
  border: 0;
  border-top: 1px solid rgba(255, 255, 255, 0.06);
}
.movers button span:last-child {
  text-align: right;
}
.movers b,
.movers small {
  display: block;
}
.movers small {
  color: var(--muted);
  font-size: 11px;
}
.detail-head {
  display: grid;
  justify-items: center;
  padding: 12px 0 15px;
  text-align: center;
}
.coin.large {
  width: 58px;
  height: 58px;
  border-radius: 20px;
  font-size: 20px;
}
.detail-head p {
  margin: 9px 0 0;
  color: var(--muted);
  font-size: 13px;
}
.detail-head > strong {
  font-size: 34px;
}
.big-chart {
  padding: 7px 0;
  background: #080b0e;
  overflow: hidden;
}
.big-chart svg {
  width: 100%;
  height: 180px;
}
.detail-chart__grid line {
  stroke: rgba(255, 255, 255, 0.06);
  stroke-width: 1;
  vector-effect: non-scaling-stroke;
}
.detail-chart__axis text {
  fill: rgba(214, 224, 230, 0.58);
  font-size: 10px;
  font-weight: 650;
}
.detail-chart__marker line {
  stroke: rgba(101, 251, 210, 0.3);
  stroke-width: 1;
  stroke-dasharray: 3 4;
  vector-effect: non-scaling-stroke;
}
.detail-chart__marker circle {
  fill: #07110f;
  stroke: var(--vault-mint);
  stroke-width: 3;
  vector-effect: non-scaling-stroke;
  filter: drop-shadow(0 0 5px rgba(101, 251, 210, 0.8));
}
.detail-chart__marker text {
  fill: #fff;
  font-size: 10px;
  font-weight: 800;
  paint-order: stroke;
  stroke: rgba(7, 11, 16, 0.94);
  stroke-width: 4px;
  stroke-linejoin: round;
}
.detail-chart {
  animation: detail-chart-in 240ms ease-out;
}
@keyframes detail-chart-in {
  from {
    opacity: 0.35;
    transform: translateY(3px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}
.periods {
  display: grid;
  grid-template-columns: repeat(5, 1fr);
  padding: 3px 9px;
}
.periods button {
  min-height: 44px;
  color: var(--muted);
  background: none;
  border: 0;
  border-radius: 11px;
  transition:
    color 160ms ease,
    background 160ms ease,
    box-shadow 160ms ease,
    transform 160ms ease;
}
.periods button.active {
  color: #fff;
  background: #252a31;
}
@media (prefers-reduced-motion: reduce) {
  .detail-chart {
    animation: none;
  }
}
.detail-copy {
  color: var(--muted);
  font-size: 12px;
  line-height: 1.5;
}
.investment,
.stats {
  padding: 16px;
  background: var(--card);
}
.investment > small {
  color: var(--muted);
}
.investment > strong {
  display: block;
  margin: 3px 0 14px;
  font-size: 28px;
}
.investment > div {
  display: grid;
  grid-template-columns: 42px 1fr auto;
  gap: 10px;
  align-items: center;
}
.investment > div span:last-child {
  text-align: right;
}
.investment b,
.investment small {
  display: block;
}
.investment small {
  color: var(--muted);
  font-size: 11px;
}
.stats div {
  display: flex;
  justify-content: space-between;
  padding: 12px 0;
  border-bottom: 1px solid rgba(255, 255, 255, 0.06);
  font-size: 12px;
}
.stats div:last-child {
  border: 0;
}
.stats span {
  color: var(--muted);
}
.detail-trade-dock {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 8px;
}
.activity-head,
.profile-head {
  display: grid;
  justify-items: center;
  padding: 22px 0;
  text-align: center;
}
.activity-head p,
.activity-head span {
  margin: 0;
  color: var(--muted);
  font-size: 12px;
}
.activity-head strong {
  font-size: 32px;
}
.profile-head > span {
  width: 78px;
  height: 78px;
  font-size: 24px;
  font-weight: 900;
}
.profile-head h2 {
  margin: 10px 0 2px;
}
.profile-head p {
  display: flex;
  gap: 5px;
  align-items: center;
  margin: 0;
  color: #49e4b2;
  font-size: 12px;
}
.profile-stats {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 7px;
}
.profile-stats div {
  display: grid;
  gap: 4px;
  padding: 13px 5px;
  text-align: center;
  background: var(--card);
  border-radius: 16px;
}
.profile-stats small {
  color: var(--muted);
  font-size: 11px;
}
.settings {
  padding: 0 14px;
  background: var(--card);
}
.settings label {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  min-height: 67px;
  border-bottom: 1px solid rgba(255, 255, 255, 0.06);
}
.settings label > span {
  display: flex;
  gap: 10px;
  align-items: center;
}
.settings b,
.settings small {
  display: block;
}
.settings small {
  max-width: 180px;
  color: var(--muted);
  font-size: 11px;
}
.sheet {
  display: grid;
  gap: 13px;
  padding: 2px 12px calc(var(--sky-safe-area-bottom) + 20px);
}
.sheet h2,
.sheet p {
  margin: 0;
}
.quote {
  display: grid;
  gap: 8px;
  padding: 14px;
}
.quote div {
  display: flex;
  justify-content: space-between;
  color: var(--muted);
  font-size: 13px;
}
.quote small {
  color: var(--muted);
  font-size: 11px;
}

/* VaultX owns a dense trading surface while shared phone geometry stays in Sky UI. */
.crypto-app {
  --card: #10151d;
  --card-strong: #151c26;
  --muted: rgba(220, 231, 238, 0.57);
  --vault-mint: #65fbd2;
  --vault-blue: #68a7ff;
  background:
    radial-gradient(
      circle at 88% 9%,
      rgba(71, 133, 175, 0.16),
      transparent 28%
    ),
    radial-gradient(
      circle at 0% 34%,
      rgba(51, 219, 176, 0.09),
      transparent 28%
    ),
    linear-gradient(180deg, #070b11 0%, #030509 74%);
}
.crypto-app::before {
  position: absolute;
  inset: 0;
  pointer-events: none;
  content: '';
  background-image: linear-gradient(
    rgba(255, 255, 255, 0.018) 1px,
    transparent 1px
  );
  background-size: 100% 48px;
  mask-image: linear-gradient(to bottom, #000, transparent 58%);
}
.crypto-app :deep(.sky-navbar) {
  --sky-navbar-glass: #070b11;
  z-index: 12;
  color: #f8fbfd;
  background: #070b11;
  border-bottom: 1px solid rgba(255, 255, 255, 0.07);
}
.crypto-app :deep(.sky-navbar__right) {
  background: transparent;
  box-shadow: none;
  -webkit-backdrop-filter: none;
  backdrop-filter: none;
}
.crypto-app :deep(.vault-navbar--profile) {
  --sky-navbar-glass: transparent;
  background: transparent;
  border-bottom-color: transparent;
}
.crypto-app :deep(.vault-navbar--profile .sky-navbar__blur) {
  -webkit-backdrop-filter: none;
  backdrop-filter: none;
  -webkit-mask-image: none;
  mask-image: none;
}
.crypto-app :deep(.vault-navbar--profile .sky-navbar__background) {
  background: transparent;
}
.vault-header-brand {
  display: inline-flex;
  gap: 8px;
  align-items: center;
}
.vault-header-logo {
  width: 30px;
  height: 30px;
  flex: 0 0 auto;
  object-fit: contain;
  filter: drop-shadow(0 4px 6px rgba(49, 214, 170, 0.22))
    drop-shadow(0 1px 2px rgba(246, 196, 83, 0.24));
}
.vault-section-title {
  font-size: 17px;
  letter-spacing: -0.02em;
}
.profile-signout {
  height: 34px;
  min-height: 34px;
  gap: 6px;
  padding: 0 10px;
  color: #ff9aa8;
  font-size: 10px;
  font-weight: 850;
  white-space: nowrap;
  background: linear-gradient(
    145deg,
    rgba(255, 117, 136, 0.15),
    rgba(255, 82, 106, 0.08)
  );
  border: 1px solid rgba(255, 117, 136, 0.25);
  border-radius: var(--sky-radius-pill);
  box-shadow:
    inset 0 1px rgba(255, 255, 255, 0.045),
    0 7px 18px rgba(255, 82, 106, 0.09);
  transition:
    color 160ms ease,
    background 160ms ease,
    border-color 160ms ease,
    transform 160ms ease;
}
.profile-signout svg {
  flex: 0 0 auto;
  color: #ff7588;
}
.profile-signout:hover {
  color: #fff;
  background: linear-gradient(
    145deg,
    rgba(255, 117, 136, 0.24),
    rgba(255, 82, 106, 0.14)
  );
  border-color: rgba(255, 135, 151, 0.4);
}
.profile-signout:active:not(:disabled) {
  opacity: 1;
  transform: translateY(1px) scale(0.98);
}
.vault-detail-title {
  display: inline-flex;
  gap: 8px;
  align-items: center;
}
.vault-detail-logo {
  width: 30px;
  height: 30px;
  border-radius: 11px;
}
.vault-detail-title > span:last-child {
  display: grid;
  justify-items: start;
  line-height: 1.05;
}
.vault-detail-title b {
  font-size: 14px;
}
.vault-detail-title small {
  margin-top: 2px;
  color: var(--muted);
  font-size: 11px;
  font-weight: 600;
}
.crypto-app :deep(.sky-scroll-area__content) {
  position: relative;
}
.crypto-app :deep(.sky-pill-navigation) {
  --sky-glass-solid: rgba(14, 19, 27, 0.97);
}
.crypto-app :deep(.sky-pill-navigation .sky-segmented-button--active) {
  color: #fff;
}
.auth-hero__mark {
  display: grid;
  width: 66px;
  height: 66px;
  place-items: center;
}
.auth-hero__mark img {
  display: block;
  width: 66px;
  height: 66px;
  object-fit: contain;
  filter: drop-shadow(0 12px 22px rgba(49, 214, 170, 0.18));
}
.portfolio-shell {
  position: relative;
  min-height: 294px;
  margin-bottom: 12px;
  padding: 18px 17px 15px;
  overflow: hidden;
  background:
    radial-gradient(
      circle at 80% 12%,
      rgba(91, 159, 255, 0.2),
      transparent 27%
    ),
    radial-gradient(
      circle at 24% 82%,
      rgba(101, 251, 210, 0.16),
      transparent 35%
    ),
    linear-gradient(145deg, #151d28, #0a0f16 66%);
  border: 1px solid rgba(255, 255, 255, 0.1);
  border-radius: 30px;
  box-shadow:
    0 22px 50px rgba(0, 0, 0, 0.36),
    inset 0 1px rgba(255, 255, 255, 0.08);
}
.portfolio-shell::after {
  position: absolute;
  inset: 0;
  pointer-events: none;
  content: '';
  background: linear-gradient(
    112deg,
    transparent 38%,
    rgba(255, 255, 255, 0.045) 49%,
    transparent 60%
  );
}
.portfolio-glow {
  position: absolute;
  top: -38px;
  right: -24px;
  width: 150px;
  height: 120px;
  pointer-events: none;
  background: radial-gradient(
    circle,
    rgba(91, 159, 255, 0.28) 0,
    rgba(101, 251, 210, 0.13) 38%,
    transparent 72%
  );
  border: 0;
  border-radius: 50%;
  filter: blur(24px);
}
.portfolio-topline,
.portfolio-value,
.portfolio-metrics,
.allocation-copy,
.market-tile__top,
.featured-market__top,
.featured-market__quote,
.featured-market__stats {
  display: flex;
  align-items: center;
}
.portfolio-topline {
  position: relative;
  z-index: 1;
  justify-content: space-between;
  color: var(--muted);
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.04em;
}
.portfolio-topline > span:first-child {
  display: flex;
  gap: 6px;
  align-items: center;
}
.portfolio-topline svg {
  color: var(--vault-mint);
}
.forecast-pill {
  display: inline-flex;
  align-items: center;
  padding: 5px 8px;
  color: #b9c8ff;
  background: rgba(112, 143, 255, 0.09);
  border: 1px solid rgba(140, 169, 255, 0.18);
  border-radius: var(--sky-radius-pill);
}
.live-pill,
.profile-status {
  display: inline-flex;
  gap: 6px;
  align-items: center;
  padding: 6px 9px;
  color: rgba(255, 255, 255, 0.76);
  background: rgba(255, 255, 255, 0.06);
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: var(--sky-radius-pill);
}
.live-pill i,
.profile-status i {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: var(--vault-mint);
  box-shadow: 0 0 9px var(--vault-mint);
}
.portfolio-value {
  position: relative;
  z-index: 1;
  justify-content: space-between;
  margin-top: 15px;
}
.portfolio-value strong {
  font-size: 35px;
  letter-spacing: -0.055em;
}
.portfolio-value > span {
  display: grid;
  justify-items: end;
  font-size: 12px;
  font-weight: 800;
}
.portfolio-value small {
  margin-top: 2px;
  color: var(--muted);
  font-size: 11px;
  font-weight: 600;
}
.portfolio-chart {
  position: relative;
  height: 148px;
  margin: 8px -8px 0;
}
.portfolio-chart svg {
  display: block;
  width: 100%;
  height: 126px;
  overflow: visible;
}
.portfolio-chart__legend {
  display: flex;
  justify-content: flex-end;
  gap: 12px;
  height: 22px;
  padding-right: 7px;
  color: var(--muted);
  font-size: 9px;
  font-weight: 700;
}
.portfolio-chart__legend span {
  display: flex;
  align-items: center;
  gap: 4px;
}
.portfolio-chart__legend i {
  width: 13px;
  height: 2px;
  border-radius: 4px;
  background: var(--vault-mint);
}
.portfolio-chart__legend i.is-forecast {
  background: repeating-linear-gradient(
    90deg,
    #8ca9ff 0 4px,
    transparent 4px 7px
  );
}
.portfolio-chart__forecast-zone {
  fill: rgba(112, 143, 255, 0.055);
}
.portfolio-chart__grid,
.portfolio-chart__zero,
.portfolio-chart__boundary {
  vector-effect: non-scaling-stroke;
}
.portfolio-chart__grid {
  stroke: rgba(255, 255, 255, 0.055);
  stroke-width: 1;
}
.portfolio-chart__zero {
  stroke: rgba(255, 255, 255, 0.2);
  stroke-width: 1;
  stroke-dasharray: 2 5;
}
.portfolio-chart__boundary {
  stroke: rgba(140, 169, 255, 0.22);
  stroke-width: 1;
  stroke-dasharray: 3 5;
}
.portfolio-history,
.portfolio-forecast,
.featured-market polyline {
  fill: none;
  stroke: #dffff6;
  stroke-width: 2.5;
  stroke-linecap: round;
  stroke-linejoin: round;
  vector-effect: non-scaling-stroke;
  filter: drop-shadow(0 0 8px rgba(101, 251, 210, 0.5));
}
.portfolio-forecast {
  stroke: #8ca9ff;
  stroke-dasharray: 7 7;
  filter: drop-shadow(0 0 7px rgba(112, 143, 255, 0.4));
}
.portfolio-current-dot {
  fill: var(--vault-mint);
  stroke: #fff;
  stroke-width: 2;
  vector-effect: non-scaling-stroke;
  filter: drop-shadow(0 0 6px var(--vault-mint));
}
.portfolio-current-label rect {
  fill: #101923;
  stroke: rgba(101, 251, 210, 0.45);
  stroke-width: 1;
  vector-effect: non-scaling-stroke;
}
.portfolio-current-label text {
  fill: #fff;
  font-size: 9px;
  font-weight: 800;
  letter-spacing: 0.01em;
}
.portfolio-scale-label {
  fill: rgba(255, 255, 255, 0.46);
  font-size: 9px;
  font-weight: 700;
}
.portfolio-metrics {
  position: relative;
  z-index: 1;
  justify-content: space-around;
  padding-top: 12px;
  border-top: 1px solid rgba(255, 255, 255, 0.07);
}
.portfolio-metrics div {
  display: grid;
  gap: 2px;
  min-width: 40%;
}
.portfolio-metrics div:last-child {
  text-align: right;
}
.portfolio-metrics small {
  color: var(--muted);
  font-size: 11px;
}
.portfolio-metrics b {
  font-size: 13px;
}
.portfolio-metrics > i {
  width: 1px;
  height: 27px;
  background: rgba(255, 255, 255, 0.08);
}
.quick {
  gap: 8px;
  margin: 0 0 14px;
}
.quick button {
  align-content: center;
  min-width: 0;
  min-height: 84px;
  gap: 8px;
  padding: 11px 5px;
  background: linear-gradient(
    160deg,
    rgba(30, 39, 51, 0.94),
    rgba(12, 17, 24, 0.94)
  );
  border: 1px solid rgba(255, 255, 255, 0.075);
  border-radius: 19px;
  box-shadow: inset 0 1px rgba(255, 255, 255, 0.045);
  transition:
    transform 180ms ease,
    background 180ms ease,
    border-color 180ms ease,
    box-shadow 180ms ease;
}
.quick button span {
  width: 38px;
  height: 38px;
  border: 1px solid rgba(101, 251, 210, 0.14);
  border-radius: 14px;
  color: var(--vault-mint);
  background: rgba(101, 251, 210, 0.08);
  transition:
    transform 180ms ease,
    background 180ms ease,
    border-color 180ms ease,
    box-shadow 180ms ease;
}
.quick button b {
  max-width: 100%;
  overflow: hidden;
  font-size: 12px;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.quick button:focus-visible {
  border-color: rgba(101, 251, 210, 0.5);
  outline: 2px solid rgba(101, 251, 210, 0.78);
  outline-offset: 2px;
}
.quick button:active {
  transform: translateY(-1px) scale(0.98);
}
@media (hover: hover) and (pointer: fine) {
  .quick button:hover {
    background: linear-gradient(
      160deg,
      rgba(37, 52, 64, 0.98),
      rgba(15, 23, 31, 0.98)
    );
    border-color: rgba(101, 251, 210, 0.28);
    box-shadow:
      0 14px 26px rgba(0, 0, 0, 0.3),
      0 0 20px rgba(101, 251, 210, 0.06),
      inset 0 1px rgba(255, 255, 255, 0.08);
    transform: translateY(-3px);
  }
  .quick button:hover span {
    background: rgba(101, 251, 210, 0.15);
    border-color: rgba(101, 251, 210, 0.36);
    box-shadow: 0 8px 18px rgba(101, 251, 210, 0.14);
    transform: scale(1.05);
  }
}
.allocation-card {
  margin-bottom: 21px;
  padding: 14px;
  background: linear-gradient(
    125deg,
    rgba(21, 29, 39, 0.98),
    rgba(12, 17, 23, 0.98)
  );
  border: 1px solid rgba(255, 255, 255, 0.07);
}
.allocation-copy {
  gap: 10px;
}
.allocation-copy > span {
  display: grid;
  place-items: center;
  width: 38px;
  height: 38px;
  color: var(--vault-mint);
  background: rgba(101, 251, 210, 0.1);
  border-radius: 13px;
}
.allocation-copy > div {
  display: grid;
  flex: 1;
  gap: 2px;
}
.allocation-copy small {
  color: var(--muted);
  font-size: 11px;
}
.allocation-copy b {
  font-size: 13px;
}
.allocation-copy > strong {
  color: var(--vault-mint);
  font-size: 14px;
}
.allocation-track,
.asset-allocation {
  display: block;
  height: 4px;
  margin-top: 11px;
  overflow: hidden;
  background: rgba(255, 255, 255, 0.07);
  border-radius: var(--sky-radius-pill);
}
.allocation-track i,
.asset-allocation i {
  display: block;
  height: 100%;
  background: linear-gradient(90deg, var(--vault-mint), var(--vault-blue));
  border-radius: inherit;
}
.asset-row {
  min-height: 72px;
  margin-bottom: 9px;
  padding: 12px;
  background: linear-gradient(
    145deg,
    rgba(19, 26, 35, 0.97),
    rgba(10, 14, 20, 0.97)
  );
  border-color: rgba(255, 255, 255, 0.07);
  border-radius: 20px;
  box-shadow: inset 0 1px rgba(255, 255, 255, 0.035);
}
.asset-allocation {
  width: 72px;
  height: 3px;
  margin-top: 7px;
}
.featured-market {
  position: relative;
  width: 100%;
  margin-bottom: 20px;
  padding: 16px;
  overflow: hidden;
  color: #fff;
  text-align: left;
  background:
    radial-gradient(
      circle at 88% 12%,
      rgba(101, 251, 210, 0.16),
      transparent 28%
    ),
    linear-gradient(145deg, #18212d, #0a0f16 68%);
  border: 1px solid rgba(255, 255, 255, 0.1);
  border-radius: 26px;
  box-shadow:
    0 20px 45px rgba(0, 0, 0, 0.28),
    inset 0 1px rgba(255, 255, 255, 0.07);
}
.featured-market__top {
  gap: 11px;
}
.featured-market__top > span:nth-child(2) {
  display: grid;
  flex: 1;
}
.featured-market__top small {
  color: var(--vault-mint);
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}
.featured-market__top b {
  margin-top: 2px;
  font-size: 16px;
}
.featured-market__top em {
  color: var(--muted);
  font-size: 11px;
  font-style: normal;
}
.featured-market__quote {
  justify-content: space-between;
  margin-top: 17px;
}
.featured-market__quote strong {
  font-size: 28px;
  letter-spacing: -0.04em;
}
.featured-market__quote span {
  font-size: 13px;
  font-weight: 800;
}
.featured-market > svg {
  width: calc(100% + 32px);
  height: 74px;
  margin: 2px -16px 6px;
}
.featured-market__stats {
  gap: 8px;
}
.featured-market__stats > span {
  display: grid;
  flex: 1;
  gap: 2px;
  padding: 9px 10px;
  background: rgba(255, 255, 255, 0.045);
  border: 1px solid rgba(255, 255, 255, 0.05);
  border-radius: 12px;
}
.featured-market__stats small {
  color: var(--muted);
  font-size: 11px;
}
.featured-market__stats b {
  font-size: 12px;
}
.market-list-heading {
  margin-top: 2px;
}
.market-grid--advanced {
  grid-template-columns: 1fr;
  gap: 9px;
}
.market-grid--advanced button {
  display: block;
  min-height: 154px;
  padding: 14px;
  background: linear-gradient(
    145deg,
    rgba(19, 26, 35, 0.96),
    rgba(10, 14, 20, 0.96)
  );
  border-radius: 20px;
}
.market-tile__top {
  gap: 10px;
}
.market-tile__top > span:nth-child(2) {
  display: grid;
  flex: 1;
}
.market-tile__top b {
  font-size: 13px;
}
.market-tile__top small {
  margin: 1px 0 0 !important;
  font-size: 11px !important;
}
.market-tile__top em {
  padding: 5px 7px;
  font-size: 11px;
  background: rgba(101, 251, 210, 0.08);
  border-radius: var(--sky-radius-pill);
}
.market-tile__price {
  display: flex;
  align-items: baseline;
  gap: 6px;
  margin-top: 11px;
}
.market-tile__price b {
  font-size: 20px;
}
.market-tile__price small {
  margin: 0 !important;
}
.market-grid--advanced svg {
  height: 43px;
  margin-top: 4px;
}
.activity-overview {
  margin-bottom: 18px;
  padding: 1px;
  overflow: hidden;
  background: linear-gradient(
    135deg,
    rgba(101, 251, 210, 0.3),
    rgba(104, 167, 255, 0.17) 48%,
    rgba(255, 255, 255, 0.06)
  );
  border-radius: 29px;
  box-shadow: 0 20px 46px rgba(0, 0, 0, 0.32);
}
.activity-dashboard {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: space-between;
  min-height: 122px;
  margin: 0;
  padding: 21px 18px 17px;
  overflow: hidden;
  text-align: left;
  background:
    radial-gradient(
      circle at 91% 18%,
      rgba(101, 251, 210, 0.21),
      transparent 33%
    ),
    radial-gradient(
      circle at 12% 105%,
      rgba(104, 167, 255, 0.16),
      transparent 42%
    ),
    linear-gradient(145deg, #18232f, #0b1119 68%);
  border: 0;
  border-radius: 28px 28px 18px 18px;
  box-shadow: inset 0 1px rgba(255, 255, 255, 0.08);
}
.activity-dashboard::after {
  position: absolute;
  inset: 0;
  pointer-events: none;
  content: '';
  background: linear-gradient(
    118deg,
    transparent 32%,
    rgba(255, 255, 255, 0.04) 48%,
    transparent 64%
  );
}
.activity-dashboard__copy {
  position: relative;
  z-index: 1;
  display: grid;
  gap: 5px;
}
.activity-dashboard__copy p {
  display: flex;
  gap: 6px;
  align-items: center;
  color: rgba(255, 255, 255, 0.62);
  font-weight: 700;
  letter-spacing: 0.02em;
}
.activity-dashboard__copy p svg {
  color: var(--vault-mint);
}
.activity-dashboard__copy strong {
  font-size: 29px;
  letter-spacing: -0.045em;
}
.activity-trade-count {
  display: inline-flex;
  gap: 6px;
  align-items: center;
  justify-self: start;
  padding: 5px 8px;
  color: rgba(255, 255, 255, 0.68) !important;
  background: rgba(255, 255, 255, 0.055);
  border: 1px solid rgba(255, 255, 255, 0.065);
  border-radius: var(--sky-radius-pill);
}
.activity-trade-count i {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: var(--vault-mint);
  box-shadow: 0 0 8px rgba(101, 251, 210, 0.68);
}
.activity-status {
  position: relative;
  z-index: 1;
  display: grid;
  place-items: center;
  gap: 5px;
  width: 72px;
  min-height: 66px;
  flex: 0 0 auto;
  padding: 7px;
  background: linear-gradient(
    145deg,
    rgba(101, 251, 210, 0.13),
    rgba(8, 17, 24, 0.7)
  );
  border: 1px solid rgba(101, 251, 210, 0.18);
  border-radius: 17px;
  box-shadow:
    inset 0 1px rgba(255, 255, 255, 0.07),
    0 10px 24px rgba(0, 0, 0, 0.18);
}
.activity-status__icon {
  display: grid;
  place-items: center;
  width: 32px;
  height: 32px;
  color: #07130f;
  background: linear-gradient(145deg, #91ffe1, #40d6b0);
  border-radius: 10px;
  box-shadow: 0 7px 16px rgba(101, 251, 210, 0.18);
}
.activity-status b {
  color: var(--vault-mint);
  font-size: 9px;
  line-height: 1.1;
  text-align: center;
  white-space: nowrap;
}
.activity-filter-panel {
  padding: 8px;
  background: linear-gradient(180deg, #0b1118, #080d13);
  border-top: 1px solid rgba(255, 255, 255, 0.055);
  border-radius: 0 0 28px 28px;
}
.activity-filters {
  width: 100%;
  height: 50px;
  min-height: 50px;
  gap: 4px;
  padding: 3px;
  background: rgba(255, 255, 255, 0.045);
  border: 1px solid rgba(255, 255, 255, 0.055);
  border-radius: 17px;
  box-shadow: inset 0 1px rgba(255, 255, 255, 0.035);
}
:deep(.activity-filters.sky-segmented--strong .sky-segmented__highlight) {
  top: 3px;
  bottom: 3px;
  inset-inline-start: 3px;
  background: linear-gradient(
    135deg,
    rgba(101, 251, 210, 0.2),
    rgba(104, 167, 255, 0.14)
  );
  border: 1px solid rgba(101, 251, 210, 0.35);
  border-radius: 13px;
  box-shadow:
    inset 0 1px rgba(255, 255, 255, 0.08),
    0 7px 18px rgba(0, 0, 0, 0.22);
}
.activity-filters :deep(.sky-segmented-button) {
  min-height: 42px;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0 7px;
  color: rgba(255, 255, 255, 0.5);
  font-size: 11px;
  font-weight: 700;
  line-height: 1;
  border-radius: 13px;
  transition:
    color var(--sky-transition-normal) ease,
    transform var(--sky-transition-fast) ease;
}
.activity-filters :deep(.activity-filter-content) {
  display: inline-flex;
  max-width: 100%;
  gap: 6px;
  align-items: center;
  justify-content: center;
  min-height: 15px;
  line-height: 1;
  white-space: nowrap;
  transform: translateY(-3px);
}
.activity-filters :deep(.activity-filter-content svg) {
  display: block;
  flex: 0 0 auto;
}
:deep(.activity-filters.sky-segmented--strong .sky-segmented-button--active) {
  color: #fff;
}
.activity-filters :deep(.sky-segmented-button:active:not(:disabled)) {
  transform: scale(0.98);
}
.activity-title {
  margin-top: 0;
}
.activity-row {
  position: relative;
  min-height: 70px;
  margin-left: 10px;
  width: calc(100% - 10px);
  overflow: visible;
  background: linear-gradient(
    145deg,
    rgba(19, 26, 35, 0.95),
    rgba(9, 13, 18, 0.95)
  );
}
.activity-row::before {
  position: absolute;
  top: -13px;
  bottom: -13px;
  left: -11px;
  width: 1px;
  content: '';
  background: rgba(255, 255, 255, 0.09);
}
.timeline-dot {
  position: absolute;
  top: 31px;
  left: -14px;
  width: 7px;
  height: 7px;
  border: 2px solid #070b11;
  border-radius: 50%;
  background: var(--vault-mint);
  box-shadow: 0 0 7px var(--vault-mint);
}
.activity-icon--withdrawal {
  color: #ff7588;
  background: rgba(255, 92, 112, 0.1);
}
.activity-icon--deposit {
  color: var(--vault-blue);
  background: rgba(104, 167, 255, 0.1);
}
.profile-card {
  position: relative;
  min-height: 244px;
  padding: 18px;
  overflow: hidden;
  background:
    radial-gradient(
      circle at 82% 14%,
      rgba(104, 167, 255, 0.28),
      transparent 30%
    ),
    radial-gradient(
      circle at 16% 90%,
      rgba(101, 251, 210, 0.2),
      transparent 30%
    ),
    linear-gradient(145deg, #1a2532, #0b1119 70%);
  border: 1px solid rgba(255, 255, 255, 0.12);
  border-radius: 29px;
  box-shadow:
    0 22px 55px rgba(0, 0, 0, 0.35),
    inset 0 1px rgba(255, 255, 255, 0.08);
}
.profile-card__mesh {
  position: absolute;
  right: -35px;
  bottom: -50px;
  width: 190px;
  height: 190px;
  border: 1px solid rgba(255, 255, 255, 0.05);
  border-radius: 50%;
  box-shadow:
    inset 0 0 0 24px rgba(255, 255, 255, 0.015),
    inset 0 0 0 48px rgba(255, 255, 255, 0.012);
}
.profile-card__top {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.profile-avatar {
  display: grid;
  place-items: center;
  width: 56px;
  height: 56px;
  color: #07100e;
  font-size: 17px;
  font-weight: 900;
  background: linear-gradient(145deg, #b8ffea, #4b94ff);
  border: 1px solid rgba(255, 255, 255, 0.55);
  border-radius: 19px;
  box-shadow: 0 12px 30px rgba(101, 251, 210, 0.18);
}
.profile-status {
  max-width: 150px;
  color: var(--vault-mint);
  font-size: 11px;
}
.profile-card__identity {
  position: relative;
  display: flex;
  gap: 12px;
  align-items: end;
  justify-content: space-between;
  margin-top: 15px;
}
.profile-card__identity > span {
  min-width: 0;
  flex: 1;
}
.profile-card h2 {
  margin: 0 0 3px;
  font-size: 24px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.profile-card__identity p {
  display: flex;
  gap: 6px;
  align-items: center;
  margin: 0;
  color: var(--muted);
  font-size: 11px;
}
.profile-card__identity p svg {
  color: var(--vault-mint);
}
.profile-edit-button {
  width: auto;
  min-width: auto;
  min-height: 36px;
  flex: 0 0 auto;
  padding: 0 12px;
  color: #fff;
  background: rgba(101, 251, 210, 0.1);
  border: 1px solid rgba(101, 251, 210, 0.2);
  box-shadow: inset 0 1px rgba(255, 255, 255, 0.06);
}
.profile-card__id {
  position: relative;
  display: grid;
  grid-template-columns: 1fr auto;
  margin-top: 20px;
  padding-top: 12px;
  border-top: 1px solid rgba(255, 255, 255, 0.08);
}
.profile-card__id small {
  color: var(--muted);
  font-size: 11px;
  letter-spacing: 0.14em;
}
.profile-card__id b {
  grid-column: 1;
  margin-top: 2px;
  font-size: 13px;
  letter-spacing: 0.16em;
}
.profile-card__id svg {
  grid-column: 2;
  grid-row: 1 / span 2;
  color: rgba(255, 255, 255, 0.45);
}
.wallet-key-card {
  display: grid;
  gap: 12px;
  margin-top: 11px;
  padding: 13px;
  background:
    radial-gradient(
      circle at 92% 0%,
      rgba(101, 251, 210, 0.14),
      transparent 36%
    ),
    linear-gradient(145deg, #151e28, #0a1017);
  border: 1px solid rgba(101, 251, 210, 0.13);
  border-radius: 19px;
}
.wallet-key-card__content {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr);
  gap: 11px;
  align-items: center;
}
.wallet-key-card__icon {
  display: grid;
  place-items: center;
  width: 42px;
  height: 42px;
  color: var(--vault-mint);
  background: rgba(101, 251, 210, 0.09);
  border: 1px solid rgba(101, 251, 210, 0.13);
  border-radius: 14px;
}
.wallet-key-card__content > span:nth-child(2) {
  display: grid;
  min-width: 0;
  gap: 2px;
}
.wallet-key-card small,
.wallet-key-card em {
  color: var(--muted);
  font-size: 9px;
  font-style: normal;
}
.wallet-key-card b {
  overflow: hidden;
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
  font-size: 11px;
  letter-spacing: 0.035em;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.wallet-key-card__actions {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 7px;
}
.wallet-key-card__actions :deep(.sky-button) {
  width: 100%;
  min-width: 0;
  min-height: 42px;
  gap: 6px;
  padding: 0 10px;
  overflow: hidden;
  font-size: 11px;
  font-weight: 800;
  border-radius: 13px;
}
.wallet-key-card__actions :deep(.sky-button > span) {
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.profile-stats--premium {
  margin-top: 10px;
}
.profile-stats--premium div {
  min-height: 66px;
  align-content: center;
  background: linear-gradient(145deg, #151c25, #0b1016);
  border: 1px solid rgba(255, 255, 255, 0.06);
}
.profile-feedback {
  margin: 10px 3px 0;
}
.security-overview {
  display: flex;
  gap: 13px;
  align-items: center;
  margin-top: 11px;
  padding: 13px;
  background: linear-gradient(
    135deg,
    rgba(101, 251, 210, 0.09),
    rgba(104, 167, 255, 0.06)
  );
  border: 1px solid rgba(101, 251, 210, 0.14);
}
.security-score {
  position: relative;
  display: grid;
  place-items: center;
  width: 62px;
  height: 62px;
  flex: 0 0 auto;
  color: var(--vault-mint);
  border: 4px solid rgba(101, 251, 210, 0.2);
  border-top-color: var(--vault-mint);
  border-radius: 50%;
}
.security-score svg {
  position: absolute;
  opacity: 0.16;
}
.security-score b {
  font-size: 14px;
  line-height: 1;
}
.security-score small {
  font-size: 9px;
}
.security-overview > span {
  display: grid;
  gap: 2px;
}
.security-overview > span small {
  color: var(--vault-mint);
  font-size: 11px;
}
.security-overview > span b {
  font-size: 13px;
}
.security-overview > span em {
  color: var(--muted);
  font-size: 11px;
  font-style: normal;
  line-height: 1.35;
}
.settings,
.stats,
.investment,
.movers {
  background: linear-gradient(
    145deg,
    rgba(20, 27, 36, 0.97),
    rgba(9, 13, 18, 0.97)
  );
  border: 1px solid rgba(255, 255, 255, 0.065);
  box-shadow: inset 0 1px rgba(255, 255, 255, 0.035);
}
.settings label > span > svg {
  color: var(--vault-mint);
}
.detail-head {
  position: relative;
  margin-bottom: 10px;
  padding: 18px 0 10px;
}
.detail-head::before {
  position: absolute;
  top: -65px;
  width: 230px;
  height: 230px;
  border-radius: 50%;
  content: '';
  background: radial-gradient(
    circle,
    rgba(101, 251, 210, 0.13),
    transparent 65%
  );
}
.detail-head > * {
  position: relative;
}
.big-chart {
  background:
    linear-gradient(rgba(255, 255, 255, 0.025) 1px, transparent 1px),
    linear-gradient(90deg, rgba(255, 255, 255, 0.025) 1px, transparent 1px),
    linear-gradient(145deg, #101720, #070b10);
  background-size:
    100% 40px,
    53px 100%,
    auto;
  border: 1px solid rgba(255, 255, 255, 0.07);
  border-radius: 24px;
  box-shadow: 0 18px 40px rgba(0, 0, 0, 0.25);
}
.periods {
  margin: 0 7px 7px;
  padding: 4px;
  background: rgba(255, 255, 255, 0.035);
  border-radius: 14px;
}
.periods button.active {
  color: #07100e;
  background: var(--vault-mint);
  box-shadow: 0 5px 18px rgba(101, 251, 210, 0.18);
}
.vault-detail-scroll {
  padding-bottom: calc(
    var(--sky-safe-area-bottom) + var(--sky-tabbar-height) + var(--sky-space-5)
  );
}
.detail-trade-dock {
  position: absolute;
  right: calc(var(--sky-page-gutter) + var(--sky-safe-area-right));
  bottom: calc(var(--sky-safe-area-bottom) + 4px);
  left: calc(var(--sky-page-gutter) + var(--sky-safe-area-left));
  z-index: 11;
  padding: 6px;
  background: #080d13;
  border: 1px solid rgba(255, 255, 255, 0.1);
  border-radius: 23px;
  box-shadow:
    0 18px 46px rgba(0, 0, 0, 0.62),
    inset 0 1px rgba(255, 255, 255, 0.06);
}
.detail-trade-action {
  min-width: 0;
  min-height: 56px;
  gap: 9px;
  justify-content: flex-start;
  padding: 0 12px;
  border-radius: 17px;
}
.detail-trade-action > span:first-child {
  display: grid;
  place-items: center;
  width: 32px;
  height: 32px;
  flex: 0 0 auto;
  background: rgba(255, 255, 255, 0.14);
  border-radius: 11px;
}
.detail-trade-action > span:last-child {
  display: grid;
  min-width: 0;
  gap: 1px;
  text-align: left;
}
.detail-trade-action b {
  font-size: 13px;
}
.detail-trade-action small {
  overflow: hidden;
  color: rgba(255, 255, 255, 0.68);
  font-size: 10px;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.detail-trade-action--buy {
  background: #179d7d;
  box-shadow: none;
}
.detail-trade-action--sell {
  background: #202630;
  border: 1px solid rgba(255, 117, 136, 0.22);
  box-shadow: none;
}
.vault-view {
  animation: vault-view-in 220ms cubic-bezier(0.22, 1, 0.36, 1);
}
@keyframes vault-view-in {
  from {
    opacity: 0;
    transform: translateX(10px);
  }
  to {
    opacity: 1;
    transform: translateX(0);
  }
}
.crypto-app :deep(.sky-sheet__panel) {
  max-height: calc(100% - var(--sky-safe-area-top) - 20px);
  overflow-y: auto;
  color: #f8fbfd;
  background:
    radial-gradient(
      circle at 92% 0%,
      rgba(101, 251, 210, 0.1),
      transparent 27%
    ),
    #0d1219;
  border: 1px solid rgba(255, 255, 255, 0.09);
  border-bottom: 0;
  border-radius: 28px 28px 0 0;
  box-shadow: 0 -22px 70px rgba(0, 0, 0, 0.52);
}
.crypto-app :deep(.sky-sheet__grabber) {
  background: transparent;
}
.crypto-app :deep(.sky-sheet__grabber::after) {
  background: rgba(255, 255, 255, 0.2);
}
.sheet {
  background: transparent;
}
.sheet-header,
.sheet-heading,
.sheet-market-summary {
  display: flex;
  align-items: center;
}
.sheet-header {
  min-height: 58px;
  justify-content: flex-start;
  gap: 12px;
  padding: 0 2px 12px;
  border-bottom: 1px solid rgba(255, 255, 255, 0.07);
}
.sheet-heading {
  width: 100%;
  min-width: 0;
  gap: 10px;
}
.sheet-heading > span:last-child {
  display: grid;
  gap: 2px;
  min-width: 0;
}
.sheet-heading small {
  overflow: hidden;
  color: var(--muted);
  font-size: 11px;
  font-weight: 700;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.sheet-heading h2 {
  font-size: 18px;
  letter-spacing: -0.025em;
}
.sheet-icon {
  display: grid;
  place-items: center;
  width: 40px;
  height: 40px;
  flex: 0 0 auto;
  color: #07100e;
  font-size: 15px;
  font-weight: 900;
  background: linear-gradient(145deg, var(--vault-mint), var(--vault-blue));
  border: 1px solid rgba(255, 255, 255, 0.2);
  border-radius: 14px;
  box-shadow: 0 9px 24px rgba(101, 251, 210, 0.12);
}
.sheet-icon--crypto {
  background: transparent;
  border: 0;
  box-shadow: none;
}
.sheet-crypto-logo {
  width: 40px;
  height: 40px;
}
.sheet-market-summary {
  justify-content: space-between;
  gap: 9px;
  min-height: 72px;
  padding: 13px 15px;
  background:
    radial-gradient(
      circle at 90% 0%,
      rgba(101, 251, 210, 0.14),
      transparent 42%
    ),
    linear-gradient(145deg, #17212c, #0b1016);
  border: 1px solid rgba(255, 255, 255, 0.07);
  border-radius: 19px;
  box-shadow: inset 0 1px rgba(255, 255, 255, 0.045);
}
.sheet-market-summary span {
  display: grid;
  gap: 3px;
}
.sheet-market-summary small {
  color: var(--muted);
  font-size: 10px;
  font-weight: 750;
  letter-spacing: 0.06em;
  text-transform: uppercase;
}
.sheet-market-summary b {
  font-size: 22px;
  letter-spacing: -0.035em;
}
.sheet-market-summary em {
  padding: 7px 9px;
  font-size: 11px;
  font-style: normal;
  font-weight: 800;
  background: rgba(101, 251, 210, 0.08);
  border: 1px solid currentColor;
  border-radius: var(--sky-radius-pill);
}
.trade-side-selector {
  min-height: 50px;
  padding: 3px;
  background: rgba(255, 255, 255, 0.045);
  border: 1px solid rgba(255, 255, 255, 0.06);
  border-radius: 17px;
}
.trade-side-selector :deep(.sky-segmented-button) {
  min-height: 42px;
  gap: 7px;
  color: rgba(255, 255, 255, 0.52);
  font-size: 12px;
  font-weight: 800;
  border-radius: 13px;
}
:deep(.trade-side-selector.sky-segmented--strong .sky-segmented__highlight) {
  top: 3px;
  bottom: 3px;
  inset-inline-start: 3px;
  background: linear-gradient(
    135deg,
    rgba(101, 251, 210, 0.18),
    rgba(104, 167, 255, 0.12)
  );
  border: 1px solid rgba(101, 251, 210, 0.28);
  border-radius: 13px;
}
:deep(
  .trade-side-selector.sky-segmented--strong .sky-segmented-button--active
) {
  color: #fff;
}
.trade-entry-card {
  display: grid;
  gap: 10px;
  padding: 12px;
  background: linear-gradient(145deg, #131b24, #0a0f15);
  border: 1px solid rgba(255, 255, 255, 0.07);
  border-radius: 19px;
}
.trade-entry-meta {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 8px;
}
.trade-entry-meta > span {
  display: grid;
  gap: 2px;
  min-width: 0;
  padding: 9px 10px;
  background: rgba(255, 255, 255, 0.035);
  border: 1px solid rgba(255, 255, 255, 0.04);
  border-radius: 12px;
}
.trade-entry-meta small {
  color: var(--muted);
  font-size: 10px;
}
.trade-entry-meta b {
  overflow: hidden;
  font-size: 11px;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.trade-protection {
  display: flex;
  gap: 10px;
  align-items: flex-start;
  padding: 11px 12px;
  color: var(--vault-mint);
  background: rgba(101, 251, 210, 0.055);
  border: 1px solid rgba(101, 251, 210, 0.12);
  border-radius: 15px;
}
.trade-protection svg {
  flex: 0 0 auto;
}
.trade-protection span {
  display: grid;
  gap: 2px;
}
.trade-protection b {
  color: #f8fbfd;
  font-size: 11px;
}
.trade-protection small {
  color: var(--muted);
  font-size: 10px;
  line-height: 1.4;
}
.trade-submit {
  min-height: 52px;
  border-radius: 16px;
  font-size: 13px;
  font-weight: 850;
}
.trade-submit--buy {
  background: #179d7d;
  box-shadow: none;
}
.trade-submit--sell {
  background: #c4475c;
  box-shadow: none;
}
.transfer-intro,
.transfer-recipient,
.transfer-balance {
  display: flex;
  align-items: center;
}
.transfer-intro {
  gap: 11px;
  padding: 13px;
  background: linear-gradient(
    145deg,
    rgba(101, 251, 210, 0.09),
    rgba(104, 167, 255, 0.055)
  );
  border: 1px solid rgba(101, 251, 210, 0.13);
  border-radius: 17px;
}
.transfer-intro > span,
.transfer-recipient > span {
  display: grid;
  place-items: center;
  width: 38px;
  height: 38px;
  flex: 0 0 auto;
  color: var(--vault-mint);
  background: rgba(101, 251, 210, 0.09);
  border-radius: 12px;
}
.transfer-intro > div,
.transfer-recipient > div {
  display: grid;
  min-width: 0;
  gap: 2px;
}
.transfer-intro b,
.transfer-recipient b {
  font-size: 12px;
}
.transfer-intro small,
.transfer-recipient small,
.transfer-recipient em {
  color: var(--muted);
  font-size: 10px;
  font-style: normal;
  line-height: 1.35;
}
.transfer-key-entry {
  display: grid;
  grid-template-columns: minmax(0, 1fr);
  gap: 8px;
}
.transfer-resolve {
  width: 100%;
  min-height: 50px;
  font-size: 12px;
  font-weight: 850;
  border-radius: 15px;
}
.transfer-recipient {
  gap: 10px;
  padding: 11px;
  background: rgba(101, 251, 210, 0.055);
  border: 1px solid rgba(101, 251, 210, 0.15);
  border-radius: 15px;
}
.transfer-recipient em {
  overflow: hidden;
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.transfer-assets {
  display: grid;
  gap: 7px;
}
.transfer-assets > small {
  color: var(--muted);
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 0.06em;
  text-transform: uppercase;
}
.transfer-assets > div {
  display: flex;
  gap: 7px;
  overflow-x: auto;
  scrollbar-width: none;
}
.transfer-assets button {
  display: flex;
  min-width: 105px;
  gap: 7px;
  align-items: center;
  padding: 8px;
  color: rgba(255, 255, 255, 0.58);
  text-align: left;
  background: rgba(255, 255, 255, 0.035);
  border: 1px solid rgba(255, 255, 255, 0.06);
  border-radius: 14px;
}
.transfer-assets button.active {
  color: #fff;
  background: rgba(101, 251, 210, 0.09);
  border-color: rgba(101, 251, 210, 0.27);
}
.transfer-assets button :deep(.crypto-logo) {
  width: 31px;
  height: 31px;
}
.transfer-assets button span {
  display: grid;
  gap: 1px;
}
.transfer-assets button b {
  font-size: 11px;
}
.transfer-assets button small {
  font-size: 9px;
}
.transfer-balance {
  justify-content: space-between;
  margin-top: -7px;
  padding: 0 3px;
  color: var(--muted);
  font-size: 10px;
}
.transfer-balance b {
  color: #fff;
}
.transfer-submit {
  min-height: 52px;
  gap: 8px;
  color: #06110e;
  font-weight: 900;
  background: var(--vault-mint);
  border-radius: 16px;
  box-shadow: none;
}
.sheet-copy {
  color: var(--muted);
  font-size: 12px;
  line-height: 1.5;
}
.sheet--settlement {
  gap: 14px;
}
.settlement-form {
  display: grid;
  width: 100%;
  gap: 13px;
}
.settlement-intro {
  display: flex;
  gap: 11px;
  align-items: flex-start;
  padding: 12px 13px;
  background:
    radial-gradient(
      circle at 0% 0%,
      rgba(101, 251, 210, 0.08),
      transparent 52%
    ),
    rgba(255, 255, 255, 0.025);
  border: 1px solid rgba(255, 255, 255, 0.065);
  border-radius: 16px;
  box-shadow: inset 0 1px rgba(255, 255, 255, 0.035);
}
.settlement-intro > span {
  display: grid;
  width: 32px;
  height: 32px;
  flex: 0 0 auto;
  place-items: center;
  color: var(--vault-mint);
  background: rgba(101, 251, 210, 0.08);
  border: 1px solid rgba(101, 251, 210, 0.14);
  border-radius: 11px;
}
.settlement-copy {
  padding-top: 1px;
  color: rgba(238, 245, 248, 0.66);
  font-size: 11px;
  line-height: 1.55;
}
.settlement-fields {
  display: grid;
  gap: 10px;
}
.sheet-field {
  min-height: 64px;
  margin: 0;
  padding: 0 15px;
  color: #f8fbfd;
  background:
    linear-gradient(145deg, rgba(255, 255, 255, 0.045), transparent), #090f16;
  border-radius: 17px;
  box-shadow: inset 0 1px rgba(255, 255, 255, 0.04);
}
.sheet-field:focus-within {
  background:
    linear-gradient(145deg, rgba(101, 251, 210, 0.07), transparent), #090f16;
  box-shadow:
    0 0 0 3px rgba(101, 251, 210, 0.065),
    inset 0 1px rgba(255, 255, 255, 0.05);
}
.sheet-field :deep(.sky-field__media) {
  display: grid;
  width: 36px;
  height: 36px;
  justify-content: center;
  margin-right: 12px;
  padding: 0;
  place-items: center;
  color: var(--vault-mint);
  background: rgba(101, 251, 210, 0.07);
  border: 1px solid rgba(101, 251, 210, 0.13);
  border-radius: 12px;
}
.sheet-field :deep(.sky-field__inner) {
  padding: 12px 0 10px;
}
.sheet-field :deep(.sky-field__label) {
  margin-top: 0;
  color: rgba(255, 255, 255, 0.55);
  font-size: 10px;
  font-weight: 750;
}
.sheet-field :deep(.sky-field__label-text) {
  top: 0;
  margin: 0;
  padding: 0;
  background: transparent;
}
.sheet-field :deep(.sky-field__control) {
  margin: -2px 0 0;
}
.sheet-field :deep(.sky-field__input) {
  height: 31px;
  min-height: 31px;
  color: #fff;
  font-size: 15px;
  font-weight: 700;
  line-height: 21px;
}
.sheet-field :deep(.sky-field__input::placeholder) {
  color: rgba(255, 255, 255, 0.24);
}
.sheet-field :deep(.sky-field__border) {
  inset: 0;
  border-color: rgba(255, 255, 255, 0.12);
  border-radius: 17px;
}
.sheet-field:focus-within :deep(.sky-field__border) {
  border-color: rgba(101, 251, 210, 0.58);
}
.sheet-field.sky-field--error :deep(.sky-field__border) {
  border-color: rgba(255, 117, 136, 0.6);
}
.settlement-error {
  margin: -3px 2px 0;
}
.settlement-submit {
  min-height: 54px;
  gap: 8px;
  color: #06110e;
  font-size: 13px;
  font-weight: 900;
  background: var(--vault-mint);
  border: 1px solid rgba(101, 251, 210, 0.48);
  border-radius: 17px;
  box-shadow: none;
}
.settlement-submit:active {
  box-shadow: none;
  transform: translateY(1px);
}
@media (hover: hover) {
  .settlement-submit:hover {
    filter: brightness(1.06);
  }
}
.sheet--profile {
  gap: 14px;
}
.sheet--profile .sheet-copy {
  padding: 0 3px;
  font-size: 11px;
  line-height: 1.55;
}
.profile-edit-sheet {
  display: grid;
  width: 100%;
  gap: 13px;
}
.profile-edit-fields {
  display: grid;
  gap: 9px;
}
.profile-edit-note {
  display: flex;
  gap: 9px;
  align-items: flex-start;
  padding: 11px 12px;
  color: rgba(255, 255, 255, 0.62);
  font-size: 11px;
  line-height: 1.4;
  background: rgba(101, 251, 210, 0.06);
  border: 1px solid rgba(101, 251, 210, 0.12);
  border-radius: 14px;
}
.profile-edit-note svg {
  flex: 0 0 auto;
  color: var(--vault-mint);
}
.profile-save-button {
  min-height: 52px;
  gap: 8px;
  color: #06110e;
  font-size: 13px;
  font-weight: 900;
  background: var(--vault-mint);
  border: 1px solid rgba(101, 251, 210, 0.48);
  border-radius: 16px;
  box-shadow: none;
}
.profile-save-button:active {
  box-shadow: none;
  transform: translateY(1px);
}
.quote {
  display: grid;
  gap: 0;
  padding: 13px;
  background: linear-gradient(145deg, #151d27, #0c1117);
  border: 1px solid rgba(255, 255, 255, 0.07);
  border-radius: 18px;
}
.quote-heading {
  align-items: center;
  margin-bottom: 8px;
  padding: 0 0 11px !important;
  color: #f8fbfd !important;
  border-bottom: 1px solid rgba(255, 255, 255, 0.07);
}
.quote-heading > span {
  display: grid;
  gap: 2px;
}
.quote-heading small {
  color: var(--vault-mint);
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 0.07em;
  text-transform: uppercase;
}
.quote-heading > svg {
  color: var(--vault-mint);
}
.quote > div:not(.quote-heading) {
  padding: 6px 0;
}
.quote > div:nth-last-of-type(1) {
  margin-top: 4px;
  padding-top: 10px;
  color: #f8fbfd;
  border-top: 1px solid rgba(255, 255, 255, 0.07);
}
.quote-expiry {
  margin-top: 8px;
  padding: 8px 9px;
  line-height: 1.35;
  background: rgba(255, 255, 255, 0.035);
  border-radius: 10px;
}
@media (prefers-reduced-motion: reduce) {
  .portfolio-shell::after {
    display: none;
  }
  .vault-view {
    animation: none;
  }
}
.phone-app--performance .portfolio-shell,
.phone-app--performance .featured-market,
.phone-app--performance .profile-card,
.phone-app--performance .activity-overview,
.phone-app--performance .activity-status {
  box-shadow: none;
}
</style>
