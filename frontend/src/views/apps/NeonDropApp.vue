<script setup lang="ts">
import {
  ArrowDown,
  ArrowLeft,
  ArrowRight,
  ChevronLeft,
  ChevronsDown,
  Pause,
  Play,
  RotateCcw,
  RotateCw,
  Trophy,
  Volume2,
  VolumeX,
  Zap,
} from 'lucide-vue-next'
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'

import { playNeonDropSound } from '@/features/games/neon-drop/audio'
import {
  createNeonDropPiece,
  getNeonDropCells,
  getNeonDropGhostPiece,
  getNeonDropInterval,
  NEON_DROP_COLUMNS,
} from '@/features/games/neon-drop/engine'
import { useNeonDropStore } from '@/features/games/neon-drop/store'
import type {
  NeonDropEvent,
  NeonDropPieceKind,
} from '@/features/games/neon-drop/types'
import { usePhoneStore } from '@/stores/phone'

type RenderCell = {
  active: boolean
  ghost: boolean
  key: number
  kind: NeonDropPieceKind | null
}

const phone = usePhoneStore()
const neon = useNeonDropStore()
const game = computed(() => neon.game)
const clearEffect = ref(false)
let dropTimer: ReturnType<typeof setTimeout> | undefined
let effectTimer: ReturnType<typeof setTimeout> | undefined
let pointerStart: { x: number; y: number } | undefined

const renderedCells = computed<RenderCell[]>(() => {
  if (!game.value) return []
  const cells = game.value.board.flat().map((kind, key) => ({
    active: false,
    ghost: false,
    key,
    kind,
  }))
  for (const point of getNeonDropCells(getNeonDropGhostPiece(game.value))) {
    if (point.y < 0) continue
    const cell = cells[point.y * NEON_DROP_COLUMNS + point.x]
    if (cell && cell.kind === null) {
      cell.ghost = true
      cell.kind = game.value.active.kind
    }
  }
  for (const point of getNeonDropCells(game.value.active)) {
    if (point.y < 0) continue
    const cell = cells[point.y * NEON_DROP_COLUMNS + point.x]
    if (cell) {
      cell.active = true
      cell.ghost = false
      cell.kind = game.value.active.kind
    }
  }
  return cells
})

const nextCells = computed(() => {
  if (!game.value) return new Set<string>()
  const points = getNeonDropCells(createNeonDropPiece(game.value.nextKind))
  const minX = Math.min(...points.map((point) => point.x))
  const minY = Math.min(...points.map((point) => point.y))
  return new Set(points.map((point) => `${point.x - minX},${point.y - minY}`))
})

const levelProgress = computed(() => ((game.value?.lines ?? 0) % 8) / 8)

function cellClass(cell: RenderCell): Record<string, boolean> {
  return {
    'neon-cell--active': cell.active,
    'neon-cell--ghost': cell.ghost,
    [`neon-piece--${cell.kind}`]: cell.kind !== null,
  }
}

function handleEvent(event: NeonDropEvent): void {
  if (event === 'none') return
  if (event === 'clear') {
    if (effectTimer) clearTimeout(effectTimer)
    clearEffect.value = true
    effectTimer = setTimeout(() => {
      clearEffect.value = false
      effectTimer = undefined
    }, 260)
  }
  playNeonDropSound(event === 'drop' ? 'drop' : event, neon.soundEnabled)
}

function clearDropTimer(): void {
  if (dropTimer) clearTimeout(dropTimer)
  dropTimer = undefined
}

function scheduleDrop(): void {
  clearDropTimer()
  if (game.value?.status !== 'playing') return
  dropTimer = setTimeout(() => {
    handleEvent(neon.tick())
    scheduleDrop()
  }, getNeonDropInterval(game.value.level))
}

function startGame(): void {
  neon.start()
  playNeonDropSound('start', neon.soundEnabled)
}

function move(direction: -1 | 1): void {
  handleEvent(neon.move(direction))
}

