<script setup lang="ts">
import { BadgeDollarSign, Check, RefreshCw, X } from 'lucide-vue-next'
import { computed } from 'vue'

import { usePhoneStore } from '@/stores/phone'
import type { MarketplaceOffer } from '@/types/marketplace'

const props = defineProps<{
  accountId: number
  actionable: boolean
  isCounter: boolean
  offer: MarketplaceOffer
}>()

defineEmits<{
  accept: []
  counter: []
  reject: []
}>()

const phone = usePhoneStore()
const isOwn = computed(() => props.offer.proposer_account_id === props.accountId)
const statusKey = computed(() =>
  props.offer.status === 'rejected' ? 'declined' : props.offer.status,
)
const formattedAmount = computed(() =>
  phone.t('Apps.citymarkt.money', {
    price: new Intl.NumberFormat(phone.lang, { maximumFractionDigits: 0 }).format(
      Number(props.offer.amount),
    ),
  }),
)
</script>

<template>
  <article
    class="citymarkt-offer"
    :class="[`citymarkt-offer--${offer.status}`, { 'citymarkt-offer--own': isOwn }]"
  >
    <header>
      <span><BadgeDollarSign :size="16" /></span>
      <div>
        <small>{{ phone.t(isCounter ? 'Apps.citymarkt.counterOffer' : 'Apps.citymarkt.offer') }}</small>
        <strong>{{ formattedAmount }}</strong>
      </div>
      <i>{{ phone.t(`Apps.citymarkt.offerStatus.${statusKey}`) }}</i>
    </header>
    <p>
      {{ phone.t(isOwn ? 'Apps.citymarkt.offeredByYou' : 'Apps.citymarkt.offeredToYou') }}
    </p>
    <div v-if="actionable" class="citymarkt-offer__actions">
      <button type="button" class="accept" @click="$emit('accept')">
        <Check :size="14" />{{ phone.t('Apps.citymarkt.acceptOffer') }}
      </button>
      <button type="button" @click="$emit('counter')">
        <RefreshCw :size="13" />{{ phone.t('Apps.citymarkt.negotiateOffer') }}
      </button>
      <button type="button" class="reject" @click="$emit('reject')">
        <X :size="14" />{{ phone.t('Apps.citymarkt.declineOffer') }}
      </button>
    </div>
  </article>
</template>

<style scoped>
.citymarkt-offer{width:92%;padding:11px;border:1px solid #ffc92842;border-radius:14px;align-self:flex-start;background:linear-gradient(145deg,#332d19,var(--panel));box-shadow:0 7px 18px #0003}.citymarkt-offer--own{align-self:flex-end}.citymarkt-offer header{display:flex;align-items:center;gap:8px}.citymarkt-offer header>span{width:32px;height:32px;flex:none;border-radius:10px;display:grid;place-items:center;background:var(--yellow);color:#171816}.citymarkt-offer header>div{min-width:0;flex:1}.citymarkt-offer header small,.citymarkt-offer header strong{display:block}.citymarkt-offer header small{color:var(--muted);font-size:9px;font-weight:800;letter-spacing:.02em;text-transform:uppercase}.citymarkt-offer header strong{margin-top:1px;font-size:18px}.citymarkt-offer header i{padding:5px 7px;border-radius:7px;background:#ffc92817;color:var(--yellow);font-size:8px;font-style:normal;font-weight:900;text-transform:uppercase}.citymarkt-offer>p{margin:7px 0 0;color:var(--muted);font-size:9px;line-height:1.35}.citymarkt-offer--accepted{border-color:#54d68173;background:linear-gradient(145deg,#193526,var(--panel))}.citymarkt-offer--accepted header>span{background:#54d681}.citymarkt-offer--accepted header i{background:#54d6811c;color:#67e494}.citymarkt-offer--rejected,.citymarkt-offer--countered{border-color:#ffffff14;filter:saturate(.65)}.citymarkt-offer--rejected header>span,.citymarkt-offer--countered header>span{background:#555750;color:#ddd}.citymarkt-offer--rejected header i,.citymarkt-offer--countered header i{background:#ffffff0c;color:var(--muted)}.citymarkt-offer__actions{margin-top:10px;display:grid;grid-template-columns:1fr 1fr;gap:6px}.citymarkt-offer__actions button{min-height:35px;padding:7px 6px;border:1px solid #ffffff12;border-radius:10px;display:flex;align-items:center;justify-content:center;gap:4px;background:#ffffff09;color:inherit;font-size:9.5px;font-weight:850;line-height:1.1}.citymarkt-offer__actions button.accept{border:0;background:#54d681;color:#102319}.citymarkt-offer__actions button.reject{grid-column:1/-1;color:#ff8078}:global(.citymarkt--light) .citymarkt-offer{background:linear-gradient(145deg,#fff8d9,#fff);box-shadow:0 7px 18px #0001}:global(.citymarkt--light) .citymarkt-offer--accepted{background:linear-gradient(145deg,#e6faed,#fff)}
.citymarkt-offer{padding:12px}.citymarkt-offer header>span{width:35px;height:35px}.citymarkt-offer header small{font-size:10.5px}.citymarkt-offer header strong{font-size:20px}.citymarkt-offer header i{padding:5px 8px;font-size:9.5px}.citymarkt-offer>p{margin-top:8px;font-size:11.5px}.citymarkt-offer__actions{margin-top:11px;gap:7px}.citymarkt-offer__actions button{min-height:40px;padding:8px;font-size:12px;font-weight:850;gap:5px}.citymarkt-offer__actions button svg{width:15px;height:15px}
.citymarkt-offer:not(.citymarkt-offer--accepted) {
  border-color: transparent;
}
</style>
