<script setup lang="ts">
import { X } from 'lucide-vue-next'
import { ref } from 'vue'

import {
  SkyBlock,
  SkyButton,
  SkyIcon,
  SkyLink,
  SkySheet,
  SkyToolbar,
  SkyToolbarPane,
} from '@/ui'

import SkyUiDemoPage from '../SkyUiDemoPage.vue'

const sheetOpened = ref(false)
</script>

<template>
  <SkyUiDemoPage title="Sheet Modal">
    <SkyBlock class="sky-ui-demo-stack" inset strong>
      <p class="sky-ui-demo-copy">
        Sheet Modals slide up from the bottom of the screen to reveal more
        content. Such modals allow to create custom overlays with custom
        content.
      </p>
      <SkyButton rounded @click="sheetOpened = true">Open Sheet</SkyButton>
    </SkyBlock>

    <template #fixed>
      <SkySheet
        aria-label="Sheet modal"
        class="sky-ui-demo-sheet"
        :opened="sheetOpened"
        @backdropclick="sheetOpened = false"
        @escape="sheetOpened = false"
      >
        <SkyToolbar
          aria-label="Sheet actions"
          class="sky-ui-demo-sheet__toolbar"
          top
        >
          <SkyToolbarPane>
            <SkyLink
              aria-label="Close sheet"
              icon-only
              @click="sheetOpened = false"
            >
              <SkyIcon :size="24"><SkyIcon :icon="X" /></SkyIcon>
            </SkyLink>
          </SkyToolbarPane>
        </SkyToolbar>
        <SkyBlock class="sky-ui-demo-stack sky-ui-demo-sheet__content">
          <p class="sky-ui-demo-copy">
            Lorem ipsum dolor sit, amet consectetur adipisicing elit. Harum ad
            excepturi nesciunt nobis aliquam. Quibusdam ducimus neque
            necessitatibus, molestias cupiditate velit nihil alias incidunt,
            excepturi voluptatem dolore itaque sapiente dolores!
          </p>
          <SkyButton block large rounded @click="sheetOpened = false"
            >Action</SkyButton
          >
        </SkyBlock>
      </SkySheet>
    </template>
  </SkyUiDemoPage>
</template>

<style scoped>
.sky-ui-demo-sheet__toolbar {
  justify-content: flex-end;
}

.sky-ui-demo-sheet__content {
  gap: var(--sky-space-4);
  padding-right: calc(var(--sky-page-gutter) + var(--sky-safe-area-right, 0px));
  padding-left: calc(var(--sky-page-gutter) + var(--sky-safe-area-left, 0px));
}

.sky-ui-demo-sheet :deep(.sky-sheet__panel) {
  padding-bottom: var(--sky-safe-area-bottom);
}
</style>
