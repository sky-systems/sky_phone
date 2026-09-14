<script setup lang="ts">
import { onBeforeUnmount, ref, onMounted, computed, watch, nextTick } from 'vue'
import { Radio, Eye, Send, SwitchCamera, Mic, MicOff, X } from 'lucide-vue-next'
import { usePhoneStore } from '@/stores/phone'
import { useRealtimeStore } from '@/features/realtime/store'
import type { LiveApp, LiveEntry } from '@/features/realtime/types'
import {
  SkyButton,
  SkySheet,
  SkyGlass,
  SkyProvider,
  SkySpinner,
  SkyMessagebar,
} from '@/ui'
import RealtimeVideo from './RealtimeVideo.vue'
const props = withDefaults(
  defineProps<{
    app: LiveApp
    hideTrigger?: boolean
    reserveNavigation?: boolean
  }>(),
  { hideTrigger: false },
)
const phone = usePhoneStore()
const realtime = useRealtimeStore()
const opened = ref(false)

const draft = ref('')
const sending = ref(false)
const chatEnd = ref<HTMLElement | null>(null)
const entries = ref<LiveEntry[]>([])
const current = computed(() =>
  realtime.room?.app === props.app ? realtime.room : null,
)
const enabled = computed(
  () => realtime.config?.enabled && realtime.config[props.app],
)
let previousStatusBar: boolean | null = null
let ownsStatusBar = false
function releaseStatusBar(): void {
  if (ownsStatusBar) phone.appStatusBarLight = previousStatusBar
  ownsStatusBar = false
}
watch(
  () => opened.value && Boolean(current.value),
  (active) => {
    if (active) {
      if (!ownsStatusBar) previousStatusBar = phone.appStatusBarLight
      ownsStatusBar = true
      phone.appStatusBarLight = true
    } else releaseStatusBar()
  },
  { flush: 'post' },
)
onBeforeUnmount(releaseStatusBar)
const validMessage = computed(
  () =>
    [...draft.value.trim()].length > 0 && [...draft.value.trim()].length <= 300,
)
const t = (key: string) => phone.t(`Realtime.${key}`)
let timer: number | undefined
async function open(id?: string): Promise<void> {
  opened.value = true
  if (id) {
    if (current.value?.id !== id) await realtime.watchLive(id)
  } else entries.value = await realtime.list(props.app)
}
defineExpose({ open })
function close(): void {
  opened.value = false
  if (current.value) realtime.stop()
}
async function send(): Promise<void> {
  if (!validMessage.value || sending.value) return
  sending.value = true
  try {
    if (await realtime.chat(draft.value.trim())) draft.value = ''
  } finally {
    sending.value = false
  }
}
function onKey(event: KeyboardEvent): void {
  if (event.key === 'Enter' && !event.shiftKey && !event.isComposing) {
    event.preventDefault()
    void send()
  }
}
watch(
  () => current.value?.messages?.at(-1)?.id,
  async () => {
    await nextTick()
    const chat = chatEnd.value?.parentElement
    if (chat) chat.scrollTop = chat.scrollHeight
  },
)
onMounted(async () => {
  await realtime.refreshConfig()
  timer = window.setInterval(async () => {
    if (opened.value && !current.value)
      entries.value = await realtime.list(props.app)
  }, 10000)
})
onBeforeUnmount(() => {
  clearInterval(timer)
  if (opened.value && current.value) realtime.stop()
})
</script>
<template>
  <slot v-if="enabled && !hideTrigger" name="trigger" :open="open">
    <SkyButton clear inline class="live-entry" @click="open()"
      ><Radio :size="18" />{{ t('live') }}</SkyButton
    >
  </slot>
  <SkySheet
    class="live-broadcast-sheet"
    :class="{
      'live-broadcast-sheet--active': current,
      'live-broadcast-sheet--navigation': reserveNavigation,
    }"
    :show-grabber="false"
    :opened="opened"
    :aria-label="t('live')"
    @backdropclick="close"
    @escape="close"
    @swipeclose="close"
    @grabberclick="close"
  >
    <SkyProvider
      :dark="Boolean(current) || phone.isDarkMode"
      component="section"
      class="live-broadcast"
      :class="{
        'live-broadcast--active': current,
        'live-broadcast--fliptok': app === 'fliptok',
      }"
    >
      <template v-if="current">
        <div class="live-broadcast__video">
          <RealtimeVideo
            v-if="current.role === 'host'"
            :stream="realtime.localStream"
            muted
          />
          <RealtimeVideo
            v-for="[id, stream] in realtime.streams"
            :key="id"
            :stream="stream"
          />
        </div>
        <header class="live-broadcast__top">
          <SkyGlass class="live-broadcast__host">
            <span class="live-broadcast__avatar"
              ><img
                v-if="current.hostAvatar"
                :src="current.hostAvatar"
                alt=""
              /><span v-else>{{ current.hostName?.slice(0, 1) }}</span></span
            >
            <span
              ><strong>{{ current.hostName }}</strong
              ><small>{{
                current.role === 'host'
                  ? t('onAir')
                  : phone.t(`Apps.${app}.name`)
              }}</small></span
            >
          </SkyGlass>
          <SkyButton
            glass
            rounded
            icon-only
            :aria-label="t(current.role === 'host' ? 'endLive' : 'leave')"
            @click="close"
            ><X :size="22"
          /></SkyButton>
        </header>
        <div class="live-broadcast__badges">
          <span class="live-broadcast__badge"
            ><span></span>{{ t('live') }}</span
          >
          <SkyGlass class="live-broadcast__viewers"
            ><Eye :size="15" /><span>{{ current.viewers }}</span
            ><span class="live-broadcast__sr">{{
              t('viewers')
            }}</span></SkyGlass
          >
        </div>
        <p
          v-if="!realtime.streams.size && current.role === 'viewer'"
          class="live-broadcast__connecting"
          role="status"
        >
          <SkySpinner :size="22" />{{ t('connecting') }}
        </p>
        <div class="live-broadcast__bottom">
          <div class="live-broadcast__identity">
            <div>
              <strong>{{
                app === 'fliptok'
                  ? current.description || current.title
                  : current.title
              }}</strong>
              <p v-if="app === 'picstagram' && current.description">
                {{ current.description }}
              </p>
            </div>
            <div
              v-if="current.role === 'host'"
              class="live-broadcast__controls"
            >
              <SkyButton
                glass
                rounded
                icon-only
                :aria-label="t('flip')"
                @click="realtime.flip"
                ><SwitchCamera :size="21"
              /></SkyButton>
              <SkyButton
                glass
                rounded
                icon-only
                :aria-label="t(realtime.muted ? 'unmute' : 'mute')"
                :aria-pressed="realtime.muted"
                @click="realtime.setMuted(!realtime.muted)"
                ><component :is="realtime.muted ? MicOff : Mic" :size="21"
              /></SkyButton>
            </div>
          </div>
          <div
            class="live-broadcast__chat"
            role="log"
            aria-live="polite"
            :aria-label="t('chat')"
          >
            <p
              v-if="!current.messages?.length"
              class="live-broadcast__empty-chat"
            >
              {{ t('chatEmpty') }}
            </p>
            <div
              v-for="message in current.messages"
              :key="message.id"
              class="live-broadcast__comment"
            >
              <span class="live-broadcast__comment-avatar">{{
                message.name.slice(0, 1)
              }}</span>
              <div>
                <strong
                  >{{ message.name
                  }}<small v-if="message.host">{{ t('host') }}</small></strong
                >
                <p>{{ message.text }}</p>
              </div>
            </div>
            <span ref="chatEnd" />
          </div>
          <SkyGlass class="live-broadcast__composer">
            <SkyMessagebar
              v-model="draft"
              embedded
              :aria-label="t('message')"
              :placeholder="t('message')"
              :disabled="sending"
              @keydown="onKey"
            >
              <template #right
                ><SkyButton
                  clear
                  icon-only
                  :aria-label="t('send')"
                  :disabled="sending || !validMessage"
                  @click="send"
                  ><Send :size="20" /></SkyButton
              ></template>
            </SkyMessagebar>
          </SkyGlass>
          <small v-if="[...draft].length > 300" role="alert">{{
            t('messageLimit')
          }}</small>
        </div>
      </template>
      <template v-else>
        <header class="live-broadcast__directory-header">
          <strong>{{ phone.t(`Apps.${app}.name`) }} · {{ t('live') }}</strong
          ><SkyButton
            glass
            rounded
            icon-only
            :aria-label="phone.t('Common.close')"
            @click="close"
            ><X :size="20"
          /></SkyButton>
        </header>
        <div class="live-broadcast__directory">
          <p>{{ t('startViaPlus') }}</p>
          <p v-if="!entries.length">{{ t('noLive') }}</p>
          <SkyButton
            v-for="entry in entries"
            :key="entry.id"
            glass
            rounded
            :disabled="realtime.busy"
            @click="realtime.watchLive(entry.id)"
            >{{ entry.hostName }} · {{ entry.title || t('live') }} ·
            {{ entry.viewers }} {{ t('viewers') }}</SkyButton
          >
        </div>
      </template>
      <p v-if="realtime.error" class="live-broadcast__error" role="alert">
        {{
          phone.t('Realtime.errors.' + realtime.error) ===
          'Realtime.errors.' + realtime.error
            ? t('errors.default')
            : phone.t('Realtime.errors.' + realtime.error)
        }}
      </p>
    </SkyProvider>
  </SkySheet>
