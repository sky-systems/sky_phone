<script setup lang="ts">
import {
  Bomb,
  ChevronLeft,
  Flag,
  RotateCcw,
  Volume2,
  VolumeX,
} from 'lucide-vue-next'
import { computed, onBeforeUnmount, onMounted } from 'vue'

import { playMinesweeperSound } from '@/features/games/minesweeper/audio'
import { MINESWEEPER_DIFFICULTIES } from '@/features/games/minesweeper/engine'
import { useMinesweeperStore } from '@/features/games/minesweeper/store'
import type {
  MinesweeperCell,
  MinesweeperDifficulty,
} from '@/features/games/minesweeper/types'
import { usePhoneStore } from '@/stores/phone'

const phone = usePhoneStore()
const minesweeper = useMinesweeperStore()
const difficulties: MinesweeperDifficulty[] = ['quick', 'classic', 'expert']
const game = computed(() => minesweeper.game)
const flagsPlaced = computed(
  () => minesweeper.game?.cells.filter((cell) => cell.isFlagged).length ?? 0,
)
const minesRemaining = computed(() =>
  Math.max(0, (minesweeper.game?.mineCount ?? 0) - flagsPlaced.value),
)
let clockTimer: ReturnType<typeof setInterval> | undefined
let longPressTimer: ReturnType<typeof setTimeout> | undefined
let suppressNextClick = false
let suppressTimer: ReturnType<typeof setTimeout> | undefined

function formatTime(milliseconds: number): string {
  const seconds = Math.floor(milliseconds / 1000)
  return `${Math.floor(seconds / 60)}:${(seconds % 60).toString().padStart(2, '0')}`
}

function bestLabel(difficulty: MinesweeperDifficulty): string {
  const best = minesweeper.best[difficulty]
  return best ? formatTime(best.timeMs) : phone.t('Apps.minesweeper.noBest')
}

function cellLabel(cell: MinesweeperCell): string {
  if (cell.isFlagged) return phone.t('Apps.minesweeper.flaggedCell')
  if (!cell.isRevealed) return phone.t('Apps.minesweeper.hiddenCell')
  if (cell.isMine) return phone.t('Apps.minesweeper.mineCell')
  return cell.adjacentMines > 0
    ? phone.t('Apps.minesweeper.numberCell', {
        count: String(cell.adjacentMines),
      })
    : phone.t('Apps.minesweeper.emptyCell')
}

function reveal(cellId: number): void {
  if (suppressNextClick) {
    suppressNextClick = false
    return
  }

  const result = minesweeper.reveal(cellId)
  if (!result?.changed) return
  if (result.state.status === 'lost') {
    playMinesweeperSound('mine', minesweeper.soundEnabled)
  } else if (result.state.status === 'won') {
    playMinesweeperSound('win', minesweeper.soundEnabled)
  } else {
    playMinesweeperSound('reveal', minesweeper.soundEnabled)
  }
}

function toggleFlag(cellId: number): void {
  const result = minesweeper.toggleFlag(cellId)
  if (result?.changed) playMinesweeperSound('flag', minesweeper.soundEnabled)
}

function beginLongPress(cellId: number): void {
  if (longPressTimer) clearTimeout(longPressTimer)
  longPressTimer = setTimeout(() => {
    suppressNextClick = true
    toggleFlag(cellId)
    if (suppressTimer) clearTimeout(suppressTimer)
    suppressTimer = setTimeout(() => {
      suppressNextClick = false
    }, 650)
  }, 470)
}

function cancelLongPress(): void {
  if (longPressTimer) clearTimeout(longPressTimer)
  longPressTimer = undefined
}

function toggleSound(): void {
  const enabled = !minesweeper.soundEnabled
  minesweeper.setSoundEnabled(enabled)
  if (enabled) playMinesweeperSound('flag', true)
}

function restart(): void {
  if (minesweeper.game) minesweeper.start(minesweeper.game.difficulty)
}

