<script setup lang="ts">
import {
  ChevronDown,
  ChevronLeft,
  ChevronRight,
  ChevronUp,
  Pause,
  Play,
} from 'lucide-vue-next'
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'

import {
  SNAKE_BOARD_HEIGHT,
  SNAKE_BOARD_WIDTH,
} from '@/features/games/snake/engine'
import { useSnakeStore } from '@/features/games/snake/store'
import type {
  SnakeDirection,
  SnakePoint,
  SnakeSpeed,
} from '@/features/games/snake/types'
import { usePhoneStore } from '@/stores/phone'

const phone = usePhoneStore()
const snake = useSnakeStore()
const touchStart = ref<SnakePoint | null>(null)
const speedOptions: SnakeSpeed[] = ['relaxed', 'normal', 'fast']
const directionButtons: Array<{
  direction: SnakeDirection
  icon: typeof ChevronUp
}> = [
  { direction: 'up', icon: ChevronUp },
  { direction: 'left', icon: ChevronLeft },
  { direction: 'down', icon: ChevronDown },
  { direction: 'right', icon: ChevronRight },
]
const game = computed(() => snake.game)
const boardMotionStyle = computed(() => ({
  '--snake-motion-duration': `${Math.min(
    110,
    Math.round(snake.tickMilliseconds * 0.7),
  )}ms`,
}))
let gameTimer: ReturnType<typeof setInterval> | undefined

function cellStyle(point: SnakePoint): Record<string, string> {
  return {
    height: `${100 / SNAKE_BOARD_HEIGHT}%`,
    left: `${(point.x / SNAKE_BOARD_WIDTH) * 100}%`,
    top: `${(point.y / SNAKE_BOARD_HEIGHT) * 100}%`,
    width: `${100 / SNAKE_BOARD_WIDTH}%`,
  }
}

function bodySegmentStyle(point: SnakePoint): Record<string, string> {
  return {
    height: `${(0.72 / SNAKE_BOARD_HEIGHT) * 100}%`,
    left: `${((point.x + 0.14) / SNAKE_BOARD_WIDTH) * 100}%`,
    top: `${((point.y + 0.14) / SNAKE_BOARD_HEIGHT) * 100}%`,
    width: `${(0.72 / SNAKE_BOARD_WIDTH) * 100}%`,
  }
}

function connectorStyle(
  first: SnakePoint,
  second: SnakePoint,
): Record<string, string> {
  if (first.y === second.y) {
    return {
      height: `${(0.62 / SNAKE_BOARD_HEIGHT) * 100}%`,
      left: `${((Math.min(first.x, second.x) + 0.5) / SNAKE_BOARD_WIDTH) * 100}%`,
      top: `${((first.y + 0.19) / SNAKE_BOARD_HEIGHT) * 100}%`,
      width: `${(Math.abs(first.x - second.x) / SNAKE_BOARD_WIDTH) * 100}%`,
    }
  }

  return {
    height: `${(Math.abs(first.y - second.y) / SNAKE_BOARD_HEIGHT) * 100}%`,
    left: `${((first.x + 0.19) / SNAKE_BOARD_WIDTH) * 100}%`,
    top: `${((Math.min(first.y, second.y) + 0.5) / SNAKE_BOARD_HEIGHT) * 100}%`,
    width: `${(0.62 / SNAKE_BOARD_WIDTH) * 100}%`,
  }
}

function stopGameTimer(): void {
  if (gameTimer) clearInterval(gameTimer)
  gameTimer = undefined
}

function syncGameTimer(): void {
  stopGameTimer()
  if (snake.game?.status === 'playing') {
    gameTimer = setInterval(() => snake.tick(), snake.tickMilliseconds)
  }
}

function handleKeydown(event: KeyboardEvent): void {
  const directionByKey: Partial<Record<string, SnakeDirection>> = {
    ArrowDown: 'down',
    ArrowLeft: 'left',
    ArrowRight: 'right',
    ArrowUp: 'up',
    a: 'left',
    d: 'right',
    s: 'down',
    w: 'up',
  }
  const direction = directionByKey[event.key]

  if (direction) {
    event.preventDefault()
    snake.turn(direction)
  } else if (event.key === ' ' && snake.game) {
    event.preventDefault()
    if (snake.game.status === 'paused') {
      snake.resume()
    } else {
      snake.pause()
    }
  }
}

function beginSwipe(event: TouchEvent): void {
  const touch = event.changedTouches[0]
  touchStart.value = touch ? { x: touch.clientX, y: touch.clientY } : null
}

