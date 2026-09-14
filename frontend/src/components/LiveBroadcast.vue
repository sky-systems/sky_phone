<script setup lang="ts">
import { onBeforeUnmount, ref, onMounted, computed, watch, nextTick } from 'vue'
import { Radio, Eye, Send, SwitchCamera, Mic, MicOff, X } from 'lucide-vue-next'
import { usePhoneStore } from '@/stores/phone'
import { useRealtimeStore } from '@/features/realtime/store'
import type { LiveApp, LiveEntry } from '@/features/realtime/types'
import {
  SkyButton,
  SkySheet,
  SkyMessages,
  SkyMessage,
  SkyMessagebar,
} from '@/ui'
import RealtimeVideo from './RealtimeVideo.vue'
const props = withDefaults(
  defineProps<{ app: LiveApp; hideTrigger?: boolean }>(),
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
const validMessage = computed(
  () =>
    [...draft.value.trim()].length > 0 && [...draft.value.trim()].length <= 300,
)
const t = (key: string) => phone.t(`Realtime.${key}`)
let timer: number | undefined
async function open(): Promise<void> {
  opened.value = true
  entries.value = await realtime.list(props.app)
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
    chatEnd.value?.scrollIntoView({ block: 'nearest' })
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
  <SkyButton
    v-if="enabled && !hideTrigger"
    clear
    inline
    class="live-entry"
    @click="open"
    ><Radio :size="18" />{{ t('live') }}</SkyButton
  >
  <SkySheet
    :opened="opened"
    :aria-label="t('live')"
    @backdropclick="close"
    @escape="close"
    @swipeclose="close"
    @grabberclick="close"
  >
    <section class="live-broadcast">
      <header>
        <strong>{{ phone.t(`Apps.${app}.name`) }} · {{ t('live') }}</strong
        ><SkyButton
          clear
          icon-only
          rounded
          :aria-label="phone.t('Common.close')"
          @click="close"
          ><X :size="20"
        /></SkyButton>
      </header>
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
          <div class="live-broadcast__badge">
            <Radio :size="16" /> {{ t('live') }} <Eye :size="16" />
            {{ current.viewers }}
            <span class="live-broadcast__sr">{{ t('viewers') }}</span>
          </div>
          <p
            v-if="!realtime.streams.size && current.role === 'viewer'"
            class="live-broadcast__connecting"
            role="status"
          >
            {{ t('connecting') }}
          </p>
        </div>
        <div class="live-broadcast__identity">
          <strong>{{ current.hostName }}</strong
          ><span>{{
            app === 'fliptok'
              ? current.description || current.title
              : current.title
          }}</span>
          <p v-if="app === 'picstagram' && current.description">
            {{ current.description }}
          </p>
        </div>
        <div class="live-broadcast__controls">
          <SkyButton
            v-if="current.role === 'host'"
            glass
            rounded
            icon-only
            :aria-label="t('flip')"
            @click="realtime.flip"
            ><SwitchCamera :size="20"
          /></SkyButton>
          <SkyButton
            v-if="current.role === 'host'"
            glass
            rounded
            icon-only
            :aria-label="t(realtime.muted ? 'unmute' : 'mute')"
            :aria-pressed="realtime.muted"
            @click="realtime.setMuted(!realtime.muted)"
            ><component :is="realtime.muted ? MicOff : Mic" :size="20"
          /></SkyButton>
          <SkyButton glass rounded @click="realtime.stop">{{
            t(current.role === 'host' ? 'endLive' : 'leave')
          }}</SkyButton>
        </div>
        <div
          class="live-broadcast__chat"
          role="log"
          aria-live="polite"
          :aria-label="t('chat')"
        >
          <p v-if="!current.messages?.length">{{ t('chatEmpty') }}</p>
          <SkyMessages>
            <SkyMessage
              v-for="message in current.messages"
              :key="message.id"
              :name="message.name"
              :text="message.text"
              :text-header="message.host ? t('host') : ''"
              type="received"
            />
          </SkyMessages>
          <span ref="chatEnd" />
        </div>
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
        <small v-if="[...draft].length > 300" role="alert">{{
          t('messageLimit')
        }}</small>
      </template>
      <div v-else class="live-broadcast__directory">
        <p>{{ t('startViaPlus') }}</p>
        <p v-if="!entries.length">{{ t('noLive') }}</p>
        <SkyButton
          v-for="entry in entries"
          :key="entry.id"
          tonal
          :disabled="realtime.busy"
          @click="realtime.watchLive(entry.id)"
          >{{ entry.hostName }} · {{ entry.title || t('live') }} ·
          {{ entry.viewers }} {{ t('viewers') }}</SkyButton
        >
      </div>
      <p v-if="realtime.error" role="alert">
        {{
          phone.t('Realtime.errors.' + realtime.error) ===
          'Realtime.errors.' + realtime.error
            ? t('errors.default')
            : phone.t('Realtime.errors.' + realtime.error)
        }}
      </p>
    </section>
  </SkySheet>
</template>
<style scoped>
.live-entry {
  flex-shrink: 0;
  gap: var(--sky-space-1);
}
.live-broadcast {
  display: flex;
  flex-direction: column;
  gap: var(--sky-space-2);
  padding: var(--sky-space-4);
  max-height: 85cqh;
  border-radius: inherit;
  overflow: hidden;
  color: var(--sky-text);
  background: var(--sky-surface);
}
.live-broadcast header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
.live-broadcast__video {
  position: relative;
  flex-shrink: 0;
  height: 30cqh;
  background: var(--sky-surface-variant);
  overflow: hidden;
  border-radius: var(--sky-radius-card);
}
.live-broadcast__video video {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.live-broadcast__badge {
  position: absolute;
  top: var(--sky-space-2);
  left: var(--sky-space-2);
  display: flex;
  align-items: center;
  gap: var(--sky-space-2);
  padding: var(--sky-space-2);
  border-radius: var(--sky-radius-pill);
  background: var(--sky-surface);
}
.live-broadcast__connecting {
  position: absolute;
  bottom: var(--sky-space-2);
  left: var(--sky-space-4);
}
.live-broadcast__controls {
  display: flex;
  gap: var(--sky-space-2);
}
.live-broadcast__identity {
  display: flex;
  flex-direction: column;
  overflow-wrap: anywhere;
}
.live-broadcast__identity p,
.live-broadcast__identity span {
  display: -webkit-box;
  -webkit-line-clamp: 3;
  -webkit-box-orient: vertical;
  overflow: hidden;
  margin: 0;
}
.live-broadcast__chat {
  min-height: 60px;
  flex: 1;
  overflow-y: auto;
  overscroll-behavior: contain;
}
.live-broadcast__directory {
  display: flex;
  flex-direction: column;
  gap: var(--sky-space-3);
  overflow-y: auto;
}
.live-broadcast__sr {
  position: absolute;
  width: 1px;
  height: 1px;
  overflow: hidden;
  clip-path: inset(50%);
}
</style>
