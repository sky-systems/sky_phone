<script setup lang="ts">
import {
  ArrowDown,
  ArrowLeft,
  ArrowRight,
  ArrowUp,
  ChevronLeft,
  RotateCcw,
  Volume2,
  VolumeX,
} from 'lucide-vue-next'
import { computed, onBeforeUnmount, onMounted, ref, type CSSProperties } from 'vue'

import { playNumberMergeSound } from '@/features/games/number-merge/audio'
import { useNumberMergeStore } from '@/features/games/number-merge/store'
import type {
  NumberMergeDirection,
  NumberMergeTile,
} from '@/features/games/number-merge/types'
import { usePhoneStore } from '@/stores/phone'

const phone = usePhoneStore()
const numberMerge = useNumberMergeStore()
const touchStart = ref<{ x: number; y: number } | null>(null)
const confirmNewGame = ref(false)
const game = computed(() => numberMerge.game)
const canResume = computed(
  () => numberMerge.game !== null && numberMerge.game.status !== 'game-over',
)
const currentHighest = computed(() =>
  Math.max(0, ...(numberMerge.game?.tiles.map((tile) => tile.value) ?? [])),
)
const directionButtons: Array<{
  direction: NumberMergeDirection
  icon: typeof ArrowUp
}> = [
  { direction: 'left', icon: ArrowLeft },
  { direction: 'up', icon: ArrowUp },
  { direction: 'down', icon: ArrowDown },
  { direction: 'right', icon: ArrowRight },
]

function formatScore(value: number): string {
  return new Intl.NumberFormat('en-US').format(value)
}

function tileStyle(tile: NumberMergeTile): CSSProperties {
  return {
    '--tile-column': tile.column,
    '--tile-row': tile.row,
  } as CSSProperties
}

function tileClass(tile: NumberMergeTile): string {
  return tile.value <= 2048
    ? `number-merge-tile--${tile.value}`
    : 'number-merge-tile--super'
}

