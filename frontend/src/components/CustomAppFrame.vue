<script setup lang="ts">
import {
  SkyAppPage as kPage,
  SkyBlock as kBlock,
  SkyButton as kButton,
  SkySpinner as kPreloader,
} from '@/ui'
import { computed, onBeforeMount, onBeforeUnmount, ref, watch } from 'vue'
import { useRouter } from 'vue-router'

import { getPhoneApp, isExternalPhoneApp } from '@/config/apps'
import { useAppCatalogStore } from '@/stores/app-catalog'
import { useCallsStore } from '@/stores/calls'
import { useMessagesStore } from '@/stores/messages'
import { useNotificationsStore } from '@/stores/notifications'
import { usePhoneStore } from '@/stores/phone'
import type {
  CustomAppOpenRequest,
  ExternalPhoneAppDefinition,
  LaunchablePhoneAppId,
  SkyPhoneAppBridgeRequest,
  SkyPhoneAppBridgeResponse,
  SkyPhoneAppContextV1,
} from '@/types/apps'
import {
  createCustomAppBridgeRequestHandler,
  getCustomAppFrameBootstrapMessages,
  getSkyPhoneAppCapabilities,
  shouldReportCustomAppReady,
} from '@/utils/customAppBridge'
import {
  createCustomAppLifecycleReporter,
  customAppOrientationCoordinator,
  customAppLifecycleScheduler,
  getCustomAppSafeArea,
} from '@/utils/customAppLifecycle'
import {
  LB_PHONE_STORAGE_MESSAGE_TYPE,
  LB_PHONE_ACTION_MESSAGE_TYPE,
  createLbPhoneFrameDocument,
  createLbPhoneHostSettings,
  getLbPhoneCallbackResource,
  readLbPhoneStorage,
  usesLbPhoneHostRuntime,
  writeLbPhoneStorage,
} from '@/utils/lbPhoneAppBridge'
import { cloneJsonData } from '@/utils/clone'
import { nuiCall } from '@/utils/nui'
import type { PhoneCall } from '@/types/phone'

const props = defineProps<{
  app: ExternalPhoneAppDefinition
}>()

const PROTOCOL_VERSION = 1

const catalog = useAppCatalogStore()
const calls = useCallsStore()
const messages = useMessagesStore()
const notifications = useNotificationsStore()
const phone = usePhoneStore()
const router = useRouter()
const frame = ref<HTMLIFrameElement | null>(null)
const frameLoaded = ref(false)
const frameUnavailable = ref(false)
const skyBridgeReady = ref(false)
const lbFrameDocument = ref<string | null>(null)
let loadTimeout: ReturnType<typeof setTimeout> | undefined
let frameDocumentController: AbortController | undefined
const lifecycleAppId = props.app.id
const initialOpenRequest: CustomAppOpenRequest | undefined =
  catalog.openRequests[lifecycleAppId]
const orientation = customAppOrientationCoordinator.createSession((landscape) =>
  phone.setCameraLandscape(landscape),
)

const lifecycle = createCustomAppLifecycleReporter({
  onFailure(event, error) {
    console.error(
      `[Custom apps] ${event} lifecycle failed for ${lifecycleAppId}: ${error}`,
    )
  },
  scheduler: customAppLifecycleScheduler,
  send: (event, data) =>
    nuiCall('custom-app:lifecycle', {
      appId: lifecycleAppId,
      ...(data === undefined ? {} : { data }),
      event,
    }),
})

const bridgeRequests = createCustomAppBridgeRequestHandler({
  createNotification(notification) {
    return notifications.show({
      ...notification,
      appId: notification.appId as LaunchablePhoneAppId,
    })
  },
  getSourceApp: () => props.app,
  prepareExternalOpen: (appId, data) => catalog.requestOpen(appId, data),
  resolveTarget(appId) {
    const target = getPhoneApp(appId)
    return target
      ? {
          external: isExternalPhoneApp(target),
          id: target.id,
          route: target.route,
        }
      : null
  },
  storageCall: (endpoint, payload) => nuiCall(endpoint, payload),
})

