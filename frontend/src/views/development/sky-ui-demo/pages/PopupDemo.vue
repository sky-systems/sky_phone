<script setup lang="ts">
import { X } from 'lucide-vue-next'
import { ref } from 'vue'

import {
  SkyAppPage,
  SkyBlock,
  SkyButton,
  SkyIcon,
  SkyLink,
  SkyNavbar,
  SkyPopup,
  SkyScrollArea,
} from '@/ui'

import SkyUiDemoPage from '../SkyUiDemoPage.vue'
import { useSkyUiDemoContext } from '../context'

const popupOpened = ref(false)
const demo = useSkyUiDemoContext()
</script>

<template>
  <SkyUiDemoPage title="Popup">
    <SkyBlock class="sky-ui-demo-stack" inset strong>
      <p class="sky-ui-demo-copy">
        Popup is a modal window with any HTML content that pops up over App's
        main content. Popup as all other overlays is part of so called
        "Temporary Views".
      </p>
      <SkyButton rounded @click="popupOpened = true">Open Popup</SkyButton>
    </SkyBlock>

    <template #fixed>
      <SkyPopup
        aria-label="Popup"
        :opened="popupOpened"
        @backdropclick="popupOpened = false"
        @escape="popupOpened = false"
      >
        <SkyAppPage
          :accent="demo.accent.value"
          :accent-soft="demo.accentSoft.value"
          class="sky-ui-demo-overlay-page"
          component="div"
          :dark="demo.dark.value"
          label="Popup"
        >
          <SkyNavbar title="Popup">
            <template #right>
              <SkyLink
                aria-label="Close popup"
                icon-only
                @click="popupOpened = false"
              >
                <SkyIcon :size="20"><X /></SkyIcon>
              </SkyLink>
            </template>
          </SkyNavbar>
          <SkyScrollArea>
            <SkyBlock class="sky-ui-demo-stack" inset strong>
              <p class="sky-ui-demo-copy">
                Here comes popup. You can put here anything, even independent
                view with its own navigation. Also not, that by default popup
                looks a bit different on iPhone/iPod and iPad, on iPhone it is
                fullscreen.
              </p>
              <p class="sky-ui-demo-copy">
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
              <p class="sky-ui-demo-copy">
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
      </SkyPopup>
    </template>
  </SkyUiDemoPage>
</template>
