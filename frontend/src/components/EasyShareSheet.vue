<script setup lang="ts">
import {
  Check,
  Clock3,
  History,
  MessageCircle,
  Share2,
  UserRound,
  X,
} from 'lucide-vue-next'
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'

import { getPhoneApp, getPhoneAppLabel } from '@/config/apps'
import { useAppStoreStore } from '@/stores/app-store'
import { useCallsStore } from '@/stores/calls'
import { useDarkChatStore } from '@/stores/darkchat'
import { useEasyShareStore } from '@/stores/easyshare'
import { useFlareStore } from '@/stores/flare'
import { useMessagesStore } from '@/stores/messages'
import { useNotesStore } from '@/stores/notes'
import { usePhoneStore } from '@/stores/phone'
import type {
  EasyShareChatApp,
  EasyShareDestinationApp,
  EasyShareTransfer,
} from '@/types/easyshare'
import {
  easyShareDestinationAppIds,
  openEasySharePayload,
} from '@/utils/easyshare'
import {
  SkyButton,
  SkyGlass,
  SkyLink,
  SkyList,
  SkyListItem,
  SkySheet,
  SkySpinner,
} from '@/ui'
import { consumeEscape } from '@/utils/keyboard'

const phone = usePhoneStore()
const appStore = useAppStoreStore()
const calls = useCallsStore()
const darkChat = useDarkChatStore()
const messages = useMessagesStore()
const notes = useNotesStore()
const easyShare = useEasyShareStore()
const flare = useFlareStore()
const router = useRouter()
const feedback = ref('')
const dragOffset = ref(0)
const dragging = ref(false)
let dragPointerId: number | null = null
let dragStartTime = 0
let dragStartY = 0
const app = computed(() =>
  easyShare.payload ? getPhoneApp(easyShare.payload.appId) : undefined,
)
const sharePeople = computed(() => {
  const people: Array<{
    avatar?: string
    kind: EasyShareChatApp
    label: string
    targetId: string
  }> = []
  const phoneNumbers = new Set<string>()

  if (appStore.isInstalled('flare')) {
    for (const match of flare.matches) {
      people.push({
        avatar: match.profile.photoUrls[0],
        kind: 'flare',
        label: match.profile.name,
        targetId: match.id,
      })
    }
  }

  for (const conversation of messages.conversations.slice(0, 8)) {
    const contact = calls.contacts.find(
      (entry) => entry.phone_number === conversation.phoneNumber,
    )
    people.push({
      avatar: contact?.avatar_url ?? undefined,
      label: contact?.name ?? conversation.phoneNumber,
      kind: 'messages' as const,
      targetId: conversation.phoneNumber,
    })
    phoneNumbers.add(conversation.phoneNumber)
  }

  for (const contact of calls.contacts) {
    if (phoneNumbers.has(contact.phone_number)) continue
    people.push({
      avatar: contact.avatar_url ?? undefined,
      kind: 'messages',
      label: contact.name,
      targetId: contact.phone_number,
    })
    phoneNumbers.add(contact.phone_number)
  }

  if (appStore.isInstalled('darkchat')) {
    for (const conversation of darkChat.conversations.slice(0, 8)) {
      people.push({
        kind: 'darkchat',
        label: conversation.peer.alias,
        targetId: conversation.id,
      })
    }
  }

  return people
})
const shareApps = computed(() =>
  (easyShare.payload ? easyShareDestinationAppIds(easyShare.payload) : [])
    .filter((id) => appStore.isInstalled(id))
    .flatMap((id) => {
      const app = getPhoneApp(id)
      return app ? [{ app, id }] : []
    }),
)
const hostStyle = computed(() => ({
  '--easyshare-drag-offset': `${dragOffset.value}px`,
}))

function label(key: string, params?: Record<string, string>): string {
  return phone.t(`Apps.easyShare.${key}`, params)
}

function initials(value: string): string {
  return value
    .split(/\s+/)
    .slice(0, 2)
    .map((part) => part.charAt(0).toUpperCase())
    .join('')
}

function statusLabel(transfer: EasyShareTransfer): string {
  return label(`status.${transfer.status}`)
}

