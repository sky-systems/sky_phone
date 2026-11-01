<script setup lang="ts">
import { computed } from 'vue'

import type { CryptoMarket } from '@/types/crypto'

type LogoMark = {
  d: string
  fill?: boolean
  opacity?: number
  width?: number
}

const props = defineProps<{
  market: Pick<CryptoMarket, 'color' | 'id' | 'name' | 'symbol'>
}>()

const logoMarks: Record<string, LogoMark[]> = {
  atlas: [
    { d: 'M10 30 20 8l10 22M14 23h12' },
    { d: 'm17 17 3-6 3 6', fill: true, opacity: 0.5 },
  ],
  aurora: [
    { d: 'M20 5 33 20 20 35 7 20Z' },
    { d: 'm7 20 13-5 13 5-13 5Z' },
    { d: 'M20 5v10m0 10v10' },
  ],
  celestium: [
    { d: 'M27 9a12 12 0 1 0 4 18 11 11 0 1 1-4-18Z', fill: true },
    { d: 'm29 10 .9 2.1L32 13l-2.1.9L29 16l-.9-2.1L26 13l2.1-.9Z', fill: true },
  ],
  crown: [
    { d: 'm8 13 7 7 5-11 5 11 7-7-3 17H11Z', fill: true },
    { d: 'M11 30h18', width: 2.8 },
  ],
  drift: [
    {
      d: 'M6 14c5-5 9 5 14 0s9 5 14 0M6 21c5-5 9 5 14 0s9 5 14 0M8 28c4-4 8 4 12 0s8 4 12 0',
    },
  ],
  dust: [
    {
      d: 'M12 12a3 3 0 1 0 0 .1M25 10a2 2 0 1 0 0 .1M29 22a3.5 3.5 0 1 0 0 .1M15 27a2.5 2.5 0 1 0 0 .1M20 19a1.5 1.5 0 1 0 0 .1',
    },
  ],
  ember: [
    {
      d: 'M22 5C24 13 17 14 20 20C22 16 27 15 27 9C33 15 34 21 31 27C28 34 16 35 11 27C7 21 10 15 14 11C13 16 15 18 17 19C15 12 22 9 22 5Z',
      fill: true,
    },
    { d: 'M20 21c4 3 3 8 0 11-4-2-5-7 0-11Z', fill: true, opacity: 0.45 },
  ],
  flux: [{ d: 'm23 4-13 19h9l-2 13 13-20h-9Z', fill: true }],
  helix: [
    {
      d: 'M11 7c16 7 16 19 0 26M29 7c-16 7-16 19 0 26M13 12h14M11 20h18M13 28h14',
    },
  ],
  moss: [
    { d: 'M32 8C18 8 9 14 9 25c0 6 5 8 10 5 7-4 9-12 13-22Z', fill: true },
    { d: 'M10 31c5-8 11-13 19-19M18 22c-1-3-3-5-6-6m9 3c2 0 5 1 7 3' },
  ],
  nano: [
    { d: 'M9 27 16 13l8 14 7-14' },
    {
      d: 'M9 27a3 3 0 1 0 0 .1M16 13a3 3 0 1 0 0 .1M24 27a3 3 0 1 0 0 .1M31 13a3 3 0 1 0 0 .1',
      fill: true,
    },
  ],
  nova: [
    {
      d: 'm20 4 3.2 10.8L34 12l-7.8 8 7.8 8-10.8-2.8L20 36l-3.2-10.8L6 28l7.8-8L6 12l10.8 2.8Z',
      fill: true,
    },
    { d: 'M20 14a6 6 0 1 0 0 12 6 6 0 0 0 0-12Z', fill: true, opacity: 0.45 },
  ],
  orbit: [
    { d: 'M20 9a11 11 0 1 0 0 22 11 11 0 0 0 0-22Z' },
    { d: 'M5 25c4 5 15 3 23-2s11-10 7-13c-3-2-10 0-16 4' },
    { d: 'M31 10a2.5 2.5 0 1 0 0 .1', fill: true },
  ],
  pebble: [
    {
      d: 'M10 25c0-5 4-9 9-9 6 0 11 4 11 9 0 6-5 9-11 9-5 0-9-3-9-9Z',
      fill: true,
    },
    {
      d: 'M13 14c1-4 4-7 8-7 3 0 6 2 7 5-5-1-10 0-15 2Z',
      fill: true,
      opacity: 0.55,
    },
  ],
  pixel: [
    {
      d: 'M8 8h7v7H8Zm9 0h7v7h-7Zm9 0h6v7h-6ZM8 17h7v7H8Zm9 0h7v7h-7Zm9 0h6v7h-6ZM8 26h7v6H8Zm9 0h7v6h-7Zm9 0h6v6h-6Z',
      fill: true,
    },
  ],
  prism: [
    { d: 'M20 6 34 32H6Z' },
    { d: 'm20 6 1 17 13 9M21 23 6 32' },
    { d: 'm21 23 6-5', opacity: 0.55 },
  ],
  pulse: [
    { d: 'M5 21h8l3-8 5 16 4-11 3 3h7' },
    { d: 'M20 7a13 13 0 1 0 0 26', opacity: 0.35 },
  ],
  quantum: [
    { d: 'M20 20a3 3 0 1 0 0 .1', fill: true },
    {
      d: 'M7 20c0-5 6-9 13-9s13 4 13 9-6 9-13 9S7 25 7 20Zm6-11c4-2 10 3 14 9s5 13 1 15-10-3-14-9S9 11 13 9Zm14 0c4 2 3 9-1 15s-10 11-14 9-1-9 3-15 8-11 12-9Z',
    },
  ],
  shard: [
    { d: 'M20 4 32 15l-5 19H13L7 15Z', fill: true },
    { d: 'm20 4-2 17 9 13m-9-13L7 15m11 6 14-6', opacity: 0.55 },
  ],
  spark: [
    {
      d: 'm20 4 3 11 9-7-5 10 9 2-10 4 7 8-10-5-2 7-2-12-8 7 5-10-9 3 10-6Z',
      fill: true,
    },
  ],
  tide: [
    {
      d: 'M5 23c4-10 10-13 17-8 5 4 8 3 13 0-2 9-9 16-18 15-5 0-9-3-12-7Z',
      fill: true,
    },
    { d: 'M9 23c6 3 12 2 17-4', opacity: 0.6 },
  ],
  titan: [
    { d: 'm20 5 13 7v16l-13 7-13-7V12Z' },
    { d: 'M12 13h16M20 13v17', width: 3.2 },
  ],
  vertex: [
    { d: 'm7 9 13 26L33 9h-8l-5 13-5-13Z', fill: true },
    { d: 'm15 9 5 13 5-13', opacity: 0.45 },
  ],
  zenith: [
    { d: 'M6 30 20 7l14 23-14-7Z', fill: true },
    { d: 'm20 7v16L6 30', opacity: 0.5 },
  ],
}

