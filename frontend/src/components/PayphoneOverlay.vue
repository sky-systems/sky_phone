<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref } from 'vue'

import payphoneFrame from '@/assets/img/payphone/american-payphone-frame.png'
import { nuiCall } from '@/utils/nui'
import { registerPhoneMediaElement } from '@/utils/phoneAudio'
import { isTrustedRootMessageSource } from '@/utils/windowMessages'

type PayphoneState =
  | 'idle'
  | 'dialing'
  | 'ringing'
  | 'connected'
  | 'completed'
  | 'cancelled'
  | 'declined'
  | 'busy'
  | 'unavailable'
  | 'no_answer'
  | 'disconnected'
  | 'insufficient_funds'

type PayphoneLocales = Record<string, string>

type PayphoneCall = {
  answeredAt?: number
  elapsedSeconds?: number
  id: string
  otherNumber: string
  state: PayphoneState
  totalCost?: number
}

type PayphoneOpenPayload = {
  currency: string
  locales: PayphoneLocales
  maxNumberLength: number
  pricePerSecond: number
}

const keypad = [
  { digit: '1', letters: '' },
  { digit: '2', letters: 'ABC' },
  { digit: '3', letters: 'DEF' },
  { digit: '4', letters: 'GHI' },
  { digit: '5', letters: 'JKL' },
  { digit: '6', letters: 'MNO' },
  { digit: '7', letters: 'PQRS' },
  { digit: '8', letters: 'TUV' },
  { digit: '9', letters: 'WXYZ' },
  { digit: '*', letters: '' },
  { digit: '0', letters: '+' },
  { digit: '#', letters: '' },
]

const visible = ref(false)
const number = ref('')
const state = ref<PayphoneState>('idle')
const call = ref<PayphoneCall | null>(null)
const locales = ref<PayphoneLocales>({})
const currency = ref('$')
const pricePerSecond = ref(0)
const maxNumberLength = ref(10)
const input = ref<HTMLInputElement | null>(null)
const now = ref(Date.now())
const statusOverride = ref('')
let ticker: number | undefined
let buttonSoundIndex = 0
const buttonSounds: HTMLAudioElement[] = []

function prepareButtonSounds(): void {
  if (buttonSounds.length) return
  for (let index = 0; index < 4; index += 1) {
    const sound = registerPhoneMediaElement(
      new Audio(`${import.meta.env.BASE_URL}sounds/button.mp3`),
    )
    sound.preload = 'auto'
    sound.volume = 0.55
    buttonSounds.push(sound)
  }
}

function playButtonSound(): void {
  prepareButtonSounds()
  const sound = buttonSounds[buttonSoundIndex]
  buttonSoundIndex = (buttonSoundIndex + 1) % buttonSounds.length
  sound.currentTime = 0
  const playback = sound.play()
  if (playback) void playback.catch(() => undefined)
}

const active = computed(() =>
  ['dialing', 'ringing', 'connected'].includes(state.value),
)
const elapsedSeconds = computed(() => {
  const serverElapsed = call.value?.elapsedSeconds ?? 0
  if (state.value !== 'connected' || !call.value?.answeredAt)
    return serverElapsed
  return Math.max(
    serverElapsed,
    Math.floor(now.value / 1000 - call.value.answeredAt),
  )
})
const totalCost = computed(() => elapsedSeconds.value * pricePerSecond.value)
const rateText = computed(() =>
  text('rate')
    .replace('{currency}', currency.value)
    .replace('{price}', String(pricePerSecond.value)),
)
const statusText = computed(() => {
  if (statusOverride.value) return statusOverride.value
  const key: Record<PayphoneState, string> = {
    busy: 'busy',
    cancelled: 'callEnded',
    completed: 'callEnded',
    connected: 'connected',
    declined: 'declined',
    dialing: 'dialing',
    disconnected: 'disconnected',
    idle: 'ready',
    insufficient_funds: 'insufficientFunds',
    no_answer: 'noAnswer',
    ringing: 'ringing',
    unavailable: 'unavailable',
  }
  return text(key[state.value])
})