function scrollRowHorizontally(event: WheelEvent): void {
  const row = event.currentTarget as HTMLElement
  const maximum = row.scrollWidth - row.clientWidth
  if (maximum <= 0) return
  const delta =
    Math.abs(event.deltaX) > Math.abs(event.deltaY)
      ? event.deltaX
      : event.deltaY
  const next = Math.min(maximum, Math.max(0, row.scrollLeft + delta))
  if (next === row.scrollLeft) return
  event.preventDefault()
  row.scrollLeft = next
}

function close(): void {
  feedback.value = ''
  easyShare.close()
}

function onKeydown(event: KeyboardEvent): void {
  if (!easyShare.opened || !consumeEscape(event)) return
  close()
}

function beginDrag(event: PointerEvent): void {
  if (!easyShare.opened || event.button !== 0) return
  dragPointerId = event.pointerId
  dragStartTime = performance.now()
  dragStartY = event.clientY
  dragOffset.value = 0
  dragging.value = true
  ;(event.currentTarget as HTMLElement).setPointerCapture(event.pointerId)
}

function moveDrag(event: PointerEvent): void {
  if (!dragging.value || event.pointerId !== dragPointerId) return
  dragOffset.value = Math.max(0, event.clientY - dragStartY)
}

function endDrag(event: PointerEvent): void {
  if (!dragging.value || event.pointerId !== dragPointerId) return
  const elapsed = Math.max(1, performance.now() - dragStartTime)
  const shouldClose =
    dragOffset.value >= 72 ||
    (dragOffset.value >= 24 && dragOffset.value / elapsed >= 0.55)
  ;(event.currentTarget as HTMLElement).releasePointerCapture(event.pointerId)
  dragging.value = false
  dragPointerId = null
  if (shouldClose) close()
  dragOffset.value = 0
}

function shareToChat(kind: EasyShareChatApp, targetId: string): void {
  if (!appStore.isInstalled(kind)) return
  if (!easyShare.prepareChatDraft(kind, targetId)) return
  close()
  void router.push(`/apps/${kind}`)
}

function openChatApp(kind: EasyShareChatApp): void {
  if (!appStore.isInstalled(kind)) return
  if (!easyShare.prepareChatDraft(kind)) return
  close()
  void router.push(`/apps/${kind}`)
}

function openShareApp(appId: EasyShareDestinationApp): void {
  if (!appStore.isInstalled(appId)) return
  if (appId === 'messages' || appId === 'darkchat' || appId === 'flare') {
    openChatApp(appId)
    return
  }
  if (appId === 'notes') saveAsNote()
}

function saveAsNote(): void {
  if (!easyShare.payload) return
  const body = [
    easyShare.payload.copyText.trim(),
    easyShare.payload.link?.trim(),
  ]
    .filter((part): part is string => Boolean(part))
    .filter((part, index, parts) => parts.indexOf(part) === index)
    .join('\n')
  notes.createNote({
    body,
    title: easyShare.payload.title,
  })
  feedback.value = label('savedToNotes')
  window.setTimeout(close, 650)
}

async function requestTransfer(targetId: number): Promise<void> {
  const response = await easyShare.request(targetId)
  feedback.value = response.success
    ? label('requestSent')
    : label(`errors.${response.error ?? 'request_failed'}`)
}

async function respond(
  transfer: EasyShareTransfer,
  accepted: boolean,
): Promise<void> {
  if (!(await easyShare.respond(transfer.id, accepted))) {
    feedback.value = label('errors.request_failed')
  }
}

async function cancelTransfer(transfer: EasyShareTransfer): Promise<void> {
  if (!(await easyShare.cancel(transfer.id))) {
    feedback.value = label('errors.request_failed')
  }
}

async function openTransfer(transfer: EasyShareTransfer): Promise<void> {
  close()
  await openEasySharePayload(router, transfer.payload)
}

onMounted(() => window.addEventListener('keydown', onKeydown, true))
onBeforeUnmount(() => window.removeEventListener('keydown', onKeydown, true))
</script>

