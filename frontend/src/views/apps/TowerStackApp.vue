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
import { kButton } from 'konsta/vue'
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
const visibleBlocks = computed(() => game.value?.blocks.slice(-6) ?? [])
const placementEffect = ref<'missed' | 'perfect' | 'placed' | null>(null)
const fallingBlock = ref<TowerActiveBlock | null>(null)
const fallingStyle = ref<CSSProperties>({})
const gameOverVisible = ref(true)
let animationFrame: number | undefined
let previousFrameTime = 0
let effectTimer: ReturnType<typeof setTimeout> | undefined

const blockColors = [
  '#ff4d67',
  '#ffd23f',
  '#27dff2',
  '#a879ff',
  '#ff7a3d',
  '#36e6a0',
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
  <main
    class="tower-app"
    :class="{ 'tower-app--playing': !tower.menuOpen && game }"
    :aria-label="phone.t('Apps.towerStack.name')"
  >
    <header v-if="tower.menuOpen" class="tower-header">
      <div>
        <span>{{ phone.t('Apps.towerStack.eyebrow') }}</span>
        <h1>{{ phone.t('Apps.towerStack.name') }}</h1>
      </div>
      <k-button
        component="button"
        clear
        rounded
        type="button"
        :aria-label="phone.t(tower.soundEnabled ? 'Apps.towerStack.mute' : 'Apps.towerStack.unmute')"
        @click="toggleSound"
      >
        <Volume2 v-if="tower.soundEnabled" :size="18" aria-hidden="true" />
        <VolumeX v-else :size="18" aria-hidden="true" />
      </k-button>
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
      <button
        type="button"
        :class="game?.status === 'paused' ? 'tower-secondary' : 'tower-primary'"
        @click="startGame"
      >
        <RotateCcw v-if="game" :size="16" aria-hidden="true" />
        <Play v-else :size="16" fill="currentColor" aria-hidden="true" />
        {{ phone.t(game ? 'Apps.towerStack.newGame' : 'Apps.towerStack.start') }}
      </button>
      <p class="tower-menu__hint">{{ phone.t('Apps.towerStack.tapHint') }}</p>
    </section>

    <section v-else-if="game" class="tower-game">
      <div class="tower-toolbar">
        <k-button
          component="button"
          clear
          rounded
          type="button"
          :aria-label="phone.t('Apps.towerStack.backToMenu')"
          @pointerdown.stop="tower.showMenu()"
          @click.stop="tower.showMenu()"
        ><ChevronLeft :size="19" /></k-button>
        <div><span>{{ phone.t('Apps.towerStack.height') }}</span><strong>{{ game.blocks.length - 1 }}</strong></div>
        <div><span>{{ phone.t('Apps.towerStack.score') }}</span><strong>{{ game.score }}</strong></div>
        <k-button component="button" clear rounded type="button" :aria-label="phone.t('Apps.towerStack.pause')" @click="togglePause">
          <Pause v-if="game.status === 'playing'" :size="17" fill="currentColor" />
          <Play v-else :size="17" fill="currentColor" />
        </k-button>
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
.tower-app--playing { padding: 0; }
.tower-header { height: 50px; display: flex; align-items: center; justify-content: space-between; }
.tower-header span { display: block; color: #c1b8f1; font-size: 10px; font-weight: 850; letter-spacing: 1.1px; text-transform: uppercase; }
.tower-header h1 { margin: 1px 0 0; font-size: 27px; line-height: 1; letter-spacing: -0.8px; }
.tower-header button, .tower-toolbar button { width: 36px; height: 36px; display: grid; place-items: center; padding: 0; border: 1px solid #ffffff14; border-radius: 12px; color: #f2edff; background: #ffffff0d; }
.tower-menu { height: calc(100% - 50px); display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 9px; text-align: center; }
.tower-menu__preview { position: relative; flex: 0 0 124px; width: 158px; height: 124px; }
.tower-menu__preview i { position: absolute; right: 12px; bottom: calc((var(--preview-index) - 1) * 15px); left: 23px; height: 21px; border-radius: 6px; background: hsl(calc(var(--preview-index) * 49deg + 5deg) 82% 62%); box-shadow: inset 0 3px 0 #ffffff35, 0 5px 11px #08091c5c; transform: perspective(200px) rotateX(5deg); }
.tower-menu__preview i:nth-child(even) { right: 23px; left: 12px; }
.tower-menu__preview span { position: absolute; top: 0; left: 4px; width: 100px; height: 21px; border-radius: 6px; background: #ff6b68; box-shadow: 0 0 20px #ff6b6877; animation: tower-preview-slide 1.5s ease-in-out infinite alternate; }
.tower-menu__copy > span { color: #ffcf59; font-size: 10px; font-weight: 900; letter-spacing: 1px; text-transform: uppercase; }
.tower-menu__copy h2 { max-width: 270px; margin: 3px auto 5px; font-size: 24px; line-height: 1.08; }
.tower-menu__copy p { max-width: 285px; margin: 0; color: #d8d3eb; font-size: 12px; font-weight: 550; line-height: 1.35; }
.tower-records { width: 100%; display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
.tower-records div { display: grid; gap: 1px; padding: 8px 9px; border: 1px solid #ffffff1f; border-radius: 13px; background: #ffffff0d; backdrop-filter: blur(8px); }
.tower-records span { color: #d1caea; font-size: 9px; font-weight: 850; letter-spacing: .35px; text-transform: uppercase; }
.tower-records strong { font-size: 20px; }
.tower-primary, .tower-secondary { width: 100%; min-height: 42px; display: flex; align-items: center; justify-content: center; gap: 7px; border-radius: 14px; font-size: 13px; font-weight: 850; }
.tower-primary { border: 0; color: #1e1839; background: linear-gradient(135deg, #ffca4f, #ff8760); box-shadow: 0 8px 18px #ff895330; }
.tower-secondary { border: 1px solid #ffffff16; color: #eeeaff; background: #ffffff0a; }
.tower-menu__hint, .tower-game__hint { margin: 0; color: #c9c2e0; font-size: 10px; font-weight: 700; line-height: 1.35; }
.tower-game { position: absolute; inset: 0; }
.tower-toolbar { position: absolute; z-index: 10; top: 66px; right: 18px; left: 18px; height: 42px; display: grid; grid-template-columns: 32px 1fr 1fr 32px; align-items: center; gap: 4px; padding: 4px; border: 1px solid #ffffff1a; border-radius: 21px; background: #292451a8; box-shadow: 0 8px 24px #08091c52; backdrop-filter: blur(14px); box-sizing: border-box; }
.tower-toolbar div { height: 32px; display: grid; grid-template-rows: 10px 20px; align-content: center; justify-items: center; }
.tower-toolbar span { color: #c9c2e9; font-size: 11px; font-weight: 850; line-height: 10px; letter-spacing: .35px; text-transform: uppercase; }
.tower-toolbar strong { display: block; font-size: 19px; line-height: 20px; }
.tower-toolbar button { width: 32px; height: 32px; border: 0; border-radius: 50%; box-shadow: none; }
.tower-stage { position: absolute; inset: 0; width: 100%; height: 100%; display: block; overflow: hidden; padding: 0; border: 0; border-radius: 0; background: linear-gradient(#1d1b52, #433078 60%, #8e4c78); box-shadow: inset 0 0 35px #08091d80; touch-action: manipulation; }
.tower-sky { position: absolute; inset: 0; pointer-events: none; }
.tower-sky i { position: absolute; width: 3px; height: 3px; border-radius: 50%; background: #fff; box-shadow: 0 0 7px #c5c2ff; opacity: .65; }
.tower-sky i:nth-child(1) { top: 8%; left: 12%; } .tower-sky i:nth-child(2) { top: 17%; left: 72%; } .tower-sky i:nth-child(3) { top: 28%; left: 42%; } .tower-sky i:nth-child(4) { top: 37%; left: 88%; } .tower-sky i:nth-child(5) { top: 46%; left: 18%; } .tower-sky i:nth-child(6) { top: 58%; left: 64%; } .tower-sky i:nth-child(7) { top: 70%; left: 31%; } .tower-sky i:nth-child(8) { top: 11%; left: 91%; } .tower-sky i:nth-child(9) { top: 22%; left: 25%; } .tower-sky i:nth-child(10) { top: 50%; left: 78%; } .tower-sky i:nth-child(11) { top: 64%; left: 8%; } .tower-sky i:nth-child(12) { top: 77%; left: 92%; } .tower-sky i:nth-child(13) { top: 33%; left: 58%; }
.tower-stack { position: absolute; inset: 0 14px; }
.tower-block { position: absolute; height: 32px; border: 1px solid #ffffff80; border-radius: 7px; background: var(--tower-block-color); box-shadow: inset 0 5px 0 #ffffff52, inset 0 -4px 0 #00000024, 0 7px 12px #08091d80; }
.tower-block--active { z-index: 3; border: 2px solid #fff; filter: saturate(1.3) brightness(1.2); box-shadow: inset 0 5px 0 #ffffff70, 0 0 8px #fff, 0 0 24px var(--tower-block-color), 0 9px 14px #08091d90; animation: tower-active-pulse .7s ease-in-out infinite alternate; }
.tower-block--placed { animation: tower-land 180ms ease-out; }
.tower-block--falling { z-index: 4; animation: tower-fall 850ms ease-in forwards; }
.tower-ground { position: absolute; right: 0; bottom: 0; left: 0; height: 35px; background: linear-gradient(#5b3468, #191630); box-shadow: 0 -8px 24px #ff729150; }
.tower-perfect { position: absolute; z-index: 8; top: 24%; left: 50%; padding: 8px 17px; border-radius: 18px; color: #332149; background: #ffdc65; box-shadow: 0 0 24px #ffcf64aa; font-size: 13px; font-weight: 950; letter-spacing: .8px; transform: translateX(-50%); animation: tower-perfect-pop 650ms ease-out forwards; }
.tower-stage--perfect { animation: tower-perfect-glow 500ms ease-out; }
.tower-stage--missed { animation: tower-stage-shake 500ms ease-out; }
.tower-game__hint { position: absolute; z-index: 6; right: 45px; bottom: 27px; left: 45px; margin: 0; padding: 7px 10px; border-radius: 999px; color: #e0daf0; background: #29245191; backdrop-filter: blur(10px); text-align: center; pointer-events: none; }
.tower-overlay { position: absolute; z-index: 15; inset: 0; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 9px; padding: 28px; color: #f7f2ff; background: #11122bd9; backdrop-filter: blur(7px); text-align: center; }
.tower-overlay > svg { color: #ffbd4d; }
.tower-overlay > span { color: #ffad78; font-size: 12px; font-weight: 900; letter-spacing: 1.2px; text-transform: uppercase; }
.tower-overlay h2 { margin: 0; font-size: 25px; }
.tower-overlay p { margin: -3px 0 5px; color: #c7c1e4; font-size: 14px; }
@keyframes tower-preview-slide { from { transform: translateX(0) rotate(-2deg); } to { transform: translateX(48px) rotate(2deg); } }
@keyframes tower-land { from { filter: brightness(1.8); transform: translateY(-8px) scaleY(.85); } to { filter: brightness(1); transform: translateY(0) scaleY(1); } }
@keyframes tower-active-pulse { from { filter: saturate(1.2) brightness(1.08); } to { filter: saturate(1.45) brightness(1.35); } }
@keyframes tower-fall { 0% { opacity: 1; transform: translate(0) rotate(0); } 100% { opacity: 0; transform: translate(45px, 390px) rotate(145deg); } }
@keyframes tower-perfect-pop { 0% { opacity: 0; transform: translateX(-50%) scale(.4); } 35% { opacity: 1; transform: translateX(-50%) scale(1.2); } 100% { opacity: 0; transform: translateX(-50%) scale(1); } }
@keyframes tower-perfect-glow { 0%, 100% { box-shadow: inset 0 0 35px #08091d99, 0 16px 28px #08091c66; } 45% { box-shadow: inset 0 0 45px #ffd75c55, 0 0 30px #ffd75c66; } }
@keyframes tower-stage-shake { 0%, 100% { transform: translate(0); } 20% { transform: translate(-5px, 2px); } 40% { transform: translate(5px, -2px); } 60% { transform: translate(-3px, 1px); } 80% { transform: translate(2px); } }
button:active { transform: scale(.97); }
@media (prefers-reduced-motion: reduce) { .tower-menu__preview span, .tower-block, .tower-perfect, .tower-stage { animation: none; } }
</style>