minesweeper.hydrate()
onMounted(() => {
  if (!minesweeper.menuOpen) minesweeper.resumeGame()
  clockTimer = setInterval(() => minesweeper.updateElapsed(), 100)
})
onBeforeUnmount(() => {
  if (clockTimer) clearInterval(clockTimer)
  if (longPressTimer) clearTimeout(longPressTimer)
  if (suppressTimer) clearTimeout(suppressTimer)
  minesweeper.pause()
  minesweeper.persist()
})
</script>

<template>
  <main class="minesweeper-app" :aria-label="phone.t('Apps.minesweeper.name')">
    <header class="minesweeper-header">
      <div>
        <span>{{ phone.t('Apps.minesweeper.eyebrow') }}</span>
        <h1>{{ phone.t('Apps.minesweeper.name') }}</h1>
      </div>
      <button
        type="button"
        :aria-label="
          phone.t(
            minesweeper.soundEnabled
              ? 'Apps.minesweeper.mute'
              : 'Apps.minesweeper.unmute',
          )
        "
        @click="toggleSound"
      >
        <Volume2 v-if="minesweeper.soundEnabled" :size="18" aria-hidden="true" />
        <VolumeX v-else :size="18" aria-hidden="true" />
      </button>
    </header>

    <section v-if="minesweeper.menuOpen" class="minesweeper-menu">
      <div class="minesweeper-hero" aria-hidden="true">
        <span></span><span></span><span class="minesweeper-hero__one">1</span>
        <span></span><span class="minesweeper-hero__mine"><Bomb :size="27" /></span><span></span>
        <span class="minesweeper-hero__two">2</span><span></span><span class="minesweeper-hero__flag"><Flag :size="24" fill="currentColor" /></span>
      </div>

      <div class="minesweeper-intro">
        <h2>{{ phone.t('Apps.minesweeper.chooseTitle') }}</h2>
        <p>{{ phone.t('Apps.minesweeper.chooseBody') }}</p>
      </div>

      <button
        v-if="game && game.status !== 'lost' && game.status !== 'won'"
        type="button"
        class="minesweeper-resume"
        @click="minesweeper.resumeGame"
      >
        {{ phone.t('Apps.minesweeper.resume') }}
        <small>{{ phone.t(`Apps.minesweeper.difficulties.${game.difficulty}`) }} · {{ formatTime(minesweeper.elapsedMs) }}</small>
      </button>

      <div class="minesweeper-difficulties">
        <button
          v-for="difficulty in difficulties"
          :key="difficulty"
          type="button"
          @click="minesweeper.start(difficulty)"
        >
          <span class="minesweeper-difficulty__size">
            {{ MINESWEEPER_DIFFICULTIES[difficulty].width }}×{{ MINESWEEPER_DIFFICULTIES[difficulty].height }}
          </span>
          <strong>{{ phone.t(`Apps.minesweeper.difficulties.${difficulty}`) }}</strong>
          <small>
            {{ MINESWEEPER_DIFFICULTIES[difficulty].mines }} {{ phone.t('Apps.minesweeper.mines') }} · {{ bestLabel(difficulty) }}
          </small>
        </button>
      </div>

      <p class="minesweeper-long-press">{{ phone.t('Apps.minesweeper.longPressHint') }}</p>
    </section>

    <section v-else-if="game" class="minesweeper-game">
      <div class="minesweeper-toolbar">
        <button
          type="button"
          class="minesweeper-toolbar__icon"
          :aria-label="phone.t('Apps.minesweeper.backToMenu')"
          @pointerup.stop="minesweeper.showMenu()"
          @click.stop="minesweeper.showMenu()"
        >
          <ChevronLeft :size="19" :stroke-width="2.7" aria-hidden="true" />
        </button>
        <div>
          <span>{{ phone.t('Apps.minesweeper.mines') }}</span>
          <strong>{{ minesRemaining }}</strong>
        </div>
        <div>
          <span>{{ phone.t('Apps.minesweeper.time') }}</span>
          <strong>{{ formatTime(minesweeper.elapsedMs) }}</strong>
        </div>
        <button
          type="button"
          class="minesweeper-toolbar__icon"
          :aria-label="phone.t('Apps.minesweeper.restart')"
          @click="restart"
        >
          <RotateCcw :size="17" :stroke-width="2.5" aria-hidden="true" />
        </button>
      </div>

      <div
        class="minesweeper-board"
        :class="`minesweeper-board--${game.difficulty}`"
        :style="{ '--minesweeper-columns': game.width }"
        :aria-label="phone.t('Apps.minesweeper.board')"
      >
        <button
          v-for="cell in game.cells"
          :key="cell.id"
          type="button"
          class="minesweeper-cell"
          :class="{
            'minesweeper-cell--revealed': cell.isRevealed,
            'minesweeper-cell--flagged': cell.isFlagged,
            'minesweeper-cell--mine': cell.isMine && cell.isRevealed,
            'minesweeper-cell--exploded': game.explodedCellId === cell.id,
            [`minesweeper-cell--number-${cell.adjacentMines}`]:
              cell.isRevealed && !cell.isMine && cell.adjacentMines > 0,
          }"
          :aria-label="cellLabel(cell)"
          @click="reveal(cell.id)"
          @contextmenu.prevent="toggleFlag(cell.id)"
          @pointerdown="beginLongPress(cell.id)"
          @pointerup="cancelLongPress"
          @pointerleave="cancelLongPress"
          @pointercancel="cancelLongPress"
        >
          <Flag v-if="cell.isFlagged" :size="15" fill="currentColor" aria-hidden="true" />
          <Bomb v-else-if="cell.isMine && cell.isRevealed" :size="16" aria-hidden="true" />
          <strong v-else-if="cell.isRevealed && cell.adjacentMines > 0">{{ cell.adjacentMines }}</strong>
        </button>

        <div v-if="game.status === 'won' || game.status === 'lost'" class="minesweeper-overlay">
          <span class="minesweeper-overlay__icon">
            <Flag v-if="game.status === 'won'" :size="30" fill="currentColor" />
            <Bomb v-else :size="30" />
          </span>
          <h2>{{ phone.t(game.status === 'won' ? 'Apps.minesweeper.wonTitle' : 'Apps.minesweeper.lostTitle') }}</h2>
          <p>
            {{
              phone.t(
                game.status === 'won'
                  ? 'Apps.minesweeper.wonBody'
                  : 'Apps.minesweeper.lostBody',
                { time: formatTime(minesweeper.elapsedMs) },
              )
            }}
          </p>
          <button type="button" class="minesweeper-primary" @click="restart">
            {{ phone.t('Apps.minesweeper.playAgain') }}
          </button>
          <button
            type="button"
            class="minesweeper-secondary"
            @pointerup.stop="minesweeper.showMenu()"
            @click.stop="minesweeper.showMenu()"
          >
            {{ phone.t('Apps.minesweeper.mainMenu') }}
          </button>
        </div>
      </div>

      <p class="minesweeper-game__hint">{{ phone.t('Apps.minesweeper.gameHint') }}</p>
    </section>
  </main>
