<script setup lang="ts">
import { ChevronLeft, ChevronRight, ImageOff } from 'lucide-vue-next'
import { ref, watch } from 'vue'

import type { MarketplaceImage } from '@/types/marketplace'

const props = defineProps<{
  emptyBody: string
  emptyTitle: string
  images: MarketplaceImage[]
  nextLabel: string
  photoLabel: string
  previousLabel: string
}>()

const activeIndex = ref(0)

watch(
  () => props.images,
  () => (activeIndex.value = 0),
  { deep: true },
)

function move(direction: number): void {
  if (props.images.length < 2) return
  activeIndex.value =
    (activeIndex.value + direction + props.images.length) % props.images.length
}
</script>

<template>
  <div class="citymarkt-gallery" :class="{ 'citymarkt-gallery--empty': !images.length }">
    <div
      v-if="images.length"
      class="citymarkt-gallery__image"
      :style="{ background: images[activeIndex]?.gradient }"
      role="img"
      :aria-label="`${photoLabel} ${activeIndex + 1}`"
    />
    <div v-else class="citymarkt-gallery__empty">
      <span><ImageOff :size="27" /></span>
      <strong>{{ emptyTitle }}</strong>
      <small>{{ emptyBody }}</small>
    </div>

    <template v-if="images.length > 1">
      <button
        class="citymarkt-gallery__arrow citymarkt-gallery__arrow--left"
        type="button"
        :aria-label="previousLabel"
        @click.stop="move(-1)"
      >
        <ChevronLeft :size="19" />
      </button>
      <button
        class="citymarkt-gallery__arrow citymarkt-gallery__arrow--right"
        type="button"
        :aria-label="nextLabel"
        @click.stop="move(1)"
      >
        <ChevronRight :size="19" />
      </button>
      <div class="citymarkt-gallery__dots" aria-hidden="true">
        <i
          v-for="(_, index) in images"
          :key="index"
          :class="{ active: index === activeIndex }"
        />
      </div>
    </template>
    <span v-if="images.length" class="citymarkt-gallery__count">
      {{ activeIndex + 1 }} / {{ images.length }}
    </span>
  </div>
</template>

<style scoped>
.citymarkt-gallery{position:relative;overflow:hidden;background:#252724}.citymarkt-gallery__image{position:absolute;inset:0;background-position:center!important;background-size:cover!important;transition:background .2s ease}.citymarkt-gallery__empty{position:absolute;inset:0;padding:18px;display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center;color:var(--muted)}.citymarkt-gallery__empty span{width:48px;height:48px;margin-bottom:8px;border:1px solid #ffffff12;border-radius:16px;display:grid;place-items:center;background:#ffffff08;color:var(--yellow)}.citymarkt-gallery__empty strong{font-size:12px}.citymarkt-gallery__empty small{max-width:190px;margin-top:3px;font-size:8px;line-height:1.35}.citymarkt-gallery__arrow{position:absolute;z-index:2;top:50%;width:31px;height:31px;padding:0;border:1px solid #ffffff24;border-radius:50%;display:grid;place-items:center;background:#11120fba;color:#fff;box-shadow:0 4px 13px #0005;transform:translateY(-50%)}.citymarkt-gallery__arrow--left{left:9px}.citymarkt-gallery__arrow--right{right:9px}.citymarkt-gallery__dots{position:absolute;z-index:2;right:52px;bottom:12px;left:52px;display:flex;justify-content:center;gap:4px}.citymarkt-gallery__dots i{width:4px;height:4px;border-radius:50%;background:#ffffff66;box-shadow:0 1px 3px #0008;transition:width .18s ease,background .18s ease}.citymarkt-gallery__dots i.active{width:11px;border-radius:4px;background:var(--yellow)}.citymarkt-gallery__count{position:absolute;z-index:2;right:9px;bottom:8px;padding:4px 7px;border-radius:8px;background:#11120fc7;color:#fff;font-size:8px;font-weight:800}:global(.citymarkt--light) .citymarkt-gallery--empty{background:#e9eae5}:global(.citymarkt--light) .citymarkt-gallery__empty span{border-color:#00000012;background:#00000008}
</style>
