<script setup lang="ts">
import { X } from 'lucide-vue-next'
import { reactive } from 'vue'

import {
  SkyAppPage,
  SkyBlock,
  SkyBlockTitle,
  SkyButton,
  SkyIcon,
  SkyLink,
  SkyNavbar,
  SkyPanel,
  SkyScrollArea,
} from '@/ui'

import SkyUiDemoPage from '../SkyUiDemoPage.vue'
import { useSkyUiDemoContext } from '../context'

type PanelId = 'left' | 'leftFloating' | 'right' | 'rightFloating'

const panels = [
  { floating: false, id: 'left', side: 'left', title: 'Left Panel' },
  { floating: false, id: 'right', side: 'right', title: 'Right Panel' },
  { floating: true, id: 'leftFloating', side: 'left', title: 'Left Panel' },
  { floating: true, id: 'rightFloating', side: 'right', title: 'Right Panel' },
] as const
const opened = reactive<Record<PanelId, boolean>>({
  left: false,
  leftFloating: false,
  right: false,
  rightFloating: false,
})
const demo = useSkyUiDemoContext()

function openPanel(id: PanelId): void {
  opened[id] = true
}

function closePanel(id: PanelId): void {
  opened[id] = false
}
</script>

<template>
  <SkyUiDemoPage title="Panel / Side Panel">
    <SkyBlock class="sky-ui-demo-stack" inset strong>
      <p class="sky-ui-demo-copy">
        Konsta UI comes with 2 panels (on left and on right), both are optional.
        You can put absolutely anything inside: data lists, forms, custom
        content, etc.
      </p>
    </SkyBlock>

    <SkyBlock class="sky-ui-demo-panel-actions" inset strong>
      <SkyButton block rounded @click="openPanel('left')">Left Panel</SkyButton>
      <SkyButton block rounded @click="openPanel('right')"
        >Right Panel</SkyButton
      >
    </SkyBlock>

    <SkyBlockTitle>Floating Panels</SkyBlockTitle>
    <SkyBlock class="sky-ui-demo-panel-actions" inset strong>
      <SkyButton block rounded @click="openPanel('leftFloating')">
        Left Panel
      </SkyButton>
      <SkyButton block rounded @click="openPanel('rightFloating')">
        Right Panel
      </SkyButton>
    </SkyBlock>

    <template #fixed>
      <SkyPanel
        v-for="panel in panels"
        :key="panel.id"
        :aria-label="panel.title"
        class="sky-ui-demo-panel"
        :floating="panel.floating"
        :opened="opened[panel.id]"
        :side="panel.side"
        @backdropclick="closePanel(panel.id)"
        @escape="closePanel(panel.id)"
      >
        <SkyAppPage
          :accent="demo.accent.value"
          :accent-soft="demo.accentSoft.value"
          class="sky-ui-demo-panel-page"
          component="div"
          :class="{
            'sky-ui-demo-panel-page--floating': panel.floating,
          }"
          :dark="demo.dark.value"
          :label="panel.title"
        >
          <SkyNavbar :title="panel.title">
            <template #right>
              <SkyLink
                :aria-label="`Close ${panel.title.toLowerCase()}`"
                icon-only
                @click="closePanel(panel.id)"
              >
                <SkyIcon :size="20"><X /></SkyIcon>
              </SkyLink>
            </template>
          </SkyNavbar>
          <SkyScrollArea>
            <SkyBlock class="sky-ui-demo-stack sky-ui-demo-panel-copy">
              <p class="sky-ui-demo-copy">Here comes {{ panel.side }} panel.</p>
              <p v-if="panel.side === 'left'" class="sky-ui-demo-copy">
                Lorem ipsum dolor sit amet, consectetur adipiscing elit.
                Suspendisse faucibus mauris leo, eu bibendum neque congue non.
                Ut leo mauris, eleifend eu commodo a, egestas ac urna. Maecenas
                in lacus faucibus, viverra ipsum pulvinar, molestie arcu. Etiam
                lacinia venenatis dignissim. Suspendisse non nisl semper tellus
                malesuada suscipit eu et eros. Nulla eu enim quis quam elementum
                vulputate. Mauris ornare consequat nunc viverra pellentesque.
                Aenean semper eu massa sit amet aliquam. Integer et neque sed
                libero mollis elementum at vitae ligula. Vestibulum pharetra sed
                libero sed porttitor. Suspendisse a faucibus lectus.
              </p>
              <p v-else class="sky-ui-demo-copy">
                Duis ut mauris sollicitudin, venenatis nisi sed, luctus ligula.
                Phasellus blandit nisl ut lorem semper pharetra. Nullam tortor
                nibh, suscipit in consequat vel, feugiat sed quam. Nam risus
                libero, auctor vel tristique ac, malesuada ut ante. Sed
                molestie, est in eleifend sagittis, leo tortor ullamcorper erat,
                at vulputate eros sapien nec libero. Mauris dapibus laoreet nibh
                quis bibendum. Fusce dolor sem, suscipit in iaculis id, pharetra
                at urna. Pellentesque tempor congue massa quis faucibus.
                Vestibulum nunc eros, convallis blandit dui sit amet, gravida
                adipiscing libero.
              </p>
            </SkyBlock>
          </SkyScrollArea>
        </SkyAppPage>
      </SkyPanel>
    </template>
  </SkyUiDemoPage>
</template>

<style scoped>
.sky-ui-demo-panel-actions {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: var(--sky-space-4);
}

.sky-ui-demo-panel-page {
  min-height: 100%;
}

.sky-ui-demo-panel-page--floating {
  --sky-safe-area-top: 0px;
  --sky-safe-area-bottom: 0px;
  background: transparent;
}

.sky-ui-demo-panel-page--floating :deep(.sky-app-page__backdrop) {
  background: transparent;
}

.sky-ui-demo-panel-copy {
  gap: var(--sky-space-4);
}
</style>
