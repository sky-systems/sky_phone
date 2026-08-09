<script setup lang="ts">
import { Headphones } from 'lucide-vue-next'
import { computed, onBeforeUnmount, onMounted, reactive, ref } from 'vue'

import type { RadioHudConfig, RadioHudMember } from '@/types/radio'

type RadioHudEntry = RadioHudMember & {
  state: 'recent' | 'talking'
}

type RadioHudMessage = {
  data?: Partial<RadioHudConfig> | { members?: RadioHudMember[] }
  type?: string
}

const config = reactive<RadioHudConfig>({
  enabled: false,
  horizontal: 'right',
  horizontalOffset: 2,
  speakerPersistMilliseconds: 3000,
  vertical: 'top',
  verticalOffset: 30,
})
const entries = ref(new Map<number, RadioHudEntry>())
const removalTimers = new Map<number, number>()
const visibleEntries = computed(() =>
  Array.from(entries.value.values()).sort((left, right) =>
    left.name.localeCompare(right.name),
  ),
)
const positionStyle = computed(() => ({
  '--radio-hud-horizontal-offset': `${config.horizontalOffset}vh`,
  '--radio-hud-vertical-offset': `${config.verticalOffset}vh`,
}))

function clearRemovalTimer(id: number): void {
  const timer = removalTimers.get(id)
  if (timer !== undefined) window.clearTimeout(timer)
  removalTimers.delete(id)
}

function setEntry(entry: RadioHudEntry): void {
  const next = new Map(entries.value)
  next.set(entry.id, entry)
  entries.value = next
}

function removeEntry(id: number): void {
  clearRemovalTimer(id)
  const next = new Map(entries.value)
  next.delete(id)
  entries.value = next
}

function clearEntries(): void {
  for (const timer of removalTimers.values()) window.clearTimeout(timer)
  removalTimers.clear()
  entries.value = new Map()
}

function scheduleRemoval(id: number): void {
  clearRemovalTimer(id)
  const duration = Math.max(
    0,
    Math.min(10_000, config.speakerPersistMilliseconds),
  )
  removalTimers.set(
    id,
    window.setTimeout(() => {
      if (entries.value.get(id)?.state === 'recent') removeEntry(id)
    }, duration),
  )
}

function updateMembers(members: RadioHudMember[]): void {
  const currentIds = new Set<number>()
  for (const member of members) {
    if (!Number.isInteger(member.id) || member.id <= 0) continue
    currentIds.add(member.id)
    const existing = entries.value.get(member.id)
    const normalized = {
      badge: String(member.badge ?? ''),
      channel: member.channel === 2 ? 2 : 1,
      id: member.id,
      name: String(member.name || `ID ${member.id}`),
      talking: member.talking === true,
    } satisfies RadioHudMember

    if (normalized.talking) {
      clearRemovalTimer(member.id)
      setEntry({ ...normalized, state: 'talking' })
    } else if (existing?.state === 'talking') {
      setEntry({ ...normalized, state: 'recent' })
      scheduleRemoval(member.id)
    } else if (existing) {
      setEntry({ ...normalized, state: existing.state })
    }
  }

  for (const id of entries.value.keys()) {
    if (!currentIds.has(id)) removeEntry(id)
  }
}

function updateConfig(value: Partial<RadioHudConfig>): void {
  config.enabled = value.enabled === true
  config.horizontal = value.horizontal === 'left' ? 'left' : 'right'
  config.vertical = value.vertical === 'bottom' ? 'bottom' : 'top'
  config.horizontalOffset = Math.max(
    0,
    Math.min(100, Number(value.horizontalOffset) || 0),
  )
  config.verticalOffset = Math.max(
    0,
    Math.min(100, Number(value.verticalOffset) || 0),
  )
  config.speakerPersistMilliseconds = Math.max(
    0,
    Math.min(10_000, Number(value.speakerPersistMilliseconds) || 0),
  )
  if (!config.enabled) clearEntries()
}

function onMessage(event: MessageEvent<RadioHudMessage>): void {
  if (event.data?.type === 'radio:hud-config' && event.data.data) {
    updateConfig(event.data.data as Partial<RadioHudConfig>)
  } else if (event.data?.type === 'radio:hud-update' && event.data.data) {
    const data = event.data.data as { members?: RadioHudMember[] }
    updateMembers(Array.isArray(data.members) ? data.members : [])
  }
}

