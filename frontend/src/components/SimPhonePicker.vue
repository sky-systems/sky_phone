<script setup lang="ts">
import { ChevronRight, Smartphone, X } from 'lucide-vue-next'
import { ref } from 'vue'

import { usePhoneStore } from '@/stores/phone'
import { nuiCall } from '@/utils/nui'
import { formatPhoneNumber } from '@/utils/phone'

export type SimPhoneChoice = {
  imei: string
  name: string
  number?: string | null
  occupied: boolean
}

const props = defineProps<{
  choices: SimPhoneChoice[]
  number: string
}>()
const emit = defineEmits<{ close: [] }>()
const phone = usePhoneStore()
const confirmation = ref<SimPhoneChoice | null>(null)
const error = ref('')

async function insert(
  choice: SimPhoneChoice,
  confirmed = false,
): Promise<void> {
  const response = await nuiCall('sim:insert', {
    confirmed,
    imei: choice.imei,
  })
  if (response.success) {
    emit('close')
    return
  }
  if (response.error === 'confirmation_required') {
    confirmation.value = choice
    return
  }
  error.value = phone.t(`Apps.phone.errors.${response.error ?? 'default'}`)
}

function close(): void {
  void nuiCall('sim:picker-close')
  emit('close')
}
</script>

<template>
  <div class="sim-picker-backdrop" @click.self="close">
    <section class="sim-picker" aria-modal="true" role="dialog">
      <div class="sim-picker__glow sim-picker__glow--top" />
      <div class="sim-picker__glow sim-picker__glow--bottom" />
      <header class="sim-picker__header">
        <div>
          <h1>{{ phone.t('Apps.phone.choosePhone') }}</h1>
          <p>
            {{
              phone.t('Apps.phone.choosePhoneBody', {
                number: formatPhoneNumber(props.number),
              })
            }}
          </p>
        </div>
        <button
          type="button"
          class="sim-picker__close"
          :aria-label="phone.t('Common.close')"
          @click="close"
        >
          <X />
        </button>
      </header>

      <div v-if="!confirmation" class="sim-picker__cards">
        <button
          v-for="choice in choices"
          :key="choice.imei"
          type="button"
          class="sim-picker__card"
          @click="insert(choice)"
        >
          <Smartphone class="sim-picker__phone-icon" />
          <span class="sim-picker__details">
            <strong>{{ choice.name }}</strong>
            <small>{{
              choice.occupied && choice.number
                ? formatPhoneNumber(choice.number)
                : phone.t('Apps.phone.emptyPhone')
            }}</small>
            <small>IMEI {{ choice.imei }}</small>
          </span>
          <ChevronRight />
        </button>
      </div>

      <div v-else class="sim-picker__confirmation">
        <h2>{{ phone.t('Apps.phone.replaceTitle') }}</h2>
        <p>{{ phone.t('Apps.phone.replaceBody') }}</p>
        <div>
          <button type="button" @click="confirmation = null">
            {{ phone.t('Common.cancel') }}
          </button>
          <button
            type="button"
            class="is-primary"
            @click="insert(confirmation, true)"
          >
            {{ phone.t('Common.done') }}
          </button>
        </div>
      </div>
      <p v-if="error" class="sim-picker__error">{{ error }}</p>
    </section>
  </div>
</template>