<template>
  <div
    class="easyshare-host"
    :class="{
      'easyshare-host--dragging': dragging,
      'easyshare-host--opened': easyShare.opened,
    }"
    :style="hostStyle"
  >
    <SkySheet
      :opened="easyShare.opened"
      :aria-label="label('name')"
      @backdropclick="close"
      @escape="close"
    >
      <div class="easyshare-panel">
        <div
          class="easyshare-grabber"
          role="button"
          tabindex="0"
          :aria-label="phone.t('Common.close')"
          @pointercancel="endDrag"
          @pointerdown="beginDrag"
          @pointermove="moveDrag"
          @pointerup="endDrag"
        ></div>
        <header class="easyshare-header">
          <img v-if="app?.iconImage" :src="app.iconImage" alt="" />
          <span v-else class="easyshare-header__fallback"><Share2 /></span>
          <div>
            <small>{{
              app ? getPhoneAppLabel(app, phone.t) : label('name')
            }}</small>
            <strong>{{ easyShare.payload?.title ?? label('incoming') }}</strong>
            <p>
              {{ easyShare.payload?.subtitle || easyShare.payload?.copyText }}
            </p>
          </div>
        </header>

        <template v-if="!easyShare.nearbyOpened && !easyShare.historyOpened">
          <section
            class="easyshare-row easyshare-row--people"
            :aria-label="label('recentChats')"
            @wheel="scrollRowHorizontally"
          >
            <button
              v-for="chat in sharePeople"
              :key="`${chat.kind}:${chat.targetId}`"
              type="button"
              class="easyshare-person"
              @click="shareToChat(chat.kind, chat.targetId)"
            >
              <span class="easyshare-avatar">
                <img v-if="chat.avatar" :src="chat.avatar" alt="" />
                <b v-else>{{ initials(chat.label) }}</b>
                <i><img :src="getPhoneApp(chat.kind)?.iconImage" alt="" /></i>
              </span>
              <small>{{ chat.label }}</small>
            </button>
            <button
              v-if="!sharePeople.length"
              type="button"
              class="easyshare-person"
              @click="openChatApp('messages')"
            >
              <span class="easyshare-avatar easyshare-avatar--empty"
                ><MessageCircle
              /></span>
              <small>{{ label('newMessage') }}</small>
            </button>
          </section>

          <section
            class="easyshare-row easyshare-row--actions"
            :aria-label="label('destinations')"
            @wheel="scrollRowHorizontally"
          >
            <button
              type="button"
              class="easyshare-action"
              @click="easyShare.showNearby"
            >
              <span
                class="easyshare-action__icon easyshare-action__icon--nearby"
                aria-hidden="true"
              ></span>
              <small>{{ label('name') }}</small>
            </button>
            <button
              v-for="destination in shareApps"
              :key="destination.id"
              type="button"
              class="easyshare-action"
              @click="openShareApp(destination.id)"
            >
              <span class="easyshare-action__app"
                ><img :src="destination.app.iconImage" alt=""
              /></span>
              <small>{{ getPhoneAppLabel(destination.app, phone.t) }}</small>
            </button>
            <button
              type="button"
              class="easyshare-action"
              @click="easyShare.showHistory"
            >
              <span class="easyshare-action__icon"><History /></span>
              <small>{{ label('history') }}</small>
            </button>
          </section>
        </template>

        <section v-else-if="easyShare.nearbyOpened" class="easyshare-detail">
          <div class="easyshare-detail__toolbar">
            <span aria-hidden="true"></span>
            <strong>{{ label('nearby') }}</strong>
            <SkyLink component="button" icon-only @click="easyShare.showHistory"
              ><History :size="18"
            /></SkyLink>
          </div>

          <SkyGlass
            v-if="easyShare.incomingTransfer"
            class="easyshare-incoming"
          >
            <UserRound :size="28" />
            <div>
              <strong>{{
                label('incomingFrom', {
                  name: easyShare.incomingTransfer.otherName,
                })
              }}</strong>
              <small>{{ easyShare.incomingTransfer.payload.title }}</small>
            </div>
            <div class="easyshare-incoming__actions">
              <SkyButton
                rounded
                tonal
                @click="respond(easyShare.incomingTransfer, false)"
                ><X
              /></SkyButton>
              <SkyButton
                rounded
                @click="respond(easyShare.incomingTransfer, true)"
                ><Check
              /></SkyButton>
            </div>
          </SkyGlass>

          <SkyGlass v-if="easyShare.activeTransfer" class="easyshare-transfer">
            <div>
              <strong>{{ easyShare.activeTransfer.otherName }}</strong>
              <small>{{ statusLabel(easyShare.activeTransfer) }}</small>
            </div>
            <div class="easyshare-progress">
              <i
                :style="{ width: `${easyShare.activeTransfer.progress}%` }"
              ></i>
            </div>
            <SkyButton
              v-if="
                ['pending', 'transferring'].includes(
                  easyShare.activeTransfer.status,
                )
              "
              clear
              rounded
              @click="cancelTransfer(easyShare.activeTransfer)"
              >{{ label('cancel') }}</SkyButton
            >
          </SkyGlass>

          <div v-if="easyShare.loading" class="easyshare-loading">
            <SkySpinner :label="label('name')" />
          </div>
          <SkyList
            v-else-if="easyShare.targets.length"
            inset
            strong
            class="easyshare-targets"
          >
            <SkyListItem
              v-for="target in easyShare.targets"
              :key="target.id"
              link
              :title="target.name"
              :subtitle="
                label('distance', { distance: String(target.distance) })
              "
              @click="requestTransfer(target.id)"
            >
              <template #media
                ><span><UserRound /></span
              ></template>
              <template #after><Share2 :size="18" /></template>
            </SkyListItem>
          </SkyList>
          <p v-else class="easyshare-empty">{{ label('noNearby') }}</p>
        </section>

        <section v-else class="easyshare-detail">
          <div class="easyshare-detail__toolbar">
            <SkyLink
              component="button"
              @click="easyShare.historyOpened = false"
              >{{ phone.t('Common.back') }}</SkyLink
            >
            <strong>{{ label('history') }}</strong>
            <span></span>
          </div>
          <SkyList inset strong class="easyshare-history">
            <SkyListItem
              v-for="transfer in easyShare.history"
              :key="transfer.id"
              link
              :title="transfer.payload.title"
              :subtitle="`${transfer.otherName} · ${statusLabel(transfer)}`"
              @click="openTransfer(transfer)"
            >
              <template #media
                ><span><Clock3 /></span
              ></template>
              <template #after>{{
                transfer.direction === 'incoming' ? '↓' : '↑'
              }}</template>
            </SkyListItem>
            <p v-if="!easyShare.history.length" class="easyshare-empty">
              {{ label('noHistory') }}
            </p>
          </SkyList>
        </section>

        <p v-if="feedback" class="easyshare-feedback">{{ feedback }}</p>
      </div>
    </SkySheet>
  </div>
