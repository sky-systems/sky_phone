<script setup lang="ts">
import { computed } from 'vue'

import SpringboardWidget from '@/components/SpringboardWidget.vue'
import { useWidgetsStore } from '@/stores/widgets'
import { WIDGET_HOME_ROWS, WIDGET_PAGE_ROWS } from '@/utils/widgetLayout'

const props = defineProps<{
  draggingWidgetId?: string | null
  editMode: boolean
  page: number
}>()
const emit = defineEmits<{
  dragcancel: []
  dragend: [event: PointerEvent]
  dragmove: [event: PointerEvent]
  dragstart: [id: string, event: PointerEvent]
  menu: [id: string]
  remove: [id: string]
}>()
const widgets = useWidgetsStore()
const rows = computed(() =>
  props.page === 0 ? WIDGET_PAGE_ROWS : WIDGET_HOME_ROWS,
)
const instances = computed(() =>
  widgets.layout.instances.filter((instance) => instance.page === props.page),
)
</script>

<template>
  <div
    class="springboard-widget-grid"
    :class="{
      'springboard-widget-grid--editing': editMode,
      'springboard-widget-grid--page': page === 0,
      'springboard-widget-grid--drag-source': instances.some(
        (instance) => instance.id === draggingWidgetId,
      ),
    }"
    :style="{ '--widget-grid-rows': rows }"
    :data-widget-page="page"
  >
    <SpringboardWidget
      v-for="instance in instances"
      :key="instance.id"
      :instance="instance"
      :edit-mode="editMode"
      @dragcancel="emit('dragcancel')"
      @dragend="emit('dragend', $event)"
      @dragmove="emit('dragmove', $event)"
      @dragstart="emit('dragstart', instance.id, $event)"
      @menu="emit('menu', instance.id)"
      @remove="emit('remove', instance.id)"
    />
  </div>
</template>

<style scoped>
.springboard-widget-grid {
  position: absolute;
  z-index: 3;
  top: 82px;
  right: 22px;
  left: 22px;
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  grid-template-rows: repeat(
    var(--widget-grid-rows),
    var(--springboard-grid-row)
  );
  grid-auto-rows: var(--springboard-grid-row);
  gap: var(--springboard-grid-row-gap) var(--springboard-grid-column-gap);
  pointer-events: none;
}

.springboard-widget-grid--page {
  position: relative;
  top: auto;
  right: auto;
  left: auto;
}

.springboard-widget-grid--drag-source {
  z-index: 50;
}

.springboard-widget-grid :deep(.home-widget-shell) {
  pointer-events: auto;
}
</style>
