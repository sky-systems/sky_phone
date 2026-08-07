<script setup lang="ts">
import {
  ChevronLeft,
  Circle,
  Cloud,
  Diamond,
  Flower2,
  Heart,
  Moon,
  Play,
  Sparkles,
  Star,
  Sun,
  Triangle,
  Volume2,
  VolumeX,
  Zap,
} from 'lucide-vue-next'
import { kButton } from 'konsta/vue'
import { computed, onBeforeUnmount, onMounted } from 'vue'

import { playMemorySound } from '@/features/games/memory/audio'
import { useMemoryStore } from '@/features/games/memory/store'
import type {
  MemoryDifficulty,
} from '@/features/games/memory/types'
import { usePhoneStore } from '@/stores/phone'

const phone = usePhoneStore()
const memory = useMemoryStore()
const difficulties: Array<{
  columns: number
  difficulty: MemoryDifficulty
  pairs: number
  rows: number
}> = [
  { columns: 3, difficulty: 'small', pairs: 6, rows: 4 },
  { columns: 4, difficulty: 'medium', pairs: 8, rows: 4 },
  { columns: 4, difficulty: 'large', pairs: 10, rows: 5 },
]
const symbols = {
  star: { color: '#f6b93b', icon: Star },
  heart: { color: '#ff6b81', icon: Heart },
  moon: { color: '#9b8afb', icon: Moon },
  sun: { color: '#ff9f43', icon: Sun },
  cloud: { color: '#67b7dc', icon: Cloud },
  bolt: { color: '#f5ca4d', icon: Zap },
  diamond: { color: '#52c6b8', icon: Diamond },
  circle: { color: '#ef7eb5', icon: Circle },
  triangle: { color: '#7c9cf5', icon: Triangle },
  flower: { color: '#a6d96a', icon: Flower2 },
}
const game = computed(() => memory.game)
let clockTimer: ReturnType<typeof setInterval> | undefined
let mismatchTimer: ReturnType<typeof setTimeout> | undefined

function formatTime(milliseconds: number): string {
  const totalSeconds = Math.floor(milliseconds / 1000)
  const minutes = Math.floor(totalSeconds / 60)
  const seconds = totalSeconds % 60
  return `${minutes}:${seconds.toString().padStart(2, '0')}`
}

function bestLabel(difficulty: MemoryDifficulty): string {
  const best = memory.best[difficulty]
  if (!best) return phone.t('Apps.memory.noBest')
  return `${best.moves} ${phone.t('Apps.memory.moves')} · ${formatTime(best.timeMs)}`
}

function selectCard(cardId: string): void {
  const previous = memory.game
  if (!previous) return

  memory.flip(cardId)
  const current = memory.game
  if (!current || current === previous) return

  if (current.status === 'won') {
    playMemorySound('win', memory.soundEnabled)
  } else if (current.matchedPairs > previous.matchedPairs) {
    playMemorySound('match', memory.soundEnabled)
  } else if (current.status === 'resolving') {
    playMemorySound('mismatch', memory.soundEnabled)
  } else {
    playMemorySound('flip', memory.soundEnabled)
  }

  if (current.status === 'resolving') {
    if (mismatchTimer) clearTimeout(mismatchTimer)
    mismatchTimer = setTimeout(() => memory.resolveMismatch(), 720)
  }
}

function toggleSound(): void {
  const enabled = !memory.soundEnabled
  memory.setSoundEnabled(enabled)
  if (enabled) playMemorySound('flip', true)
}

function restart(): void {
  const difficulty = memory.game?.difficulty
  if (difficulty) memory.start(difficulty)
}

function returnToMenu(): void {
  if (mismatchTimer) {
    clearTimeout(mismatchTimer)
    mismatchTimer = undefined
  }
  memory.showMenu()
}

