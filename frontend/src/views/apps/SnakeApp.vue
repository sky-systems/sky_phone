<script setup lang="ts">
import {
  ChevronLeft,
  Pause,
  Play,
} from 'lucide-vue-next'
import { kButton } from 'konsta/vue'
import { computed, onBeforeUnmount, onMounted, watch } from 'vue'

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
const speedOptions: SnakeSpeed[] = ['relaxed', 'normal', 'fast']
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
    gameTimer = setInterval(() => {
      snake.tick()
    }, snake.tickMilliseconds)
  }
}

function returnToMenu(): void {
  stopGameTimer()
  snake.showMenu()
}

function startGame(): void {
  snake.start()
}

function handleKeydown(event: KeyboardEvent): void {
  const directionByKey: Partial<Record<string, SnakeDirection>> = {
    ArrowDown: 'down',
    ArrowLeft: 'left',
    ArrowRight: 'right',
    ArrowUp: 'up',
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
  <main
    class="snake-app"
    :class="{ 'snake-app--playing': game }"
    :aria-label="phone.t('Apps.snake.name')"
  >
    <header v-if="!game" class="snake-header">
      <span class="snake-brand">{{ phone.t('Apps.snake.name') }}</span>
      <div class="snake-score-card">
        <span>{{ phone.t('Apps.snake.highScore') }}</span>
        <strong>{{ snake.highScore }}</strong>
      </div>
    </header>

    <section v-if="!game" class="snake-menu">
      <div class="snake-mark" aria-hidden="true">
        <svg viewBox="0 0 150 128" role="presentation">
          <defs>
            <linearGradient id="snake-menu-body" x1="0" y1="1" x2="1" y2="0">
              <stop offset="0" stop-color="#58b957" />
              <stop offset="0.55" stop-color="#72d267" />
              <stop offset="1" stop-color="#94e879" />
            </linearGradient>
            <filter id="snake-menu-shadow" x="-30%" y="-30%" width="160%" height="170%">
              <feDropShadow dx="0" dy="7" stdDeviation="6" flood-color="#000" flood-opacity="0.28" />
            </filter>
          </defs>
          <g filter="url(#snake-menu-shadow)">
            <path
              class="snake-mark__body"
              d="M25 96 C17 70 35 55 58 61 C78 67 89 79 108 68 C123 59 122 42 112 31"
              fill="none"
              stroke="url(#snake-menu-body)"
              stroke-linecap="round"
              stroke-width="22"
            />
            <circle cx="25" cy="96" r="7" fill="#4fae51" />
            <g class="snake-mark__head" transform="translate(111 29) rotate(-35)">
              <rect x="-13" y="-13" width="34" height="27" rx="13" fill="#91e678" />
              <circle cx="12" cy="-6" r="3.3" fill="#f4ffe9" />
              <circle cx="12" cy="7" r="3.3" fill="#f4ffe9" />
              <circle cx="13" cy="-6" r="1.7" fill="#10241e" />
              <circle cx="13" cy="7" r="1.7" fill="#10241e" />
            </g>
          </g>
          <g class="snake-mark__fruit" transform="translate(126 87)">
            <circle r="12" fill="#ff6256" />
            <path d="M0 -11 C1 -17 5 -19 8 -20" fill="none" stroke="#6fbe58" stroke-linecap="round" stroke-width="3" />
            <ellipse cx="8" cy="-17" rx="6" ry="3" fill="#8adb67" transform="rotate(-22 8 -17)" />
            <circle cx="-4" cy="-4" r="2.5" fill="#ff9b8f" opacity="0.72" />
          </g>
        </svg>
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
      <button type="button" class="snake-primary" @click="startGame">
        <Play :size="18" fill="currentColor" />
        {{ phone.t('Apps.snake.start') }}
      </button>
    </section>

    <section v-else class="snake-game">
      <div class="snake-game__meta">
        <k-button
          component="button"
          clear
          rounded
          type="button"
          class="snake-game__back"
          :aria-label="phone.t('Apps.snake.backToMenu')"
          :title="phone.t('Apps.snake.backToMenu')"
          @click="returnToMenu"
        >
          <ChevronLeft :size="18" :stroke-width="2.7" aria-hidden="true" />
        </k-button>
        <div>
          <span>{{ phone.t('Apps.snake.score') }}</span>
          <strong>{{ game.score }}</strong>
        </div>
        <k-button
          component="button"
          clear
          rounded
          v-if="game.status !== 'game-over'"
          type="button"
          class="snake-game__pause"
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
        </k-button>
      </div>

      <div
        class="snake-board"
        :style="boardMotionStyle"
        :aria-label="phone.t('Apps.snake.board')"
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
            <button type="button" class="snake-primary" @click="startGame">
              {{ phone.t('Apps.snake.restart') }}
            </button>
            <button type="button" class="snake-secondary" @click="returnToMenu">
              {{ phone.t('Apps.snake.menu') }}
            </button>
          </template>
        </div>
      </div>

      <p class="snake-hint">{{ phone.t('Apps.snake.swipeHint') }}</p>
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

.snake-app--playing {
  padding: 0;
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
  width: 174px;
  height: 148px;
  display: grid;
  place-items: center;
  border: 1px solid rgb(180 242 164 / 9%);
  border-radius: 35px;
  background:
    radial-gradient(circle at 75% 20%, rgb(138 226 118 / 14%), transparent 34%),
    rgb(255 255 255 / 4%);
  box-shadow: inset 0 1px 0 rgb(255 255 255 / 5%), 0 18px 32px rgb(0 0 0 / 19%);
}

.snake-mark svg {
  width: 157px;
  height: 134px;
  overflow: visible;
}

.snake-mark__body {
  animation: snake-menu-breathe 2.8s ease-in-out infinite;
  transform-origin: center;
}

.snake-mark__fruit {
  animation: snake-menu-fruit 1.8s ease-in-out infinite;
  transform-box: fill-box;
  transform-origin: center;
}

@keyframes snake-menu-breathe {
  0%, 100% { opacity: 0.94; transform: scale(0.985); }
  50% { opacity: 1; transform: scale(1.01); }
}

@keyframes snake-menu-fruit {
  0%, 100% { transform: translate(126px, 87px) scale(0.94); }
  50% { transform: translate(126px, 87px) scale(1.05); }
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
  position: absolute;
  inset: 0;
}

.snake-game__meta {
  position: absolute;
  z-index: 7;
  top: 66px;
  right: 18px;
  left: 18px;
  height: 42px;
  display: grid;
  grid-template-columns: 32px 1fr 32px;
  align-items: center;
  gap: 4px;
  padding: 4px;
  border: 1px solid rgb(255 255 255 / 9%);
  border-radius: 21px;
  background: rgb(8 22 18 / 58%);
  box-shadow: 0 8px 24px rgb(0 0 0 / 18%);
  backdrop-filter: blur(14px);
  box-sizing: border-box;
}

.snake-game__meta div {
  height: 32px;
  display: grid;
  grid-template-rows: 10px 20px;
  align-content: center;
  justify-items: center;
}

.snake-game__meta span {
  color: #9fb3a9;
  font-size: 11px;
  font-weight: 700;
  line-height: 10px;
  text-transform: uppercase;
}

.snake-game__meta strong {
  display: block;
  font-size: 19px;
  line-height: 20px;
}

.snake-game__meta button {
  width: 32px;
  height: 32px;
  display: grid;
  place-items: center;
  border: 0;
  border-radius: 50%;
  color: #dff6d9;
  background: rgb(255 255 255 / 8%);
}

.snake-game__meta .snake-game__pause { justify-self: end; }
.snake-game__meta .snake-game__back { justify-self: start; }

.snake-board {
  position: absolute;
  top: 118px;
  right: 18px;
  bottom: 62px;
  left: 18px;
  overflow: hidden;
  border: 1px solid rgb(145 228 117 / 24%);
  border-radius: 18px;
  background-color: #162d26;
  background-image:
    linear-gradient(rgb(173 233 160 / 4%) 1px, transparent 1px),
    linear-gradient(90deg, rgb(173 233 160 / 4%) 1px, transparent 1px),
    radial-gradient(circle at 50% 42%, rgb(94 191 91 / 8%), transparent 68%);
  background-size:
    calc(100% / 16) calc(100% / 30),
    calc(100% / 16) calc(100% / 30),
    100% 100%;
  box-shadow:
    inset 0 0 55px rgb(0 0 0 / 24%),
    inset 0 0 0 1px rgb(213 255 199 / 3%),
    0 12px 30px rgb(0 0 0 / 20%),
    0 0 18px rgb(89 196 82 / 7%);
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
  position: absolute;
  z-index: 6;
  right: 50px;
  bottom: 27px;
  left: 50px;
  margin: 0;
  padding: 7px 10px;
  border-radius: 999px;
  color: #9eb2a8;
  background: rgb(8 22 18 / 48%);
  backdrop-filter: blur(10px);
  font-size: 10px;
  text-align: center;
  pointer-events: none;
}

button:active {
  transform: scale(0.96);
}

@media (prefers-reduced-motion: reduce) {
  .snake-mark__body,
  .snake-mark__fruit { animation: none; }
}
</style>