function text(key: string): string {
  return locales.value[key] ?? ''
}

function formatDuration(seconds: number): string {
  const minutes = Math.floor(seconds / 60)
  return `${String(minutes).padStart(2, '0')}:${String(seconds % 60).padStart(2, '0')}`
}

function appendDigit(digit: string): void {
  if (active.value || !/^\d$/.test(digit)) return
  playButtonSound()
  statusOverride.value = ''
  state.value = 'idle'
  call.value = null
  number.value = `${number.value}${digit}`.slice(0, maxNumberLength.value)
  input.value?.focus()
}

function deleteDigit(): void {
  if (active.value || !number.value) return
  playButtonSound()
  statusOverride.value = ''
  state.value = 'idle'
  call.value = null
  number.value = number.value.slice(0, -1)
  input.value?.focus()
}

function clearNumber(): void {
  if (active.value || !number.value) return
  playButtonSound()
  statusOverride.value = ''
  state.value = 'idle'
  call.value = null
  number.value = ''
  input.value?.focus()
}

function sanitizeNumber(): void {
  statusOverride.value = ''
  state.value = 'idle'
  call.value = null
  number.value = number.value.replace(/\D/g, '').slice(0, maxNumberLength.value)
}

function applyCall(nextCall: PayphoneCall): void {
  statusOverride.value = ''
  call.value = nextCall
  state.value = nextCall.state
  if (nextCall.otherNumber) number.value = nextCall.otherNumber
}

async function dial(): Promise<void> {
  if (active.value || !number.value) return
  playButtonSound()
  state.value = 'dialing'
  const response = await nuiCall<PayphoneCall>('payphone:dial', {
    phoneNumber: number.value,
  })
  if (response.success && response.data) {
    applyCall(response.data)
    return
  }
  call.value = null
  const errorStates: Record<string, PayphoneState> = {
    busy: 'busy',
    insufficient_funds: 'insufficient_funds',
    invalid_number: 'idle',
    voice_unavailable: 'disconnected',
  }
  state.value = errorStates[response.error ?? ''] ?? 'disconnected'
  if (response.error === 'invalid_number')
    statusOverride.value = text('invalidNumber')
  else if (response.error === 'voice_unavailable')
    statusOverride.value = text('voiceUnavailable')
  else if (!errorStates[response.error ?? ''])
    statusOverride.value = text('requestFailed')
}

async function hangup(): Promise<void> {
  if (!call.value || !['ringing', 'connected'].includes(state.value)) return
  playButtonSound()
  await nuiCall('payphone:hangup')
}

async function close(): Promise<void> {
  playButtonSound()
  await nuiCall('payphone:close')
}

function onMessage(event: MessageEvent): void {
  if (!isTrustedRootMessageSource(event.source, window)) return
  if (event.data?.type === 'payphone:open' && event.data.data) {
    const payload = event.data.data as PayphoneOpenPayload
    currency.value = payload.currency
    locales.value = { ...payload.locales }
    maxNumberLength.value = payload.maxNumberLength
    pricePerSecond.value = payload.pricePerSecond
    number.value = ''
    call.value = null
    state.value = 'idle'
    statusOverride.value = ''
    visible.value = true
    void nextTick(() => input.value?.focus())
  } else if (event.data?.type === 'payphone:state' && event.data.data) {
    applyCall(event.data.data as PayphoneCall)
  } else if (event.data?.type === 'payphone:close') {
    visible.value = false
  }
}

function onKeydown(event: KeyboardEvent): void {
  if (!visible.value) return
  if (event.key === 'Escape') {
    event.preventDefault()
    event.stopImmediatePropagation()
    void close()
    return
  }
  if (event.key === 'Enter') {
    event.preventDefault()
    if (active.value) void hangup()
    else void dial()
    return
  }
  if (event.target === input.value) return
  if (/^\d$/.test(event.key)) appendDigit(event.key)
  else if (event.key === 'Backspace') deleteDigit()
}

