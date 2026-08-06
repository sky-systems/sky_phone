<script setup lang="ts">
import {
  ChevronLeft,
  Layers3,
  Pause,
  Play,
  RotateCcw,
  Volume2,
  VolumeX,
} from 'lucide-vue-next'
import {
  computed,
  onBeforeUnmount,
  ref,
  watch,
  type CSSProperties,
} from 'vue'

import { playTowerStackSound } from '@/features/games/tower-stack/audio'
import { useTowerStackStore } from '@/features/games/tower-stack/store'
import type {
  TowerActiveBlock,
  TowerBlock,
} from '@/features/games/tower-stack/types'
import { usePhoneStore } from '@/stores/phone'

const phone = usePhoneStore()
const tower = useTowerStackStore()
const game = computed(() => tower.game)
const visibleBlocks = computed(() => game.value?.blocks.slice(-9) ?? [])
const placementEffect = ref<'missed' | 'perfect' | 'placed' | null>(null)
const fallingBlock = ref<TowerActiveBlock | null>(null)
const fallingStyle = ref<CSSProperties>({})
const gameOverVisible = ref(true)
let animationFrame: number | undefined
let previousFrameTime = 0
let effectTimer: ReturnType<typeof setTimeout> | undefined

const blockColors = [
  '#ff6b68',
  '#ffbf3f',
  '#39c9d3',
  '#8c63e8',
  '#ff8454',
  '#54d5a5',
]

function blockStyle(block: TowerBlock, index: number): CSSProperties {
  return {
    '--tower-block-color': blockColors[block.colorIndex % blockColors.length],
    bottom: `${24 + index * 35}px`,
    left: `${block.x}%`,
    width: `${block.width}%`,
  } as CSSProperties
}

const activeStyle = computed<CSSProperties>(() => {
  const active = game.value?.active
  if (!active) return {}
  return {
    '--tower-block-color': blockColors[active.colorIndex % blockColors.length],
    bottom: `${24 + visibleBlocks.value.length * 35}px`,
    left: `${active.x}%`,
    width: `${active.width}%`,
  } as CSSProperties
})

function runFrame(time: number): void {
  if (game.value?.status !== 'playing') return

  if (previousFrameTime > 0) {
    tower.tick(Math.min(0.04, (time - previousFrameTime) / 1000))
  }
  previousFrameTime = time
  animationFrame = requestAnimationFrame(runFrame)
}

function startLoop(): void {
  if (animationFrame !== undefined) cancelAnimationFrame(animationFrame)
  previousFrameTime = 0
  animationFrame = requestAnimationFrame(runFrame)
}

function stopLoop(): void {
  if (animationFrame !== undefined) cancelAnimationFrame(animationFrame)
  animationFrame = undefined
  previousFrameTime = 0
}

function startGame(): void {
  clearEffects()
  tower.start()
  playTowerStackSound('start', tower.soundEnabled)
}

function placeBlock(): void {
  if (game.value?.status !== 'playing' || !game.value.active) return

  const activeBeforePlacement = { ...game.value.active }
  const visibleLevel = visibleBlocks.value.length
  const result = tower.place()
  if (!result) return

  placementEffect.value = result.outcome
  gameOverVisible.value = result.outcome !== 'missed'
  if (result.outcome === 'perfect') {
    playTowerStackSound('perfect', tower.soundEnabled)
  } else if (result.outcome === 'placed') {
    playTowerStackSound('hit', tower.soundEnabled)
  } else {
    playTowerStackSound('fall', tower.soundEnabled)
  }

  if (result.cutWidth > 0) {
    fallingBlock.value = {
      ...activeBeforePlacement,
      width: result.cutWidth,
      x:
        result.cutSide === 'left'
          ? activeBeforePlacement.x
          : activeBeforePlacement.x + activeBeforePlacement.width - result.cutWidth,
    }
    fallingStyle.value = {
      '--tower-block-color':
        blockColors[activeBeforePlacement.colorIndex % blockColors.length],
      bottom: `${24 + visibleLevel * 35}px`,
      left: `${fallingBlock.value.x}%`,
      width: `${fallingBlock.value.width}%`,
    } as CSSProperties
  }

  if (effectTimer) clearTimeout(effectTimer)
  effectTimer = setTimeout(() => {
    placementEffect.value = null
    fallingBlock.value = null
    gameOverVisible.value = true
    effectTimer = undefined
  }, result.outcome === 'missed' ? 950 : 650)
}

