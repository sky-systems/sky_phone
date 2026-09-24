<script setup lang="ts">
import { computed, ref } from 'vue'
import {
  Camera,
  LockKeyhole,
  MessageCircle,
  Mic,
  MicOff,
  PhoneOff,
  PictureInPicture2,
  UserRound,
  Video,
  VideoOff,
  Volume2,
} from 'lucide-vue-next'
import { SkyButton, SkyGlass } from '@/ui'
import RealtimeVideo from '@/components/RealtimeVideo.vue'
import { useCallsStore } from '@/stores/calls'
import { usePhoneStore } from '@/stores/phone'
import { useRealtimeStore } from '@/features/realtime/store'

const props = defineProps<{
  name: string
  avatar?: string | null
  status: string
  error: string
  locked?: boolean
  speakerPending: boolean
  mutePending: boolean
  videoPending: boolean
}>()
const emit = defineEmits<{
  speaker: []
  mute: []
  endVideo: []
  hangup: []
  message: []
  unlock: []
}>()
const phone = usePhoneStore()
const calls = useCallsStore()
const realtime = useRealtimeStore()
const swapped = ref(false)
const remote = computed(() => realtime.streams.values().next().value ?? null)
const mainStream = computed(() =>
  swapped.value ? realtime.localStream : remote.value,
)
const smallStream = computed(() =>
  swapped.value ? remote.value : realtime.localStream,
)
const initials = computed(() =>
  props.name
    .trim()
    .split(/\s+/)
    .slice(0, 2)
    .map((part) => part[0])
    .join(''),
)
</script>

<template>
  <section
    class="facetime-call"
    :aria-label="phone.t('Realtime.faceTimeVideo')"
  >
    <RealtimeVideo :stream="mainStream" muted class="facetime-call__remote" />
    <div v-if="!mainStream" class="facetime-call__waiting" role="status">
      <SkyGlass class="facetime-call__portrait">
        <img v-if="avatar" :src="avatar" alt="" />
        <UserRound v-else :size="56" />
      </SkyGlass>
      <p>{{ phone.t('Realtime.connecting') }}</p>
    </div>
    <SkyGlass class="facetime-call__panel">
      <header class="facetime-call__identity">
        <span class="facetime-call__avatar">
          <img v-if="avatar" :src="avatar" alt="" />
          <UserRound v-else-if="/^[\d\s]+$/.test(name)" :size="24" /><span
            v-else
            >{{ initials }}</span
          >
        </span>
        <div class="facetime-call__contact">
          <h1>{{ name }}</h1>
          <p><Video :size="14" /> {{ phone.t('Realtime.faceTimeVideo') }}</p>
        </div>
        <SkyButton
          rounded
          variant="danger"
          class="facetime-call__end"
          :aria-label="phone.t('Apps.phone.hangup')"
          @click="emit('hangup')"
        >
          <PhoneOff :size="18" /><span>{{ phone.t('Apps.phone.hangup') }}</span>
        </SkyButton>
      </header>
      <div class="facetime-call__controls">
        <SkyButton
          glass
          rounded
          icon-only
          :aria-label="
            phone.t(
              locked ? 'HardwareButtons.unlock' : 'Apps.phone.sendMessage',
            )
          "
          @click="locked ? emit('unlock') : emit('message')"
        >
          <LockKeyhole v-if="locked" :size="22" /><MessageCircle
            v-else
            :size="22"
          />
        </SkyButton>
        <SkyButton
          glass
          rounded
          icon-only
          :aria-label="phone.t('Apps.phone.speaker')"
          :aria-pressed="calls.activeCall?.speakerEnabled === true"
          :disabled="!calls.activeCall?.speakerSupported || speakerPending"
          :title="
            !calls.activeCall?.speakerSupported
              ? phone.t('Apps.phone.errors.speaker_unsupported')
              : undefined
          "
          @click="emit('speaker')"
        >
          <Volume2 :size="23" />
        </SkyButton>
        <SkyButton
          glass
          rounded
          icon-only
          :aria-label="
            phone.t(
              calls.activeCall?.muted ? 'Realtime.unmute' : 'Realtime.mute',
            )
          "
          :aria-pressed="calls.activeCall?.muted === true"
          :disabled="!calls.activeCall?.muteSupported || mutePending"
          :title="
            !calls.activeCall?.muteSupported
              ? phone.t('Apps.phone.errors.mute_unsupported')
              : undefined
          "
          @click="emit('mute')"
        >
          <MicOff v-if="calls.activeCall?.muted" :size="23" /><Mic
            v-else
            :size="23"
          />
        </SkyButton>
        <SkyButton
          glass
          rounded
          icon-only
          :aria-label="phone.t('Realtime.endVideo')"
          :disabled="videoPending"
          @click="emit('endVideo')"
          ><VideoOff :size="23"
        /></SkyButton>
        <SkyButton
          glass
          rounded
          icon-only
          :aria-label="phone.t('Realtime.yourCamera')"
          :aria-pressed="swapped"
          :disabled="!remote || !realtime.localStream"
          @click="swapped = !swapped"
          ><PictureInPicture2 :size="23"
        /></SkyButton>
      </div>
      <p class="facetime-call__duration"><span></span>{{ status }}</p>
    </SkyGlass>
    <p v-if="error || realtime.error" class="facetime-call__error" role="alert">
      {{ error || phone.t('Realtime.errors.default') }}
    </p>
    <SkyGlass
      class="facetime-call__self"
      :aria-label="phone.t('Realtime.yourCamera')"
    >
      <RealtimeVideo :stream="smallStream" muted />
      <VideoOff
        v-if="!smallStream"
        class="facetime-call__no-camera"
        :size="24"
      />
      <SkyButton
        glass
        rounded
        icon-only
        class="facetime-call__flip"
        :aria-label="phone.t('Realtime.flip')"
        :disabled="!realtime.localStream"
        @click="realtime.flip"
        ><Camera :size="20"
      /></SkyButton>
    </SkyGlass>
  </section>