function move(direction: NumberMergeDirection): void {
  if (numberMerge.menuOpen || numberMerge.game?.status !== 'playing') return

  const result = numberMerge.move(direction)
  if (!result?.changed) return

  if (result.state.status === 'won') {
    playNumberMergeSound('win', numberMerge.soundEnabled)
  } else if (result.state.status === 'game-over') {
    playNumberMergeSound('game-over', numberMerge.soundEnabled)
  } else if (result.gained > 0) {
    playNumberMergeSound('merge', numberMerge.soundEnabled)
  } else {
    playNumberMergeSound('move', numberMerge.soundEnabled)
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
  if (Math.max(Math.abs(deltaX), Math.abs(deltaY)) < 20) return

  if (Math.abs(deltaX) > Math.abs(deltaY)) {
    move(deltaX > 0 ? 'right' : 'left')
  } else {
    move(deltaY > 0 ? 'down' : 'up')
  }
}

function handleKeydown(event: KeyboardEvent): void {
  const directions: Partial<Record<string, NumberMergeDirection>> = {
    ArrowDown: 'down',
    ArrowLeft: 'left',
    ArrowRight: 'right',
    ArrowUp: 'up',
    a: 'left',
    d: 'right',
    s: 'down',
    w: 'up',
  }
  const direction = directions[event.key]
  if (!direction) return

  event.preventDefault()
  move(direction)
}

function requestNewGame(): void {
  if (numberMerge.game && numberMerge.game.status !== 'game-over') {
    confirmNewGame.value = true
    return
  }
  numberMerge.start()
}

function startNewGame(): void {
  confirmNewGame.value = false
  numberMerge.start()
}

function toggleSound(): void {
  const enabled = !numberMerge.soundEnabled
  numberMerge.setSoundEnabled(enabled)
  if (enabled) playNumberMergeSound('move', true)
}

numberMerge.hydrate()
onMounted(() => window.addEventListener('keydown', handleKeydown))
onBeforeUnmount(() => window.removeEventListener('keydown', handleKeydown))
</script>

<template>
  <main class="number-merge-app" :aria-label="phone.t('Apps.numberMerge.name')">
    <header class="number-merge-header">
      <div>
        <span>{{ phone.t('Apps.numberMerge.eyebrow') }}</span>
        <h1>{{ phone.t('Apps.numberMerge.name') }}</h1>
      </div>
      <button
        type="button"
        :aria-label="
          phone.t(
            numberMerge.soundEnabled
              ? 'Apps.numberMerge.mute'
              : 'Apps.numberMerge.unmute',
          )
        "
        :title="
          phone.t(
            numberMerge.soundEnabled
              ? 'Apps.numberMerge.mute'
              : 'Apps.numberMerge.unmute',
          )
        "
        @click="toggleSound"
      >
        <Volume2 v-if="numberMerge.soundEnabled" :size="18" aria-hidden="true" />
        <VolumeX v-else :size="18" aria-hidden="true" />
      </button>
    </header>

    <section v-if="numberMerge.menuOpen" class="number-merge-menu">
      <div class="number-merge-hero" aria-hidden="true">
        <span class="number-merge-hero__tile number-merge-hero__tile--2">2</span>
        <span class="number-merge-hero__tile number-merge-hero__tile--0">0</span>
        <span class="number-merge-hero__tile number-merge-hero__tile--4">4</span>
        <span class="number-merge-hero__tile number-merge-hero__tile--8">8</span>
      </div>

      <div class="number-merge-menu__intro">
        <h2>{{ phone.t('Apps.numberMerge.menuTitle') }}</h2>
        <p>{{ phone.t('Apps.numberMerge.menuBody') }}</p>
      </div>

      <div class="number-merge-records">
        <div>
          <span>{{ phone.t('Apps.numberMerge.best') }}</span>
          <strong>{{ formatScore(numberMerge.bestScore) }}</strong>
        </div>
        <div>
          <span>{{ phone.t('Apps.numberMerge.highest') }}</span>
          <strong>{{ numberMerge.highestTile || '–' }}</strong>
        </div>
      </div>

      <div class="number-merge-menu__actions">
        <button
          v-if="canResume"
          type="button"
          class="number-merge-primary"
          @click="numberMerge.resume"
        >
          {{ phone.t('Apps.numberMerge.continueGame') }}
        </button>
        <button
          type="button"
          :class="canResume ? 'number-merge-secondary' : 'number-merge-primary'"
          @click="requestNewGame"
        >
          {{ phone.t('Apps.numberMerge.newGame') }}
        </button>
      </div>

      <div class="number-merge-how-to">
        <strong>{{ phone.t('Apps.numberMerge.howToTitle') }}</strong>
        <p>{{ phone.t('Apps.numberMerge.howToBody') }}</p>
        <div>{{ phone.t('Apps.numberMerge.howToExample') }}</div>
        <small>{{ phone.t('Apps.numberMerge.howToGoal') }}</small>
      </div>
    </section>

    <section v-else-if="game" class="number-merge-game">
      <div class="number-merge-toolbar">
        <button
          type="button"
          class="number-merge-toolbar__icon"
          :aria-label="phone.t('Apps.numberMerge.backToMenu')"
          :title="phone.t('Apps.numberMerge.backToMenu')"
          @click="numberMerge.showMenu"
        >
          <ChevronLeft :size="19" :stroke-width="2.7" aria-hidden="true" />
        </button>
        <div>
          <span>{{ phone.t('Apps.numberMerge.score') }}</span>
          <strong>{{ formatScore(game.score) }}</strong>
        </div>
        <div>
          <span>{{ phone.t('Apps.numberMerge.best') }}</span>
          <strong>{{ formatScore(numberMerge.bestScore) }}</strong>
        </div>
        <button
          type="button"
          class="number-merge-toolbar__icon number-merge-toolbar__restart"
          :aria-label="phone.t('Apps.numberMerge.newGame')"
          :title="phone.t('Apps.numberMerge.newGame')"
          @click="requestNewGame"
        >
          <RotateCcw :size="17" :stroke-width="2.5" aria-hidden="true" />
        </button>
      </div>

      <div
        class="number-merge-board"
        :aria-label="phone.t('Apps.numberMerge.board')"
        @touchstart.passive="beginSwipe"
        @touchend.passive="endSwipe"
      >
        <span v-for="cell in 16" :key="`cell-${cell}`" class="number-merge-cell"></span>
        <span
          v-for="tile in game.tiles"
          :key="tile.id"
          class="number-merge-tile"
          :class="[
            tileClass(tile),
            {
              'number-merge-tile--new': tile.isNew,
              'number-merge-tile--merged': tile.merged,
            },
          ]"
          :style="tileStyle(tile)"
        >
          <strong>{{ tile.value }}</strong>
        </span>

        <div v-if="game.status !== 'playing'" class="number-merge-overlay">
          <span>{{ currentHighest }}</span>
          <h2>
            {{
              phone.t(
                game.status === 'won'
                  ? 'Apps.numberMerge.wonTitle'
                  : 'Apps.numberMerge.gameOverTitle',
              )
            }}
          </h2>
          <p>
            {{
              phone.t(
                game.status === 'won'
                  ? 'Apps.numberMerge.wonBody'
                  : 'Apps.numberMerge.gameOverBody',
              )
            }}
          </p>
          <button
            v-if="game.status === 'won'"
            type="button"
            class="number-merge-primary"
            @click="numberMerge.continueAfterWin"
          >
            {{ phone.t('Apps.numberMerge.keepPlaying') }}
          </button>
          <button
            type="button"
            :class="
              game.status === 'won'
                ? 'number-merge-secondary'
                : 'number-merge-primary'
            "
            @click="requestNewGame"
          >
            {{ phone.t('Apps.numberMerge.newGame') }}
          </button>
          <button type="button" class="number-merge-link" @click="numberMerge.showMenu">
            {{ phone.t('Apps.numberMerge.mainMenu') }}
          </button>
        </div>
      </div>

      <p class="number-merge-hint">{{ phone.t('Apps.numberMerge.swipeHint') }}</p>
      <div class="number-merge-controls" :aria-label="phone.t('Apps.numberMerge.controls')">
        <button
          v-for="control in directionButtons"
          :key="control.direction"
          type="button"
          :aria-label="phone.t(`Apps.numberMerge.directions.${control.direction}`)"
          @click="move(control.direction)"
        >
          <component :is="control.icon" :size="19" :stroke-width="2.5" aria-hidden="true" />
        </button>
      </div>
    </section>

    <div v-if="confirmNewGame" class="number-merge-confirm" role="dialog" aria-modal="true">
      <div>
        <h2>{{ phone.t('Apps.numberMerge.confirmTitle') }}</h2>
        <p>{{ phone.t('Apps.numberMerge.confirmBody') }}</p>
        <button type="button" class="number-merge-danger" @click="startNewGame">
          {{ phone.t('Apps.numberMerge.confirmNew') }}
        </button>
        <button type="button" class="number-merge-secondary" @click="confirmNewGame = false">
          {{ phone.t('Apps.numberMerge.cancel') }}
        </button>
      </div>
    </div>
  </main>