function endSwipe(event: TouchEvent): void {
  const start = touchStart.value
  const touch = event.changedTouches[0]
  touchStart.value = null
  if (!start || !touch) return

  const deltaX = touch.clientX - start.x
  const deltaY = touch.clientY - start.y
  if (Math.max(Math.abs(deltaX), Math.abs(deltaY)) < 18) return

  if (Math.abs(deltaX) > Math.abs(deltaY)) {
    snake.turn(deltaX > 0 ? 'right' : 'left')
  } else {
    snake.turn(deltaY > 0 ? 'down' : 'up')
  }
}

snake.hydrate()
watch(
  () => [snake.game?.status, snake.tickMilliseconds],
  syncGameTimer,
  { immediate: true },
)
onMounted(() => window.addEventListener('keydown', handleKeydown))
onBeforeUnmount(() => {
  stopGameTimer()
  snake.pause()
  window.removeEventListener('keydown', handleKeydown)
})
</script>

<template>
  <main class="snake-app" :aria-label="phone.t('Apps.snake.name')">
    <header class="snake-header">
      <span class="snake-brand">{{ phone.t('Apps.snake.name') }}</span>
      <div class="snake-score-card">
        <span>{{ phone.t('Apps.snake.highScore') }}</span>
        <strong>{{ snake.highScore }}</strong>
      </div>
    </header>

    <section v-if="!game" class="snake-menu">
      <div class="snake-mark" aria-hidden="true">
        <span class="snake-mark__eye"></span>
        <span class="snake-mark__fruit"></span>
      </div>
      <div>
        <h1>{{ phone.t('Apps.snake.readyTitle') }}</h1>
        <p>{{ phone.t('Apps.snake.readyBody') }}</p>
      </div>
      <fieldset class="snake-speed-picker">
        <legend>{{ phone.t('Apps.snake.speed') }}</legend>
        <button
          v-for="speed in speedOptions"
          :key="speed"
          type="button"
          :class="{ active: snake.speed === speed }"
          @click="snake.setSpeed(speed)"
        >
          {{ phone.t(`Apps.snake.speeds.${speed}`) }}
        </button>
      </fieldset>
      <button type="button" class="snake-primary" @click="snake.start">
        <Play :size="18" fill="currentColor" />
        {{ phone.t('Apps.snake.start') }}
      </button>
    </section>

    <section v-else class="snake-game">
      <div class="snake-game__meta">
        <span>{{ phone.t('Apps.snake.score') }}</span>
        <strong>{{ game.score }}</strong>
        <button
          v-if="game.status !== 'game-over'"
          type="button"
          :aria-label="
            phone.t(
              game.status === 'paused'
                ? 'Apps.snake.resume'
                : 'Apps.snake.pause',
            )
          "
          @click="game.status === 'paused' ? snake.resume() : snake.pause()"
        >
          <Play v-if="game.status === 'paused'" :size="18" fill="currentColor" />
          <Pause v-else :size="18" fill="currentColor" />
        </button>
      </div>

      <div
        class="snake-board"
        :style="boardMotionStyle"
        :aria-label="phone.t('Apps.snake.board')"
        @touchstart.passive="beginSwipe"
        @touchend.passive="endSwipe"
      >
        <span
          v-for="(_, index) in game.body.slice(1)"
          :key="`connector-${index}`"
          class="snake-body-connector"
          :style="connectorStyle(game.body[index], game.body[index + 1])"
        ></span>
        <span
          v-for="(segment, index) in game.body"
          :key="`body-${index}`"
          class="snake-body-segment"
          :class="{ 'snake-body-segment--tail': index === game.body.length - 1 }"
          :style="bodySegmentStyle(segment)"
        ></span>
        <span
          class="snake-head"
          :class="`snake-head--${game.direction}`"
          :style="cellStyle(game.body[0])"
        >
          <i class="snake-head__eye snake-head__eye--top"></i>
          <i class="snake-head__eye snake-head__eye--bottom"></i>
        </span>
        <span class="snake-fruit" :style="cellStyle(game.fruit)">
          <i></i>
        </span>

        <div v-if="game.status !== 'playing'" class="snake-overlay">
          <template v-if="game.status === 'paused'">
            <h2>{{ phone.t('Apps.snake.paused') }}</h2>
            <button type="button" class="snake-primary" @click="snake.resume">
              <Play :size="17" fill="currentColor" />
              {{ phone.t('Apps.snake.resume') }}
            </button>
          </template>
          <template v-else>
            <span class="snake-overline">{{ phone.t('Apps.snake.score') }} {{ game.score }}</span>
            <h2>{{ phone.t('Apps.snake.gameOver') }}</h2>
            <button type="button" class="snake-primary" @click="snake.start">
              {{ phone.t('Apps.snake.restart') }}
            </button>
            <button type="button" class="snake-secondary" @click="snake.showMenu">
              {{ phone.t('Apps.snake.menu') }}
            </button>
          </template>
        </div>
      </div>

      <p class="snake-hint">{{ phone.t('Apps.snake.swipeHint') }}</p>
      <div class="snake-controls" :aria-label="phone.t('Apps.snake.controls')">
        <button
          v-for="control in directionButtons"
          :key="control.direction"
          type="button"
          :class="`snake-control--${control.direction}`"
          :aria-label="phone.t(`Apps.snake.directions.${control.direction}`)"
          @click="snake.turn(control.direction)"
        >
          <component :is="control.icon" :size="24" :stroke-width="2.6" />
        </button>
      </div>
    </section>
  </main>
