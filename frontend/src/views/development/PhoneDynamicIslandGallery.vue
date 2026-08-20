<script setup lang="ts">
import PhoneDynamicIsland from '@/components/PhoneDynamicIsland.vue'
import type { DynamicIslandActivity } from '@/types/dynamicIsland'

type GalleryVariant = {
  activity: DynamicIslandActivity
  expanded: boolean
  eyebrow: string
  label: string
  progress?: number
  subtitle: string
  title: string
  value: string
}

type GalleryGroup = {
  label: string
  variants: GalleryVariant[]
}

const galleryGroups: GalleryGroup[] = [
  {
    label: 'Incoming call',
    variants: [
      {
        activity: 'incoming-call',
        expanded: true,
        eyebrow: 'Incoming call',
        label: 'Expanded',
        subtitle: 'mobile',
        title: 'Tania Castillo',
        value: 'Incoming',
      },
    ],
  },
  {
    label: 'Active call',
    variants: [
      {
        activity: 'call',
        expanded: false,
        eyebrow: 'Connected',
        label: 'Compact',
        subtitle: '00:42',
        title: 'Alex Rivera',
        value: '00:42',
      },
      {
        activity: 'call',
        expanded: true,
        eyebrow: 'Connected',
        label: 'Expanded',
        subtitle: '00:42',
        title: 'Alex Rivera',
        value: '00:42',
      },
    ],
  },
  {
    label: 'Music',
    variants: [
      {
        activity: 'music',
        expanded: false,
        eyebrow: 'Now Playing',
        label: 'Compact',
        progress: 0.64,
        subtitle: 'Los Santos Radio',
        title: 'Night Drive',
        value: 'Night Drive',
      },
      {
        activity: 'music',
        expanded: true,
        eyebrow: 'Now Playing',
        label: 'Expanded',
        progress: 0.64,
        subtitle: 'Los Santos Radio',
        title: 'Night Drive',
        value: 'Night Drive',
      },
    ],
  },
  {
    label: 'Voice recording',
    variants: [
      {
        activity: 'recording',
        expanded: false,
        eyebrow: 'Recording',
        label: 'Compact',
        subtitle: 'Voice memo',
        title: '00:37',
        value: '00:37',
      },
      {
        activity: 'recording',
        expanded: true,
        eyebrow: 'Recording',
        label: 'Expanded',
        subtitle: 'Voice memo',
        title: '00:37',
        value: '00:37',
      },
    ],
  },
  {
    label: 'Timer',
    variants: [
      {
        activity: 'timer',
        expanded: false,
        eyebrow: 'Timer',
        label: 'Compact',
        progress: 0.47,
        subtitle: 'Training',
        title: '14:42',
        value: '14:42',
      },
      {
        activity: 'timer',
        expanded: true,
        eyebrow: 'Timer',
        label: 'Expanded',
        progress: 0.47,
        subtitle: 'Training',
        title: '14:42',
        value: '14:42',
      },
    ],
  },
  {
    label: 'Stopwatch',
    variants: [
      {
        activity: 'stopwatch',
        expanded: false,
        eyebrow: 'Stopwatch',
        label: 'Compact',
        subtitle: 'Running',
        title: '02:18.43',
        value: '02:18.43',
      },
      {
        activity: 'stopwatch',
        expanded: true,
        eyebrow: 'Stopwatch',
        label: 'Expanded',
        subtitle: 'Running',
        title: '02:18.43',
        value: '02:18.43',
      },
    ],
  },
]
</script>

<template>
  <main class="dynamic-island-gallery">
    <header class="dynamic-island-gallery__header">
      <span>Development preview</span>
      <h1>Dynamic Islands</h1>
      <p>Every runtime activity in its supported compact and expanded state.</p>
    </header>

    <section
      v-for="group in galleryGroups"
      :key="group.label"
      class="dynamic-island-gallery__group"
    >
      <h2>{{ group.label }}</h2>
      <article
        v-for="variant in group.variants"
        :key="`${variant.activity}-${variant.label}`"
        class="dynamic-island-gallery__variant"
      >
        <span>{{ variant.label }}</span>
        <div
          class="dynamic-island-gallery__stage"
          :class="{
            'dynamic-island-gallery__stage--expanded': variant.expanded,
          }"
        >
          <PhoneDynamicIsland
            class="dynamic-island-gallery__preview"
            preview
            :preview-activity="variant.activity"
            :preview-expanded="variant.expanded"
            :preview-eyebrow="variant.eyebrow"
            :preview-progress="variant.progress"
            :preview-subtitle="variant.subtitle"
            :preview-title="variant.title"
            :preview-value="variant.value"
          />
        </div>
      </article>
    </section>
  </main>
</template>

<style scoped>
.dynamic-island-gallery {
  position: absolute;
  z-index: 2;
  inset: 0;
  overflow-y: auto;
  padding: 58px 6px 32px;
  color: #f7f7fb;
  background:
    radial-gradient(circle at 50% 0%, rgb(96 75 180 / 22%), transparent 30%),
    linear-gradient(180deg, #111116 0%, #070709 100%);
  scrollbar-width: none;
}

.dynamic-island-gallery::-webkit-scrollbar {
  display: none;
}

.dynamic-island-gallery__header,
.dynamic-island-gallery__group {
  width: 100%;
  max-width: 356px;
  margin-inline: auto;
}

.dynamic-island-gallery__header {
  padding: 4px 8px 18px;
}

.dynamic-island-gallery__header span,
.dynamic-island-gallery__variant > span {
  color: #a7a7b3;
  font-size: 11px;
  font-weight: 650;
  letter-spacing: 0.55px;
  text-transform: uppercase;
}

.dynamic-island-gallery__header h1 {
  margin: 4px 0 5px;
  font-size: 28px;
  letter-spacing: -0.8px;
}

.dynamic-island-gallery__header p {
  margin: 0;
  color: #b6b6c2;
  font-size: 12px;
  line-height: 17px;
}

.dynamic-island-gallery__group {
  padding: 14px 0 18px;
  border-top: 1px solid rgb(255 255 255 / 9%);
}

.dynamic-island-gallery__group h2 {
  margin: 0 8px 10px;
  font-size: 15px;
  letter-spacing: -0.2px;
}

.dynamic-island-gallery__variant + .dynamic-island-gallery__variant {
  margin-top: 10px;
}

.dynamic-island-gallery__variant > span {
  display: block;
  margin: 0 10px 5px;
  font-size: 9px;
}

.dynamic-island-gallery__stage {
  display: grid;
  width: 100%;
  min-height: 72px;
  overflow: hidden;
  place-items: center;
  border: 1px solid rgb(255 255 255 / 8%);
  border-radius: 30px;
  background:
    radial-gradient(circle at 70% 15%, rgb(93 89 255 / 24%), transparent 34%),
    #1a1a22;
}

.dynamic-island-gallery__stage--expanded {
  min-height: 142px;
}

:deep(.dynamic-island-gallery__preview.phone-dynamic-island) {
  position: relative;
  top: auto;
  left: auto;
  max-width: none;
  transform: none;
}

:deep(
  .dynamic-island-gallery__preview.phone-dynamic-island[data-expanded='true']
) {
  width: 100%;
}

@media (prefers-reduced-motion: reduce) {
  .dynamic-island-gallery {
    scroll-behavior: auto;
  }
}
</style>
