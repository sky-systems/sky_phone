<script setup lang="ts">
import {
  kButton,
  kCard,
  kPage,
  kPreloader,
  kTabbar,
  kTabbarLink,
} from 'konsta/vue'
import {
  ArrowDownLeft,
  ArrowRight,
  ArrowUpRight,
  BarChart3,
  ChevronRight,
  CircleDollarSign,
  House,
  Landmark,
  RefreshCw,
  Send,
  WalletCards,
  X,
} from 'lucide-vue-next'
import { computed, onMounted, ref } from 'vue'

import { useBankingStore } from '@/stores/banking'
import { usePhoneStore } from '@/stores/phone'
import type {
  BankingAction,
  BankingTransaction,
  BankingTransactionKind,
} from '@/types/banking'

type BankingTab = 'home' | 'activity'

const phone = usePhoneStore()
const banking = useBankingStore()
const activeTab = ref<BankingTab>('home')
const action = ref<BankingAction | null>(null)
const amount = ref('')
const target = ref('')
const formError = ref('')

const transactionIcons: Record<BankingTransactionKind, typeof Send> = {
  deposit: ArrowDownLeft,
  withdrawal: ArrowUpRight,
  transfer_in: ArrowDownLeft,
  transfer_out: ArrowUpRight,
}

const isIncoming = (kind: BankingTransactionKind): boolean =>
  kind === 'deposit' || kind === 'transfer_in'

const chart = computed(() => {
  const days = Array.from({ length: 7 }, (_, offset) => {
    const date = new Date()
    date.setHours(0, 0, 0, 0)
    date.setDate(date.getDate() - (6 - offset))
    return { date, incoming: 0, outgoing: 0 }
  })
  for (const transaction of banking.overview?.transactions ?? []) {
    const transactionDate = new Date(transaction.createdAt)
    transactionDate.setHours(0, 0, 0, 0)
    const day = days.find(
      (candidate) => candidate.date.getTime() === transactionDate.getTime(),
    )
    if (!day) continue
    if (isIncoming(transaction.kind)) day.incoming += transaction.amount
    else day.outgoing += transaction.amount
  }
  const maximum = Math.max(
    1,
    ...days.flatMap((day) => [day.incoming, day.outgoing]),
  )
  return days.map((day) => ({
    ...day,
    incomingHeight: Math.max(5, (day.incoming / maximum) * 100),
    label: new Intl.DateTimeFormat(phone.lang, { weekday: 'narrow' }).format(
      day.date,
    ),
    outgoingHeight: Math.max(5, (day.outgoing / maximum) * 100),
  }))
})

const totals = computed(() =>
  (banking.overview?.transactions ?? []).reduce(
    (result, transaction) => {
      if (isIncoming(transaction.kind)) result.incoming += transaction.amount
      else result.outgoing += transaction.amount
      return result
    },
    { incoming: 0, outgoing: 0 },
  ),
)

function formatMoney(value: number, signed = false): string {
  const formatted = new Intl.NumberFormat(phone.lang, {
    maximumFractionDigits: 0,
    minimumFractionDigits: 0,
  }).format(Math.abs(value))
  const prefix = signed ? (value >= 0 ? '+' : '−') : ''
  return `${prefix}${banking.overview?.currency ?? '$'}${formatted}`
}

function formatDate(timestamp: number): string {
  return new Intl.DateTimeFormat(phone.lang, {
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    month: 'short',
  }).format(timestamp)
}

function transactionTitle(transaction: BankingTransaction): string {
  if (transaction.label) return transaction.label
  return phone.t(`Apps.banking.transactions.${transaction.kind}`)
}

function openAction(nextAction: BankingAction): void {
  action.value = nextAction
  amount.value = ''
  target.value = ''
  formError.value = ''
}

function closeAction(): void {
  if (banking.isLoading) return
  action.value = null
}

function errorMessage(code: string): string {
  return phone.t(`Apps.banking.errors.${code}`) ===
    `Apps.banking.errors.${code}`
    ? phone.t('Apps.banking.errors.default')
    : phone.t(`Apps.banking.errors.${code}`)
}

async function submitAction(): Promise<void> {
  if (!action.value) return
  const parsedAmount = Number(amount.value)
  const parsedTarget = action.value === 'transfer' ? Number(target.value) : undefined
  if (
    !Number.isSafeInteger(parsedAmount) ||
    parsedAmount <= 0 ||
    (action.value === 'transfer' &&
      (!Number.isSafeInteger(parsedTarget) || (parsedTarget ?? 0) <= 0))
  ) {
    formError.value = phone.t('Apps.banking.errors.invalid_request')
    return
  }
  const response = await banking.perform(action.value, parsedAmount, parsedTarget)
  if (!response.success) {
    formError.value = errorMessage(response.error ?? 'default')
    return
  }
  action.value = null
}

