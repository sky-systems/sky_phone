<script setup lang="ts">
import { SkyButton, SkyIcon } from '@/ui'

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
  emit('close')
}
</script>

<template>
  <div
    class="sim-picker-backdrop"
    :class="`phone-app--${phone.preferences.settings.graphicsMode}`"
    @click.self="close"
  >
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
        <SkyButton
          variant="content"
          type="button"
          class="sim-picker__close"
          :aria-label="phone.t('Common.close')"
          @click="close"
        >
          <SkyIcon :icon="X" />
        </SkyButton>
      </header>

      <div v-if="!confirmation" class="sim-picker__cards">
        <SkyButton
          variant="content"
          v-for="choice in choices"
          :key="choice.imei"
          type="button"
          class="sim-picker__card"
          @click="insert(choice)"
        >
          <SkyIcon :icon="Smartphone" class="sim-picker__phone-icon" />
          <span class="sim-picker__details">
            <strong>{{ choice.name }}</strong>
            <small>{{
              choice.occupied && choice.number
                ? formatPhoneNumber(choice.number)
                : phone.t('Apps.phone.emptyPhone')
            }}</small>
            <small>IMEI {{ choice.imei }}</small>
          </span>
          <SkyIcon :icon="ChevronRight" />
        </SkyButton>
      </div>

      <div v-else class="sim-picker__confirmation">
        <h2>{{ phone.t('Apps.phone.replaceTitle') }}</h2>
        <p>{{ phone.t('Apps.phone.replaceBody') }}</p>
        <div>
          <SkyButton
            variant="content"
            type="button"
            @click="confirmation = null"
          >
            {{ phone.t('Common.cancel') }}
          </SkyButton>
          <SkyButton
            variant="content"
            type="button"
            class="is-primary"
            @click="insert(confirmation, true)"
          >
            {{ phone.t('Common.done') }}
          </SkyButton>
        </div>
      </div>
      <p v-if="error" class="sim-picker__error">{{ error }}</p>
    </section>
  </div>
</template>