function rotate(): void {
  handleEvent(neon.rotate())
}

function softDrop(): void {
  handleEvent(neon.softDrop())
}

function hardDrop(): void {
  playNeonDropSound('drop', neon.soundEnabled)
  const event = neon.hardDrop()
  if (event !== 'lock') handleEvent(event)
}

function togglePause(): void {
  if (game.value?.status === 'playing') neon.pause()
  else if (game.value?.status === 'paused') neon.resume()
}

function toggleSound(): void {
  const enabled = !neon.soundEnabled
  neon.setSoundEnabled(enabled)
  if (enabled) playNeonDropSound('rotate', true)
}

function onPointerDown(event: PointerEvent): void {
  pointerStart = { x: event.clientX, y: event.clientY }
}

function onPointerUp(event: PointerEvent): void {
  if (!pointerStart || game.value?.status !== 'playing') return
  const deltaX = event.clientX - pointerStart.x
  const deltaY = event.clientY - pointerStart.y
  pointerStart = undefined
  if (Math.abs(deltaX) < 14 && Math.abs(deltaY) < 14) rotate()
  else if (Math.abs(deltaX) > Math.abs(deltaY)) move(deltaX > 0 ? 1 : -1)
  else if (deltaY < 0) rotate()
  else if (deltaY > 90) hardDrop()
  else softDrop()
}

function onKeyDown(event: KeyboardEvent): void {
  if (neon.menuOpen || game.value?.status !== 'playing') return
  if (event.key === 'ArrowLeft' || event.key.toLowerCase() === 'a') move(-1)
  else if (event.key === 'ArrowRight' || event.key.toLowerCase() === 'd')
    move(1)
  else if (event.key === 'ArrowUp' || event.key.toLowerCase() === 'w') rotate()
  else if (event.key === 'ArrowDown' || event.key.toLowerCase() === 's')
    softDrop()
  else if (event.code === 'Space') hardDrop()
  else return
  event.preventDefault()
}

neon.hydrate()
watch(
  () => game.value?.status,
  (status) => {
    if (status === 'playing') scheduleDrop()
    else clearDropTimer()
  },
  { immediate: true },
)
onMounted(() => document.addEventListener('keydown', onKeyDown))
onBeforeUnmount(() => {
  clearDropTimer()
  if (effectTimer) clearTimeout(effectTimer)
  document.removeEventListener('keydown', onKeyDown)
  neon.pause()
})
</script>