onMounted(() => {
  window.addEventListener('message', onMessage)
  if (
    import.meta.env.DEV &&
    new URLSearchParams(window.location.search).has('radioHudPreview')
  ) {
    updateConfig({
      enabled: true,
      horizontal: 'right',
      horizontalOffset: 2,
      speakerPersistMilliseconds: 3000,
      vertical: 'top',
      verticalOffset: 30,
    })
    updateMembers([
      {
        badge: '231',
        channel: 1,
        id: 21,
        name: 'Unit 21',
        talking: true,
      },
      {
        badge: '12',
        channel: 2,
        id: 12,
        name: 'Unit 12',
        talking: true,
      },
    ])
  }
})

onBeforeUnmount(() => {
  window.removeEventListener('message', onMessage)
  clearEntries()
})
</script>

<template>
  <aside
    v-if="config.enabled"
    class="radio-hud"
    :data-horizontal="config.horizontal"
    :data-vertical="config.vertical"
    :style="positionStyle"
    aria-hidden="true"
  >
    <TransitionGroup
      name="radio-hud-member"
      tag="div"
      class="radio-hud__members"
    >
      <div
        v-for="entry in visibleEntries"
        :key="entry.id"
        class="radio-hud__member"
        :class="[
          `radio-hud__member--${entry.state}`,
          { 'radio-hud__member--secondary': entry.channel === 2 },
        ]"
      >
        <Headphones class="radio-hud__icon" aria-hidden="true" />
        <span v-if="entry.badge" class="radio-hud__badge">
          [{{ entry.badge }}]
        </span>
        <span class="radio-hud__name">{{ entry.name }}</span>
      </div>
    </TransitionGroup>
  </aside>
</template>

<style scoped>
.radio-hud {
  position: fixed;
  z-index: 40;
  display: flex;
  pointer-events: none;
  font-family: Inter, ui-sans-serif, system-ui, sans-serif;
}

.radio-hud[data-horizontal='left'] {
  right: auto;
  left: var(--radio-hud-horizontal-offset);
  justify-content: flex-start;
}

.radio-hud[data-horizontal='right'] {
  right: var(--radio-hud-horizontal-offset);
  left: auto;
  justify-content: flex-end;
}

.radio-hud[data-vertical='bottom'] {
  top: auto;
  bottom: var(--radio-hud-vertical-offset);
}

.radio-hud[data-vertical='top'] {
  top: var(--radio-hud-vertical-offset);
  bottom: auto;
}

.radio-hud__members {
  display: flex;
  flex-direction: column;
  gap: 0.6vh;
  align-items: flex-end;
}

.radio-hud[data-horizontal='left'] .radio-hud__members {
  align-items: flex-start;
}

.radio-hud__member {
  display: flex;
  max-width: 32vw;
  align-items: center;
  gap: 0.7vh;
  color: #4ade80;
  font-size: clamp(12px, 1.25vh, 16px);
  font-weight: 700;
  line-height: 1;
  filter: drop-shadow(0 2px 4px rgb(0 0 0 / 80%));
}

.radio-hud__member--secondary {
  color: #facc15;
}

.radio-hud__member--recent {
  color: rgb(255 255 255 / 90%);
}

.radio-hud__icon {
  width: 1.8vh;
  min-width: 14px;
  height: 1.8vh;
  min-height: 14px;
  animation: radio-hud-pulse 0.8s ease-in-out infinite;
  filter: drop-shadow(0 0 6px currentColor);
}

.radio-hud__member--recent .radio-hud__icon {
  animation: none;
  filter: none;
}

.radio-hud__badge {
  opacity: 0.75;
  white-space: nowrap;
  letter-spacing: 0.03em;
}

.radio-hud__name {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  letter-spacing: 0.02em;
}

.radio-hud-member-enter-active,
.radio-hud-member-leave-active {
  transition:
    opacity 0.3s ease,
    transform 0.3s cubic-bezier(0.22, 1, 0.36, 1);
}

.radio-hud-member-enter-from,
.radio-hud-member-leave-to {
  opacity: 0;
  transform: translateX(2vh);
}

.radio-hud[data-horizontal='left'] .radio-hud-member-enter-from,
.radio-hud[data-horizontal='left'] .radio-hud-member-leave-to {
  transform: translateX(-2vh);
}

@keyframes radio-hud-pulse {
  0%,
  100% {
    opacity: 1;
    transform: scale(1);
  }

  50% {
    opacity: 0.55;
    transform: scale(0.86);
  }
}
</style>
