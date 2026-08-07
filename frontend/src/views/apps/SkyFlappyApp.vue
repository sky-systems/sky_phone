

<script setup lang="ts">
import { ChevronLeft, Pause, Play, RotateCcw, Volume2, VolumeX, Wind } from 'lucide-vue-next'
import { kButton } from 'konsta/vue'
import { computed, onBeforeUnmount, ref, watch, type CSSProperties } from 'vue'

import { playSkyFlappySound } from '@/features/games/sky-flappy/audio'
import SkyFlappyBird from '@/features/games/sky-flappy/SkyFlappyBird.vue'
import { useSkyFlappyStore } from '@/features/games/sky-flappy/store'
import type { SkyFlappyDesign, SkyFlappyObstacle } from '@/features/games/sky-flappy/types'
import { usePhoneStore } from '@/stores/phone'

const phone = usePhoneStore()
const flappy = useSkyFlappyStore()
const game = computed(() => flappy.game)
const designs: SkyFlappyDesign[] = ['dawn', 'neon', 'storm']
const gameOverVisible = ref(true)
const flapEffect = ref(0)
let animationFrame: number | undefined
let previousTime = 0
let resultTimer: ReturnType<typeof setTimeout> | undefined

const playerStyle = computed<CSSProperties>(() => ({
  top: `${game.value?.playerY ?? 48}%`,
  transform: `translate(-50%, -50%) rotate(${Math.max(-24, Math.min(70, (game.value?.playerVelocity ?? 0) * 1.35))}deg)`,
}))

function obstacleStyle(obstacle: SkyFlappyObstacle): CSSProperties {
  return { left: `${obstacle.x}%`, width: '14%' }
}

function runFrame(time: number): void {
  if (game.value?.status !== 'playing') return
  if (previousTime > 0) {
    const previousScore = game.value.score
    flappy.tick(Math.min(0.035, (time - previousTime) / 1000))
    if (game.value && game.value.score > previousScore) {
      playSkyFlappySound('point', flappy.soundEnabled)
    }
    const nextStatus: string | undefined = flappy.game?.status
    if (nextStatus === 'over') {
      playSkyFlappySound('crash', flappy.soundEnabled)
      gameOverVisible.value = false
      resultTimer = setTimeout(() => {
        gameOverVisible.value = true
        resultTimer = undefined
      }, 650)
    }
  }
  previousTime = time
  animationFrame = requestAnimationFrame(runFrame)
}

function startLoop(): void {
  if (animationFrame !== undefined) cancelAnimationFrame(animationFrame)
  previousTime = 0
  animationFrame = requestAnimationFrame(runFrame)
}

function stopLoop(): void {
  if (animationFrame !== undefined) cancelAnimationFrame(animationFrame)
  animationFrame = undefined
  previousTime = 0
}

function startGame(): void {
  if (resultTimer) clearTimeout(resultTimer)
  resultTimer = undefined
  gameOverVisible.value = true
  flappy.start()
}

function flap(): void {
  if (!game.value || game.value.status === 'over' || game.value.status === 'paused') return
  flappy.flap()
  flapEffect.value += 1
  playSkyFlappySound('flap', flappy.soundEnabled)
}

function togglePause(): void {
  if (game.value?.status === 'playing') flappy.pause()
  else if (game.value?.status === 'paused') flappy.resume()
}

function toggleSound(): void {
  const enabled = !flappy.soundEnabled
  flappy.setSoundEnabled(enabled)
  if (enabled) playSkyFlappySound('point', true)
}

flappy.hydrate()
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
  if (resultTimer) clearTimeout(resultTimer)
  flappy.pause()
})
</script>