const frameUrl = computed(() => {
  const url = new URL(props.app.ui)
  url.searchParams.set('skyPhoneAppId', props.app.id)
  return url.href
})
const frameOrigin = computed(() => new URL(frameUrl.value).origin)
const lbHostRuntime = computed(() => usesLbPhoneHostRuntime(props.app))
const frameMountable = computed(
  () => !lbHostRuntime.value || lbFrameDocument.value !== null,
)
const frameSource = computed(() =>
  lbHostRuntime.value ? undefined : frameUrl.value,
)
const postMessageOrigin = computed(() =>
  props.app.bundled || lbHostRuntime.value ? '*' : frameOrigin.value,
)
const sandbox = computed(() =>
  props.app.bundled || lbHostRuntime.value
    ? 'allow-downloads allow-forms allow-modals allow-scripts'
    : 'allow-downloads allow-forms allow-modals allow-same-origin allow-scripts',
)
const frameReady = computed(
  () =>
    frameLoaded.value &&
    (props.app.bridgeMode === 'legacy' || skyBridgeReady.value),
)
const context = computed<SkyPhoneAppContextV1>(() => {
  const capabilities = getSkyPhoneAppCapabilities(props.app.capabilities)
  return {
    appId: props.app.id,
    capabilities,
    ...(capabilities.includes('theme.read')
      ? { colorScheme: phone.isDarkMode ? ('dark' as const) : ('light' as const) }
      : {}),
    ...(capabilities.includes('locale.read')
      ? {
          language: phone.lang,
          locale: {
            description: props.app.description,
            name: props.app.name,
          },
        }
      : {}),
    phoneScale: phone.preferences.settings.phoneScale / 100,
    protocolVersion: PROTOCOL_VERSION,
    safeArea: getCustomAppSafeArea(props.app.orientation),
  }
})
const lbSettings = computed(() =>
  createLbPhoneHostSettings({
    deviceName: phone.device?.name ?? '',
    isDarkMode: phone.isDarkMode,
    language: phone.lang,
    preferences: phone.preferences,
    securityEnabled: phone.security.enabled,
  }),
)

function postToFrame(payload: unknown): boolean {
  const target = frame.value?.contentWindow
  if (!target) return false

  try {
    target.postMessage(cloneJsonData(payload), postMessageOrigin.value)
    return true
  } catch (error) {
    console.error(`[Custom apps] Could not message ${props.app.id}.`, error)
    return false
  }
}

function queueReadyLifecycle(): void {
  void lifecycle.report('open', initialOpenRequest?.data)
  void lifecycle.report('ready')
}

function sendContext(): void {
  if (!skyBridgeReady.value) return
  postToFrame({
    appId: props.app.id,
    context: context.value,
    protocolVersion: PROTOCOL_VERSION,
    type: 'sky-phone-app:context',
  })
}

function sendLbSettings(): void {
  if (!lbHostRuntime.value || !frameLoaded.value) return
  postToFrame({
    settings: lbSettings.value,
    type: 'sky-phone:lb-settings',
  })
}

async function prepareLbFrameDocument(): Promise<void> {
  const controller = new AbortController()
  frameDocumentController = controller
  try {
    let appStorage = {}
    try {
      appStorage = readLbPhoneStorage(window.localStorage, props.app.id)
    } catch (error) {
      console.error(
        `[Custom apps] Could not read LB Phone storage for ${props.app.id}.`,
        error,
      )
    }

    const response = await fetch(frameUrl.value, {
      credentials: 'omit',
      signal: controller.signal,
    })
    if (!response.ok) {
      throw new Error(`${response.status} ${response.statusText}`)
    }
    const html = await response.text()
    lbFrameDocument.value = createLbPhoneFrameDocument(html, {
      appName: props.app.id,
      localStorage: appStorage,
      resourceName: getLbPhoneCallbackResource(props.app),
      settings: lbSettings.value,
      ui: props.app.ui,
    })
  } catch (error) {
    if (controller.signal.aborted) return
    if (loadTimeout !== undefined) clearTimeout(loadTimeout)
    loadTimeout = undefined
    frameUnavailable.value = true
    console.error(
      `[Custom apps] Could not prepare LB Phone frame ${props.app.id}.`,
      error,
    )
  }
}

function flushOpenRequest(): void {
  const request = catalog.openRequests[props.app.id]
  if (!request || !frameLoaded.value) return
  if (props.app.bridgeMode === 'sky' && !skyBridgeReady.value) return

  if (
    props.app.bridgeMode === 'legacy' ||
    postToFrame({
      appId: props.app.id,
      data: request.data,
      protocolVersion: PROTOCOL_VERSION,
      type: 'sky-phone-app:open',
    })
  ) {
    catalog.consumeOpenRequest(props.app.id, request.sequence)
  }
}

