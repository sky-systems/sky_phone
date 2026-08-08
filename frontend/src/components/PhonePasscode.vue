<script setup lang="ts">
import { Delete } from 'lucide-vue-next'
import { computed, ref, watch } from 'vue'

import { usePhoneStore } from '@/stores/phone'

const props = withDefaults(
  defineProps<{
    busy?: boolean
    cancelable?: boolean
    disabled?: boolean
    error?: string
    length: 4 | 6
    resetKey?: number
    subtitle?: string
    title: string
  }>(),
  {
    busy: false,
    cancelable: true,
    disabled: false,
    error: '',
    resetKey: 0,
    subtitle: '',
  },
)

const emit = defineEmits<{
  cancel: []
  complete: [passcode: string]
}>()

const phone = usePhoneStore()
const digits = ref('')
const keypad = [1, 2, 3, 4, 5, 6, 7, 8, 9]
const inputDisabled = computed(() => props.busy || props.disabled)

function enterDigit(digit: number): void {
  if (inputDisabled.value || digits.value.length >= props.length) return
  digits.value += String(digit)
  if (digits.value.length === props.length) emit('complete', digits.value)
}

function removeDigit(): void {
  if (inputDisabled.value) return
  digits.value = digits.value.slice(0, -1)
}

watch(
  () => props.resetKey,
  () => {
    digits.value = ''
  },
)
</script>

<template>
  <section class="passcode-screen" :aria-label="title">
    <header class="passcode-screen__header">
      <h1>{{ title }}</h1>
      <p v-if="subtitle">{{ subtitle }}</p>
      <div class="passcode-screen__dots" aria-hidden="true">
        <span
          v-for="index in length"
          :key="index"
          :class="{ 'passcode-screen__dot--filled': digits.length >= index }"
        ></span>
      </div>
      <p
        v-if="error"
        class="passcode-screen__error"
        role="alert"
      >
        {{ error }}
      </p>
    </header>

    <div class="passcode-screen__keypad">
      <button
        v-for="digit in keypad"
        :key="digit"
        type="button"
        :disabled="inputDisabled"
        @click="enterDigit(digit)"
      >
        {{ digit }}
      </button>
      <button
        type="button"
        class="passcode-screen__action"
        :disabled="!cancelable || busy"
        @click="emit('cancel')"
      >
        {{ cancelable ? phone.t('LockScreen.passcode.cancel') : '' }}
      </button>
      <button type="button" :disabled="inputDisabled" @click="enterDigit(0)">
        0
      </button>
      <button
        type="button"
        class="passcode-screen__action"
        :aria-label="phone.t('LockScreen.passcode.delete')"
        :disabled="inputDisabled || digits.length === 0"
        @click="removeDigit"
      >
        <Delete :size="25" :stroke-width="1.7" aria-hidden="true" />
      </button>
    </div>
  </section>
</template>

<style scoped>
.passcode-screen {
  position: absolute;
  inset: 0;
  z-index: 90;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: space-between;
  padding: 76px 28px 30px;
  color: white;
  background:
    radial-gradient(circle at 50% 16%, rgb(76 92 132 / 46%), transparent 35%),
    linear-gradient(160deg, #182139, #080b12 72%);
  user-select: none;
}

.passcode-screen__header {
  min-height: 170px;
  text-align: center;
}

.passcode-screen__header h1 {
  margin: 0;
  font-size: 20px;
  font-weight: 600;
  letter-spacing: -0.02em;
}

.passcode-screen__header p {
  max-width: 270px;
  margin: 8px auto 0;
  color: rgb(255 255 255 / 72%);
  font-size: 13px;
  line-height: 1.35;
}

.passcode-screen__dots {
  display: flex;
  justify-content: center;
  gap: 14px;
  margin-top: 28px;
}

.passcode-screen__dots span {
  width: 12px;
  height: 12px;
  border: 1.5px solid rgb(255 255 255 / 78%);
  border-radius: 50%;
  transition: background-color 120ms ease, transform 120ms ease;
}

.passcode-screen__dots .passcode-screen__dot--filled {
  background: white;
  transform: scale(1.06);
}

.passcode-screen__header .passcode-screen__error {
  color: #ff9b93;
  font-weight: 500;
}

.passcode-screen__keypad {
  display: grid;
  grid-template-columns: repeat(3, 72px);
  gap: 15px 20px;
  align-items: center;
  justify-items: center;
}

.passcode-screen__keypad button:not(.passcode-screen__action) {
  width: 72px;
  height: 72px;
  border: 0;
  border-radius: 50%;
  color: white;
  background: rgb(255 255 255 / 16%);
  font-size: 30px;
  font-weight: 400;
  backdrop-filter: blur(18px);
  transition: background-color 100ms ease, transform 100ms ease;
}

.passcode-screen__keypad button:not(.passcode-screen__action):active {
  background: rgb(255 255 255 / 34%);
  transform: scale(0.96);
}

.passcode-screen__keypad button:disabled {
  opacity: 0.45;
}

.passcode-screen__keypad .passcode-screen__action {
  display: flex;
  align-items: center;
  justify-content: center;
  min-width: 72px;
  min-height: 48px;
  border: 0;
  color: white;
  background: transparent;
  font-size: 14px;
}
</style>