const marketIds = Object.keys(logoMarks)
const variant = computed(() =>
  Math.max(0, marketIds.indexOf(props.market.id) % 6),
)
const marks = computed(
  () =>
    logoMarks[props.market.id] ?? [
      { d: 'M8 20a12 12 0 1 0 24 0 12 12 0 0 0-24 0Z' },
      { d: 'M14 20h12' },
    ],
)
</script>

<template>
  <span
    class="crypto-logo"
    :class="`crypto-logo--${variant}`"
    :style="{ '--crypto-logo-color': market.color }"
    role="img"
    :aria-label="`${market.name} (${market.symbol})`"
  >
    <svg aria-hidden="true" viewBox="0 0 40 40">
      <path
        v-for="(mark, index) in marks"
        :key="index"
        :d="mark.d"
        :fill="mark.fill ? 'currentColor' : 'none'"
        :opacity="mark.opacity ?? 1"
        :stroke="mark.fill ? 'none' : 'currentColor'"
        stroke-linecap="round"
        stroke-linejoin="round"
        :stroke-width="mark.width ?? 2.2"
      />
    </svg>
  </span>
</template>

<style scoped>
.crypto-logo {
  position: relative;
  display: inline-grid;
  flex: 0 0 auto;
  place-items: center;
  width: 38px;
  height: 38px;
  overflow: hidden;
  color: color-mix(in srgb, var(--crypto-logo-color) 82%, #fff);
  background:
    radial-gradient(
      circle at 28% 22%,
      rgba(255, 255, 255, 0.22),
      transparent 34%
    ),
    color-mix(in srgb, var(--crypto-logo-color) 20%, #091019);
  border: 1px solid
    color-mix(in srgb, var(--crypto-logo-color) 42%, transparent);
  border-radius: 13px;
  box-shadow:
    0 8px 18px color-mix(in srgb, var(--crypto-logo-color) 16%, transparent),
    inset 0 1px rgba(255, 255, 255, 0.16);
}
.crypto-logo::after {
  position: absolute;
  inset: 2px;
  pointer-events: none;
  content: '';
  border: 1px solid rgba(255, 255, 255, 0.07);
  border-radius: inherit;
}
.crypto-logo svg {
  position: relative;
  z-index: 1;
  width: 72%;
  height: 72%;
}
.crypto-logo--1 {
  color: #fff;
  background: linear-gradient(
    145deg,
    var(--crypto-logo-color),
    color-mix(in srgb, var(--crypto-logo-color) 54%, #07101a)
  );
  border-radius: 50%;
}
.crypto-logo--2 {
  color: color-mix(in srgb, var(--crypto-logo-color) 68%, #fff);
  background:
    linear-gradient(
      135deg,
      rgba(255, 255, 255, 0.08) 0 40%,
      transparent 40% 100%
    ),
    #0b1119;
  border-radius: 10px 18px 10px 18px;
}
.crypto-logo--3 {
  color: #071018;
  background: linear-gradient(
    155deg,
    color-mix(in srgb, var(--crypto-logo-color) 68%, #fff),
    var(--crypto-logo-color)
  );
  border-color: rgba(255, 255, 255, 0.25);
  border-radius: 50%;
}
.crypto-logo--4 {
  color: #fff;
  background:
    radial-gradient(circle, var(--crypto-logo-color) 0 3px, transparent 4px),
    conic-gradient(
      from 25deg,
      color-mix(in srgb, var(--crypto-logo-color) 74%, #fff),
      #111827,
      var(--crypto-logo-color)
    );
  border-radius: 12px;
}
.crypto-logo--5 {
  color: color-mix(in srgb, var(--crypto-logo-color) 75%, #fff);
  background: #080d13;
  border: 2px solid color-mix(in srgb, var(--crypto-logo-color) 72%, #fff);
  border-radius: 50% 50% 50% 12px;
  box-shadow:
    0 0 18px color-mix(in srgb, var(--crypto-logo-color) 24%, transparent),
    inset 0 0 14px color-mix(in srgb, var(--crypto-logo-color) 13%, transparent);
}
</style>