</template>

<style scoped>
.easyshare-host {
  --easyshare-solid-surface: #1c1c1d;
  position: absolute;
  z-index: 95;
  inset: 0;
  overflow: hidden;
  border-radius: inherit;
  pointer-events: none;
  transform: translateZ(0);
}
:global(.phone-app--light) .easyshare-host {
  --easyshare-solid-surface: #fff;
}
.easyshare-host--opened {
  pointer-events: auto;
}
.easyshare-panel {
  position: relative;
  max-height: 78cqh;
  overflow: hidden;
  padding: 8px 14px calc(18px + var(--sky-safe-area-bottom));
  border-radius: var(--sky-radius-sheet) var(--sky-radius-sheet) 0 0;
  color: var(--sky-text);
  background: var(--easyshare-solid-surface) !important;
}
.easyshare-grabber {
  width: 38px;
  height: 5px;
  margin: 0 auto 10px;
  border-radius: 999px;
  background: var(--sky-muted);
  opacity: 0.55;
  cursor: grab;
  touch-action: none;
}
.easyshare-grabber:active {
  cursor: grabbing;
}
.easyshare-header {
  display: grid;
  grid-template-columns: 54px 1fr;
  align-items: center;
  gap: 11px;
  padding: 5px 2px 14px;
  border-bottom: 1px solid var(--sky-hairline);
}
.easyshare-header > img,
.easyshare-header__fallback {
  width: 54px;
  height: 54px;
  border-radius: 14px;
  display: grid;
  place-items: center;
  object-fit: cover;
  background: var(--sky-app-accent, #0a84ff);
  color: white;
}
.easyshare-header div {
  min-width: 0;
}
.easyshare-header small,
.easyshare-header strong,
.easyshare-header p {
  display: block;
  overflow: hidden;
  margin: 0;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.easyshare-header small {
  font-size: 11px;
  color: var(--sky-muted);
}
.easyshare-header strong {
  font-size: 17px;
}
.easyshare-header p {
  margin-top: 2px;
  font-size: 12px;
  color: var(--sky-muted);
}
.easyshare-row {
  display: flex;
  gap: 12px;
  overflow-x: auto;
  padding: 16px 2px;
  scrollbar-width: none;
}
.easyshare-row::-webkit-scrollbar {
  display: none;
}
.easyshare-row + .easyshare-row {
  border-top: 1px solid var(--sky-hairline);
}
.easyshare-row--people {
  min-height: 114px;
  align-items: flex-start;
}
.easyshare-person,
.easyshare-action {
  width: 68px;
  flex: 0 0 68px;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 7px;
  color: inherit;
  text-align: center;
}
.easyshare-person {
  min-height: 98px;
  gap: 14px;
}
.easyshare-person small,
.easyshare-action small {
  position: relative;
  z-index: 3;
  display: -webkit-box;
  width: 72px;
  max-height: 26px;
  min-height: 26px;
  overflow: hidden;
  font-size: 11px;
  line-height: 13px;
  text-overflow: ellipsis;
  overflow-wrap: anywhere;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
}
.easyshare-avatar {
  position: relative;
  isolation: isolate;
  width: 58px;
  height: 58px;
  flex: 0 0 58px;
  border-radius: 50%;
  display: grid;
  place-items: center;
  overflow: visible;
  background: linear-gradient(145deg, #6e6e73, #2c2c2e);
  color: white;
}
.easyshare-avatar > img {
  position: absolute;
  z-index: 0;
  inset: 0;
  display: block;
  width: 58px;
  height: 58px;
  max-width: none;
  border-radius: 50%;
  clip-path: circle(50% at 50% 50%);
  object-fit: cover;
}
.easyshare-avatar > b {
  position: relative;
  z-index: 1;
  font-size: 17px;
}
.easyshare-avatar > i {
  position: absolute;
  z-index: 2;
  right: -2px;
  bottom: -2px;
  width: 20px;
  height: 20px;
  border: 2px solid var(--easyshare-solid-surface);
  border-radius: 7px;
  display: grid;
  place-items: center;
  overflow: hidden;
  background: #34c759;
  color: white;
}
.easyshare-avatar > i img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.easyshare-action__icon,
.easyshare-action__app {
  width: 57px;
  height: 57px;
  border-radius: 15px;
  display: grid;
  place-items: center;
  background: var(--sky-surface-variant);
}
.easyshare-action__icon svg {
  width: 27px;
}
.easyshare-action__icon--nearby {
  background: radial-gradient(
    circle at 50% 70%,
    #0a84ff 0 15%,
    #142d59 16% 29%,
    #0a84ff 30% 35%,
    #101722 36%
  );
  color: white;
}
.easyshare-action__app img {
  width: 100%;
  height: 100%;
  border-radius: inherit;
  object-fit: cover;
}
.easyshare-detail {
  min-height: 245px;
  max-height: 56cqh;
  overflow-y: auto;
  padding-top: 8px;
}
.easyshare-detail__toolbar {
  height: 37px;
  display: grid;
  grid-template-columns: 1fr auto 1fr;
  align-items: center;
}
.easyshare-detail__toolbar > :last-child {
  justify-self: end;
}
.easyshare-visibility {
  display: flex;
  align-items: center;
  gap: 8px;
  margin: 8px 0 12px;
  padding: 10px 12px;
  border-radius: 14px;
  background: var(--sky-surface-variant);
}
.easyshare-visibility select {
  min-width: 0;
  flex: 1;
  border: 0;
  color: inherit;
  background: transparent;
  text-align: right;
}
.easyshare-incoming,
.easyshare-transfer {
  display: grid !important;
  grid-template-columns: auto 1fr;
  align-items: center;
  gap: 10px;
  margin: 10px 0;
  padding: 12px !important;
  border-radius: 18px !important;
}
.easyshare-incoming div,
.easyshare-transfer div {
  min-width: 0;
}
.easyshare-incoming small,
.easyshare-transfer small {
  display: block;
  color: var(--sky-muted);
}
.easyshare-incoming__actions {
  grid-column: 1/-1;
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 8px;
}
.easyshare-incoming__actions :deep(.sky-button) {
  margin: 0;
}
.easyshare-transfer {
  grid-template-columns: 1fr auto;
}
.easyshare-progress {
  grid-column: 1/-1;
  height: 6px;
  overflow: hidden;
  border-radius: 999px;
  background: var(--sky-surface-variant);
}
.easyshare-progress i {
  display: block;
  height: 100%;
  border-radius: inherit;
  background: var(--sky-accent);
  transition: width 0.25s ease;
}
.easyshare-targets {
  display: grid;
  gap: 7px;
}
.easyshare-targets button,
.easyshare-history article {
  display: grid;
  grid-template-columns: 42px 1fr auto;
  align-items: center;
  gap: 10px;
  padding: 9px 10px;
  border-radius: 14px;
  color: inherit;
  background: var(--sky-surface-variant);
  text-align: left;
}
.easyshare-targets button > span,
.easyshare-history article > span {
  width: 39px;
  height: 39px;
  border-radius: 50%;
  display: grid;
  place-items: center;
  background: var(--sky-accent);
  color: white;
}
.easyshare-targets strong,
.easyshare-targets small,
.easyshare-history strong,
.easyshare-history small {
  display: block;
}
.easyshare-targets small,
.easyshare-history small {
  color: var(--sky-muted);
  font-size: 11px;
}
.easyshare-history {
  display: grid;
  gap: 7px;
  padding-top: 8px;
}
.easyshare-empty,
.easyshare-loading {
  padding: 35px 10px;
  text-align: center;
  color: var(--sky-muted);
}
.easyshare-feedback {
  margin: 8px 0 0;
  text-align: center;
  color: var(--sky-accent);
  font-size: 12px;
}
.easyshare-host :deep(.sky-sheet) {
  z-index: 9500;
}
.easyshare-host :deep(.sky-sheet__panel) {
  max-height: 78cqh;
  overflow: hidden;
  background: var(--easyshare-solid-surface) !important;
}
.easyshare-host--dragging :deep(.sky-sheet__panel) {
  transform: translateY(var(--easyshare-drag-offset, 0px));
  transition-duration: 0ms;
}
.easyshare-panel {
  max-height: 645px;
}
.easyshare-detail {
  max-height: 463px;
}
.easyshare-targets button > div,
.easyshare-history article > div {
  min-width: 0;
}
.easyshare-targets strong,
.easyshare-targets small,
.easyshare-history strong,
.easyshare-history small {
  overflow-wrap: anywhere;
}
.easyshare-host {
  --easyshare-list-surface: #2c2c2e;
  --easyshare-text: #f5f5f7;
  --easyshare-secondary: #a1a1a6;
}
:global(.phone-app--light) .easyshare-host {
  --easyshare-list-surface: #f2f2f7;
  --easyshare-text: #171719;
  --easyshare-secondary: #6e6e73;
}
.easyshare-panel {
  color: var(--easyshare-text);
}
.easyshare-history {
  overflow: hidden;
  background: var(--easyshare-list-surface) !important;
  color: var(--easyshare-text) !important;
}
.easyshare-history :deep(.sky-list-item),
.easyshare-history :deep(.sky-list-item__row),
.easyshare-history :deep(.sky-list-item__title) {
  background: transparent !important;
  color: var(--easyshare-text) !important;
}
.easyshare-history :deep(.sky-list-item__subtitle),
.easyshare-history :deep(.sky-list-item__after),
.easyshare-history :deep(.sky-list-item__chevron) {
  color: var(--easyshare-secondary) !important;
}
@supports (container-type: size) {
  .easyshare-panel {
    max-height: 78cqh;
  }
  .easyshare-detail {
    max-height: 56cqh;
  }
}
.easyshare-action__icon--nearby {
  position: relative;
  overflow: hidden;
  background: #0c1524;
  box-shadow: inset 0 0 0 1px #ffffff0a;
}

.easyshare-action__icon--nearby::before {
  position: absolute;
  inset: 8px;
  border: 3px solid #1687ff;
  border-radius: 50%;
  box-shadow:
    inset 0 0 0 7px #0c1524,
    inset 0 0 0 10px #1687ff;
  content: '';
}

.easyshare-action__icon--nearby::after {
  position: absolute;
  top: 50%;
  left: 50%;
  width: 10px;
  height: 10px;
  border-radius: 50%;
  background: #1687ff;
  box-shadow: 0 0 9px #1687ff;
  content: '';
  transform: translate(-50%, -50%);
}
</style>
