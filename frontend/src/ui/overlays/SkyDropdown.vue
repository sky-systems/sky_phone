<script setup lang="ts">
import SkyIcon from '../controls/SkyIcon.vue'

import { Check, ChevronRight } from 'lucide-vue-next'
import { computed } from 'vue'

import SkyPopover from './SkyPopover.vue'

defineOptions({ inheritAttrs: false })

interface SkyDropdownItem {
  checked?: boolean
  destructive?: boolean
  disabled?: boolean
  group?: string
  groupLabel?: string
  id: string
  label: string
  separatorBefore?: boolean
  submenu?: boolean
}

const props = withDefaults(
  defineProps<{
    items: readonly SkyDropdownItem[]
    label: string
    motion?: 'fade' | 'spring'
    opened: boolean
    placement?: 'auto' | 'bottom' | 'left' | 'right' | 'top'
    singleLine?: boolean
    target: HTMLElement | string | null
  }>(),
  {
    placement: 'bottom',
    motion: 'spring',
    singleLine: false,
  },
)

const emit = defineEmits<{
  backdropclick: [event: MouseEvent]
  escape: [event: KeyboardEvent]
  positionerror: [reason: string]
  select: [id: string, event: MouseEvent]
}>()

const actionOnly = computed(() =>
  props.items.every((item) => item.checked === undefined && !item.submenu),
)

const menuSections = computed(() => {
  const sections: Array<{
    group: string | null
    items: SkyDropdownItem[]
    key: string
    label?: string
  }> = []

  props.items.forEach((item) => {
    const group = item.group ?? null
    const previous = sections[sections.length - 1]
    if (!previous || previous.group !== group) {
      sections.push({
        group,
        items: [item],
        key: `${group ?? 'items'}:${sections.length}`,
        label: item.groupLabel,
      })
      return
    }

    previous.items.push(item)
  })

  return sections
})
</script>

<template>
  <SkyPopover
    v-bind="$attrs"
    class="sky-dropdown"
    :class="{
      'sky-dropdown--single-line': singleLine,
      'sky-dropdown--actions': actionOnly,
    }"
    :aria-label="label"
    :opened="opened"
    :motion="motion"
    :placement="placement"
    role="menu"
    :target="target"
    @backdropclick="emit('backdropclick', $event)"
    @escape="emit('escape', $event)"
    @positionerror="emit('positionerror', $event)"
  >
    <div class="sky-dropdown__menu">
      <div
        v-for="section in menuSections"
        :key="section.key"
        :aria-label="section.group ? section.label : undefined"
        :role="section.group ? 'group' : 'presentation'"
      >
        <button
          v-for="item in section.items"
          :key="item.id"
          class="sky-dropdown__item"
          :class="{
            'sky-dropdown__item--destructive': item.destructive,
            'sky-dropdown__item--separator': item.separatorBefore,
          }"
          :aria-checked="item.checked === undefined ? undefined : item.checked"
          :aria-haspopup="item.submenu ? 'menu' : undefined"
          :disabled="item.disabled"
          :role="item.checked === undefined ? 'menuitem' : 'menuitemradio'"
          type="button"
          @click="emit('select', item.id, $event)"
        >
          <span class="sky-dropdown__indicator" aria-hidden="true">
            <SkyIcon
              :icon="Check"
              v-if="item.checked"
              :size="21"
              :stroke-width="2.5"
            />
          </span>
          <span class="sky-dropdown__label">{{ item.label }}</span>
          <SkyIcon
            :icon="ChevronRight"
            v-if="item.submenu"
            class="sky-dropdown__chevron"
            :size="21"
            :stroke-width="2.5"
            aria-hidden="true"
          />
        </button>
      </div>
    </div>
  </SkyPopover>
</template>
