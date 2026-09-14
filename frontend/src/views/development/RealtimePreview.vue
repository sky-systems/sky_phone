<script setup lang="ts">
// Development-only fixture. Uses the production views with simulated media and participants.
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { SkyNavbar, SkyButton } from '@/ui'
import PhoneApp from '@/views/apps/PhoneApp.vue'
import PicstagramApp from '@/views/apps/PicstagramApp.vue'
import FlipTokApp from '@/views/apps/FlipTokApp.vue'
import LiveBroadcast from '@/components/LiveBroadcast.vue'
import { useCallsStore } from '@/stores/calls'
import { useRealtimeStore } from '@/features/realtime/store'
import type { LiveApp } from '@/features/realtime/types'
const route = useRoute(),
  router = useRouter()
const realtime = useRealtimeStore(),
  calls = useCallsStore()
const live = ref<InstanceType<typeof LiveBroadcast> | null>(null)
const scene = computed(() =>
  ['picstagram', 'fliptok'].includes(String(route.params.scene))
    ? (String(route.params.scene) as LiveApp)
    : 'call',
)
const view = computed(() =>
  ['entry', 'viewer'].includes(String(route.query.view))
    ? String(route.query.view)
    : 'host',
)
const callView = computed(() => String(route.query.view || 'connected'))
const streams: MediaStream[] = []
const originalAnswer = calls.answer,
  originalVideoAction = calls.videoAction,
  originalHangup = calls.hangup,
  originalDecline = calls.decline,
  originalSpeaker = calls.setSpeaker,
  originalMute = calls.setMuted
const originalChat = realtime.chat,
  originalStop = realtime.stop,
  originalFlip = realtime.flip
const originalList = realtime.list,
  originalStart = realtime.startLive,
  originalWatch = realtime.watchLive,
  originalConfig = realtime.refreshConfig
let animation = 0
let previewTitle = '',
  previewDescription = ''