<template>
  <main class="neon-drop-app" :aria-label="phone.t('Apps.neonDrop.name')">
    <header class="neon-header">
      <div>
        <span>{{ phone.t('Apps.neonDrop.eyebrow') }}</span>
        <h1>{{ phone.t('Apps.neonDrop.name') }}</h1>
      </div>
      <button
        type="button"
        :aria-label="
          phone.t(
            neon.soundEnabled ? 'Apps.neonDrop.mute' : 'Apps.neonDrop.unmute',
          )
        "
        @click="toggleSound"
      >
        <Volume2 v-if="neon.soundEnabled" :size="18" /><VolumeX
          v-else
          :size="18"
        />
      </button>
    </header>

    <section v-if="neon.menuOpen" class="neon-menu">
      <div class="neon-hero" aria-hidden="true">
        <div class="neon-hero__beam"></div>
        <div class="neon-hero__piece neon-hero__piece--one">
          <i v-for="cell in 4" :key="cell"></i>
        </div>
        <div class="neon-hero__piece neon-hero__piece--two">
          <i v-for="cell in 4" :key="cell"></i>
        </div>
        <div class="neon-hero__floor">
          <i v-for="cell in 8" :key="cell"></i>
        </div>
      </div>
      <div class="neon-menu__copy">
        <span>{{ phone.t('Apps.neonDrop.ready') }}</span>
        <h2>{{ phone.t('Apps.neonDrop.menuTitle') }}</h2>
        <p>{{ phone.t('Apps.neonDrop.menuBody') }}</p>
      </div>
      <div class="neon-records">
        <div>
          <span>{{ phone.t('Apps.neonDrop.bestScore') }}</span
          ><strong>{{ neon.bestScore }}</strong>
        </div>
        <div>
          <span>{{ phone.t('Apps.neonDrop.bestLines') }}</span
          ><strong>{{ neon.bestLines }}</strong>
        </div>
      </div>
      <div class="neon-how">
        <Zap :size="17" />
        <p>
          <strong>{{ phone.t('Apps.neonDrop.howToTitle') }}</strong
          >{{ phone.t('Apps.neonDrop.howToBody') }}
        </p>
      </div>
      <button type="button" class="neon-primary" @click="startGame">
        <Play :size="17" fill="currentColor" />{{
          phone.t(game ? 'Apps.neonDrop.newGame' : 'Apps.neonDrop.start')
        }}
      </button>
      <button
        v-if="game?.status === 'paused'"
        type="button"
        class="neon-secondary"
        @click="neon.resume()"
      >
        {{ phone.t('Apps.neonDrop.resume') }}
      </button>
    </section>

    <section v-else-if="game" class="neon-game">
      <div class="neon-toolbar">
        <button
          type="button"
          :aria-label="phone.t('Apps.neonDrop.backToMenu')"
          @click="neon.showMenu()"
        >
          <ChevronLeft :size="19" />
        </button>
        <div>
          <span>{{ phone.t('Apps.neonDrop.score') }}</span
          ><strong>{{ game.score }}</strong>
        </div>
        <div>
          <span>{{ phone.t('Apps.neonDrop.lines') }}</span
          ><strong>{{ game.lines }}</strong>
        </div>
        <button
          type="button"
          :aria-label="phone.t('Apps.neonDrop.pause')"
          @click="togglePause"
        >
          <Pause
            v-if="game.status === 'playing'"
            :size="16"
            fill="currentColor"
          /><Play v-else :size="16" fill="currentColor" />
        </button>
      </div>

      <div class="neon-play-area">
        <div
          class="neon-board"
          :class="{ 'neon-board--clear': clearEffect }"
          :aria-label="phone.t('Apps.neonDrop.board')"
          role="application"
          @pointerdown.prevent="onPointerDown"
          @pointerup.prevent="onPointerUp"
        >
          <i
            v-for="cell in renderedCells"
            :key="cell.key"
            class="neon-cell"
            :class="cellClass(cell)"
          ></i>
        </div>
        <aside class="neon-side">
          <span>{{ phone.t('Apps.neonDrop.next') }}</span>
          <div class="neon-preview" aria-hidden="true">
            <i
              v-for="index in 16"
              :key="index"
              :class="{
                [`neon-piece--${game.nextKind}`]: nextCells.has(
                  `${(index - 1) % 4},${Math.floor((index - 1) / 4)}`,
                ),
              }"
            ></i>
          </div>
          <span>{{ phone.t('Apps.neonDrop.level') }}</span
          ><strong>{{ game.level }}</strong>
          <div class="neon-level">
            <i :style="{ height: `${levelProgress * 100}%` }"></i>
          </div>
        </aside>
      </div>

      <div
        class="neon-controls"
        :aria-label="phone.t('Apps.neonDrop.controls')"
      >
        <button
          type="button"
          :aria-label="phone.t('Apps.neonDrop.left')"
          @click="move(-1)"
        >
          <ArrowLeft :size="18" />
        </button>
        <button
          type="button"
          :aria-label="phone.t('Apps.neonDrop.rotate')"
          @click="rotate"
        >
          <RotateCw :size="18" />
        </button>
        <button
          type="button"
          :aria-label="phone.t('Apps.neonDrop.right')"
          @click="move(1)"
        >
          <ArrowRight :size="18" />
        </button>
        <button
          type="button"
          :aria-label="phone.t('Apps.neonDrop.softDrop')"
          @click="softDrop"
        >
          <ArrowDown :size="18" />
        </button>
        <button
          type="button"
          :aria-label="phone.t('Apps.neonDrop.hardDrop')"
          @click="hardDrop"
        >
          <ChevronsDown :size="18" />
        </button>
      </div>
      <p class="neon-hint">{{ phone.t('Apps.neonDrop.gameHint') }}</p>

      <div v-if="game.status === 'paused'" class="neon-overlay">
        <Pause :size="30" />
        <h2>{{ phone.t('Apps.neonDrop.paused') }}</h2>
        <button type="button" class="neon-primary" @click="neon.resume()">
          {{ phone.t('Apps.neonDrop.resume') }}</button
        ><button type="button" class="neon-secondary" @click="neon.showMenu()">
          {{ phone.t('Apps.neonDrop.mainMenu') }}
        </button>
      </div>
      <div v-if="game.status === 'over'" class="neon-overlay">
        <Trophy :size="33" /><span>{{
          phone.t('Apps.neonDrop.gameOver')
        }}</span>
        <h2>{{ game.score }} {{ phone.t('Apps.neonDrop.points') }}</h2>
        <p>{{ game.lines }} {{ phone.t('Apps.neonDrop.lines') }}</p>
        <button type="button" class="neon-primary" @click="startGame">
          <RotateCcw :size="16" />{{
            phone.t('Apps.neonDrop.playAgain')
          }}</button
        ><button type="button" class="neon-secondary" @click="neon.showMenu()">
          {{ phone.t('Apps.neonDrop.mainMenu') }}
        </button>
      </div>
    </section>
  </main>
