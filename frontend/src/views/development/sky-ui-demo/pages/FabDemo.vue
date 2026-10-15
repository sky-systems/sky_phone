<script setup lang="ts">
import { SkyIcon } from '@/ui'

import { Plus } from 'lucide-vue-next'

import { SkyBlock, SkyFab } from '@/ui'

import SkyUiDemoPage from '../SkyUiDemoPage.vue'
</script>

<template>
  <SkyUiDemoPage title="FAB">
    <SkyBlock class="fab-demo__copy" inset strong>
      <p>
        Lorem ipsum dolor sit amet, consectetur adipisicing elit. Quia, quo rem
        beatae, delectus eligendi est saepe molestias perferendis suscipit,
        commodi labore ipsa non quasi eum magnam neque ducimus! Quasi, numquam.
      </p>
      <p>
        Maiores culpa, itaque! Eaque natus ab cum ipsam numquam blanditiis a,
        quia, molestiae aut laudantium recusandae ipsa. Ad iste ex asperiores
        ipsa, mollitia perferendis consectetur quam eaque, voluptate laboriosam
        unde.
      </p>
      <p>
        Sed odit quis aperiam temporibus vitae necessitatibus, laboriosam,
        exercitationem dolores odio sapiente provident. Accusantium id, itaque
        aliquam libero ipsum eos fugiat distinctio laboriosam exercitationem
        sequi facere quas quidem magnam reprehenderit.
      </p>
      <p>
        Pariatur corporis illo, amet doloremque. Ab veritatis sunt nisi
        consectetur error modi, nam illo et nostrum quia aliquam ipsam vitae
        facere voluptates atque similique odit mollitia, rerum placeat nobis
        est.
      </p>
      <p>
        Et impedit soluta minus a autem adipisci cupiditate eius dignissimos
        nihil officia dolore voluptatibus aperiam reprehenderit esse facilis
        labore qui, officiis consectetur. Ipsa obcaecati aspernatur odio
        assumenda veniam, ipsum alias.
      </p>
    </SkyBlock>

    <SkyBlock class="fab-demo__copy" inset strong>
      <p>
        Lorem ipsum dolor sit amet, consectetur adipisicing elit. Culpa ipsa
        debitis sed nihil eaque dolore cum iste quibusdam, accusamus doloribus,
        tempora quia quos voluptatibus corporis officia at quas dolorem earum!
      </p>
      <p>
        Quod soluta eos inventore magnam suscipit enim at hic in maiores
        temporibus pariatur tempora minima blanditiis vero autem est
        perspiciatis totam dolorum, itaque repellat? Nobis necessitatibus aut
        odit aliquam adipisci.
      </p>
      <p>
        Tenetur delectus perspiciatis ex numquam, unde corrupti velit! Quam
        aperiam, animi fuga veritatis consectetur, voluptatibus atque
        consequuntur dignissimos itaque, sint impedit cum cumque at. Adipisci
        sint, iusto blanditiis ullam? Vel?
      </p>
      <p>
        Dignissimos velit officia quibusdam! Eveniet beatae, aut, omnis
        temporibus consequatur expedita eaque aliquid quos accusamus fugiat id
        iusto autem obcaecati repellat fugit cupiditate suscipit natus quas
        doloribus? Temporibus necessitatibus, libero.
      </p>
      <p>
        Architecto quisquam ipsa fugit facere, repudiandae asperiores vitae
        obcaecati possimus, labore excepturi reprehenderit consectetur
        perferendis, ullam quidem hic, repellat fugiat eaque fuga. Consectetur
        in eveniet, deleniti recusandae omnis eum quas?
      </p>
      <p>
        Quos nulla consequatur quo, officia quaerat. Nulla voluptatum, assumenda
        quibusdam, placeat cum aut illo deleniti dolores commodi odio ipsam,
        recusandae est pariatur veniam repudiandae blanditiis. Voluptas unde
        deleniti quisquam, nobis?
      </p>
      <p>
        Atque qui quaerat quasi officia molestiae, molestias totam incidunt
        reprehenderit laboriosam facilis veritatis, non iusto! Dolore ipsam
        obcaecati voluptates minima maxime minus qui mollitia facere. Nostrum
        esse recusandae voluptatibus eligendi.
      </p>
    </SkyBlock>

    <template #fixed>
      <SkyFab
        aria-label="Add from the right top"
        class="fab-demo__button fab-demo__button--right-top sky-ui-demo-color-red"
      >
        <template #icon><SkyIcon :icon="Plus" /></template>
      </SkyFab>
      <SkyFab
        aria-label="Add from the right bottom"
        class="fab-demo__button fab-demo__button--right-bottom"
      >
        <template #icon><SkyIcon :icon="Plus" /></template>
      </SkyFab>
      <SkyFab
        aria-label="Add from the left bottom"
        class="fab-demo__button fab-demo__button--left-bottom sky-ui-demo-color-green"
      >
        <template #icon><SkyIcon :icon="Plus" /></template>
      </SkyFab>
      <SkyFab
        aria-label="Add from the top left"
        class="fab-demo__button fab-demo__button--left-top sky-ui-demo-color-yellow"
      >
        <template #icon><SkyIcon :icon="Plus" /></template>
      </SkyFab>
      <SkyFab
        aria-label="Add from the center"
        class="fab-demo__button fab-demo__button--center"
      >
        <template #icon><SkyIcon :icon="Plus" /></template>
      </SkyFab>
      <SkyFab
        aria-label="Create"
        class="fab-demo__button fab-demo__button--center-bottom"
        text="Create"
        text-position="after"
      >
        <template #icon><SkyIcon :icon="Plus" /></template>
      </SkyFab>
    </template>
  </SkyUiDemoPage>
</template>

<style scoped>
.fab-demo__copy {
  display: grid;
  gap: var(--sky-space-4);
}

.fab-demo__copy p {
  margin: 0;
}

.fab-demo__button {
  position: absolute;
  z-index: 20;
}

.fab-demo__button--right-bottom {
  right: calc(var(--sky-safe-area-right) + var(--sky-space-4));
  bottom: calc(var(--sky-safe-area-bottom) + var(--sky-space-4));
}

.fab-demo__button--right-top {
  top: calc(var(--sky-safe-area-top) + var(--sky-navbar-height) + 16px);
  right: calc(var(--sky-safe-area-right) + var(--sky-space-4));
}

.fab-demo__button--left-bottom {
  bottom: calc(var(--sky-safe-area-bottom) + var(--sky-space-4));
  left: calc(var(--sky-safe-area-left) + var(--sky-space-4));
}

.fab-demo__button--left-top {
  top: calc(var(--sky-safe-area-top) + var(--sky-navbar-height) + 16px);
  left: calc(var(--sky-safe-area-left) + var(--sky-space-4));
}

.fab-demo__button--center {
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
}

.fab-demo__button--center.sky-glass--touch-highlight {
  transform: translate(-50%, -50%) scale(var(--sky-glass-touch-scale, 1.25));
}

.fab-demo__button--center-bottom {
  bottom: calc(var(--sky-safe-area-bottom) + var(--sky-space-4));
  left: 50%;
  transform: translateX(-50%);
}

.fab-demo__button--center-bottom.sky-glass--touch-highlight {
  transform: translateX(-50%) scale(var(--sky-glass-touch-scale, 1.25));
}

@media (prefers-reduced-motion: reduce) {
  .fab-demo__button--center.sky-glass--touch-highlight {
    transform: translate(-50%, -50%);
  }

  .fab-demo__button--center-bottom.sky-glass--touch-highlight {
    transform: translateX(-50%);
  }
}
</style>