memory.hydrate()
onMounted(() => {
  memory.resume()
  clockTimer = setInterval(() => memory.updateElapsed(), 100)
})
onBeforeUnmount(() => {
  if (clockTimer) clearInterval(clockTimer)
  if (mismatchTimer) clearTimeout(mismatchTimer)
  memory.resolveMismatch()
  memory.pause()
})
</script>

<template>
  <main
    class="memory-app"
    :class="{ 'memory-app--playing': game }"
    :aria-label="phone.t('Apps.memory.name')"
  >
    <header v-if="!game" class="memory-header">
      <div>
        <span>{{ phone.t('Apps.memory.eyebrow') }}</span>
        <h1>{{ phone.t('Apps.memory.name') }}</h1>
      </div>
      <div class="memory-header__actions">
        <Sparkles :size="23" aria-hidden="true" />
        <k-button
          component="button"
          clear
          rounded
          type="button"
          :aria-label="phone.t(memory.soundEnabled ? 'Apps.memory.mute' : 'Apps.memory.unmute')"
          :title="phone.t(memory.soundEnabled ? 'Apps.memory.mute' : 'Apps.memory.unmute')"
          @click="toggleSound"
        >
          <Volume2 v-if="memory.soundEnabled" :size="18" aria-hidden="true" />
          <VolumeX v-else :size="18" aria-hidden="true" />
        </k-button>
      </div>
    </header>

    <section v-if="!game" class="memory-menu">
      <div class="memory-hero" aria-hidden="true">
        <span class="memory-hero__card memory-hero__card--back"></span>
        <span class="memory-hero__card memory-hero__card--front">
          <Star :size="34" fill="currentColor" />
        </span>
      </div>
      <div class="memory-intro">
        <h2>{{ phone.t('Apps.memory.chooseTitle') }}</h2>
        <p>{{ phone.t('Apps.memory.chooseBody') }}</p>
      </div>

      <div class="memory-difficulties">
        <button
          v-for="option in difficulties"
          :key="option.difficulty"
          type="button"
          @click="memory.start(option.difficulty)"
        >
          <span class="memory-difficulty__size">
            {{ option.columns }}×{{ option.rows }}
          </span>
          <span class="memory-difficulty__name">
            {{ phone.t(`Apps.memory.difficulties.${option.difficulty}`) }}
          </span>
          <span class="memory-difficulty__best">
            {{ bestLabel(option.difficulty) }}
          </span>
          <Play :size="16" fill="currentColor" />
        </button>
      </div>
    </section>

    <section v-else class="memory-game">
      <div class="memory-stats">
        <k-button
          component="button"
          clear
          rounded
          type="button"
          class="memory-menu-button"
          :aria-label="phone.t('Apps.memory.backToMenu')"
          :title="phone.t('Apps.memory.backToMenu')"
          @click="returnToMenu"
        >
          <ChevronLeft :size="18" :stroke-width="2.6" aria-hidden="true" />
        </k-button>
        <div>
          <span>{{ phone.t('Apps.memory.time') }}</span>
          <strong>{{ formatTime(memory.elapsedMs) }}</strong>
        </div>
        <div>
          <span>{{ phone.t('Apps.memory.moves') }}</span>
          <strong>{{ game.moves }}</strong>
        </div>
        <k-button component="button" clear rounded type="button" @click="restart">
          {{ phone.t('Apps.memory.restart') }}
        </k-button>
      </div>

      <div
        class="memory-board"
        :class="`memory-board--${game.difficulty}`"
        :aria-label="phone.t('Apps.memory.board')"
      >
        <button
          v-for="card in game.cards"
          :key="card.id"
          type="button"
          class="memory-game-card"
          :class="{
            'memory-game-card--flipped': card.state !== 'hidden',
            'memory-game-card--matched': card.state === 'matched',
            'memory-game-card--mismatch':
              game.status === 'resolving' && game.selectedIds.includes(card.id),
          }"
          :disabled="card.state !== 'hidden' || game.status !== 'playing'"
          :aria-label="
            phone.t(
              card.state === 'hidden'
                ? 'Apps.memory.hiddenCard'
                : 'Apps.memory.revealedCard',
            )
          "
          @click="selectCard(card.id)"
        >
          <span class="memory-game-card__inner">
            <span class="memory-game-card__face memory-game-card__back">
              <i></i><i></i><i></i><i></i>
            </span>
            <span
              class="memory-game-card__face memory-game-card__front"
              :style="{ color: symbols[card.symbol as keyof typeof symbols].color }"
            >
              <component
                :is="symbols[card.symbol as keyof typeof symbols].icon"
                :size="game.difficulty === 'small' ? 30 : 24"
                :stroke-width="2.2"
                fill="currentColor"
              />
            </span>
          </span>
        </button>

        <div v-if="game.status === 'won'" class="memory-complete">
          <div class="memory-complete__burst"><Star :size="35" fill="currentColor" /></div>
          <span>{{ phone.t('Apps.memory.completeEyebrow') }}</span>
          <h2>{{ phone.t('Apps.memory.completeTitle') }}</h2>
          <p>
            {{ game.moves }} {{ phone.t('Apps.memory.moves') }} ·
            {{ formatTime(memory.elapsedMs) }}
          </p>
          <button type="button" class="memory-primary" @click="restart">
            {{ phone.t('Apps.memory.playAgain') }}
          </button>
          <button type="button" class="memory-secondary" @click="returnToMenu">
            {{ phone.t('Apps.memory.menu') }}
          </button>
        </div>
      </div>
    </section>
  </main>