onMounted(() => {
  prepareButtonSounds()
  window.addEventListener('message', onMessage)
  window.addEventListener('keydown', onKeydown, true)
  ticker = window.setInterval(() => {
    now.value = Date.now()
  }, 250)
})

onBeforeUnmount(() => {
  window.removeEventListener('message', onMessage)
  window.removeEventListener('keydown', onKeydown, true)
  if (ticker !== undefined) window.clearInterval(ticker)
  for (const sound of buttonSounds) {
    sound.pause()
    sound.src = ''
  }
  buttonSounds.length = 0
})
</script>

<template>
  <Transition name="payphone-fade">
    <div v-if="visible" class="payphone-overlay">
      <section class="payphone-console" :aria-label="text('title')">
        <img
          class="payphone-console__frame"
          :src="payphoneFrame"
          alt=""
          aria-hidden="true"
          draggable="false"
        />
        <button
          type="button"
          class="payphone-console__close"
          :aria-label="text('close')"
          @click="close"
        >
          ×
        </button>
        <div class="payphone-display">
          <header class="payphone-console__header">
            <span class="payphone-console__signal" aria-hidden="true"></span>
            <div>
              <strong>{{ text('title') }}</strong>
              <small>{{ text('subtitle') }}</small>
            </div>
          </header>
          <div class="payphone-display__topline">
            <span>{{ statusText }}</span>
            <b>{{ rateText }}</b>
          </div>
          <label for="payphone-number">{{ text('numberLabel') }}</label>
          <div class="payphone-number-row">
            <input
              id="payphone-number"
              ref="input"
              v-model="number"
              :aria-label="text('numberLabel')"
              :disabled="active"
              :maxlength="maxNumberLength"
              :placeholder="text('numberPlaceholder')"
              autocomplete="off"
              inputmode="numeric"
              type="text"
              @input="sanitizeNumber"
            />
            <button
              type="button"
              :aria-label="text('delete')"
              :disabled="active || !number"
              @click="deleteDigit"
            >
              ⌫
            </button>
          </div>
          <div v-if="state === 'connected'" class="payphone-meter">
            <span
              ><small>{{ text('elapsed') }}</small
              >{{ formatDuration(elapsedSeconds) }}</span
            >
            <span
              ><small>{{ text('cost') }}</small
              >{{ currency }}{{ totalCost }}</span
            >
          </div>
        </div>

        <div class="payphone-keypad" :aria-label="text('keypad')">
          <button
            v-for="key in keypad"
            :key="key.digit"
            type="button"
            :disabled="active || !/^\d$/.test(key.digit)"
            @click="appendDigit(key.digit)"
          >
            <strong>{{ key.digit }}</strong>
            <small>{{ key.letters }}</small>
          </button>
        </div>

        <footer class="payphone-actions">
          <button
            v-if="state === 'ringing' || state === 'connected'"
            type="button"
            class="payphone-action payphone-action--hangup"
            @click="hangup"
          >
            <span aria-hidden="true">☎</span>{{ text('hangup') }}
          </button>
          <button
            v-else
            type="button"
            class="payphone-action payphone-action--call"
            :disabled="state === 'dialing' || !number"
            @click="dial"
          >
            <span aria-hidden="true">☎</span>{{ text('call') }}
          </button>
          <button
            type="button"
            class="payphone-action payphone-action--clear"
            :disabled="active || !number"
            @click="clearNumber"
          >
            {{ text('clear') }}
          </button>
        </footer>
      </section>
    </div>
  </Transition>
</template>

<style scoped>
.payphone-overlay {
  position: fixed;
  z-index: 10000;
  inset: 0;
  display: grid;
  place-items: center;
  background: radial-gradient(
    circle at 50% 44%,
    rgb(30 38 42 / 35%),
    rgb(0 0 0 / 84%) 72%
  );
  font-family: var(--sky-font-family);
  pointer-events: auto;
  user-select: none;
}