</template>

<style scoped>
.facetime-call {
  position: absolute;
  inset: 0;
  overflow: hidden;
  color: var(--sky-text);
  background: var(--sky-action-surface);
}
.facetime-call__remote {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.facetime-call__waiting {
  position: absolute;
  inset: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: var(--sky-space-4);
  color: var(--sky-muted);
}
.facetime-call__portrait {
  display: grid;
  place-items: center;
  width: 112px;
  height: 112px;
  overflow: hidden;
  border-radius: var(--sky-radius-pill);
}
.facetime-call__portrait img,
.facetime-call__avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.facetime-call__panel {
  position: relative;
  margin: calc(var(--sky-safe-area-top) + var(--sky-space-2)) var(--sky-space-3)
    0;
  padding: var(--sky-space-3);
  border-radius: var(--sky-radius-card);
  background: var(--sky-glass);
}
.facetime-call__identity {
  display: flex;
  align-items: center;
  gap: var(--sky-space-2);
  text-align: left;
}
.facetime-call__avatar {
  display: grid;
  place-items: center;
  flex-shrink: 0;
  width: var(--sky-touch-target);
  height: var(--sky-touch-target);
  border-radius: var(--sky-radius-pill);
  overflow: hidden;
  background: var(--sky-surface-variant);
  font-size: var(--sky-font-body);
  font-weight: 600;
}
.facetime-call__contact {
  min-width: 0;
  flex: 1;
}
.facetime-call__contact h1 {
  margin: 0;
  font-size: var(--sky-font-title);
  font-weight: 650;
  line-height: 1.3;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.facetime-call__contact p {
  display: flex;
  align-items: center;
  gap: var(--sky-space-1);
  margin: var(--sky-space-1) 0 0;
  color: var(--sky-muted);
  font-size: var(--sky-font-caption);
}
.facetime-call__end {
  width: auto;
  flex-shrink: 0;
  gap: var(--sky-space-1);
  padding-inline: var(--sky-space-3);
}
.facetime-call__controls {
  display: flex;
  justify-content: space-between;
  gap: var(--sky-space-2);
  margin-top: var(--sky-space-4);
}
.facetime-call__controls .sky-button {
  flex-shrink: 0;
  color: var(--sky-text);
}
.facetime-call__controls .sky-button[aria-pressed='true'] {
  background: var(--sky-text);
  color: var(--sky-bg);
}
.facetime-call__duration {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: var(--sky-space-1);
  margin: var(--sky-space-2) 0 0;
  font-size: var(--sky-font-caption);
  font-variant-numeric: tabular-nums;
  color: var(--sky-muted);
}
.facetime-call__duration span {
  width: 6px;
  height: 6px;
  border-radius: var(--sky-radius-pill);
  background: var(--sky-success);
}
.facetime-call__error {
  position: relative;
  margin: var(--sky-space-3);
  padding: var(--sky-space-3);
  border-radius: var(--sky-radius-card);
  background: var(--sky-action-surface);
  color: var(--sky-danger);
  font-size: var(--sky-font-caption);
}
.facetime-call__self {
  position: absolute;
  bottom: calc(var(--sky-safe-area-bottom) + var(--sky-space-5));
  right: var(--sky-space-3);
  width: 30%;
  height: 27%;
  min-height: 120px;
  border-radius: var(--sky-radius-card);
  overflow: hidden;
  background: var(--sky-action-surface);
}
.facetime-call__self > video {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.facetime-call__flip {
  position: absolute;
  right: var(--sky-space-1);
  bottom: var(--sky-space-1);
  color: var(--sky-text);
}
.facetime-call__no-camera {
  position: absolute;
  inset: 0;
  margin: auto;
}
</style>