function flushHostMessages(): void {
  if (!frameLoaded.value) return
  if (props.app.bridgeMode === 'sky' && !skyBridgeReady.value) return

  let lastDeliveredSequence = 0
  for (const message of catalog.hostMessages[props.app.id] ?? []) {
    const delivered = postToFrame(
      props.app.bridgeMode === 'sky'
        ? {
            appId: props.app.id,
            payload: message.payload,
            protocolVersion: PROTOCOL_VERSION,
            type: 'sky-phone-app:message',
          }
        : message.payload,
    )
    if (!delivered) break
    lastDeliveredSequence = message.sequence
  }
  if (lastDeliveredSequence) {
    catalog.consumeHostMessages(props.app.id, lastDeliveredSequence)
  }
}

function sendResponse(response: SkyPhoneAppBridgeResponse): void {
  postToFrame({
    appId: props.app.id,
    ...response,
    protocolVersion: PROTOCOL_VERSION,
    type: 'sky-phone-app:response',
  })
}

async function handleBridgeRequest(
  request: SkyPhoneAppBridgeRequest,
): Promise<void> {
  const result = await bridgeRequests.handle(request)
  if (!result) return

  sendResponse(result.response)
  if (result.effect?.type === 'close') {
    void router.push('/')
  } else if (result.effect?.type === 'open') {
    void router.push(result.effect.route)
  }
}

async function handleLbPhoneAction(message: Record<string, unknown>) {
  if (message.action === 'createCall') {
    const options = message.options
    if (!options || typeof options !== 'object' || Array.isArray(options)) {
      console.error(
        `[Custom apps] Rejected invalid LB call action from ${props.app.id}.`,
      )
      return
    }
    const target = options as Record<string, unknown>
    if (
      typeof target.number !== 'string' &&
      typeof target.company !== 'string'
    ) {
      console.error(
        `[Custom apps] Rejected invalid LB call target from ${props.app.id}.`,
      )
      return
    }
    const response = await nuiCall<PhoneCall>('calls:dial', {
      company: target.company,
      phoneNumber: target.number,
    })
    if (response.success && response.data) calls.applyCallState(response.data)
    return
  }

  if (message.action === 'createSMS') {
    const options = message.options
    const phoneNumber =
      typeof options === 'string'
        ? options
        : options && typeof options === 'object' && !Array.isArray(options)
          ? ((options as Record<string, unknown>).number ??
            (options as Record<string, unknown>).phoneNumber)
          : undefined
    if (
      typeof phoneNumber !== 'string' ||
      !(await messages.openThread(phoneNumber))
    ) {
      console.error(
        `[Custom apps] Rejected invalid LB SMS target from ${props.app.id}.`,
      )
      return
    }
    void router.push('/apps/messages')
  }
}

function isTrustedFrameMessage(event: MessageEvent): boolean {
  if (event.source !== frame.value?.contentWindow) return false
  if (props.app.bundled || lbHostRuntime.value) {
    return event.origin === 'null' || event.origin === frameOrigin.value
  }
  return event.origin === frameOrigin.value
}

function onFrameMessage(event: MessageEvent): void {
  if (!isTrustedFrameMessage(event)) return
  if (
    !event.data ||
    typeof event.data !== 'object' ||
    Array.isArray(event.data)
  ) {
    return
  }

  const message = event.data as Record<string, unknown>
  if (
    message.appId !== props.app.id ||
    message.protocolVersion !== PROTOCOL_VERSION
  ) {
    return
  }

  if (message.type === LB_PHONE_STORAGE_MESSAGE_TYPE) {
    try {
      if (
        !writeLbPhoneStorage(window.localStorage, props.app.id, message.storage)
      ) {
        console.error(
          `[Custom apps] Rejected invalid LB Phone storage for ${props.app.id}.`,
        )
      }
    } catch (error) {
      console.error(
        `[Custom apps] Could not persist LB Phone storage for ${props.app.id}.`,
        error,
      )
    }
    return
  }

  if (message.type === LB_PHONE_ACTION_MESSAGE_TYPE) {
    void handleLbPhoneAction(message)
    return
  }

  if (message.type === 'sky-phone-app:ready') {
    if (!skyBridgeReady.value) {
      if (loadTimeout !== undefined) clearTimeout(loadTimeout)
      loadTimeout = undefined
      skyBridgeReady.value = true
      frameUnavailable.value = false
      sendContext()
      flushOpenRequest()
      flushHostMessages()
    }
    if (shouldReportCustomAppReady(props.app.bridgeMode, 'bridge-ready')) {
      queueReadyLifecycle()
    }
    return
  }

  if (message.type === 'sky-phone-app:request') {
    void handleBridgeRequest(message as unknown as SkyPhoneAppBridgeRequest)
  }
}