.payphone-console {
  position: relative;
  width: min(640px, 62vh, 94vw);
  aspect-ratio: 2 / 3;
  overflow: hidden;
  filter: drop-shadow(0 34px 44px rgb(0 0 0 / 68%));
  color: #e8edf0;
}

.payphone-console__frame {
  position: absolute;
  z-index: 0;
  inset: -0.8%;
  width: 101.6%;
  height: 101.6%;
  object-fit: contain;
  pointer-events: none;
}

.payphone-console__header {
  display: grid;
  grid-template-columns: 8px 1fr;
  align-items: center;
  gap: 7px;
  margin-bottom: 4%;
  color: #9fbcaa;
  font-family: 'Courier New', monospace;
  pointer-events: none;
}

.payphone-console__header strong,
.payphone-console__header small {
  display: block;
}

.payphone-console__header strong {
  overflow: hidden;
  font-size: clamp(8px, 1.15vw, 12px);
  letter-spacing: 0.11em;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.payphone-console__header small {
  color: rgb(159 188 170 / 65%);
  font-size: clamp(6px, 0.78vw, 8px);
  letter-spacing: 0.14em;
}

.payphone-number-row button {
  border: 0;
  color: #cbd4d8;
  background: transparent;
  cursor: pointer;
}

.payphone-console__close {
  position: absolute;
  z-index: 5;
  top: 4.1%;
  right: 4.4%;
  display: grid;
  width: clamp(25px, 4.7vw, 34px);
  aspect-ratio: 1;
  padding: 0;
  place-items: center;
  border: 1px solid rgb(255 255 255 / 22%);
  border-radius: 50%;
  background: linear-gradient(#41494d, #161c1f);
  box-shadow:
    0 2px 4px rgb(0 0 0 / 70%),
    inset 0 1px 0 rgb(255 255 255 / 18%);
  color: #d8dddf;
  font-size: clamp(18px, 3vw, 25px);
  line-height: 1;
  cursor: pointer;
}

.payphone-console__close:hover {
  filter: brightness(1.25);
}

.payphone-console__signal {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: #62dd91;
  box-shadow: 0 0 8px #62dd91;
}

.payphone-display {
  position: absolute;
  z-index: 2;
  top: 22.7%;
  left: 33.5%;
  width: 54.3%;
  height: 17.3%;
  padding: 3.4%;
  overflow: hidden;
  border-radius: 6px;
  background:
    linear-gradient(155deg, rgb(132 162 143 / 92%), rgb(70 99 81 / 94%)),
    #75927f;
  box-shadow: inset 0 0 18px rgb(5 18 10 / 48%);
  color: #10261a;
  font-family: 'Courier New', monospace;
}

.payphone-display__topline,
.payphone-meter {
  display: flex;
  justify-content: space-between;
  gap: 16px;
}

.payphone-display__topline {
  font-size: clamp(7px, 1vw, 10px);
  font-weight: 800;
  letter-spacing: 0.08em;
}

.payphone-display label {
  display: block;
  margin-top: 4%;
  font-size: clamp(6px, 0.82vw, 8px);
  font-weight: 700;
  letter-spacing: 0.1em;
}

.payphone-number-row {
  display: grid;
  grid-template-columns: 1fr 38px;
  align-items: center;
}

.payphone-number-row input {
  width: 100%;
  padding: 1.8% 0 0;
  border: 0;
  outline: 0;
  color: #10261a;
  background: transparent;
  caret-color: #10261a;
  font:
    700 clamp(15px, 2.7vw, 25px) / 1.05 'Courier New',
    monospace;
  letter-spacing: 0.055em;
}

.payphone-number-row input::placeholder {
  color: rgb(27 48 36 / 45%);
  font-size: clamp(9px, 1.5vw, 14px);
  letter-spacing: 0;
}

.payphone-number-row button {
  color: #1b3024;
  font-size: clamp(14px, 2.2vw, 20px);
}

.payphone-meter {
  margin-top: 2%;
  padding-top: 2%;
  border-top: 1px solid rgb(27 48 36 / 24%);
}

.payphone-meter span {
  font-size: clamp(9px, 1.45vw, 14px);
  font-weight: 800;
}

.payphone-meter small {
  margin-right: 5px;
  font-size: clamp(6px, 0.75vw, 8px);
  letter-spacing: 0.08em;
}

.payphone-keypad {
  position: absolute;
  z-index: 2;
  top: 44.7%;
  left: 35.3%;
  width: 50.9%;
  height: 29%;
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  grid-template-rows: repeat(4, 1fr);
  gap: 2.8% 3.2%;
  padding: 0;
}

.payphone-keypad button {
  min-width: 0;
  min-height: 0;
  padding: 0;
  border: 1px solid #080c0e;
  border-radius: 8%;
  background:
    linear-gradient(145deg, rgb(255 255 255 / 26%), transparent 32%),
    linear-gradient(#d7ddde, #899499);
  box-shadow:
    0 3px 0 #070b0d,
    inset 0 1px 0 #fff;
  color: #172126;
  cursor: pointer;
}

.payphone-keypad button:hover:not(:disabled) {
  filter: brightness(1.1);
}

.payphone-keypad button:active:not(:disabled) {
  box-shadow: 0 1px 0 #10171a;
  transform: translateY(2px);
}

.payphone-keypad strong,
.payphone-keypad small {
  display: block;
}

.payphone-keypad strong {
  font-size: clamp(15px, 2.7vw, 24px);
  line-height: 1;
}

.payphone-keypad small {
  min-height: 8px;
  margin-top: 2px;
  color: #586368;
  font-size: clamp(5px, 0.78vw, 8px);
  font-weight: 800;
  letter-spacing: 0.16em;
}

.payphone-keypad button:disabled {
  cursor: default;
  opacity: 0.68;
}

.payphone-actions {
  position: absolute;
  z-index: 2;
  top: 75.6%;
  left: 35.3%;
  width: 50.9%;
  height: 5.9%;
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 3.2%;
}

.payphone-action {
  min-width: 0;
  min-height: 0;
  padding: 0 clamp(7px, 1.7vw, 16px);
  border: 1px solid rgb(0 0 0 / 52%);
  border-radius: 7px;
  box-shadow:
    inset 0 1px 0 rgb(255 255 255 / 22%),
    0 3px 0 #101518;
  color: white;
  font-size: clamp(7px, 1.15vw, 11px);
  font-weight: 800;
  letter-spacing: 0.11em;
  cursor: pointer;
}

.payphone-action span {
  display: inline-block;
  margin-right: 6px;
  font-size: clamp(11px, 1.8vw, 17px);
  transform: rotate(-22deg);
}

.payphone-action--call {
  grid-column: span 2;
  background: linear-gradient(#3dbd74, #187c43);
}

.payphone-action--hangup {
  grid-column: span 2;
  background: linear-gradient(#e95c55, #a12420);
}

.payphone-action--clear {
  color: #cbd4d8;
  background: linear-gradient(#465158, #283238);
}

.payphone-action:disabled {
  cursor: default;
  filter: grayscale(0.5);
  opacity: 0.45;
}

.payphone-fade-enter-active,
.payphone-fade-leave-active {
  transition: opacity 180ms ease;
}

.payphone-fade-enter-active .payphone-console,
.payphone-fade-leave-active .payphone-console {
  transition: transform 220ms cubic-bezier(0.2, 0.8, 0.2, 1);
}

.payphone-fade-enter-from,
.payphone-fade-leave-to {
  opacity: 0;
}

.payphone-fade-enter-from .payphone-console,
.payphone-fade-leave-to .payphone-console {
  transform: translateY(18px) scale(0.96);
}
</style>