onMounted(() => void banking.load())
</script>

<template>
  <k-page
    component="main"
    class="banking-app"
    :colors="{ bgIos: 'bg-transparent' }"
  >
    <div class="banking-app__aurora" aria-hidden="true"></div>

    <header class="banking-header">
      <div>
        <span>{{ phone.t('Apps.banking.welcome') }}</span>
        <h1>{{ banking.overview?.playerName ?? phone.t('Common.loading') }}</h1>
      </div>
      <button
        type="button"
        class="banking-profile"
        :aria-label="phone.t('Apps.banking.refresh')"
        :disabled="banking.isLoading"
        @click="banking.load()"
      >
        <Landmark :size="20" />
        <RefreshCw v-if="banking.isLoading" class="banking-spin" :size="10" />
      </button>
    </header>

    <div v-if="!banking.overview && banking.isLoading" class="banking-loading">
      <k-preloader />
      <span>{{ phone.t('Common.loading') }}</span>
    </div>

    <div v-else-if="!banking.overview" class="banking-empty">
      <Landmark :size="34" />
      <strong>{{ phone.t('Apps.banking.unavailable') }}</strong>
      <p>{{ errorMessage(banking.error) }}</p>
      <k-button rounded @click="banking.load()">
        {{ phone.t('Apps.banking.tryAgain') }}
      </k-button>
    </div>

    <div v-else class="banking-scroll">
      <template v-if="activeTab === 'home'">
        <section class="banking-balance">
          <div class="banking-balance__label">
            <span>{{ phone.t('Apps.banking.totalBalance') }}</span>
            <small>#{{ banking.overview.playerId }}</small>
          </div>
          <strong>{{ formatMoney(banking.overview.bank) }}</strong>
          <div class="banking-balance__trend">
            <span>{{ formatMoney(totals.incoming - totals.outgoing, true) }}</span>
            {{ phone.t('Apps.banking.recentPeriod') }}
          </div>
        </section>

        <section class="banking-actions" :aria-label="phone.t('Apps.banking.actions')">
          <button type="button" @click="openAction('transfer')">
            <span><Send :size="20" /></span>
            {{ phone.t('Apps.banking.send') }}
          </button>
          <button type="button" @click="openAction('deposit')">
            <span><ArrowDownLeft :size="20" /></span>
            {{ phone.t('Apps.banking.deposit') }}
          </button>
          <button type="button" @click="openAction('withdraw')">
            <span><ArrowUpRight :size="20" /></span>
            {{ phone.t('Apps.banking.withdraw') }}
          </button>
        </section>

        <k-card :content-wrap="false" class="banking-card banking-accounts">
          <div class="banking-section-title">
            <h2>{{ phone.t('Apps.banking.accounts') }}</h2>
            <ChevronRight :size="17" />
          </div>
          <div class="banking-account-row banking-account-row--primary">
            <span><WalletCards :size="18" /></span>
            <div>
              <small>{{ phone.t('Apps.banking.bankAccount') }}</small>
              <strong>{{ formatMoney(banking.overview.bank) }}</strong>
            </div>
            <span class="banking-card-mark" aria-hidden="true"></span>
          </div>
          <div class="banking-account-row">
            <span><CircleDollarSign :size="18" /></span>
            <div>
              <small>{{ phone.t('Apps.banking.cash') }}</small>
              <strong>{{ formatMoney(banking.overview.cash) }}</strong>
            </div>
          </div>
        </k-card>

        <section class="banking-transactions">
          <div class="banking-section-title">
            <h2>{{ phone.t('Apps.banking.latestTransactions') }}</h2>
            <button type="button" @click="activeTab = 'activity'">
              {{ phone.t('Apps.banking.viewAll') }}
            </button>
          </div>
          <div v-if="banking.overview.transactions.length" class="banking-transaction-list">
            <article
              v-for="transaction in banking.overview.transactions.slice(0, 5)"
              :key="transaction.id"
              class="banking-transaction"
            >
              <span :class="{ 'is-incoming': isIncoming(transaction.kind) }">
                <component :is="transactionIcons[transaction.kind]" :size="17" />
              </span>
              <div>
                <strong>{{ transactionTitle(transaction) }}</strong>
                <small>{{ formatDate(transaction.createdAt) }}</small>
              </div>
              <b :class="{ 'is-incoming': isIncoming(transaction.kind) }">
                {{ formatMoney(isIncoming(transaction.kind) ? transaction.amount : -transaction.amount, true) }}
              </b>
            </article>
          </div>
          <p v-else class="banking-no-transactions">
            {{ phone.t('Apps.banking.noTransactions') }}
          </p>
        </section>
      </template>

      <template v-else>
        <section class="banking-activity-hero">
          <span>{{ phone.t('Apps.banking.activity') }}</span>
          <strong>{{ formatMoney(totals.incoming - totals.outgoing, true) }}</strong>
          <small>{{ phone.t('Apps.banking.recentPeriod') }}</small>
        </section>

        <k-card :content-wrap="false" class="banking-card banking-chart-card">
          <div class="banking-chart-legend">
            <span><i class="is-incoming"></i>{{ phone.t('Apps.banking.incoming') }}</span>
            <span><i></i>{{ phone.t('Apps.banking.outgoing') }}</span>
          </div>
          <div class="banking-chart">
            <div v-for="day in chart" :key="day.date.getTime()" class="banking-chart__day">
              <div>
                <i class="is-incoming" :style="{ height: `${day.incomingHeight}%` }"></i>
                <i :style="{ height: `${day.outgoingHeight}%` }"></i>
              </div>
              <span>{{ day.label }}</span>
            </div>
          </div>
        </k-card>

        <section class="banking-transactions banking-transactions--all">
          <div class="banking-section-title">
            <h2>{{ phone.t('Apps.banking.allTransactions') }}</h2>
          </div>
          <div class="banking-transaction-list">
            <article
              v-for="transaction in banking.overview.transactions"
              :key="transaction.id"
              class="banking-transaction"
            >
              <span :class="{ 'is-incoming': isIncoming(transaction.kind) }">
                <component :is="transactionIcons[transaction.kind]" :size="17" />
              </span>
              <div>
                <strong>{{ transactionTitle(transaction) }}</strong>
                <small>{{ formatDate(transaction.createdAt) }}</small>
              </div>
              <b :class="{ 'is-incoming': isIncoming(transaction.kind) }">
                {{ formatMoney(isIncoming(transaction.kind) ? transaction.amount : -transaction.amount, true) }}
              </b>
            </article>
          </div>
        </section>
      </template>
    </div>

    <k-tabbar
      v-if="banking.overview"
      component="nav"
      icons
      labels
      class="banking-tabbar"
      bg-class="banking-tabbar__background"
      inner-class="banking-tabbar__inner"
      :aria-label="phone.t('Apps.banking.navigation')"
    >
      <k-tabbar-link
        component="button"
        :active="activeTab === 'home'"
        :label="phone.t('Apps.banking.home')"
        :link-props="{ type: 'button' }"
        @click="activeTab = 'home'"
      >
        <template #icon><House :size="19" /></template>
      </k-tabbar-link>
      <k-tabbar-link
        component="button"
        :active="activeTab === 'activity'"
        :label="phone.t('Apps.banking.activity')"
        :link-props="{ type: 'button' }"
        @click="activeTab = 'activity'"
      >
        <template #icon><BarChart3 :size="19" /></template>
      </k-tabbar-link>
    </k-tabbar>

    <div v-if="action" class="banking-modal-backdrop" @click.self="closeAction">
      <section class="banking-modal" role="dialog" aria-modal="true">
        <button
          type="button"
          class="banking-modal__close"
          :aria-label="phone.t('Common.close')"
          @click="closeAction"
        >
          <X :size="17" />
        </button>
        <span class="banking-modal__icon">
          <Send v-if="action === 'transfer'" :size="23" />
          <ArrowDownLeft v-else-if="action === 'deposit'" :size="23" />
          <ArrowUpRight v-else :size="23" />
        </span>
        <h2>{{ phone.t(`Apps.banking.forms.${action}.title`) }}</h2>
        <p>{{ phone.t(`Apps.banking.forms.${action}.body`) }}</p>
        <label v-if="action === 'transfer'">
          <span>{{ phone.t('Apps.banking.playerId') }}</span>
          <input
            v-model="target"
            inputmode="numeric"
            min="1"
            type="number"
            :placeholder="phone.t('Apps.banking.playerIdPlaceholder')"
          />
        </label>
        <label>
          <span>{{ phone.t('Apps.banking.amount') }}</span>
          <div class="banking-amount-input">
            <i>{{ banking.overview?.currency }}</i>
            <input
              v-model="amount"
              inputmode="numeric"
              min="1"
              type="number"
              :placeholder="phone.t('Apps.banking.amountPlaceholder')"
              @keydown.enter="submitAction"
            />
          </div>
        </label>
        <p v-if="formError" class="banking-form-error">{{ formError }}</p>
        <k-button
          large
          rounded
          :disabled="banking.isLoading"
          @click="submitAction"
        >
          <k-preloader v-if="banking.isLoading" />
          <template v-else>
            {{ phone.t(`Apps.banking.forms.${action}.submit`) }}
            <ArrowRight :size="17" />
          </template>
        </k-button>
      </section>
    </div>
  </k-page>
</template>