function clearEffects(): void {
  if (effectTimer) clearTimeout(effectTimer)
  effectTimer = undefined
  placementEffect.value = null
  fallingBlock.value = null
  gameOverVisible.value = true
}

function toggleSound(): void {
  const enabled = !tower.soundEnabled
  tower.setSoundEnabled(enabled)
  if (enabled) playTowerStackSound('hit', true)
}

function togglePause(): void {
  if (game.value?.status === 'playing') tower.pause()
  else if (game.value?.status === 'paused') tower.resume()
}

tower.hydrate()
watch(
  () => game.value?.status,
  (status) => {
    if (status === 'playing') startLoop()
    else stopLoop()
  },
  { immediate: true },
)

onBeforeUnmount(() => {
  stopLoop()
  clearEffects()
  tower.pause()
})
</script>

<template>
  <main class="tower-app" :aria-label="phone.t('Apps.towerStack.name')">
    <header class="tower-header">
      <div>
        <span>{{ phone.t('Apps.towerStack.eyebrow') }}</span>
        <h1>{{ phone.t('Apps.towerStack.name') }}</h1>
      </div>
      <button
        type="button"
        :aria-label="phone.t(tower.soundEnabled ? 'Apps.towerStack.mute' : 'Apps.towerStack.unmute')"
        @click="toggleSound"
      >
        <Volume2 v-if="tower.soundEnabled" :size="18" aria-hidden="true" />
        <VolumeX v-else :size="18" aria-hidden="true" />
      </button>
    </header>

    <section v-if="tower.menuOpen" class="tower-menu">
      <div class="tower-menu__preview" aria-hidden="true">
        <i v-for="index in 7" :key="index" :style="{ '--preview-index': index }"></i>
        <span></span>
      </div>
      <div class="tower-menu__copy">
        <span>{{ phone.t('Apps.towerStack.ready') }}</span>
        <h2>{{ phone.t('Apps.towerStack.menuTitle') }}</h2>
        <p>{{ phone.t('Apps.towerStack.menuBody') }}</p>
      </div>
      <div class="tower-records">
        <div><span>{{ phone.t('Apps.towerStack.bestHeight') }}</span><strong>{{ tower.highHeight }}</strong></div>
        <div><span>{{ phone.t('Apps.towerStack.bestScore') }}</span><strong>{{ tower.highScore }}</strong></div>
      </div>
      <button
        v-if="game?.status === 'paused'"
        type="button"
        class="tower-primary"
        @click="tower.resume()"
      >
        <Play :size="17" fill="currentColor" />
        {{ phone.t('Apps.towerStack.resume') }}
      </button>
      <button type="button" class="tower-secondary" @click="startGame">
        {{ phone.t(game ? 'Apps.towerStack.newGame' : 'Apps.towerStack.start') }}
      </button>
      <p class="tower-menu__hint">{{ phone.t('Apps.towerStack.tapHint') }}</p>
    </section>

    <section v-else-if="game" class="tower-game">
      <div class="tower-toolbar">
        <button
          type="button"
          :aria-label="phone.t('Apps.towerStack.backToMenu')"
          @pointerdown.stop="tower.showMenu()"
          @click.stop="tower.showMenu()"
        ><ChevronLeft :size="19" /></button>
        <div><span>{{ phone.t('Apps.towerStack.height') }}</span><strong>{{ game.blocks.length - 1 }}</strong></div>
        <div><span>{{ phone.t('Apps.towerStack.score') }}</span><strong>{{ game.score }}</strong></div>
        <button type="button" :aria-label="phone.t('Apps.towerStack.pause')" @click="togglePause">
          <Pause v-if="game.status === 'playing'" :size="17" fill="currentColor" />
          <Play v-else :size="17" fill="currentColor" />
        </button>
      </div>

      <button
        type="button"
        class="tower-stage"
        :class="{
          'tower-stage--perfect': placementEffect === 'perfect',
          'tower-stage--missed': placementEffect === 'missed',
        }"
        :aria-label="phone.t('Apps.towerStack.placeBlock')"
        @pointerdown.stop.prevent="placeBlock"
      >
        <div class="tower-sky" aria-hidden="true"><i v-for="star in 13" :key="star"></i></div>
        <span v-if="placementEffect === 'perfect'" class="tower-perfect">
          {{ phone.t('Apps.towerStack.perfect') }}
        </span>
        <div class="tower-stack" aria-hidden="true">
          <span
            v-for="(block, index) in visibleBlocks"
            :key="block.id"
            class="tower-block tower-block--placed"
            :style="blockStyle(block, index)"
          ></span>
          <span
            v-if="game.active"
            class="tower-block tower-block--active"
            :style="activeStyle"
          ></span>
          <span
            v-if="fallingBlock"
            class="tower-block tower-block--falling"
            :style="fallingStyle"
          ></span>
        </div>
        <div class="tower-ground" aria-hidden="true"></div>
      </button>

      <p class="tower-game__hint">{{ phone.t('Apps.towerStack.gameHint') }}</p>

      <div v-if="game.status === 'paused'" class="tower-overlay">
        <Pause :size="30" />
        <h2>{{ phone.t('Apps.towerStack.paused') }}</h2>
        <button type="button" class="tower-primary" @click="tower.resume()">
          {{ phone.t('Apps.towerStack.resume') }}
        </button>
        <button type="button" class="tower-secondary" @click="tower.showMenu()">
          {{ phone.t('Apps.towerStack.mainMenu') }}
        </button>
      </div>

      <div
        v-if="game.status === 'over' && gameOverVisible"
        class="tower-overlay tower-overlay--over"
      >
        <Layers3 :size="34" />
        <span>{{ phone.t('Apps.towerStack.gameOver') }}</span>
        <h2>{{ game.blocks.length - 1 }} {{ phone.t('Apps.towerStack.blocks') }}</h2>
        <p>{{ phone.t('Apps.towerStack.finalScore') }}: {{ game.score }}</p>
        <button type="button" class="tower-primary" @click="startGame">
          <RotateCcw :size="16" /> {{ phone.t('Apps.towerStack.playAgain') }}
        </button>
        <button type="button" class="tower-secondary" @click="tower.showMenu()">
          {{ phone.t('Apps.towerStack.mainMenu') }}
        </button>
      </div>
    </section>
  </main>
