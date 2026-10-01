<script setup lang="ts">
import { onBeforeMount, onBeforeUnmount, ref } from 'vue'
import { useRouter } from 'vue-router'
import CustomAppFrame from '@/components/CustomAppFrame.vue'
import { useAppCatalogStore } from '@/stores/app-catalog'
import { usePhoneStore } from '@/stores/phone'
import type { ExternalPhoneAppDefinition } from '@/types/apps'
import { SkyAppPage, SkyButton, SkyEmptyState, SkySpinner } from '@/ui'
import { getCustomAppAccessRequest } from '@/utils/customAppAccess'
import { nuiCall } from '@/utils/nui'

const props = defineProps<{ app: ExternalPhoneAppDefinition }>()
const phone = usePhoneStore()
const catalog = useAppCatalogStore()
const router = useRouter()
const authorized = ref(false)
const failed = ref(false)
let disposed = false
let actionOpened = false

onBeforeMount(async () => {
  const generation = phone.persistenceGeneration
  const session = phone.persistenceSession
  const response = await nuiCall(
    'custom-app:authorize',
    getCustomAppAccessRequest(
      props.app,
      phone.device?.imei,
      phone.deviceSessionToken,
    ),
  )
  if (
    disposed ||
    !phone.isOpen ||
    generation !== phone.persistenceGeneration ||
    session !== phone.persistenceSession
  )
    return
  if (!response.success) {
    console.error(
      `[Custom apps] Open rejected for ${props.app.id}: ${response.error ?? 'request_failed'}`,
    )
    failed.value = true
    return
  }
  if (props.app.launchMode !== 'action') {
    authorized.value = true
    return
  }
  const request = catalog.openRequests[props.app.id]
  const result = await nuiCall('custom-app:lifecycle', {
    appId: props.app.id,
    event: 'open',
    data: request?.data,
  })
  actionOpened = result.success
  if (disposed) {
    if (actionOpened)
      void nuiCall('custom-app:lifecycle', {
        appId: props.app.id,
        event: 'close',
      })
    return
  }
  if (request) catalog.consumeOpenRequest(props.app.id, request.sequence)
  if (!result.success) {
    console.error(
      `[Custom apps] Action failed for ${props.app.id}: ${result.error ?? 'request_failed'}`,
    )
    failed.value = true
  } else {
    void router.replace('/')
  }
})
onBeforeUnmount(() => {
  disposed = true
  if (actionOpened)
    void nuiCall('custom-app:lifecycle', {
      appId: props.app.id,
      event: 'close',
    })
})
</script>

<template>
  <CustomAppFrame v-if="authorized" :app="app" />
  <SkyAppPage v-else class="custom-app-host-state">
    <template v-if="failed">
      <SkyEmptyState
        :title="phone.t('Apps.customApps.unavailableTitle')"
        :body="phone.t('Apps.customApps.accessDenied')"
      />
      <SkyButton @click="router.push('/')">{{
        phone.t('Apps.customApps.close')
      }}</SkyButton>
    </template>
    <template v-else>
      <SkySpinner />
      <p role="status">{{ phone.t('Apps.customApps.loading') }}</p>
    </template>
  </SkyAppPage>
</template>

<style scoped>
.custom-app-host-state {
  align-items: center;
  justify-content: center;
  gap: var(--sky-space-4);
  padding: var(--sky-space-4);
}
</style>