function makeStream(local: boolean): MediaStream {
  const canvas = document.createElement('canvas')
  canvas.width = 540
  canvas.height = 720
  const context = canvas.getContext('2d')!
  const draw = () => {
    const gradient = context.createLinearGradient(0, 0, 540, 720)
    gradient.addColorStop(0, local ? '#3f4667' : '#866760')
    gradient.addColorStop(1, local ? '#162839' : '#152f43')
    context.fillStyle = gradient
    context.fillRect(0, 0, 540, 720)
    context.fillStyle = '#112939'
    for (let i = 0; i < 9; i++)
      context.fillRect(i * 75, 290 + (i % 3) * 26, 60, 440)
    context.fillStyle = local ? '#91a6bc' : '#dfc2a5'
    context.beginPath()
    context.arc(270, 290, 90, 0, Math.PI * 2)
    context.fill()
    context.fillStyle = local ? '#26333f' : '#243542'
    context.beginPath()
    context.ellipse(270, 685, 210, 290, 0, 0, Math.PI * 2)
    context.fill()
    context.fillStyle = '#ffffff'
    context.font = '18px sans-serif'
    context.textAlign = 'center'
    context.fillText('KAMERAVORSCHAU · DEMO', 270, 690)
  }
  draw()
  animation = requestAnimationFrame(draw)
  const stream = canvas.captureStream(1)
  streams.push(stream)
  return stream
}
async function show(): Promise<void> {
  await nextTick()
  streams
    .splice(0)
    .forEach((stream) => stream.getTracks().forEach((track) => track.stop()))
  calls.activeCall = null
  realtime.config = {
    enabled: true,
    transport: 'p2p',
    videoCalls: true,
    picstagram: true,
    fliptok: true,
    fps: 24,
    bitrate: 1200000,
    edge: 720,
    nearbyAudio: true,
    iceServers: [],
    iceTransportPolicy: 'all',
  }
  realtime.error = ''
  realtime.busy = false
  const remote = makeStream(false),
    local = makeStream(true)
  realtime.localStream = local
  realtime.streams = new Map([[2, remote]])
  realtime.room = {
    id: 'preview',
    kind: scene.value === 'call' ? 'call' : 'live',
    app: scene.value === 'call' ? undefined : scene.value,
    self: 1,
    role:
      scene.value === 'call'
        ? 'call'
        : view.value === 'viewer'
          ? 'viewer'
          : 'host',
    peers: [],
    viewers: scene.value === 'fliptok' ? 128 : 42,
    transport: 'p2p',
    hostName: 'Luna Walker',
    title:
      previewTitle ||
      (scene.value === 'fliptok'
        ? 'Abendrunde durch Los Santos'
        : 'Sonnenuntergang in Vespucci'),
    description: previewDescription,
    messages: [
      {
        id: 1,
        name: 'Harald Kronberg',
        text: 'Das sieht richtig gut aus 👋',
        host: false,
        at: 1,
      },
      {
        id: 2,
        name: 'Mia Santos',
        text: 'Wo seid ihr gerade?',
        host: false,
        at: 2,
      },
      {
        id: 3,
        name: 'Luna Walker',
        text: 'Direkt am Strand! 🌅',
        host: true,
        at: 3,
      },
    ],
  }
  if (scene.value === 'call') {
    const ringing = ['incoming', 'outgoing'].includes(callView.value)
    calls.activeCall = {
      id: 'preview-call',
      otherNumber: '5550142',
      direction: callView.value === 'outgoing' ? 'outgoing' : 'incoming',
      state: ringing ? 'ringing' : 'connected',
      startedAt: Date.now() - 83000,
      answeredAt: Date.now() - 83000,
      video: !['request', 'audio'].includes(callView.value),
      videoIncoming: callView.value === 'request',
      videoRequested: callView.value === 'request',
      muteSupported: callView.value !== 'pma',
      speakerSupported: callView.value !== 'pma',
    }
    if (ringing || !calls.activeCall.video) {
      realtime.room = null
      realtime.streams = new Map()
      realtime.localStream = null
    }
  } else if (view.value === 'entry') {
    realtime.room = null
    realtime.streams = new Map()
    realtime.localStream = null
  } else {
    realtime.streams =
      view.value === 'viewer' ? new Map([[2, remote]]) : new Map()
    realtime.localStream = remote
    await nextTick()
    await live.value?.open()
    realtime.error = ''
  }
}
realtime.chat = async (text: string) => {
  if (!realtime.room) return false
  realtime.room = {
    ...realtime.room,
    messages: [
      ...(realtime.room.messages ?? []),
      {
        id: Date.now(),
        name: realtime.room.role === 'host' ? 'Luna Walker' : 'Harald Kronberg',
        text,
        host: realtime.room.role === 'host',
        at: Date.now(),
      },
    ],
  }
  return true
}
realtime.stop = () => {
  realtime.room = null
  calls.activeCall = null
}
realtime.flip = async () => {
  realtime.front = !realtime.front
}
realtime.list = async (app) => [
  {
    id: 'preview',
    profileId: app === 'picstagram' ? 'pic-profile-2' : '2',
    title: 'Sonnenuntergang in Vespucci',
    hostName: 'Luna Walker',
    viewers: 42,
  },
]
realtime.refreshConfig = async () => undefined
realtime.startLive = async (_app, title, description = '') => {
  previewTitle = title
  previewDescription = description
  window.setTimeout(
    () =>
      void router.replace({
        path: `/development/realtime/${scene.value}`,
        query: { view: 'host' },
      }),
    0,
  )
}
realtime.watchLive = async () => {
  await router.replace({
    path: `/development/realtime/${scene.value}`,
    query: { view: 'viewer' },
  })
}
calls.answer = async (video = false) => {
  await router.replace({
    path: '/development/realtime/call',
    query: { view: video ? 'connected' : 'audio' },
  })
  return { success: true }
}
calls.videoAction = async (action) => {
  await router.replace({
    path: '/development/realtime/call',
    query: {
      view:
        action === 'accept'
          ? 'connected'
          : action === 'request'
            ? 'request'
            : 'audio',
    },
  })
  return { success: true }
}
calls.hangup = calls.decline = async () => {
  realtime.stop()
  return true
}
calls.setSpeaker = async (enabled) => {
  if (calls.activeCall) calls.activeCall.speakerEnabled = enabled
  return { success: true, data: { speakerEnabled: enabled } }
}
calls.setMuted = async (enabled) => {
  if (calls.activeCall) calls.activeCall.muted = enabled
  return { success: true, data: { muted: enabled } }
}
watch([scene, view, callView], () => void show())
onMounted(() => void show())
onBeforeUnmount(() => {
  cancelAnimationFrame(animation)
  streams.forEach((stream) =>
    stream.getTracks().forEach((track) => track.stop()),
  )
  realtime.room = null
  calls.activeCall = null
  realtime.chat = originalChat
  realtime.stop = originalStop
  realtime.flip = originalFlip
  realtime.list = originalList
  realtime.startLive = originalStart
  realtime.watchLive = originalWatch
  realtime.refreshConfig = originalConfig
  calls.answer = originalAnswer
  calls.videoAction = originalVideoAction
  calls.hangup = originalHangup
  calls.decline = originalDecline
  calls.setSpeaker = originalSpeaker
  calls.setMuted = originalMute
})
</script>
<template>
  <div class="realtime-preview">
    <Teleport to="body"
      ><nav
        class="realtime-preview__switch sky-ui-provider"
        aria-label="Vorschauszenen"
      >
        <SkyButton
          v-for="value in ['call', 'picstagram', 'fliptok']"
          :key="value"
          clear
          @click="router.replace('/development/realtime/' + value)"
          >{{
            value === 'call'
              ? 'Videoanruf'
              : value === 'picstagram'
                ? 'Picstagram'
                : 'FlipTok'
          }}</SkyButton
        >
        <div v-if="scene === 'call'" class="realtime-preview__roles">
          <SkyButton
            v-for="option in [
              'incoming',
              'outgoing',
              'request',
              'connected',
              'pma',
            ]"
            :key="option"
            clear
            :aria-pressed="callView === option"
            @click="
              router.replace({
                path: '/development/realtime/call',
                query: { view: option },
              })
            "
            >{{
              {
                incoming: 'Eingehend',
                outgoing: 'Ausgehend',
                request: 'Videoanfrage',
                connected: 'Verbunden',
                pma: 'PMA',
              }[option]
            }}</SkyButton
          >
        </div>
        <div v-else class="realtime-preview__roles">
          <SkyButton
            v-for="option in ['entry', 'host', 'viewer']"
            :key="option"
            clear
            :aria-pressed="view === option"
            @click="
              router.replace({
                path: `/development/realtime/${scene}`,
                query: { view: option },
              })
            "
            >{{
              option === 'entry'
                ? 'Einstieg'
                : option === 'host'
                  ? 'Sender'
                  : 'Zuschauer'
            }}</SkyButton
          >
        </div>
      </nav></Teleport
    >
    <PhoneApp v-if="scene === 'call'" />
    <PicstagramApp v-else-if="scene === 'picstagram' && view === 'entry'" />
    <FlipTokApp v-else-if="scene === 'fliptok' && view === 'entry'" />
    <template v-else>
      <SkyNavbar :title="scene === 'picstagram' ? 'Picstagram' : 'FlipTok'" />
      <LiveBroadcast :key="scene" ref="live" :app="scene" />
    </template>
  </div>
</template>
<style scoped>
.realtime-preview {
  position: absolute;
  inset: 0;
  background: var(--sky-surface);
}
.realtime-preview__switch {
  pointer-events: auto;
  position: fixed;
  top: var(--sky-space-6);
  left: var(--sky-space-6);
  width: min(400px, calc(100vw - 48px));
  z-index: 2000;
  display: flex;
  flex-wrap: wrap;
  justify-content: center;
  padding: var(--sky-space-2);
  border-radius: var(--sky-radius-card);
  background: var(--sky-surface);
  box-shadow: var(--sky-shadow-glass);
}
.realtime-preview__switch > .sky-button {
  width: auto;
}
.realtime-preview__roles {
  display: flex;
  flex-wrap: wrap;
  width: 100%;
}
.realtime-preview__roles .sky-button[aria-pressed='true'] {
  font-weight: 700;
  background: var(--sky-surface-variant);
}
</style>
