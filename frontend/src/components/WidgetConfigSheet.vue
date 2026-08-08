<script setup lang="ts">
import { Check } from 'lucide-vue-next'
import {
  kLink,
  kList,
  kListItem,
  kNavbar,
  kPage,
  kSegmented,
  kSegmentedButton,
  kSheet,
  kToggle,
} from 'konsta/vue'
import { ref, watch } from 'vue'

import SpringboardWidget from '@/components/SpringboardWidget.vue'
import { WIDGET_REGISTRY_BY_KIND } from '@/config/widgets'
import { useContactsService } from '@/services/widgetServices'
import { usePhoneStore } from '@/stores/phone'
import type {
  WidgetInstance,
  WidgetSettings,
  WidgetSize,
} from '@/types/widgets'

const props = defineProps<{
  instance: WidgetInstance | null
  opened: boolean
}>()
const emit = defineEmits<{
  close: []
  save: [size: WidgetSize, settings: WidgetSettings]
}>()
const phone = usePhoneStore()
const contactsService = useContactsService()
const size = ref<WidgetSize>('small')
const showDate = ref(true)
const balanceSource = ref<'bank' | 'cash'>('bank')
const contactIds = ref<string[]>([])
const sheetColors = {
  bgIos: 'bg-[#f2f2f7] dark:bg-black',
}

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
  <k-sheet
    :opened="opened"
    class="widget-config-sheet"
    :colors="sheetColors"
    @backdropclick="emit('close')"
  >
    <k-page
      v-if="instance"
      class="widget-config-page"
      :class="{ 'widget-config-page--dark': phone.isDarkMode }"
    >
      <k-navbar :title="phone.t('Home.widgetSystem.configure')">
        <template #left>
          <k-link component="button" type="button" @click="emit('close')">
            {{ phone.t('Common.cancel') }}
          </k-link>
        </template>
        <template #right>
          <k-link component="button" type="button" @click="save">
            {{ phone.t('Common.done') }}
          </k-link>
        </template>
      </k-navbar>

      <div class="widget-config-scroll">
        <div class="widget-config-preview">
          <SpringboardWidget
            :instance="{ ...instance, size }"
            preview
            :interactive="false"
          />
        </div>

        <section class="widget-config-size">
          <span>{{ phone.t('Home.widgetSystem.size') }}</span>
          <k-segmented raised>
            <k-segmented-button
              v-for="supportedSize in WIDGET_REGISTRY_BY_KIND.get(instance.kind)
                ?.supportedSizes"
              :key="supportedSize"
              :active="size === supportedSize"
              @click="size = supportedSize"
            >
              {{ phone.t(`Home.widgetSystem.sizes.${supportedSize}`) }}
            </k-segmented-button>
          </k-segmented>
        </section>

        <k-list
          v-if="instance.kind === 'clock'"
          inset
          strong
          class="widget-config-list"
        >
          <k-list-item :title="phone.t('Home.widgetSystem.clock.showDate')">
            <template #after>
              <k-toggle :checked="showDate" @change="showDate = !showDate" />
            </template>
          </k-list-item>
        </k-list>

        <k-list
          v-if="instance.kind === 'wallet'"
          inset
          strong
          class="widget-config-list"
        >
          <k-list-item :title="phone.t('Home.widgetSystem.wallet.balance')">
            <template #after>
              <k-segmented class="widget-config-balance">
                <k-segmented-button
                  :active="balanceSource === 'bank'"
                  @click="balanceSource = 'bank'"
                >
                  {{ phone.t('Home.widgetSystem.wallet.bank') }}
                </k-segmented-button>
                <k-segmented-button
                  :active="balanceSource === 'cash'"
                  @click="balanceSource = 'cash'"
                >
                  {{ phone.t('Home.widgetSystem.wallet.cash') }}
                </k-segmented-button>
              </k-segmented>
            </template>
          </k-list-item>
        </k-list>

        <section v-if="instance.kind === 'contacts'">
          <h3>{{ phone.t('Home.widgetSystem.contacts.choose') }}</h3>
          <k-list inset strong class="widget-config-list">
            <k-list-item
              v-for="contact in contactsService.contacts.value"
              :key="contact.id"
              link
              link-component="button"
              :title="contact.name"
              :subtitle="contact.phone_number"
              @click="toggleContact(contact.id)"
            >
              <template #media>
                <span class="widget-config-avatar">{{
                  contact.name.charAt(0).toUpperCase()
                }}</span>
              </template>
              <template v-if="contactIds.includes(contact.id)" #after>
                <Check :size="20" class="widget-config-check" />
              </template>
            </k-list-item>
          </k-list>
        </section>
      </div>
    </k-page>
  </k-sheet>
</template>

<style scoped>
:global(.widget-config-sheet) {
  z-index: 115;
  height: calc(100% - 22px);
  overflow: hidden;
  border-radius: 28px 28px 0 0;
}

.widget-config-page {
  height: 100%;
  color: #111;
  background: #f2f2f7;
}

.widget-config-page--dark {
  color: #fff;
  background: #000;
}

.widget-config-scroll {
  height: calc(100% - 54px);
  padding: 8px 12px 42px;
  overflow-y: auto;
  scrollbar-width: none;
}

.widget-config-scroll::-webkit-scrollbar {
  display: none;
}

.widget-config-preview {
  display: flex;
  min-height: 215px;
  padding: 20px 12px;
  align-items: center;
  justify-content: center;
}

.widget-config-preview :deep(.home-widget-shell) {
  max-height: 188px;
}

.widget-config-size {
  display: grid;
  margin: 0 4px 16px;
  grid-template-columns: auto 1fr;
  align-items: center;
  gap: 12px;
}

.widget-config-size > span,
.widget-config-scroll h3 {
  color: #6e6e73;
  font-size: 13px;
  font-weight: 600;
}

.widget-config-scroll h3 {
  margin: 18px 14px 7px;
}

.widget-config-list :deep([class*='title']) {
  color: inherit;
}

.widget-config-balance {
  width: 138px;
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

.widget-config-check {
  color: #0a84ff;
}
</style>