</template>
<style scoped>
.live-entry {
  flex-shrink: 0;
  gap: var(--sky-space-1);
}
.live-broadcast-sheet {
  bottom: 0;
}
.live-broadcast-sheet--navigation {
  bottom: calc(var(--sky-safe-area-bottom) + var(--sky-tabbar-height) + 18px);
}
.live-broadcast-sheet :deep(.sky-sheet__panel) {
  max-height: 100%;
}
.live-broadcast-sheet--active :deep(.sky-sheet__panel) {
  height: 100%;
  overflow: hidden;
}
.live-broadcast {
  position: relative;
  display: flex;
  flex-direction: column;
  gap: var(--sky-space-3);
  padding: var(--sky-space-4);
  max-height: 90cqh;
  border-radius: inherit;
  overflow: hidden;
  color: var(--sky-text);
  background: var(--sky-surface);
}
.live-broadcast--active {
  height: 100%;
  box-sizing: border-box;
  max-height: none;
  padding-top: calc(var(--sky-safe-area-top) + var(--sky-space-4));
  padding-bottom: calc(var(--sky-safe-area-bottom) + var(--sky-space-4));
  background: var(--sky-action-surface);
}
.live-broadcast__video {
  position: absolute;
  inset: 0;
}
.live-broadcast__video video {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.live-broadcast--active::before {
  content: '';
  position: absolute;
  z-index: 1;
  inset: 0;
  pointer-events: none;
  background: linear-gradient(
    180deg,
    var(--sky-overlay-backdrop),
    transparent 32%,
    var(--sky-overlay-backdrop) 65%,
    var(--sky-action-surface)
  );
}
.live-broadcast__top,
.live-broadcast__badges,
.live-broadcast__bottom {
  position: relative;
  z-index: 2;
}
.live-broadcast__top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--sky-space-3);
}
.live-broadcast__host {
  display: flex;
  align-items: center;
  gap: var(--sky-space-2);
  padding: var(--sky-space-2) var(--sky-space-3) var(--sky-space-2)
    var(--sky-space-2);
  border-radius: var(--sky-radius-pill);
  background: var(--sky-glass);
  min-width: 0;
}
.live-broadcast__avatar {
  flex-shrink: 0;
  display: grid;
  place-items: center;
  width: var(--sky-touch-target);
  height: var(--sky-touch-target);
  border: 2px solid var(--sky-danger);
  border-radius: var(--sky-radius-pill);
  background: var(--sky-surface-variant);
  overflow: hidden;
}
.live-broadcast__avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.live-broadcast__host > span:last-child {
  min-width: 0;
  display: grid;
  gap: var(--sky-space-1);
}
.live-broadcast__host strong {
  font-size: var(--sky-font-body);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.live-broadcast__host small {
  font-size: var(--sky-font-caption);
  color: var(--sky-muted);
}
.live-broadcast__top > .sky-button {
  flex-shrink: 0;
  color: var(--sky-text);
}
.live-broadcast__badges {
  display: flex;
  align-items: center;
  gap: var(--sky-space-2);
}
.live-broadcast__badge,
.live-broadcast__viewers {
  display: flex;
  align-items: center;
  gap: var(--sky-space-1);
  border-radius: var(--sky-radius-pill);
  padding: var(--sky-space-1) var(--sky-space-2);
  font-size: var(--sky-font-caption);
  font-weight: 650;
}
.live-broadcast__badge {
  background: var(--sky-danger);
  color: var(--sky-text);
}
.live-broadcast__badge > span {
  width: 5px;
  height: 5px;
  border-radius: var(--sky-radius-pill);
  background: currentColor;
}
.live-broadcast__viewers {
  background: var(--sky-glass);
  font-variant-numeric: tabular-nums;
}
.live-broadcast__connecting {
  position: absolute;
  z-index: 2;
  top: 43%;
  left: 0;
  right: 0;
  display: flex;
  justify-content: center;
  align-items: center;
  gap: var(--sky-space-2);
  font-size: var(--sky-font-caption);
}
.live-broadcast__bottom {
  margin-top: auto;
  display: flex;
  flex-direction: column;
  gap: var(--sky-space-3);
  min-height: 0;
}
.live-broadcast__identity {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: var(--sky-space-3);
}
.live-broadcast__identity > div:first-child {
  min-width: 0;
}
.live-broadcast__identity strong {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  font-size: var(--sky-font-title);
  text-align: left;
}
.live-broadcast__identity p {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  margin: var(--sky-space-1) 0 0;
  font-size: var(--sky-font-caption);
  color: var(--sky-muted);
}
.live-broadcast__controls {
  display: flex;
  gap: var(--sky-space-2);
  flex-shrink: 0;
}
.live-broadcast__controls .sky-button {
  color: var(--sky-text);
}
.live-broadcast__controls .sky-button[aria-pressed='true'] {
  color: var(--sky-danger);
}
.live-broadcast__chat {
  height: 22cqh;
  min-height: 64px;
  overflow-y: auto;
  overscroll-behavior: contain;
  scrollbar-width: none;
  padding-top: var(--sky-space-2);
}
.live-broadcast__comment {
  display: flex;
  align-items: flex-start;
  gap: var(--sky-space-2);
  margin-bottom: var(--sky-space-3);
  text-align: left;
}
.live-broadcast__comment-avatar {
  display: grid;
  place-items: center;
  flex-shrink: 0;
  width: 28px;
  height: 28px;
  border-radius: var(--sky-radius-pill);
  background: var(--sky-glass);
  font-size: var(--sky-font-caption);
}
.live-broadcast__comment > div {
  min-width: 0;
}
.live-broadcast__comment strong {
  display: flex;
  align-items: center;
  gap: var(--sky-space-2);
  font-size: var(--sky-font-caption);
  color: var(--sky-muted);
}
.live-broadcast__comment strong small {
  padding: 1px var(--sky-space-1);
  border-radius: var(--sky-radius-control);
  background: var(--sky-glass);
  color: var(--sky-text);
}
.live-broadcast__comment p {
  margin: 2px 0 0;
  font-size: var(--sky-font-caption);
  line-height: 1.4;
  overflow-wrap: anywhere;
}
.live-broadcast__empty-chat {
  font-size: var(--sky-font-caption);
  color: var(--sky-muted);
}
.live-broadcast__composer {
  border-radius: var(--sky-radius-card);
  background: var(--sky-glass);
  padding: var(--sky-space-1);
}
.live-broadcast__composer :deep(.sky-messagebar) {
  background: transparent;
}
.live-broadcast__directory-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: var(--sky-space-2);
}
.live-broadcast__directory {
  display: flex;
  flex-direction: column;
  gap: var(--sky-space-3);
  overflow-y: auto;
}
.live-broadcast__error {
  position: relative;
  z-index: 2;
  padding: var(--sky-space-2);
  border-radius: var(--sky-radius-control);
  background: var(--sky-action-surface);
  color: var(--sky-danger);
  font-size: var(--sky-font-caption);
}
.live-broadcast__sr {
  position: absolute;
  width: 1px;
  height: 1px;
  overflow: hidden;
  clip-path: inset(50%);
}
</style>