</template>

<style scoped>
.tower-app { position: absolute; inset: 0; overflow: hidden; padding: 52px 16px 27px; color: #eef5ff; background: radial-gradient(circle at 75% 8%, #7146c866, transparent 35%), linear-gradient(170deg, #161634, #242054 52%, #10132c); font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; user-select: none; touch-action: manipulation; }
.tower-header { height: 55px; display: flex; align-items: center; justify-content: space-between; }
.tower-header span { display: block; color: #a69dd3; font-size: 9px; font-weight: 850; letter-spacing: 1.1px; text-transform: uppercase; }
.tower-header h1 { margin: 0; font-size: 24px; line-height: 1; letter-spacing: -0.8px; }
.tower-header button, .tower-toolbar button { width: 36px; height: 36px; display: grid; place-items: center; padding: 0; border: 1px solid #ffffff14; border-radius: 12px; color: #f2edff; background: #ffffff0d; }
.tower-menu { height: calc(100% - 55px); display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 13px; text-align: center; }
.tower-menu__preview { position: relative; width: 190px; height: 235px; }
.tower-menu__preview i { position: absolute; right: 12px; bottom: calc(var(--preview-index) * 25px); left: 25px; height: 29px; border-radius: 7px; background: hsl(calc(var(--preview-index) * 49deg + 5deg) 82% 62%); box-shadow: inset 0 4px 0 #ffffff35, 0 8px 15px #08091c5c; transform: perspective(200px) rotateX(5deg); }
.tower-menu__preview i:nth-child(even) { right: 25px; left: 12px; }
.tower-menu__preview span { position: absolute; top: 4px; left: 2px; width: 120px; height: 29px; border-radius: 7px; background: #ff6b68; box-shadow: 0 0 24px #ff6b6877; animation: tower-preview-slide 1.5s ease-in-out infinite alternate; }
.tower-menu__copy > span { color: #ffbd45; font-size: 9px; font-weight: 900; letter-spacing: 1px; text-transform: uppercase; }
.tower-menu__copy h2 { margin: 3px 0 5px; font-size: 21px; }
.tower-menu__copy p { max-width: 275px; margin: 0; color: #aca7cc; font-size: 10px; line-height: 1.4; }
.tower-records { width: 100%; display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
.tower-records div { display: grid; gap: 2px; padding: 9px; border: 1px solid #ffffff0e; border-radius: 13px; background: #ffffff0a; }
.tower-records span { color: #9790bd; font-size: 8px; font-weight: 800; text-transform: uppercase; }
.tower-records strong { font-size: 18px; }
.tower-primary, .tower-secondary { width: 100%; min-height: 43px; display: flex; align-items: center; justify-content: center; gap: 7px; border-radius: 14px; font-size: 11px; font-weight: 850; }
.tower-primary { border: 0; color: #1e1839; background: linear-gradient(135deg, #ffca4f, #ff8760); box-shadow: 0 8px 18px #ff895330; }
.tower-secondary { border: 1px solid #ffffff16; color: #eeeaff; background: #ffffff0a; }
.tower-menu__hint, .tower-game__hint { margin: 0; color: #8d87b3; font-size: 9px; }
.tower-game { position: relative; height: calc(100% - 55px); }
.tower-toolbar { height: 47px; display: grid; grid-template-columns: 36px 1fr 1fr 36px; align-items: center; gap: 7px; }
.tower-toolbar div { display: grid; justify-items: center; line-height: 1.05; }
.tower-toolbar span { color: #918ab9; font-size: 8px; font-weight: 850; text-transform: uppercase; }
.tower-toolbar strong { font-size: 16px; }
.tower-stage { position: relative; width: 100%; height: 500px; display: block; overflow: hidden; padding: 0; border: 1px solid #ffffff12; border-radius: 22px; background: linear-gradient(#17173b, #322361 60%, #70426c); box-shadow: inset 0 0 35px #08091d99, 0 16px 28px #08091c66; touch-action: manipulation; }
.tower-sky { position: absolute; inset: 0; pointer-events: none; }
.tower-sky i { position: absolute; width: 3px; height: 3px; border-radius: 50%; background: #fff; box-shadow: 0 0 7px #c5c2ff; opacity: .65; }
.tower-sky i:nth-child(1) { top: 8%; left: 12%; } .tower-sky i:nth-child(2) { top: 17%; left: 72%; } .tower-sky i:nth-child(3) { top: 28%; left: 42%; } .tower-sky i:nth-child(4) { top: 37%; left: 88%; } .tower-sky i:nth-child(5) { top: 46%; left: 18%; } .tower-sky i:nth-child(6) { top: 58%; left: 64%; } .tower-sky i:nth-child(7) { top: 70%; left: 31%; } .tower-sky i:nth-child(8) { top: 11%; left: 91%; } .tower-sky i:nth-child(9) { top: 22%; left: 25%; } .tower-sky i:nth-child(10) { top: 50%; left: 78%; } .tower-sky i:nth-child(11) { top: 64%; left: 8%; } .tower-sky i:nth-child(12) { top: 77%; left: 92%; } .tower-sky i:nth-child(13) { top: 33%; left: 58%; }
.tower-stack { position: absolute; inset: 0 14px; }
.tower-block { position: absolute; height: 31px; border-radius: 7px; background: linear-gradient(180deg, color-mix(in srgb, var(--tower-block-color), white 18%), var(--tower-block-color)); box-shadow: inset 0 4px 0 #ffffff35, inset 0 -4px 0 #00000016, 0 7px 10px #08091d55; }
.tower-block--active { z-index: 3; box-shadow: inset 0 4px 0 #ffffff45, 0 0 18px color-mix(in srgb, var(--tower-block-color), transparent 45%); }
.tower-block--placed { animation: tower-land 180ms ease-out; }
.tower-block--falling { z-index: 4; animation: tower-fall 850ms ease-in forwards; }
.tower-ground { position: absolute; right: 0; bottom: 0; left: 0; height: 35px; background: linear-gradient(#31224f, #16152e); box-shadow: 0 -8px 20px #a9547928; }
.tower-perfect { position: absolute; z-index: 8; top: 24%; left: 50%; padding: 8px 17px; border-radius: 18px; color: #332149; background: #ffdc65; box-shadow: 0 0 24px #ffcf64aa; font-size: 13px; font-weight: 950; letter-spacing: .8px; transform: translateX(-50%); animation: tower-perfect-pop 650ms ease-out forwards; }
.tower-stage--perfect { animation: tower-perfect-glow 500ms ease-out; }
.tower-stage--missed { animation: tower-stage-shake 500ms ease-out; }
.tower-game__hint { margin-top: 8px; text-align: center; }
.tower-overlay { position: absolute; z-index: 15; inset: 47px 0 25px; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 9px; padding: 28px; border-radius: 22px; color: #f7f2ff; background: #11122bd9; backdrop-filter: blur(7px); text-align: center; }
.tower-overlay > svg { color: #ffbd4d; }
.tower-overlay > span { color: #ff9b65; font-size: 9px; font-weight: 900; letter-spacing: 1.2px; text-transform: uppercase; }
.tower-overlay h2 { margin: 0; font-size: 25px; }
.tower-overlay p { margin: -3px 0 5px; color: #a9a3c9; font-size: 10px; }
@keyframes tower-preview-slide { from { transform: translateX(0) rotate(-2deg); } to { transform: translateX(66px) rotate(2deg); } }
@keyframes tower-land { from { filter: brightness(1.8); transform: translateY(-8px) scaleY(.85); } to { filter: brightness(1); transform: translateY(0) scaleY(1); } }
@keyframes tower-fall { 0% { opacity: 1; transform: translate(0) rotate(0); } 100% { opacity: 0; transform: translate(45px, 390px) rotate(145deg); } }
@keyframes tower-perfect-pop { 0% { opacity: 0; transform: translateX(-50%) scale(.4); } 35% { opacity: 1; transform: translateX(-50%) scale(1.2); } 100% { opacity: 0; transform: translateX(-50%) scale(1); } }
@keyframes tower-perfect-glow { 0%, 100% { box-shadow: inset 0 0 35px #08091d99, 0 16px 28px #08091c66; } 45% { box-shadow: inset 0 0 45px #ffd75c55, 0 0 30px #ffd75c66; } }
@keyframes tower-stage-shake { 0%, 100% { transform: translate(0); } 20% { transform: translate(-5px, 2px); } 40% { transform: translate(5px, -2px); } 60% { transform: translate(-3px, 1px); } 80% { transform: translate(2px); } }
button:active { transform: scale(.97); }
@media (prefers-reduced-motion: reduce) { .tower-menu__preview span, .tower-block, .tower-perfect, .tower-stage { animation: none; } }
</style>