</template>

<style scoped>
.memory-app {
  position: absolute;
  inset: 0;
  overflow: hidden;
  padding: 52px 17px 27px;
  color: #302a48;
  background:
    radial-gradient(circle at 88% 8%, rgb(255 255 255 / 72%), transparent 28%),
    linear-gradient(155deg, #f4efff 0%, #e7ddff 55%, #d9cdf7 100%);
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  user-select: none;
}

.memory-app--playing {
  padding: 0;
}

.memory-header {
  height: 52px;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.memory-header span {
  display: block;
  color: #8175a2;
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 1.25px;
  text-transform: uppercase;
}

.memory-header h1 {
  margin: 1px 0 0;
  font-size: 24px;
  line-height: 1;
  letter-spacing: -0.7px;
}

.memory-header__actions {
  display: flex;
  align-items: center;
  gap: 5px;
}

.memory-header__actions > svg,
.memory-header__actions button {
  box-sizing: content-box;
  padding: 9px;
  border: 0;
  border-radius: 13px;
  color: #7658c7;
  background: rgb(255 255 255 / 54%);
}

.memory-header__actions button {
  display: grid;
  place-items: center;
  cursor: pointer;
}

.memory-menu {
  height: calc(100% - 52px);
  display: flex;
  flex-direction: column;
  justify-content: center;
  gap: 17px;
}

.memory-hero {
  position: relative;
  width: 130px;
  height: 108px;
  margin: 0 auto;
}

.memory-hero__card {
  position: absolute;
  width: 70px;
  height: 88px;
  display: grid;
  place-items: center;
  border: 4px solid rgb(255 255 255 / 75%);
  border-radius: 17px;
  box-shadow: 0 12px 22px rgb(72 52 118 / 18%);
}

.memory-hero__card--back {
  left: 9px;
  top: 4px;
  background: repeating-linear-gradient(45deg, #8e72db 0 7px, #9f83e6 7px 14px);
  transform: rotate(-12deg);
}

.memory-hero__card--front {
  right: 9px;
  bottom: 0;
  color: #f4b83f;
  background: #fffaf0;
  transform: rotate(10deg);
}

.memory-intro { text-align: center; }
.memory-intro h2 { margin: 0; font-size: 23px; letter-spacing: -0.6px; }
.memory-intro p { margin: 7px 18px 0; color: #74698f; font-size: 14px; line-height: 1.4; }

.memory-difficulties {
  display: grid;
  gap: 7px;
}

.memory-difficulties button {
  min-height: 62px;
  display: grid;
  grid-template-columns: 48px 1fr auto;
  grid-template-rows: 1fr 1fr;
  align-items: center;
  column-gap: 10px;
  padding: 8px 12px;
  border: 1px solid rgb(91 67 143 / 8%);
  border-radius: 16px;
  color: #342d4c;
  background: rgb(255 255 255 / 62%);
  box-shadow: 0 5px 14px rgb(80 58 129 / 8%);
  text-align: left;
}

.memory-difficulty__size {
  grid-row: 1 / 3;
  display: grid;
  place-items: center;
  height: 39px;
  border-radius: 11px;
  color: #fff;
  background: linear-gradient(135deg, #9a7be1, #7558c4);
  font-size: 14px;
  font-weight: 800;
}

.memory-difficulty__name { align-self: end; font-size: 15px; font-weight: 800; }
.memory-difficulty__best { align-self: start; color: #74698f; font-size: 11.5px; line-height: 1.2; }
.memory-difficulties svg { grid-column: 3; grid-row: 1 / 3; color: #7658c7; }

.memory-game {
  position: absolute;
  inset: 0;
}

.memory-stats {
  position: absolute;
  z-index: 7;
  top: 66px;
  right: 18px;
  left: 18px;
  height: 42px;
  display: grid;
  grid-template-columns: 32px 1fr 1fr auto;
  align-items: center;
  gap: 4px;
  padding: 4px;
  border: 1px solid rgb(105 79 160 / 10%);
  border-radius: 21px;
  background: rgb(246 241 255 / 64%);
  box-shadow: 0 8px 24px rgb(75 52 121 / 13%);
  backdrop-filter: blur(14px);
  box-sizing: border-box;
}

.memory-stats div { height: 32px; display: grid; grid-template-rows: 10px 20px; align-content: center; justify-items: center; }
.memory-stats span { color: #74698f; font-size: 10.5px; font-weight: 800; line-height: 10px; text-transform: uppercase; }
.memory-stats strong { display: block; font-size: 19px; line-height: 20px; }
.memory-stats button { justify-self: end; border: 0; color: #7052bf; background: transparent; font-size: 13px; font-weight: 800; }
.memory-stats .memory-menu-button {
  width: 32px;
  height: 32px;
  display: grid;
  place-items: center;
  justify-self: start;
  padding: 0;
  border: 0;
  border-radius: 50%;
  background: rgb(255 255 255 / 48%);
  cursor: pointer;
}

.memory-board {
  position: absolute;
  inset: 0;
  display: grid;
  gap: 8px;
  align-content: center;
  padding: 108px 17px 28px;
  border: 0;
  border-radius: 0;
  background:
    radial-gradient(circle at 12% 88%, rgb(135 105 207 / 12%), transparent 31%),
    radial-gradient(circle at 88% 16%, rgb(255 255 255 / 54%), transparent 28%);
  perspective: 900px;
}

.memory-board--small { grid-template-columns: repeat(3, minmax(0, 1fr)); }
.memory-board--medium,
.memory-board--large { grid-template-columns: repeat(4, minmax(0, 1fr)); }
.memory-board--large { gap: 6px; padding-right: 15px; padding-left: 15px; }

.memory-game-card {
  aspect-ratio: 0.82;
  padding: 0;
  border: 0;
  border-radius: 13px;
  background: transparent;
  cursor: pointer;
  perspective: 500px;
}

.memory-game-card:disabled { cursor: default; }

.memory-game-card__inner {
  position: relative;
  width: 100%;
  height: 100%;
  display: block;
  transform-style: preserve-3d;
  transition: transform 360ms cubic-bezier(0.22, 0.68, 0.3, 1);
}

.memory-game-card--flipped .memory-game-card__inner { transform: rotateY(180deg); }

.memory-game-card__face {
  position: absolute;
  inset: 0;
  display: grid;
  place-items: center;
  overflow: hidden;
  border: 2px solid rgb(255 255 255 / 75%);
  border-radius: 13px;
  backface-visibility: hidden;
  box-shadow: 0 5px 10px rgb(73 52 117 / 13%);
}

.memory-game-card__back {
  position: absolute;
  grid-template-columns: repeat(2, 6px);
  grid-template-rows: repeat(2, 6px);
  gap: 6px;
  background: linear-gradient(145deg, #9d82e1, #7558bf);
}

.memory-game-card__back::before {
  position: absolute;
  inset: 5px;
  border: 1px solid rgb(255 255 255 / 15%);
  border-radius: 9px;
  background: radial-gradient(circle at 24% 18%, rgb(255 255 255 / 12%), transparent 42%);
  content: "";
}

.memory-game-card__back i { width: 6px; height: 6px; border-radius: 50%; background: rgb(255 255 255 / 30%); }

.memory-game-card__front {
  background: radial-gradient(circle at 50% 42%, #fff 0 25%, #fffaf1 72%, #f8f1e7 100%);
  transform: rotateY(180deg);
}

.memory-game-card--matched .memory-game-card__front {
  background: #f7fff2;
  box-shadow: 0 0 0 2px rgb(121 199 107 / 32%), 0 6px 12px rgb(71 143 65 / 14%);
}

.memory-game-card--matched {
  animation: memory-match-pop 520ms cubic-bezier(0.2, 0.9, 0.25, 1.25);
}

.memory-game-card--mismatch {
  animation: memory-mismatch-shake 420ms ease-in-out;
}

@keyframes memory-match-pop {
  0% { transform: scale(1) translateY(0); }
  38% { transform: scale(1.12) translateY(-4px); }
  68% { transform: scale(0.97) translateY(1px); }
  100% { transform: scale(1) translateY(0); }
}

@keyframes memory-mismatch-shake {
  0%, 100% { transform: translateX(0); }
  25% { transform: translateX(-3px) rotate(-1.5deg); }
  50% { transform: translateX(3px) rotate(1.5deg); }
  75% { transform: translateX(-2px) rotate(-1deg); }
}

.memory-complete {
  position: absolute;
  z-index: 5;
  inset: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 10px;
  border-radius: 0;
  background: rgb(244 239 255 / 90%);
  backdrop-filter: blur(6px);
  text-align: center;
}

.memory-complete__burst {
  width: 68px;
  height: 68px;
  display: grid;
  place-items: center;
  border-radius: 50%;
  color: #f3b63e;
  background: #fff9e8;
  box-shadow: 0 9px 22px rgb(100 75 151 / 17%);
}

.memory-complete > span { color: #74698f; font-size: 11px; font-weight: 800; letter-spacing: 1px; text-transform: uppercase; }
.memory-complete h2 { margin: 0; font-size: 27px; }
.memory-complete p { margin: -4px 0 4px; color: #756b8e; font-size: 14px; }

.memory-primary,
.memory-secondary {
  min-width: 155px;
  min-height: 42px;
  border-radius: 14px;
  font-size: 14px;
  font-weight: 800;
}

.memory-primary { border: 0; color: #fff; background: linear-gradient(135deg, #9a7be1, #7051bf); box-shadow: 0 8px 17px rgb(91 61 164 / 22%); }
.memory-secondary { border: 1px solid rgb(92 72 134 / 14%); color: #6e6091; background: rgb(255 255 255 / 48%); }

button:active { transform: scale(0.97); }

@media (prefers-reduced-motion: reduce) {
  .memory-game-card__inner { transition-duration: 1ms; }
  .memory-game-card--matched,
  .memory-game-card--mismatch { animation: none; }
}
</style>