function onFrameLoad(): void {
  if (props.app.bridgeMode === 'legacy') {
    if (loadTimeout !== undefined) clearTimeout(loadTimeout)
    loadTimeout = undefined
  }
  frameLoaded.value = true
  for (const message of getCustomAppFrameBootstrapMessages(
    props.app.compatibility,
  )) {
    postToFrame(message)
  }
  sendLbSettings()
  if (props.app.bridgeMode === 'legacy' || skyBridgeReady.value) {
    frameUnavailable.value = false
  }
  if (shouldReportCustomAppReady(props.app.bridgeMode, 'frame-load')) {
    queueReadyLifecycle()
  }
  flushOpenRequest()
  flushHostMessages()
}

function closeApp(): void {
  void router.push('/')
}

onBeforeMount(() => {
  window.addEventListener('message', onFrameMessage)
  orientation.apply(props.app.orientation)
  void lifecycle.report('open', initialOpenRequest?.data)
  if (props.app.bridgeMode === 'legacy' && initialOpenRequest) {
    catalog.consumeOpenRequest(props.app.id, initialOpenRequest.sequence)
  }
  loadTimeout = setTimeout(() => {
    loadTimeout = undefined
    frameUnavailable.value = true
    console.error(
      `[Custom apps] Frame readiness timed out for ${props.app.id}.`,
    )
  }, props.app.readyTimeoutMs)
  if (lbHostRuntime.value) void prepareLbFrameDocument()
})

onBeforeUnmount(() => {
  if (loadTimeout !== undefined) clearTimeout(loadTimeout)
  frameDocumentController?.abort()
  window.removeEventListener('message', onFrameMessage)
  orientation.release()
  void lifecycle.report('close')
})

watch(context, sendContext, { deep: true })
watch(lbSettings, sendLbSettings, { deep: true })
watch(
  () => props.app.orientation,
  (nextOrientation) => orientation.apply(nextOrientation),
)
watch(() => catalog.hostMessages[props.app.id], flushHostMessages, {
  deep: true,
})
watch(() => catalog.openRequests[props.app.id], flushOpenRequest, {
  deep: true,
})
</script>

<template>
  <k-page
    component="main"
    class="custom-app-page"
    :class="{
      'custom-app-page--landscape': app.orientation === 'landscape',
    }"
  >
    <iframe
      v-if="frameMountable"
      ref="frame"
      v-show="frameReady && !frameUnavailable"
      class="custom-app-frame"
      :class="{
        'custom-app-frame--fix-blur': app.compatibility.fixBlur === true,
      }"
      :sandbox="sandbox"
      :src="frameSource"
      :srcdoc="lbFrameDocument ?? undefined"
      :title="app.name"
      referrerpolicy="no-referrer"
      @load="onFrameLoad"
    />

    <div
      v-if="!frameReady && !frameUnavailable"
      class="custom-app-state"
      role="status"
    >
      <k-preloader />
      <k-block>{{ phone.t('Apps.customApps.loading') }}</k-block>
    </div>

    <div v-else-if="frameUnavailable" class="custom-app-state" role="alert">
      <k-block>
        <strong>{{ phone.t('Apps.customApps.unavailableTitle') }}</strong>
        <p>{{ phone.t('Apps.customApps.unavailableBody') }}</p>
      </k-block>
      <k-button rounded @click="closeApp">
        {{ phone.t('Apps.customApps.close') }}
      </k-button>
    </div>
  </k-page>
</template>

<style scoped>
.custom-app-page {
  position: absolute;
  inset: 0;
  overflow: hidden;
  background: var(--phone-app-background, #000);
}

.custom-app-page--landscape {
  top: 50%;
  right: auto;
  bottom: auto;
  left: 50%;
  width: 827px;
  height: 368px;
  width: 100cqh;
  height: 100cqw;
  transform: translate(-50%, -50%) rotate(90deg);
}

.custom-app-frame {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  border: 0;
  background: transparent;
}

.custom-app-frame--fix-blur {
  transform: translateZ(0);
}

.custom-app-state {
  position: absolute;
  inset: 44px 20px 25px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 14px;
  text-align: center;
}

.custom-app-state :deep(.sky-block) {
  margin: 0;
}

.custom-app-state strong {
  display: block;
  margin-bottom: 7px;
  font-size: 17px;
}

.custom-app-state p {
  margin: 0;
  color: rgb(142 142 147);
  font-size: 13px;
  line-height: 1.35;
}
</style>
