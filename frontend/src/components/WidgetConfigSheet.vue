<script setup lang="ts">
import { computed, ref, watch } from 'vue'

import SpringboardWidget from '@/components/SpringboardWidget.vue'
import { WIDGET_REGISTRY_BY_KIND } from '@/config/widgets'
import { useContactsService } from '@/services/widgetServices'
import { usePhoneStore } from '@/stores/phone'
import type {
  WidgetInstance,
  WidgetSettings,
  WidgetSize,
} from '@/types/widgets'
import {
  SkyButton,
  SkyProvider,
  SkyScrollArea,
  SkySegmented,
  SkySegmentedButton,
  SkySettingsGroup,
  SkySettingsRow,
  SkySheet,
} from '@/ui'

const props = defineProps<{
  instance: WidgetInstance | null
  opened: boolean
}>()
const emit = defineEmits<{
  close: []
  save: [size: WidgetSize, settings: WidgetSettings]
}>()
const phone = usePhoneStore()
const contactsService = useContactsService(
  computed(() => props.opened && props.instance?.kind === 'contacts'),
)
const size = ref<WidgetSize>('small')
const showDate = ref(true)
const balanceSource = ref<'bank' | 'cash'>('bank')
const contactIds = ref<string[]>([])
const supportedSizes = computed(
  () =>
    (props.instance &&
      WIDGET_REGISTRY_BY_KIND.get(props.instance.kind)?.supportedSizes) ||
    [],
)
const activeSizeIndex = computed(() =>
  Math.max(0, supportedSizes.value.indexOf(size.value)),
)

function toggleContact(id: string): void {
  const index = contactIds.value.indexOf(id)
  if (index !== -1) contactIds.value.splice(index, 1)
  else if (contactIds.value.length < 6) contactIds.value.push(id)
}

function save(): void {
  emit('save', size.value, {
    balanceSource: balanceSource.value,
    contactIds: contactIds.value,
    showDate: showDate.value,
  })
}

watch(
  [() => props.opened, () => props.instance],
  ([opened, instance]) => {
    if (!opened || !instance) return
    size.value = instance.size
    showDate.value = instance.settings.showDate !== false
    balanceSource.value = instance.settings.balanceSource ?? 'bank'
    contactIds.value = [...(instance.settings.contactIds ?? [])]
  },
  { immediate: true },
)
</script>

<template>
  <SkyProvider
    class="widget-config-provider"
    :dark="phone.isDarkMode"
    safe-areas
  >
    <SkySheet
      class="widget-config-sheet"
      :opened="opened"
      :aria-label="phone.t('Home.widgetSystem.configure')"
      grabber-clickable
      :grabber-label="phone.t('Common.cancel')"
      swipe-to-close
      @backdropclick="emit('close')"
      @escape="emit('close')"
      @grabberclick="emit('close')"
      @swipeclose="emit('close')"
    >
      <section v-if="instance" class="widget-config-surface">
        <header class="widget-config-navbar">
          <SkyButton
            class="widget-config-nav-button"
            inline
            rounded
            type="button"
            variant="secondary"
            @click="emit('close')"
          >
            {{ phone.t('Common.cancel') }}
          </SkyButton>
          <h2>{{ phone.t('Home.widgetSystem.configure') }}</h2>
          <SkyButton
            class="widget-config-nav-button"
            inline
            rounded
            type="button"
            variant="secondary"
            @click="save"
          >
            {{ phone.t('Common.done') }}
          </SkyButton>
        </header>

        <SkyScrollArea class="widget-config-scroll">
          <div class="widget-config-preview">
            <SpringboardWidget
              :instance="{ ...instance, size }"
              preview
              :interactive="false"
            />
          </div>

          <section class="widget-config-size">
            <h3>{{ phone.t('Home.widgetSystem.size') }}</h3>
            <SkySegmented
              :active-index="activeSizeIndex"
              :aria-label="phone.t('Home.widgetSystem.size')"
              :item-count="supportedSizes.length"
              rounded
              strong
            >
              <SkySegmentedButton
                v-for="supportedSize in supportedSizes"
                :key="supportedSize"
                :active="size === supportedSize"
                @click="size = supportedSize"
              >
                {{ phone.t(`Home.widgetSystem.sizes.${supportedSize}`) }}
              </SkySegmentedButton>
            </SkySegmented>
          </section>

          <SkySettingsGroup
            v-if="instance.kind === 'clock'"
            class="widget-config-group"
            :aria-label="phone.t('Home.widgetSystem.clock.name')"
          >
            <SkySettingsRow
              v-model="showDate"
              kind="toggle"
              :title="phone.t('Home.widgetSystem.clock.showDate')"
            />
          </SkySettingsGroup>

          <SkySettingsGroup
            v-if="instance.kind === 'wallet'"
            class="widget-config-group"
            :aria-label="phone.t('Home.widgetSystem.wallet.balance')"
          >
            <SkySettingsRow
              kind="custom"
              :title="phone.t('Home.widgetSystem.wallet.balance')"
            >
              <template #trailing>
                <SkySegmented
                  :active-index="balanceSource === 'bank' ? 0 : 1"
                  :aria-label="phone.t('Home.widgetSystem.wallet.balance')"
                  class="widget-config-balance"
                  :item-count="2"
                  rounded
                  strong
                >
                  <SkySegmentedButton
                    :active="balanceSource === 'bank'"
                    @click="balanceSource = 'bank'"
                  >
                    {{ phone.t('Home.widgetSystem.wallet.bank') }}
                  </SkySegmentedButton>
                  <SkySegmentedButton
                    :active="balanceSource === 'cash'"
                    @click="balanceSource = 'cash'"
                  >
                    {{ phone.t('Home.widgetSystem.wallet.cash') }}
                  </SkySegmentedButton>
                </SkySegmented>
              </template>
            </SkySettingsRow>
          </SkySettingsGroup>

          <SkySettingsGroup
            v-if="instance.kind === 'contacts'"
            class="widget-config-group"
            :title="phone.t('Home.widgetSystem.contacts.choose')"
          >
            <SkySettingsRow
              v-for="contact in contactsService.contacts.value"
              :key="contact.id"
              kind="choice"
              :description="contact.phone_number"
              :selected="contactIds.includes(contact.id)"
              :title="contact.name"
              @activate="toggleContact(contact.id)"
            >
              <template #leading>
                <span class="widget-config-avatar">{{
                  contact.name.charAt(0).toUpperCase()
                }}</span>
              </template>
            </SkySettingsRow>
          </SkySettingsGroup>
        </SkyScrollArea>
      </section>
    </SkySheet>
  </SkyProvider>