<template>
  <main
    class="flappy-app"
    :class="[
      `flappy-app--${flappy.design}`,
      { 'flappy-app--playing': !flappy.menuOpen && game },
    ]"
    :aria-label="phone.t('Apps.skyFlappy.name')"
  >
    <header v-if="flappy.menuOpen" class="flappy-header">
      <div><span>{{ phone.t('Apps.skyFlappy.eyebrow') }}</span><h1>{{ phone.t('Apps.skyFlappy.name') }}</h1></div>
      <k-button component="button" clear rounded type="button" :aria-label="phone.t(flappy.soundEnabled ? 'Apps.skyFlappy.mute' : 'Apps.skyFlappy.unmute')" @click="toggleSound">
        <Volume2 v-if="flappy.soundEnabled" :size="18" /><VolumeX v-else :size="18" />
      </k-button>
    </header>

    <section v-if="flappy.menuOpen" class="flappy-menu">
      <div class="flappy-menu__hero" aria-hidden="true">
        <SkyFlappyBird class="sky-bird sky-bird--hero" />
        <i class="flappy-menu__trail"></i>
        <div class="flappy-menu__tower flappy-menu__tower--top"></div>
        <div class="flappy-menu__tower flappy-menu__tower--bottom"></div>
      </div>
      <div class="flappy-menu__copy"><span>{{ phone.t('Apps.skyFlappy.ready') }}</span><h2>{{ phone.t('Apps.skyFlappy.menuTitle') }}</h2><p>{{ phone.t('Apps.skyFlappy.menuBody') }}</p></div>
      <div class="flappy-record"><span>{{ phone.t('Apps.skyFlappy.highScore') }}</span><strong>{{ flappy.highScore }}</strong></div>
      <div class="flappy-designs" :aria-label="phone.t('Apps.skyFlappy.design')">
        <button v-for="design in designs" :key="design" type="button" :class="{ active: flappy.design === design }" @click="flappy.setDesign(design)">
          <i :class="`flappy-designs__${design}`"></i>{{ phone.t(`Apps.skyFlappy.designs.${design}`) }}
        </button>
      </div>
      <button type="button" class="flappy-primary" @click="startGame">{{ phone.t('Apps.skyFlappy.start') }}</button>
      <p>{{ phone.t('Apps.skyFlappy.tapHint') }}</p>
    </section>

    <section v-else-if="game" class="flappy-game">
      <div class="flappy-toolbar">
        <k-button component="button" clear rounded type="button" :aria-label="phone.t('Apps.skyFlappy.backToMenu')" @pointerdown.stop="flappy.showMenu()" @click.stop="flappy.showMenu()"><ChevronLeft :size="19" /></k-button>
        <div><span>{{ phone.t('Apps.skyFlappy.score') }}</span><strong>{{ game.score }}</strong></div>
        <div><span>{{ phone.t('Apps.skyFlappy.best') }}</span><strong>{{ flappy.highScore }}</strong></div>
        <k-button component="button" clear rounded type="button" :aria-label="phone.t('Apps.skyFlappy.pause')" @click="togglePause"><Pause v-if="game.status === 'playing'" :size="16" fill="currentColor" /><Play v-else :size="16" fill="currentColor" /></k-button>
      </div>

      <button type="button" class="flappy-stage" :class="{ 'flappy-stage--crashed': game.status === 'over' && !gameOverVisible }" :aria-label="phone.t('Apps.skyFlappy.flap')" @pointerdown.stop.prevent="flap">
        <div class="flappy-clouds" aria-hidden="true"><i v-for="cloud in 7" :key="cloud"></i></div>
        <div v-for="obstacle in game.obstacles" :key="obstacle.id" class="flappy-obstacle" :style="obstacleStyle(obstacle)" aria-hidden="true">
          <span class="flappy-obstacle__top" :style="{ height: `${obstacle.gapTop}%` }"></span>
          <span class="flappy-obstacle__bottom" :style="{ top: `${obstacle.gapTop + obstacle.gapHeight}%` }"></span>
        </div>
        <SkyFlappyBird :key="flapEffect" class="sky-bird sky-bird--player" :style="playerStyle" />
        <strong v-if="game.status === 'ready'" class="flappy-ready">{{ phone.t('Apps.skyFlappy.firstTap') }}</strong>
        <div class="flappy-horizon" aria-hidden="true"></div>
      </button>

      <div v-if="game.status === 'paused'" class="flappy-overlay"><Pause :size="30" /><h2>{{ phone.t('Apps.skyFlappy.paused') }}</h2><button type="button" class="flappy-primary" @click="flappy.resume()">{{ phone.t('Apps.skyFlappy.resume') }}</button><button type="button" class="flappy-secondary" @click="flappy.showMenu()">{{ phone.t('Apps.skyFlappy.mainMenu') }}</button></div>
      <div v-if="game.status === 'over' && gameOverVisible" class="flappy-overlay"><Wind :size="34" /><span>{{ phone.t('Apps.skyFlappy.gameOver') }}</span><h2>{{ game.score }} {{ phone.t('Apps.skyFlappy.points') }}</h2><button type="button" class="flappy-primary" @click="startGame"><RotateCcw :size="16" />{{ phone.t('Apps.skyFlappy.playAgain') }}</button><button type="button" class="flappy-secondary" @click="flappy.showMenu()">{{ phone.t('Apps.skyFlappy.mainMenu') }}</button></div>
      <p class="flappy-game__hint">{{ phone.t('Apps.skyFlappy.gameHint') }}</p>
    </section>
  </main>