</template>

<style scoped>
.minesweeper-app {
  position: absolute;
  inset: 0;
  overflow: hidden;
  padding: 52px 16px 27px;
  color: #153b42;
  background:
    radial-gradient(circle at 88% 7%, rgb(108 231 218 / 32%), transparent 30%),
    linear-gradient(155deg, #effcf7 0%, #cfeee5 52%, #abdcd7 100%);
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  touch-action: manipulation;
  user-select: none;
}

.minesweeper-header {
  height: 55px;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.minesweeper-header span { display: block; color: #59878a; font-size: 9px; font-weight: 800; letter-spacing: 1.1px; text-transform: uppercase; }
.minesweeper-header h1 { margin: 0; font-size: 24px; line-height: 1; letter-spacing: -0.7px; }

.minesweeper-header button,
.minesweeper-toolbar__icon {
  width: 36px;
  height: 36px;
  display: grid;
  place-items: center;
  padding: 0;
  border: 1px solid rgb(23 83 87 / 9%);
  border-radius: 12px;
  color: #246871;
  background: rgb(255 255 255 / 48%);
  box-shadow: 0 4px 10px rgb(23 73 75 / 8%);
}

.minesweeper-menu {
  height: calc(100% - 55px);
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 12px;
  text-align: center;
}

.minesweeper-hero {
  width: 136px;
  height: 136px;
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 5px;
  padding: 7px;
  border-radius: 25px;
  background: #167e82;
  box-shadow: 0 15px 28px rgb(18 87 90 / 20%);
  transform: rotate(-2deg);
}

.minesweeper-hero > span {
  display: grid;
  place-items: center;
  border-radius: 10px;
  color: #eafff8;
  background: linear-gradient(145deg, #46c2bc, #279c9d);
  box-shadow: inset 0 2px 0 rgb(255 255 255 / 18%), 0 3px 5px rgb(10 68 71 / 18%);
  font-size: 20px;
  font-weight: 900;
}

.minesweeper-hero .minesweeper-hero__one,
.minesweeper-hero .minesweeper-hero__two { background: #fff8e9; }
.minesweeper-hero__one { color: #367bd3 !important; }
.minesweeper-hero__two { color: #198768 !important; }
.minesweeper-hero__mine { color: #203b54 !important; background: #46b7b2 !important; }
.minesweeper-hero__flag { color: #f15f57 !important; }

.minesweeper-intro h2 { margin: 0; font-size: 21px; }
.minesweeper-intro p { max-width: 270px; margin: 5px 0 0; color: #5f8584; font-size: 11px; line-height: 1.4; }

.minesweeper-resume {
  width: 100%;
  min-height: 48px;
  display: grid;
  place-items: center;
  gap: 1px;
  border: 0;
  border-radius: 14px;
  color: #effff9;
  background: linear-gradient(135deg, #249b96, #147a81);
  box-shadow: 0 7px 15px rgb(20 111 113 / 18%);
  font-size: 12px;
  font-weight: 850;
}
.minesweeper-resume small { color: #bfece3; font-size: 8px; }

.minesweeper-difficulties { width: 100%; display: grid; gap: 6px; }
.minesweeper-difficulties button {
  min-height: 50px;
  display: grid;
  grid-template-columns: 49px 1fr;
  grid-template-rows: 1fr 1fr;
  align-items: center;
  column-gap: 10px;
  padding: 6px 10px;
  border: 1px solid rgb(23 91 93 / 8%);
  border-radius: 14px;
  color: #204b50;
  background: rgb(255 255 255 / 45%);
  text-align: left;
}
.minesweeper-difficulty__size { grid-row: 1 / 3; display: grid; place-items: center; height: 37px; border-radius: 10px; color: #f0fff9; background: #238f8e; font-size: 11px; font-weight: 850; }
.minesweeper-difficulties strong { align-self: end; font-size: 12px; }
.minesweeper-difficulties small { align-self: start; color: #658a89; font-size: 8px; }
.minesweeper-long-press { margin: 0; color: #628887; font-size: 9px; }

.minesweeper-game { padding-top: 5px; }
.minesweeper-toolbar { height: 46px; display: grid; grid-template-columns: 36px 1fr 1fr 36px; align-items: center; gap: 7px; }
.minesweeper-toolbar div { display: grid; justify-items: center; line-height: 1.05; }
.minesweeper-toolbar span { color: #5a8484; font-size: 8px; font-weight: 800; text-transform: uppercase; }
.minesweeper-toolbar strong { font-size: 16px; }

.minesweeper-board {
  position: relative;
  display: grid;
  grid-template-columns: repeat(var(--minesweeper-columns), minmax(0, 1fr));
  gap: 3px;
  padding: 7px;
  border: 1px solid rgb(16 78 82 / 10%);
  border-radius: 18px;
  background: #187a7e;
  box-shadow: inset 0 2px 2px rgb(255 255 255 / 10%), 0 15px 27px rgb(20 79 81 / 18%);
}

.minesweeper-cell {
  aspect-ratio: 1;
  min-width: 0;
  display: grid;
  place-items: center;
  padding: 0;
  border: 0;
  border-radius: 7px;
  color: #effff8;
  background: linear-gradient(145deg, #4bc4bd, #279d9e);
  box-shadow: inset 0 2px 0 rgb(255 255 255 / 15%), 0 2px 3px rgb(9 61 64 / 20%);
  font-size: 13px;
  transition: transform 100ms ease, background 130ms ease;
}

.minesweeper-board--expert .minesweeper-cell { border-radius: 6px; font-size: 11px; }
.minesweeper-cell--revealed { color: #477078; background: #eef5e9; box-shadow: inset 0 1px 3px rgb(39 83 80 / 12%); animation: minesweeper-reveal 170ms ease-out; }
.minesweeper-cell--flagged { color: #f35f58; background: linear-gradient(145deg, #5bcec5, #2ca5a4); }
.minesweeper-cell--mine { color: #263c51; background: #dce5dd; }
.minesweeper-cell--exploded { color: #fff; background: #ed6459; animation: minesweeper-explode 350ms ease-out; }
.minesweeper-cell--number-1 { color: #3275ce; }
.minesweeper-cell--number-2 { color: #188569; }
.minesweeper-cell--number-3 { color: #dd574b; }
.minesweeper-cell--number-4 { color: #7354ad; }
.minesweeper-cell--number-5,
.minesweeper-cell--number-6,
.minesweeper-cell--number-7,
.minesweeper-cell--number-8 { color: #9b4e34; }

@keyframes minesweeper-reveal { from { opacity: 0.45; transform: scale(0.84); } to { opacity: 1; transform: scale(1); } }
@keyframes minesweeper-explode { 0% { transform: scale(0.8); } 48% { transform: scale(1.18); } 100% { transform: scale(1); } }

.minesweeper-overlay {
  position: absolute;
  z-index: 5;
  inset: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 22px;
  border-radius: 17px;
  color: #effff9;
  background: rgb(13 66 70 / 86%);
  backdrop-filter: blur(5px);
  text-align: center;
}
.minesweeper-overlay__icon { width: 58px; height: 58px; display: grid; place-items: center; border-radius: 50%; color: #ff756a; background: rgb(255 255 255 / 10%); }
.minesweeper-overlay h2 { margin: 0; font-size: 24px; }
.minesweeper-overlay p { max-width: 220px; margin: -2px 0 4px; color: #bee1dc; font-size: 10px; line-height: 1.35; }
.minesweeper-primary,
.minesweeper-secondary { position: relative; z-index: 1; min-width: 155px; min-height: 40px; border-radius: 13px; font-size: 11px; font-weight: 850; pointer-events: auto; }
.minesweeper-primary { border: 0; color: #104d51; background: #8ce3d2; }
.minesweeper-secondary { border: 1px solid rgb(255 255 255 / 13%); color: #e6faf5; background: rgb(255 255 255 / 7%); }
.minesweeper-game__hint { margin: 9px 0 0; color: #668c8c; font-size: 9px; text-align: center; }

button:active { transform: scale(0.96); }

@media (prefers-reduced-motion: reduce) {
  .minesweeper-cell--revealed,
  .minesweeper-cell--exploded { animation: none; }
}
</style>