</template>

<style scoped>
.widget-config-provider {
  position: absolute;
  z-index: 115;
  inset: 0;
  pointer-events: none;
}

.widget-config-sheet {
  --sky-overlay-layer: 115;
}

.widget-config-sheet :deep(.sky-overlay-backdrop) {
  background: rgb(0 0 0 / 58%);
}

.widget-config-sheet :deep(.sky-sheet__panel) {
  height: calc(100% - var(--sky-space-3));
  max-height: calc(100% - var(--sky-space-3));
  overflow: hidden;
  background: var(--sky-bg);
}

.widget-config-surface {
  height: calc(100% - 32px);
  min-height: 0;
  display: flex;
  flex-direction: column;
  background: var(--sky-bg);
  color: var(--sky-text);
}

.widget-config-navbar {
  min-height: 56px;
  display: grid;
  grid-template-columns: minmax(72px, 1fr) minmax(0, 2fr) minmax(72px, 1fr);
  align-items: center;
  gap: var(--sky-space-2);
  padding: 0 var(--sky-space-3);
  border-bottom: 1px solid var(--sky-hairline);
}

.widget-config-navbar h2 {
  overflow: hidden;
  margin: 0;
  color: var(--sky-text);
  font-size: var(--sky-font-title);
  font-weight: 650;
  text-align: center;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.widget-config-navbar > :first-child {
  justify-self: start;
}

.widget-config-navbar > :last-child {
  justify-self: end;
}

.widget-config-navbar :deep(.widget-config-nav-button.sky-button) {
  min-height: var(--sky-touch-target);
  padding: 0 var(--sky-space-4);
  border: 1px solid var(--sky-action-border);
  background: var(--sky-action-surface);
  color: #fff;
  font-size: 15px;
  font-weight: 600;
}

.widget-config-navbar :deep(.widget-config-nav-button.sky-button:active) {
  background: var(--sky-action-pressed);
}

.widget-config-scroll {
  min-height: 0;
  flex: 1;
  overflow-y: auto;
  padding: var(--sky-space-3) var(--sky-page-gutter)
    calc(var(--sky-space-6) + var(--sky-safe-area-bottom));
}

.widget-config-preview {
  display: flex;
  min-height: 250px;
  padding: var(--sky-space-4) 0;
  align-items: center;
  justify-content: center;
}

.widget-config-size {
  margin-bottom: var(--sky-space-5);
}

.widget-config-size h3 {
  margin: 0 0 var(--sky-space-2) var(--sky-space-3);
  color: var(--sky-muted);
  font-size: var(--sky-font-caption);
  font-weight: 600;
  text-transform: uppercase;
}

.widget-config-size :deep(.sky-segmented) {
  width: 100%;
}

.widget-config-group {
  margin: 0 0 var(--sky-space-5);
}

.widget-config-balance {
  width: 146px;
}

.widget-config-avatar {
  display: grid;
  width: 38px;
  height: 38px;
  place-items: center;
  border-radius: 50%;
  color: #fff;
  background: #5e5ce6;
  font-weight: 650;
}

@media (max-height: 700px) {
  .widget-config-preview {
    min-height: 205px;
  }
}
</style>