</template>

<style scoped>
.flappy-app { --sky-a:#50d8f2;--sky-b:#765ce8;--tower:#574be8;--tower-light:#9b94ff;--tower-dark:#3429a6;--tower-glow:#79e7ff; position:absolute;inset:0;overflow:hidden;padding:52px 16px 27px;color:#fff;background:linear-gradient(160deg,#19375e,#433b80);font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;user-select:none;touch-action:manipulation; }
.flappy-app--playing { padding:0; }
.flappy-app--neon { --sky-a:#151c58;--sky-b:#a329a2;--tower:#19dfe6;--tower-light:#82ffff;--tower-dark:#087f91;--tower-glow:#26fbff; }.flappy-app--storm { --sky-a:#6f8497;--sky-b:#2b3955;--tower:#df765f;--tower-light:#ffb18e;--tower-dark:#8d3e39;--tower-glow:#ff997d; }
.flappy-header{height:55px;display:flex;align-items:center;justify-content:space-between}.flappy-header span{display:block;color:#d9e9fa;font-size:14px;font-weight:850;letter-spacing:1.1px;text-transform:uppercase}.flappy-header h1{margin:1px 0 0;font-size:32px;line-height:1}.flappy-header button,.flappy-toolbar button{width:36px;height:36px;display:grid;place-items:center;padding:0;border:1px solid #ffffff35;border-radius:12px;color:#fff;background:#ffffff18}
.flappy-menu{height:calc(100% - 55px);display:flex;flex-direction:column;align-items:center;justify-content:center;gap:12px;text-align:center}.flappy-menu__hero{position:relative;width:220px;height:210px;overflow:hidden;border-radius:28px;background:linear-gradient(var(--sky-a),var(--sky-b));box-shadow:inset 0 0 28px #223c6d35,0 18px 32px #101b3b66}.flappy-menu__hero::before{position:absolute;z-index:0;top:22px;left:25px;width:39px;height:39px;border-radius:50%;background:#ffe8a7cc;box-shadow:0 0 18px #fff1b46b;content:""}.flappy-menu__hero::after{position:absolute;z-index:1;bottom:30px;left:-12px;width:68px;height:18px;border-radius:999px;background:#ffffff3d;box-shadow:27px -9px 0 3px #ffffff36,57px 1px 0 -2px #ffffff2c;content:""}.flappy-menu__tower{position:absolute;z-index:3;right:10px;width:42px;background:linear-gradient(90deg,color-mix(in srgb,var(--tower),white 30%),var(--tower));box-shadow:inset 7px 0 0 #ffffff22,inset -6px 0 9px #0003}.flappy-menu__tower::after{position:absolute;left:-8px;width:58px;height:22px;border:3px solid color-mix(in srgb,var(--tower),black 22%);border-radius:7px;background:linear-gradient(90deg,color-mix(in srgb,var(--tower),white 36%),var(--tower));box-shadow:inset 0 4px 0 #ffffff26;content:""}.flappy-menu__tower--top{top:0;height:61px;border-radius:0 0 5px 5px}.flappy-menu__tower--top::after{bottom:-11px}.flappy-menu__tower--bottom{bottom:0;height:67px;border-radius:5px 5px 0 0}.flappy-menu__tower--bottom::after{top:-11px}.flappy-menu__trail{position:absolute;z-index:2;top:102px;left:11px;width:46px;height:4px;border-radius:99px;background:#edfbffb8;box-shadow:13px 12px 0 -1px #e9faff8c,6px -12px 0 -1px #e9faff73;animation:flappy-trail 1s ease-in-out infinite}.sky-bird{position:absolute;z-index:4;width:66px;height:46px;overflow:visible;filter:drop-shadow(0 4px 5px #071d3e66)}.sky-bird :deep(path){stroke-linecap:round;stroke-linejoin:round}.sky-bird :deep(.sky-flappy-bird__far-wing){fill:#2d7188;stroke:#123f57;stroke-width:2}.sky-bird :deep(.sky-flappy-bird__far-wing path:last-child){fill:none;stroke:#8ec6ce;stroke-width:1.4;opacity:.65}.sky-bird :deep(.sky-flappy-bird__tail){fill:#285e78;stroke:#123f57;stroke-width:2}.sky-bird :deep(.sky-flappy-bird__body){fill:url(#sky-bird-body);stroke:#123f57;stroke-width:2}.sky-bird :deep(.sky-flappy-bird__belly){fill:#b7e5df;opacity:.84}.sky-bird :deep(.sky-flappy-bird__neck){fill:#377f98}.sky-bird :deep(.sky-flappy-bird__wing){transform-box:view-box;transform-origin:52px 38px}.sky-bird :deep(.sky-flappy-bird__wing-shape){fill:url(#sky-bird-wing);stroke:#123f57;stroke-width:2}.sky-bird :deep(.sky-flappy-bird__feather){fill:none;stroke:#d4f0ed;stroke-width:1.5;opacity:.78}.sky-bird :deep(.sky-flappy-bird__face){fill:#d8f0e9}.sky-bird :deep(.sky-flappy-bird__eye-ring){fill:#f5fbf7}.sky-bird :deep(.sky-flappy-bird__eye){fill:#102d3d}.sky-bird :deep(.sky-flappy-bird__beak){fill:#f2a84b;stroke:#6f4727;stroke-width:1.5}.sky-bird--hero{top:72px;left:42px;width:100px;height:69px;animation:flappy-hero 1.1s ease-in-out infinite alternate}.sky-bird--hero :deep(.sky-flappy-bird__wing){animation:flappy-bird-glide 1.1s ease-in-out infinite}.sky-bird--hero :deep(.sky-flappy-bird__far-wing){transform-box:view-box;transform-origin:50px 38px;animation:flappy-bird-far-glide 1.1s ease-in-out infinite}.flappy-menu__copy>span{color:#ffda70;font-size:9px;font-weight:900;letter-spacing:1px;text-transform:uppercase}.flappy-menu__copy h2{margin:3px 0 5px;font-size:21px}.flappy-menu__copy p{max-width:275px;margin:0;color:#c0c8df;font-size:10px;line-height:1.4}.flappy-record{width:100%;display:flex;align-items:center;justify-content:space-between;padding:9px 14px;border:1px solid #ffffff14;border-radius:13px;background:#ffffff0c}.flappy-record span{color:#bdc8df;font-size:9px;font-weight:800;text-transform:uppercase}.flappy-record strong{font-size:19px}.flappy-designs{width:100%;display:grid;grid-template-columns:repeat(3,1fr);gap:6px}.flappy-designs button{display:grid;place-items:center;gap:3px;padding:7px 3px;border:1px solid #ffffff12;border-radius:12px;color:#ccd4e9;background:#ffffff0a;font-size:8px}.flappy-designs button.active{border-color:#ffdd72;color:#fff;background:#ffffff1b}.flappy-designs i{width:26px;height:13px;border-radius:8px}.flappy-designs__dawn{background:linear-gradient(90deg,#58d6ee,#ff9b80)}.flappy-designs__neon{background:linear-gradient(90deg,#24255f,#ef55ca)}.flappy-designs__storm{background:linear-gradient(90deg,#71899b,#253750)}.flappy-primary,.flappy-secondary{width:100%;min-height:43px;display:flex;align-items:center;justify-content:center;gap:7px;border-radius:14px;font-size:11px;font-weight:850}.flappy-primary{border:0;color:#173353;background:linear-gradient(135deg,#ffe16c,#ff9d68)}.flappy-secondary{border:1px solid #ffffff18;color:#fff;background:#ffffff0b}.flappy-menu>p,.flappy-game__hint{margin:0;color:#aeb9d2;font-size:9px}
.flappy-game{position:absolute;inset:0}.flappy-toolbar{position:absolute;z-index:10;top:48px;right:14px;left:14px;height:42px;display:grid;grid-template-columns:36px 1fr 1fr 36px;align-items:center;gap:7px;padding:4px 6px;border:1px solid #ffffff2b;border-radius:22px;background:#263c6da8;box-shadow:0 8px 24px #10193455;backdrop-filter:blur(14px)}.flappy-toolbar div{display:grid;justify-items:center}.flappy-toolbar span{color:#bac9df;font-size:8px;font-weight:850;text-transform:uppercase}.flappy-toolbar strong{font-size:16px}.flappy-toolbar button{width:34px;height:34px;border:0;border-radius:50%;box-shadow:none}.flappy-stage{position:absolute;inset:0;width:100%;height:100%;display:block;overflow:hidden;padding:0;border:0;border-radius:0;background:linear-gradient(var(--sky-a),var(--sky-b));box-shadow:inset 0 0 35px #15244c55;touch-action:manipulation}.flappy-clouds{position:absolute;z-index:1;inset:0;overflow:hidden;pointer-events:none}.flappy-clouds i{--cloud-scale:1;--cloud-opacity:.34;--cloud-duration:18s;--cloud-delay:0s;position:absolute;left:100%;width:70px;height:18px;border-radius:999px;background:linear-gradient(180deg,#ffffffd9,#eaf7ff9c);box-shadow:0 8px 16px #24376518;opacity:var(--cloud-opacity);animation:cloud-drift var(--cloud-duration) linear var(--cloud-delay) infinite;will-change:transform}.flappy-clouds i::before{position:absolute;bottom:4px;left:12px;width:29px;height:29px;border-radius:50%;background:#f8fcffe6;box-shadow:22px -8px 0 4px #f7fcff,40px 1px 0 -2px #eef9ff;content:""}.flappy-clouds i::after{position:absolute;right:8px;bottom:-3px;left:8px;height:8px;border-radius:50%;background:#bcdff477;filter:blur(4px);content:""}.flappy-clouds i:nth-child(1){--cloud-scale:.7;--cloud-opacity:.3;--cloud-duration:20s;--cloud-delay:-4s;top:9%}.flappy-clouds i:nth-child(2){--cloud-scale:1.05;--cloud-opacity:.4;--cloud-duration:15s;--cloud-delay:-11s;top:22%}.flappy-clouds i:nth-child(3){--cloud-scale:.52;--cloud-opacity:.25;--cloud-duration:23s;--cloud-delay:-17s;top:38%}.flappy-clouds i:nth-child(4){--cloud-scale:.88;--cloud-opacity:.36;--cloud-duration:17s;--cloud-delay:-7s;top:53%}.flappy-clouds i:nth-child(5){--cloud-scale:1.18;--cloud-opacity:.42;--cloud-duration:14s;--cloud-delay:-2s;top:68%}.flappy-clouds i:nth-child(6){--cloud-scale:.62;--cloud-opacity:.27;--cloud-duration:21s;--cloud-delay:-14s;top:78%}.flappy-clouds i:nth-child(7){--cloud-scale:.96;--cloud-opacity:.34;--cloud-duration:16s;--cloud-delay:-9s;top:86%}.flappy-obstacle{position:absolute;z-index:2;top:0;bottom:0}.flappy-obstacle span{position:absolute;right:0;left:0;background:linear-gradient(90deg,color-mix(in srgb,var(--tower),white 20%),var(--tower));box-shadow:inset -6px 0 8px #0003,0 0 13px #17204e55}.flappy-obstacle span::after{position:absolute;right:-4px;left:-4px;height:14px;border-radius:6px;background:color-mix(in srgb,var(--tower),white 10%);box-shadow:inset 0 3px 0 #ffffff25;content:""}.flappy-obstacle__top{top:0;border-radius:0 0 7px 7px}.flappy-obstacle__top::after{bottom:0}.flappy-obstacle__bottom{bottom:0;border-radius:7px 7px 0 0}.flappy-obstacle__bottom::after{top:0}.sky-bird--player{left:23%;animation:flappy-wing .24s ease-out}.sky-bird--player :deep(.sky-flappy-bird__wing){animation:flappy-bird-flap .24s cubic-bezier(.2,.75,.35,1)}.sky-bird--player :deep(.sky-flappy-bird__far-wing){transform-box:view-box;transform-origin:50px 38px;animation:flappy-bird-far-flap .24s cubic-bezier(.2,.75,.35,1)}.flappy-ready{position:absolute;z-index:6;top:36%;left:50%;padding:9px 15px;border-radius:17px;background:#15284fbb;font-size:11px;transform:translateX(-50%)}.flappy-horizon{position:absolute;z-index:3;right:0;bottom:0;left:0;height:12px;background:#263a62;box-shadow:0 -5px 14px #ffffff26}.flappy-stage--crashed{animation:flappy-crash .55s ease-out}.flappy-game__hint{position:absolute;z-index:6;right:45px;bottom:27px;left:45px;margin:0;padding:7px 10px;border-radius:999px;background:#263c6d91;backdrop-filter:blur(10px);text-align:center;pointer-events:none}.flappy-overlay{position:absolute;z-index:12;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:9px;padding:28px;background:#101a38dc;backdrop-filter:blur(7px);text-align:center}.flappy-overlay>svg{color:#ffdc71}.flappy-overlay>span{color:#ffad78;font-size:9px;font-weight:900;letter-spacing:1px;text-transform:uppercase}.flappy-overlay h2{margin:0 0 5px;font-size:26px}
.flappy-menu__tower{border:2px solid var(--tower-dark);background:linear-gradient(90deg,var(--tower-light),var(--tower),var(--tower-dark));box-shadow:inset 7px 0 0 #ffffff38,inset -6px 0 9px #0004,0 0 18px var(--tower-glow)}
.flappy-menu__tower::after{border-color:var(--tower-dark);background:linear-gradient(90deg,var(--tower-light),var(--tower));box-shadow:inset 0 4px 0 #ffffff45,0 0 14px var(--tower-glow)}
.flappy-menu__copy>span{color:#ffdf7d;font-size:14px}
.flappy-menu__copy h2{margin:4px 0 7px;font-size:30px}
.flappy-menu__copy p{max-width:295px;color:#e4ebf7;font-size:18px;font-weight:550;line-height:1.4}
.flappy-record{padding:12px 14px;border-color:#ffffff2b;background:#ffffff12}
.flappy-record span{color:#d9e4f3;font-size:15px;font-weight:850}
.flappy-record strong{font-size:26px}
.flappy-designs button{gap:5px;padding:9px 3px;border-color:#ffffff25;color:#edf3ff;background:#ffffff0e;font-size:14px;font-weight:750}
.flappy-designs button.active{background:#ffffff24}
.flappy-designs i{width:32px;height:15px}
.flappy-primary,.flappy-secondary{min-height:50px;gap:8px;font-size:18px}
.flappy-secondary{border-color:#ffffff2c;background:#ffffff12}
.flappy-menu>p,.flappy-game__hint{color:#e1e9f6;font-size:16px;font-weight:700;line-height:1.35}
.flappy-toolbar span{color:#e0eafa;font-size:11px;line-height:10px;letter-spacing:.35px}
.flappy-toolbar strong{display:block;font-size:19px;line-height:20px}
.flappy-toolbar{top:66px;right:18px;left:18px;height:42px;grid-template-columns:32px 1fr 1fr 32px;gap:4px;padding:4px;border-radius:21px;box-sizing:border-box}
.flappy-toolbar div{height:32px;display:grid;grid-template-rows:10px 20px;align-content:center;justify-items:center}
.flappy-toolbar button{width:32px;height:32px}
.flappy-clouds{top:110px}
.flappy-stage{border:0;box-shadow:inset 0 0 35px #15244c38}
.flappy-obstacle span{border:2px solid var(--tower-dark);background:linear-gradient(90deg,var(--tower-light),var(--tower),var(--tower-dark));box-shadow:inset 7px 0 0 #ffffff42,inset -6px 0 8px #0004,0 0 18px var(--tower-glow)}
.flappy-obstacle span::after{right:-5px;left:-5px;height:17px;border:2px solid var(--tower-dark);background:linear-gradient(180deg,var(--tower-light),var(--tower));box-shadow:inset 0 4px 0 #ffffff55,0 0 14px var(--tower-glow)}
.flappy-ready{padding:11px 18px;border:2px solid #ffffff55;border-radius:19px;background:#15284fe6;font-size:16px;font-weight:850}
.flappy-horizon{background:var(--tower-dark);box-shadow:0 -5px 18px var(--tower-glow)}
.flappy-overlay>span{color:#ffc09b;font-size:13px}
.flappy-overlay h2{font-size:30px}
@keyframes flappy-hero{from{transform:translateY(7px) rotate(-5deg)}to{transform:translateY(-8px) rotate(7deg)}}@keyframes flappy-trail{0%,100%{opacity:.18;transform:scaleX(.65)}50%{opacity:.62;transform:scaleX(1)}}@keyframes flappy-wing{0%{filter:brightness(1.12) drop-shadow(0 4px 5px #071d3e66);scale:1.04}100%{filter:brightness(1) drop-shadow(0 4px 5px #071d3e66);scale:1}}@keyframes flappy-bird-flap{0%{transform:rotate(13deg) scaleY(.92)}42%{transform:rotate(-42deg) scaleY(.84)}100%{transform:rotate(8deg)}}@keyframes flappy-bird-far-flap{0%{transform:rotate(5deg)}45%{transform:rotate(-27deg)}100%{transform:rotate(3deg)}}@keyframes flappy-bird-glide{0%,100%{transform:rotate(7deg)}50%{transform:rotate(-32deg) scaleY(.88)}}@keyframes flappy-bird-far-glide{0%,100%{transform:rotate(2deg)}50%{transform:rotate(-20deg)}}@keyframes cloud-drift{from{transform:translate3d(40px,0,0) scale(var(--cloud-scale))}to{transform:translate3d(-440px,0,0) scale(var(--cloud-scale))}}@keyframes flappy-crash{0%,100%{transform:translate(0)}25%{transform:translate(-5px,3px)}50%{transform:translate(5px,-2px)}75%{transform:translate(-3px,1px)}}button:active{transform:scale(.97)}@media(prefers-reduced-motion:reduce){.sky-bird,.sky-bird :deep(*),.flappy-menu__trail,.flappy-clouds i,.flappy-stage{animation:none}}
</style>