</template>

<style scoped>
.neon-drop-app {
  position: absolute;
  inset: 0;
  overflow: hidden;
  padding: 52px 14px 25px;
  color: #f5fbff;
  background: radial-gradient(circle at 50% 0, #253163, #090c22 58%, #050715);
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  user-select: none;
  touch-action: manipulation;
}
.neon-header {
  height: 54px;
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.neon-header span,
.neon-menu__copy > span {
  display: block;
  color: #7cf6e7;
  font-size: 14px;
  font-weight: 900;
  letter-spacing: 1.2px;
  text-transform: uppercase;
}
.neon-header h1 {
  margin: 1px 0 0;
  font-size: 32px;
  line-height: 1;
}
.neon-header button,
.neon-toolbar button {
  width: 35px;
  height: 35px;
  display: grid;
  place-items: center;
  padding: 0;
  border: 1px solid #7cf6e72d;
  border-radius: 12px;
  color: #fff;
  background: #ffffff0d;
}
.neon-menu {
  height: calc(100% - 54px);
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 10px;
  text-align: center;
}
.neon-hero {
  position: relative;
  width: 210px;
  height: 145px;
  overflow: hidden;
  border: 1px solid #80f8ec35;
  border-radius: 25px;
  background: linear-gradient(160deg, #172557, #09102c);
  box-shadow:
    0 18px 32px #02040db3,
    inset 0 0 35px #19f5de12;
}
.neon-hero::before {
  position: absolute;
  inset: 0;
  background:
    linear-gradient(#61f8e70a 1px, transparent 1px),
    linear-gradient(90deg, #61f8e70a 1px, transparent 1px);
  background-size: 18px 18px;
  content: '';
}
.neon-hero__beam {
  position: absolute;
  top: 0;
  left: 91px;
  width: 28px;
  height: 85px;
  background: linear-gradient(#79fff000, #79fff033);
  clip-path: polygon(35% 0, 65% 0, 100% 100%, 0 100%);
}
.neon-hero__piece {
  position: absolute;
  z-index: 2;
  display: grid;
  grid-template-columns: repeat(2, 18px);
  gap: 2px;
  filter: drop-shadow(0 0 8px currentColor);
}
.neon-hero__piece i,
.neon-hero__floor i {
  height: 18px;
  border: 1px solid #ffffff75;
  border-radius: 4px;
  background: currentColor;
  box-shadow: inset 2px 2px #ffffff3d;
}
.neon-hero__piece--one {
  top: 22px;
  left: 86px;
  color: #65f4e4;
  animation: neon-fall 2.1s ease-in infinite;
}
.neon-hero__piece--two {
  right: 44px;
  bottom: 23px;
  color: #ff668e;
  transform: rotate(90deg);
}
.neon-hero__floor {
  position: absolute;
  right: 31px;
  bottom: 4px;
  left: 31px;
  display: grid;
  grid-template-columns: repeat(8, 1fr);
  gap: 2px;
  color: #7a6cff;
}
.neon-menu__copy h2 {
  margin: 4px 0 7px;
  font-size: 30px;
}
.neon-menu__copy p {
  max-width: 296px;
  margin: 0;
  color: #e1e7f5;
  font-size: 18px;
  font-weight: 550;
  line-height: 1.4;
}
.neon-records {
  width: 100%;
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 7px;
}
.neon-records div {
  padding: 12px 9px;
  border: 1px solid #ffffff24;
  border-radius: 13px;
  background: #ffffff08;
}
.neon-records span,
.neon-side > span,
.neon-toolbar span {
  display: block;
  color: #d2dcef;
  font-size: 12px;
  font-weight: 850;
  text-transform: uppercase;
}
.neon-records strong {
  font-size: 26px;
}
.neon-how {
  width: 100%;
  display: flex;
  align-items: center;
  gap: 9px;
  padding: 12px 13px;
  border: 1px solid #6ff5e42a;
  border-radius: 13px;
  color: #72f5e4;
  background: #34d7c60d;
  text-align: left;
}
.neon-how p {
  margin: 0;
  color: #dce4f3;
  font-size: 16px;
  line-height: 1.4;
}
.neon-how strong {
  display: block;
  color: #fff;
  font-size: 17px;
}
.neon-primary,
.neon-secondary {
  width: 100%;
  min-height: 50px;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 7px;
  border-radius: 13px;
  font-size: 18px;
  font-weight: 900;
}
.neon-primary {
  border: 0;
  color: #061521;
  background: linear-gradient(135deg, #71f5e5, #73a7ff);
  box-shadow: 0 8px 20px #39dfca2b;
}
.neon-secondary {
  border: 1px solid #ffffff1b;
  color: #fff;
  background: #ffffff0a;
}
.neon-game {
  position: relative;
  height: calc(100% - 54px);
}
.neon-toolbar {
  height: 42px;
  display: grid;
  grid-template-columns: 35px 1fr 1fr 35px;
  align-items: center;
  gap: 5px;
}
.neon-toolbar div {
  text-align: center;
}
.neon-toolbar strong {
  font-size: 21px;
}
.neon-play-area {
  display: flex;
  justify-content: center;
  align-items: flex-start;
  gap: 5px;
}
.neon-board {
  width: 218px;
  height: 414px;
  display: grid;
  grid-template-columns: repeat(10, 1fr);
  grid-template-rows: repeat(18, 1fr);
  gap: 1.5px;
  padding: 5px;
  border: 1px solid #65f4e43b;
  border-radius: 13px;
  background: #06091af2;
  box-shadow:
    inset 0 0 25px #000b,
    0 12px 26px #0008;
  touch-action: none;
}
.neon-cell {
  display: block;
  border: 1px solid #87a1c00c;
  border-radius: 3px;
  background: #ffffff06;
}
.neon-cell[class*='neon-piece--'] {
  border-color: #ffffff70;
  background: currentColor;
  box-shadow:
    inset 2px 2px #ffffff45,
    inset -2px -2px #0003,
    0 0 6px currentColor;
}
.neon-cell--ghost {
  opacity: 0.2;
  background: transparent !important;
  outline: 1px dashed currentColor;
  outline-offset: -2px;
  box-shadow: none !important;
}
.neon-cell--active {
  animation: neon-active 0.22s ease-out;
}
.neon-piece--I {
  color: #49e8e0;
}
.neon-piece--J {
  color: #5c8cff;
}
.neon-piece--L {
  color: #ffad4c;
}
.neon-piece--O {
  color: #ffe265;
}
.neon-piece--S {
  color: #63e17e;
}
.neon-piece--T {
  color: #b86cff;
}
.neon-piece--Z {
  color: #ff5f7e;
}
.neon-board--clear {
  animation: neon-clear 0.24s ease-out;
}
.neon-side {
  width: 70px;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 9px;
  padding: 10px 4px 11px;
  border: 1px solid #65f4e448;
  border-radius: 13px;
  background: linear-gradient(180deg, #1420478f, #090d24a3);
  box-shadow: inset 0 0 16px #53e8d90a;
}
.neon-side > strong {
  font-size: 28px;
}
.neon-preview {
  width: 62px;
  height: 62px;
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  grid-template-rows: repeat(4, 1fr);
  gap: 2px;
  padding: 5px;
  border: 1px solid #ffffff35;
  border-radius: 10px;
  background: #ffffff08;
}
.neon-preview i[class*='neon-piece--'] {
  border: 1px solid #ffffff68;
  border-radius: 2px;
  background: currentColor;
  box-shadow: 0 0 5px currentColor;
}
.neon-level {
  position: relative;
  width: 12px;
  height: 221px;
  overflow: hidden;
  border-radius: 8px;
  background: #ffffff0c;
}
.neon-level i {
  position: absolute;
  right: 0;
  bottom: 0;
  left: 0;
  border-radius: 8px;
  background: linear-gradient(#73a7ff, #71f5e5);
  box-shadow: 0 0 9px #69f4e5;
  transition: height 0.25s;
}
.neon-controls {
  display: grid;
  grid-template-columns: repeat(5, 1fr);
  gap: 5px;
  margin-top: 9px;
}
.neon-controls button {
  height: 48px;
  display: grid;
  place-items: center;
  padding: 0;
  border: 1px solid #ffffff16;
  border-radius: 11px;
  color: #dffefd;
  background: #ffffff0b;
}
.neon-controls button:last-child {
  color: #071225;
  background: linear-gradient(135deg, #ffe265, #ff9167);
}
.neon-controls svg {
  transform: scale(1.2);
}
.neon-hint {
  margin: 7px 0 0;
  color: #d6deed;
  font-size: 16px;
  font-weight: 700;
  text-align: center;
}
.neon-overlay {
  position: absolute;
  z-index: 10;
  inset: 42px 0 19px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 25px;
  border-radius: 17px;
  background: #080c21e8;
  backdrop-filter: blur(6px);
  text-align: center;
}
.neon-overlay > svg {
  color: #71f5e5;
}
.neon-overlay > span {
  color: #ff7fa0;
  font-size: 13px;
  font-weight: 900;
  letter-spacing: 1px;
  text-transform: uppercase;
}
.neon-overlay h2 {
  margin: 0;
  font-size: 30px;
}
.neon-overlay p {
  margin: 0 0 4px;
  color: #dce4f2;
  font-size: 16px;
}
@keyframes neon-fall {
  0% {
    opacity: 0;
    transform: translateY(-25px);
  }
  18% {
    opacity: 1;
  }
  72% {
    transform: translateY(37px);
  }
  84%,
  100% {
    opacity: 0;
    transform: translateY(37px);
  }
}
@keyframes neon-active {
  from {
    filter: brightness(1.8);
    transform: scale(0.82);
  }
  to {
    filter: brightness(1);
    transform: scale(1);
  }
}
@keyframes neon-clear {
  0% {
    filter: brightness(1);
  }
  50% {
    filter: brightness(2.1);
    box-shadow:
      inset 0 0 40px #fff8,
      0 0 22px #67f8e5;
  }
  100% {
    filter: brightness(1);
  }
}
button:active {
  transform: scale(0.96);
}
@media (prefers-reduced-motion: reduce) {
  .neon-hero__piece,
  .neon-cell,
  .neon-board {
    animation: none;
  }
}
</style>