</template>

<style scoped>
.number-merge-app {
  position: absolute;
  inset: 0;
  overflow: hidden;
  padding: 52px 17px 27px;
  color: #4a302b;
  background:
    radial-gradient(circle at 86% 8%, rgb(255 192 94 / 28%), transparent 29%),
    linear-gradient(155deg, #fff3dc 0%, #f3d8b7 55%, #e8b98d 100%);
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  touch-action: none;
  user-select: none;
}

.number-merge-header {
  height: 55px;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.number-merge-header span {
  display: block;
  color: #9c7465;
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 1.2px;
  text-transform: uppercase;
}

.number-merge-header h1 {
  margin: 0;
  font-size: 28px;
  line-height: 1;
  letter-spacing: -1px;
}

.number-merge-header button,
.number-merge-toolbar__icon {
  width: 36px;
  height: 36px;
  display: grid;
  place-items: center;
  padding: 0;
  border: 1px solid rgb(109 66 52 / 9%);
  border-radius: 12px;
  color: #784c3c;
  background: rgb(255 255 255 / 46%);
  box-shadow: 0 4px 10px rgb(95 48 31 / 8%);
  cursor: pointer;
}

.number-merge-menu {
  height: calc(100% - 55px);
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 13px;
  text-align: center;
}

.number-merge-hero {
  width: 154px;
  height: 154px;
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 7px;
  padding: 9px;
  border-radius: 29px;
  background: #7e5147;
  box-shadow: 0 17px 30px rgb(93 48 36 / 20%);
  transform: rotate(-2deg);
}

.number-merge-hero__tile {
  display: grid;
  place-items: center;
  border-radius: 18px;
  font-size: 35px;
  font-weight: 900;
  box-shadow: inset 0 2px 0 rgb(255 255 255 / 25%), 0 5px 8px rgb(54 24 18 / 17%);
}

.number-merge-hero__tile--2 { color: #765044; background: #f7e1bc; }
.number-merge-hero__tile--0 { color: #fff7e4; background: #eea62e; }
.number-merge-hero__tile--4 { color: #fff7e4; background: #e96c2c; }
.number-merge-hero__tile--8 { color: #fff7e4; background: #713c31; }

.number-merge-menu__intro h2 { margin: 0; font-size: 25px; letter-spacing: -0.5px; }
.number-merge-menu__intro p { max-width: 300px; margin: 6px 0 0; color: #8b675b; font-size: 14px; line-height: 1.45; }

.number-merge-records {
  width: 100%;
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 7px;
}

.number-merge-records div {
  display: grid;
  gap: 1px;
  padding: 8px;
  border: 1px solid rgb(112 66 49 / 8%);
  border-radius: 13px;
  background: rgb(255 255 255 / 38%);
}

.number-merge-records span,
.number-merge-toolbar span {
  color: #9d7567;
  font-size: 11px;
  font-weight: 800;
  text-transform: uppercase;
}

.number-merge-records strong { font-size: 20px; }

.number-merge-menu__actions { width: 100%; display: grid; gap: 7px; }

.number-merge-primary,
.number-merge-secondary,
.number-merge-danger {
  min-height: 46px;
  padding: 0 18px;
  border-radius: 14px;
  font-size: 15px;
  font-weight: 850;
  cursor: pointer;
}

.number-merge-primary {
  border: 0;
  color: #fffaf0;
  background: linear-gradient(135deg, #d76b32, #a8462d);
  box-shadow: 0 8px 17px rgb(142 61 37 / 20%);
}

.number-merge-secondary {
  border: 1px solid rgb(104 61 47 / 13%);
  color: #70493e;
  background: rgb(255 255 255 / 42%);
}

.number-merge-how-to {
  padding: 9px 15px;
  border-radius: 14px;
  color: #795549;
  background: rgb(255 255 255 / 28%);
}

.number-merge-how-to strong { font-size: 13px; text-transform: uppercase; }
.number-merge-how-to p { margin: 5px 0 0; font-size: 12px; line-height: 1.4; }
.number-merge-how-to div {
  margin: 7px 0 4px;
  color: #a7472d;
  font-size: 14px;
  font-weight: 900;
  letter-spacing: -0.2px;
}
.number-merge-how-to small { display: block; color: #8b6559; font-size: 11px; line-height: 1.35; }

.number-merge-game { padding-top: 5px; }

.number-merge-toolbar {
  height: 48px;
  display: grid;
  grid-template-columns: 36px 1fr 1fr 36px;
  align-items: center;
  gap: 7px;
}

.number-merge-toolbar div {
  min-width: 0;
  display: grid;
  justify-items: center;
  line-height: 1.05;
}

.number-merge-toolbar strong { max-width: 80px; overflow: hidden; font-size: 18px; text-overflow: ellipsis; }
.number-merge-toolbar__restart { justify-self: end; }

.number-merge-board {
  --board-gap: 7px;
  --board-padding: 9px;
  position: relative;
  width: 100%;
  aspect-ratio: 1;
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: var(--board-gap);
  padding: var(--board-padding);
  border: 1px solid rgb(78 41 32 / 9%);
  border-radius: 21px;
  background: #80564c;
  box-shadow: inset 0 2px 2px rgb(255 255 255 / 10%), 0 17px 28px rgb(101 52 38 / 18%);
}

.number-merge-cell {
  aspect-ratio: 1;
  border-radius: 13px;
  background: rgb(255 235 207 / 16%);
  box-shadow: inset 0 1px 3px rgb(53 24 19 / 12%);
}

.number-merge-tile {
  position: absolute;
  z-index: 2;
  left: var(--board-padding);
  top: var(--board-padding);
  width: calc((100% - var(--board-padding) * 2 - var(--board-gap) * 3) / 4);
  aspect-ratio: 1;
  transform: translate(
    calc(var(--tile-column) * (100% + var(--board-gap))),
    calc(var(--tile-row) * (100% + var(--board-gap)))
  );
  transition: transform 145ms cubic-bezier(0.22, 0.68, 0.3, 1);
  will-change: transform;
}

.number-merge-tile strong {
  width: 100%;
  height: 100%;
  display: grid;
  place-items: center;
  border-radius: 13px;
  color: #725044;
  background: #f5dfbc;
  box-shadow: inset 0 2px 0 rgb(255 255 255 / 30%), 0 4px 7px rgb(47 20 15 / 18%);
  font-size: 25px;
  font-weight: 900;
  letter-spacing: -1px;
}

.number-merge-tile--4 strong { background: #f4ce91; }
.number-merge-tile--8 strong { color: #fff9eb; background: #ee9c4a; }
.number-merge-tile--16 strong { color: #fff9eb; background: #ec7e38; }
.number-merge-tile--32 strong { color: #fff9eb; background: #e96335; }
.number-merge-tile--64 strong { color: #fff9eb; background: #d94b2e; }
.number-merge-tile--128 strong { color: #fff9e6; background: #d5a333; font-size: 21px; }
.number-merge-tile--256 strong { color: #fff9e6; background: #c98d29; font-size: 21px; }
.number-merge-tile--512 strong { color: #fff9e6; background: #b97624; font-size: 21px; }
.number-merge-tile--1024 strong { color: #fff; background: #8f4935; font-size: 17px; }
.number-merge-tile--2048 strong { color: #fff; background: #642f3a; font-size: 17px; box-shadow: 0 0 17px rgb(255 191 69 / 55%); }
.number-merge-tile--super strong { color: #fff; background: #3e2634; font-size: 14px; }

.number-merge-tile--new strong { animation: number-merge-spawn 210ms cubic-bezier(0.2, 0.9, 0.3, 1.35); }
.number-merge-tile--merged strong { animation: number-merge-pop 250ms cubic-bezier(0.2, 0.9, 0.3, 1.35); }

@keyframes number-merge-spawn {
  0% { opacity: 0; transform: scale(0.35); }
  100% { opacity: 1; transform: scale(1); }
}

@keyframes number-merge-pop {
  0% { transform: scale(1); }
  48% { transform: scale(1.16); }
  100% { transform: scale(1); }
}

.number-merge-overlay {
  position: absolute;
  z-index: 8;
  inset: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 22px;
  border-radius: 20px;
  background: rgb(74 42 35 / 86%);
  backdrop-filter: blur(5px);
  color: #fff7ea;
  text-align: center;
}

.number-merge-overlay > span { color: #ffc75b; font-size: 29px; font-weight: 900; }
.number-merge-overlay h2 { margin: 0; font-size: 25px; }
.number-merge-overlay p { margin: -3px 0 4px; color: #e7cabd; font-size: 14px; line-height: 1.4; }
.number-merge-overlay button { min-width: 160px; }
.number-merge-overlay .number-merge-secondary { color: #fff1df; background: rgb(255 255 255 / 8%); border-color: rgb(255 255 255 / 13%); }

.number-merge-link {
  min-height: 28px;
  border: 0;
  color: #e9cec2;
  background: transparent;
  font-size: 13px;
  font-weight: 800;
}

.number-merge-hint { margin: 10px 0 7px; color: #976f61; font-size: 12px; text-align: center; }

.number-merge-controls {
  display: grid;
  grid-template-columns: repeat(4, 38px);
  justify-content: center;
  gap: 7px;
}

.number-merge-controls button {
  width: 38px;
  height: 38px;
  display: grid;
  place-items: center;
  padding: 0;
  border: 1px solid rgb(97 56 44 / 10%);
  border-radius: 12px;
  color: #71483b;
  background: rgb(255 255 255 / 38%);
}

.number-merge-confirm {
  position: absolute;
  z-index: 20;
  inset: 0;
  display: grid;
  place-items: center;
  padding: 30px;
  background: rgb(54 29 25 / 54%);
  backdrop-filter: blur(6px);
}

.number-merge-confirm > div {
  width: 100%;
  display: grid;
  gap: 9px;
  padding: 21px;
  border-radius: 21px;
  color: #4a302b;
  background: #fff1dd;
  box-shadow: 0 20px 45px rgb(52 23 18 / 28%);
  text-align: center;
}

.number-merge-confirm h2 { margin: 0; font-size: 21px; }
.number-merge-confirm p { margin: 0 0 5px; color: #876359; font-size: 14px; line-height: 1.4; }
.number-merge-danger { border: 0; color: #fff; background: #b64f39; }

button:active { transform: scale(0.97); }

@media (prefers-reduced-motion: reduce) {
  .number-merge-tile { transition-duration: 1ms; }
  .number-merge-tile--new strong,
  .number-merge-tile--merged strong { animation: none; }
}
</style>