</template>

<style scoped>
.snake-app {
  position: absolute;
  inset: 0;
  overflow: hidden;
  padding: 52px 18px 28px;
  color: #eef7ec;
  background:
    radial-gradient(circle at 85% 8%, rgb(100 211 91 / 22%), transparent 30%),
    linear-gradient(165deg, #142b25 0%, #0c1715 62%, #08100f 100%);
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  user-select: none;
  touch-action: none;
}

.snake-header,
.snake-game__meta {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.snake-brand {
  font-size: 24px;
  font-weight: 800;
  letter-spacing: -0.7px;
}

.snake-score-card {
  display: grid;
  grid-template-columns: auto auto;
  align-items: center;
  gap: 2px 9px;
  padding: 7px 11px;
  border: 1px solid rgb(255 255 255 / 9%);
  border-radius: 13px;
  background: rgb(255 255 255 / 7%);
}

.snake-score-card span {
  grid-row: 1 / 3;
  max-width: 50px;
  color: #9db3a8;
  font-size: 9px;
  font-weight: 700;
  line-height: 1.05;
  text-transform: uppercase;
}

.snake-score-card strong {
  font-size: 20px;
  line-height: 1;
}

.snake-menu {
  height: calc(100% - 56px);
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 25px;
  text-align: center;
}

.snake-mark {
  position: relative;
  width: 118px;
  height: 118px;
  border: 22px solid #65c85d;
  border-top-color: #84df6d;
  border-radius: 50%;
  filter: drop-shadow(0 14px 18px rgb(0 0 0 / 26%));
}

.snake-mark::after {
  content: "";
  position: absolute;
  right: -25px;
  top: -20px;
  width: 39px;
  height: 29px;
  border-radius: 55% 60% 55% 45%;
  background: #85df6e;
  transform: rotate(13deg);
}

.snake-mark__eye {
  position: absolute;
  z-index: 2;
  right: -13px;
  top: -10px;
  width: 5px;
  height: 5px;
  border-radius: 50%;
  background: #142b25;
}

.snake-mark__fruit {
  position: absolute;
  right: -43px;
  bottom: -17px;
  width: 25px;
  height: 25px;
  border-radius: 48% 52% 55% 45%;
  background: #ff5f52;
  box-shadow: inset -4px -4px 0 rgb(139 21 22 / 22%);
}

.snake-menu h1,
.snake-overlay h2 {
  margin: 0;
  font-size: 28px;
  letter-spacing: -0.8px;
}

.snake-menu p {
  max-width: 265px;
  margin: 7px 0 0;
  color: #a6bbb0;
  font-size: 13px;
  line-height: 1.4;
}

.snake-speed-picker {
  width: 100%;
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 5px;
  padding: 5px;
  border: 0;
  border-radius: 14px;
  background: rgb(255 255 255 / 7%);
}

.snake-speed-picker legend {
  position: absolute;
  width: 1px;
  height: 1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
}

.snake-speed-picker button,
.snake-secondary {
  min-height: 38px;
  border: 0;
  border-radius: 10px;
  color: #9fb3a9;
  background: transparent;
  font-size: 12px;
  font-weight: 700;
}

.snake-speed-picker button.active {
  color: #10241e;
  background: #dff6d9;
  box-shadow: 0 4px 12px rgb(0 0 0 / 18%);
}

.snake-primary {
  min-width: 170px;
  min-height: 47px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 0 22px;
  border: 0;
  border-radius: 16px;
  color: #10241e;
  background: linear-gradient(135deg, #8ae276, #61c95c);
  box-shadow: 0 9px 22px rgb(63 176 78 / 25%);
  font-size: 14px;
  font-weight: 800;
}

.snake-game {
  padding-top: 8px;
}

.snake-game__meta {
  height: 43px;
  justify-content: flex-start;
  gap: 8px;
}

.snake-game__meta span {
  color: #9fb3a9;
  font-size: 11px;
  font-weight: 700;
  text-transform: uppercase;
}

.snake-game__meta strong {
  font-size: 22px;
}

.snake-game__meta button {
  width: 34px;
  height: 34px;
  display: grid;
  place-items: center;
  margin-left: auto;
  border: 1px solid rgb(255 255 255 / 9%);
  border-radius: 50%;
  color: #dff6d9;
  background: rgb(255 255 255 / 7%);
}

.snake-board {
  position: relative;
  width: 100%;
  aspect-ratio: 16 / 18;
  overflow: hidden;
  border: 1px solid rgb(167 231 157 / 16%);
  border-radius: 18px;
  background-color: #162d26;
  background-image:
    linear-gradient(rgb(255 255 255 / 2%) 1px, transparent 1px),
    linear-gradient(90deg, rgb(255 255 255 / 2%) 1px, transparent 1px);
  background-size: calc(100% / 16) calc(100% / 18);
  box-shadow: inset 0 0 35px rgb(0 0 0 / 20%), 0 17px 35px rgb(0 0 0 / 20%);
}

.snake-head,
.snake-fruit {
  position: absolute;
  display: block;
}

.snake-body-connector,
.snake-body-segment {
  position: absolute;
  z-index: 1;
  background: #6dcc62;
  transition-duration: var(--snake-motion-duration);
  transition-timing-function: cubic-bezier(0.22, 0.68, 0.3, 1);
  will-change: left, top, width, height;
}

.snake-body-connector {
  border-radius: 999px;
  transition-property: left, top, width, height;
}

.snake-body-segment {
  border-radius: 50%;
  transition-property: left, top;
}

.snake-body-segment--tail {
  background: #62be5c;
  transform: scale(0.86);
}

.snake-head {
  z-index: 3;
  border: 1px solid #438f48;
  border-radius: 45% 55% 55% 45%;
  background: #86dc6b;
  box-shadow:
    inset -2px -2px 0 rgb(35 112 51 / 14%),
    0 2px 3px rgb(2 15 8 / 24%);
  transform-origin: center;
  transition-duration: var(--snake-motion-duration);
  transition-property: left, top;
  transition-timing-function: cubic-bezier(0.22, 0.68, 0.3, 1);
  will-change: left, top;
}

.snake-head--right { transform: scale(0.92) rotate(0deg); }
.snake-head--down { transform: scale(0.92) rotate(90deg); }
.snake-head--left { transform: scale(0.92) rotate(180deg); }
.snake-head--up { transform: scale(0.92) rotate(-90deg); }

.snake-head__eye {
  position: absolute;
  right: 18%;
  width: 4px;
  height: 4px;
  border: 1px solid #f5ffe9;
  border-radius: 50%;
  background: #10241e;
}

.snake-head__eye--top { top: 17%; }
.snake-head__eye--bottom { bottom: 17%; }

.snake-fruit {
  z-index: 2;
  padding: 3px;
  border-radius: 50%;
  background-color: #ff5c50;
  box-shadow:
    inset -2px -3px 0 rgb(130 17 21 / 27%),
    0 0 0 3px rgb(255 92 80 / 10%),
    0 3px 5px rgb(0 0 0 / 25%);
  animation: snake-fruit-pulse 1.35s ease-in-out infinite;
}

.snake-fruit i {
  position: absolute;
  left: 50%;
  top: 0;
  width: 2px;
  height: 5px;
  border-radius: 2px;
  background: #9ee07a;
  transform: rotate(25deg);
}

@keyframes snake-fruit-pulse {
  0%, 100% { transform: scale(0.88); }
  50% { transform: scale(1.06); }
}

.snake-overlay {
  position: absolute;
  z-index: 5;
  inset: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 13px;
  background: rgb(6 16 13 / 82%);
  backdrop-filter: blur(4px);
}

.snake-overlay .snake-primary {
  min-height: 43px;
}

.snake-overline {
  color: #91e475;
  font-size: 12px;
  font-weight: 800;
  text-transform: uppercase;
}

.snake-secondary {
  min-width: 140px;
  color: #c0d0c8;
  border: 1px solid rgb(255 255 255 / 10%);
}

.snake-hint {
  margin: 9px 0 6px;
  color: #71867c;
  font-size: 10px;
  text-align: center;
}

.snake-controls {
  position: relative;
  width: 132px;
  height: 91px;
  margin: 0 auto;
}

.snake-controls button {
  position: absolute;
  width: 42px;
  height: 42px;
  display: grid;
  place-items: center;
  border: 1px solid rgb(255 255 255 / 9%);
  border-radius: 13px;
  color: #cae6d1;
  background: rgb(255 255 255 / 7%);
}

.snake-control--up { left: 45px; top: 0; }
.snake-control--left { left: 0; top: 45px; }
.snake-control--down { left: 45px; top: 45px; }
.snake-control--right { right: 0; top: 45px; }

button:active {
  transform: scale(0.96);
}
</style>
