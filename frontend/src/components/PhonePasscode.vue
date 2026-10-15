<script setup lang="ts">
import { SkyButton, SkyIcon } from '@/ui'

import { Delete } from 'lucide-vue-next'
import { computed, onMounted, ref, watch, type CSSProperties } from 'vue'

import PhoneStatusBar from '@/components/PhoneStatusBar.vue'
import { usePhoneStore } from '@/stores/phone'

const props = withDefaults(
  defineProps<{
    busy?: boolean
    cancelable?: boolean
    disabled?: boolean
    error?: string
    length: 4 | 6
    lockScreen?: boolean
    resetKey?: number
    subtitle?: string
    title: string
  }>(),
  {
    busy: false,
    cancelable: true,
    disabled: false,
    error: '',
    lockScreen: false,
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
const screen = ref<HTMLElement | null>(null)
const keypad = [
  { digit: 1, letters: '' },
  { digit: 2, letters: 'ABC' },
  { digit: 3, letters: 'DEF' },
  { digit: 4, letters: 'GHI' },
  { digit: 5, letters: 'JKL' },
  { digit: 6, letters: 'MNO' },
  { digit: 7, letters: 'PQRS' },
  { digit: 8, letters: 'TUV' },
  { digit: 9, letters: 'WXYZ' },
] as const
const inputDisabled = computed(() => props.busy || props.disabled)
const screenClass = computed(() =>
  props.lockScreen
    ? [
        `passcode-screen--lock`,
        `wallpaper--${phone.preferences.settings.lockWallpaper}`,
      ]
    : ['passcode-screen--surface'],
)
const screenStyle = computed<CSSProperties>(() => {
  const imageUrl = phone.preferences.settings.lockWallpaperImageUrl
  if (
    !props.lockScreen ||
    phone.preferences.settings.lockWallpaper !== 'custom' ||
    !imageUrl
  ) {
    return {}
  }
  return {
    '--phone-wallpaper-image': `url(${JSON.stringify(imageUrl)})`,
  }
})

function enterDigit(digit: number): void {
  if (inputDisabled.value || digits.value.length >= props.length) return
  digits.value += String(digit)
  if (digits.value.length === props.length) emit('complete', digits.value)
}

function removeDigit(): void {
  if (inputDisabled.value) return
  digits.value = digits.value.slice(0, -1)
}

function handleKeydown(event: KeyboardEvent): void {
  if (/^[0-9]$/.test(event.key)) {
    event.preventDefault()
    enterDigit(Number(event.key))
    return
  }
  if (event.key === 'Backspace') {
    event.preventDefault()
    removeDigit()
    return
  }
  if (event.key === 'Escape' && props.cancelable && !props.busy) {
    event.preventDefault()
    emit('cancel')
  }
}

watch(
  () => props.resetKey,
  () => {
    digits.value = ''
  },
)

onMounted(() => screen.value?.focus())
</script>

<template>
  <section
    ref="screen"
    class="passcode-screen"
    :class="screenClass"
    :style="screenStyle"
    :aria-label="title"
    :aria-busy="busy"
    tabindex="-1"
    @keydown="handleKeydown"
  >
    <PhoneStatusBar v-if="lockScreen" :interactive="false" />
    <div class="passcode-screen__backdrop" aria-hidden="true"></div>

    <div class="passcode-screen__layout">
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
        <p v-if="error" class="passcode-screen__error" role="alert">
          {{ error }}
        </p>
      </header>

      <div class="passcode-screen__keypad">
        <SkyButton
          variant="content"
          v-for="key in keypad"
          :key="key.digit"
          type="button"
          class="passcode-screen__key"
          :class="{ 'passcode-screen__key--single': !key.letters }"
          :aria-label="String(key.digit)"
          :disabled="inputDisabled"
          @click="enterDigit(key.digit)"
        >
          <span>{{ key.digit }}</span>
          <small v-if="key.letters">{{ key.letters }}</small>
        </SkyButton>
        <span aria-hidden="true"></span>
        <SkyButton
          variant="content"
          type="button"
          class="passcode-screen__key passcode-screen__key--single"
          aria-label="0"
          :disabled="inputDisabled"
          @click="enterDigit(0)"
        >
          <span>0</span>
        </SkyButton>
        <span aria-hidden="true"></span>
      </div>

      <footer class="passcode-screen__footer">
        <span aria-hidden="true"></span>
        <SkyButton
          variant="content"
          v-if="digits.length > 0"
          type="button"
          class="passcode-screen__action"
          :aria-label="phone.t('LockScreen.passcode.delete')"
          :disabled="inputDisabled || digits.length === 0"
          @click="removeDigit"
        >
          <SkyIcon
            :icon="Delete"
            :size="24"
            :stroke-width="1.7"
            aria-hidden="true"
          />
        </SkyButton>
        <SkyButton
          variant="content"
          v-else
          type="button"
          class="passcode-screen__action"
          :disabled="!cancelable || busy"
          @click="emit('cancel')"
        >
          {{ cancelable ? phone.t('LockScreen.passcode.cancel') : '' }}
        </SkyButton>
      </footer>
    </div>
  </section>
</template>

<style scoped>
.passcode-screen {
  --passcode-text: #fff;
  --passcode-muted: rgb(255 255 255 / 72%);
  --passcode-key-background: transparent;
  --passcode-key-border: rgb(255 255 255 / 58%);
  --passcode-key-pressed: rgb(255 255 255 / 24%);
  position: absolute;
  inset: 0;
  z-index: 90;
  overflow: hidden;
  color: var(--passcode-text);
  background-color: #080b12;
  background-position: center;
  background-size: cover;
  outline: none;
  font-family: var(--sky-font-family);
  user-select: none;
}

.passcode-screen--surface {
  background-image:
    radial-gradient(circle at 50% 16%, rgb(76 92 132 / 46%), transparent 35%),
    linear-gradient(160deg, #182139, #080b12 72%);
}

.passcode-screen--lock {
  background-color: #090a0d;
}

.passcode-screen__backdrop {
  position: absolute;
  inset: -16px;
  z-index: 0;
  background: linear-gradient(180deg, rgb(0 0 0 / 32%), rgb(0 0 0 / 48%));
  backdrop-filter: blur(18px) saturate(0.76);
  -webkit-backdrop-filter: blur(18px) saturate(0.76);
}

.passcode-screen--surface .passcode-screen__backdrop {
  background: rgb(0 0 0 / 8%);
  backdrop-filter: none;
  -webkit-backdrop-filter: none;
}

.passcode-screen :deep(.phone-status-bar) {
  color: #fff;
}

.passcode-screen__layout {
  position: relative;
  z-index: 1;
  width: 100%;
  height: 100%;
  padding: 116px 28px 34px;
}

.passcode-screen__header {
  width: 100%;
  text-align: center;
}

.passcode-screen__header h1 {
  margin: 0;
  font-size: 19px;
  font-weight: 430;
  letter-spacing: -0.015em;
  text-shadow: 0 1px 8px rgb(0 0 0 / 36%);
}

.passcode-screen__header p {
  max-width: 270px;
  margin: 7px auto 0;
  color: var(--passcode-muted);
  font-size: 13px;
  line-height: 1.4;
  text-shadow: 0 1px 6px rgb(0 0 0 / 30%);
}

.passcode-screen--lock
  .passcode-screen__header
  > p:not(.passcode-screen__error) {
  display: none;
}

.passcode-screen__dots {
  display: flex;
  justify-content: center;
  gap: 22px;
  margin-top: 29px;
}

.passcode-screen__dots span {
  width: 12px;
  height: 12px;
  border: 1.25px solid currentColor;
  border-radius: 50%;
  background: transparent;
  box-shadow: 0 1px 4px rgb(0 0 0 / 25%);
  transition:
    background-color var(--sky-transition-fast) ease,
    transform var(--sky-transition-fast) ease;
}

.passcode-screen__dots .passcode-screen__dot--filled {
  background: currentColor;
  transform: scale(1.08);
}

.passcode-screen__header .passcode-screen__error {
  min-height: 18px;
  color: #ffb4ae;
  font-weight: 570;
}

.passcode-screen__keypad {
  display: grid;
  grid-template-columns: repeat(3, 80px);
  gap: 14px 24px;
  align-items: center;
  justify-items: center;
  width: max-content;
  margin: 48px auto 0;
}

.passcode-screen__key {
  display: flex;
  width: 80px;
  height: 80px;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  border: 1.25px solid var(--passcode-key-border);
  border-radius: 50%;
  padding: 0;
  color: inherit;
  background: var(--passcode-key-background);
  box-shadow: 0 1px 5px rgb(0 0 0 / 12%);
  cursor: pointer;
  transition:
    background-color var(--sky-transition-fast) ease,
    transform var(--sky-transition-fast) ease;
}

.passcode-screen__key span {
  font-size: 32px;
  font-weight: 320;
  line-height: 32px;
  letter-spacing: -0.025em;
}

.passcode-screen__key small {
  min-height: 11px;
  margin-top: 3px;
  font-size: 9px;
  font-weight: 650;
  line-height: 9px;
  letter-spacing: 0.22em;
}

.passcode-screen__key--single span {
  transform: translateY(1px);
}

.passcode-screen__key:active {
  background: var(--passcode-key-pressed);
  transform: scale(0.96);
}

.passcode-screen__keypad button:disabled {
  cursor: default;
  opacity: 0.42;
}

.passcode-screen__footer {
  position: absolute;
  right: 28px;
  bottom: 35px;
  left: 28px;
  display: grid;
  grid-template-columns: 1fr 1fr;
  align-items: center;
}

.passcode-screen__action {
  display: flex;
  align-items: center;
  justify-content: center;
  justify-self: end;
  min-width: 96px;
  min-height: var(--sky-touch-target);
  border: 0;
  border-radius: var(--sky-radius-pill);
  padding: 0 8px;
  color: inherit;
  background: transparent;
  font-size: 15px;
  font-weight: 430;
  cursor: pointer;
  text-shadow: 0 1px 5px rgb(0 0 0 / 30%);
}

.passcode-screen__action:active:not(:disabled) {
  background: rgb(255 255 255 / 12%);
}

:global(.phone-app--light) .passcode-screen--surface {
  --passcode-text: #111;
  --passcode-muted: rgb(0 0 0 / 55%);
  --passcode-key-background: transparent;
  --passcode-key-border: rgb(0 0 0 / 32%);
  --passcode-key-pressed: rgb(0 0 0 / 12%);
  background-color: #f2f2f7;
  background-image:
    radial-gradient(circle at 50% 18%, rgb(188 211 255 / 72%), transparent 38%),
    linear-gradient(160deg, #f8f8fb, #e8e8ee 72%);
}

@media (prefers-reduced-motion: reduce) {
  .passcode-screen__dots span,
  .passcode-screen__key {
    transition: none;
  }
}
</style>
