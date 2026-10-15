<script setup lang="ts">
import {
  Bookmark,
  CheckCircle2,
  Heart,
  MessageCircle,
  MoreHorizontal,
  Share2,
  UserRound,
} from 'lucide-vue-next'
import { SkyButton, SkyGlass, SkyIcon } from '@/ui'
import { computed, nextTick, onBeforeUnmount, ref } from 'vue'

import { usePhoneStore } from '@/stores/phone'
import type { FeatherPost } from '@/types/feather'

const props = defineProps<{ post: FeatherPost }>()
const emit = defineEmits<{
  follow: [post: FeatherPost]
  media: [post: FeatherPost, index: number]
  menu: [post: FeatherPost]
  open: [post: FeatherPost]
  profile: [profileId: number]
  react: [post: FeatherPost, kind: 'like' | 'bookmark']
  reply: [post: FeatherPost]
  share: [post: FeatherPost]
}>()

const phone = usePhoneStore()
const expanded = ref(false)
const reactionPulse = ref<'like' | 'bookmark' | null>(null)
let reactionPulseFrame: number | null = null
let reactionPulseTimer: number | null = null
const shouldTruncate = computed(() => props.post.body.length > 260)
const visibleBody = computed(() =>
  shouldTruncate.value && !expanded.value
    ? `${props.post.body.slice(0, 260).trimEnd()}…`
    : props.post.body,
)
const leadingMention = computed(
  () => visibleBody.value.match(/^@[a-z0-9_]+/i)?.[0] ?? '',
)
const visibleBodyAfterMention = computed(() =>
  leadingMention.value
    ? visibleBody.value.slice(leadingMention.value.length)
    : visibleBody.value,
)

function relativeTime(timestamp: number): string {
  const seconds = Math.max(1, Math.floor((Date.now() - timestamp) / 1000))
  if (seconds < 60) return `${seconds}s`
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m`
  if (seconds < 86400) return `${Math.floor(seconds / 3600)}h`
  return new Intl.DateTimeFormat(phone.lang, {
    day: 'numeric',
    month: 'short',
  }).format(timestamp)
}

function playReactionPulse(kind: 'like' | 'bookmark'): void {
  if (reactionPulseFrame !== null)
    window.cancelAnimationFrame(reactionPulseFrame)
  if (reactionPulseTimer !== null) window.clearTimeout(reactionPulseTimer)
  reactionPulse.value = null
  void nextTick(() => {
    reactionPulseFrame = window.requestAnimationFrame(() => {
      reactionPulse.value = kind
      reactionPulseFrame = null
      reactionPulseTimer = window.setTimeout(() => {
        reactionPulse.value = null
        reactionPulseTimer = null
      }, 520)
    })
  })
}

function react(kind: 'like' | 'bookmark'): void {
  const isActivating =
    kind === 'like' ? !props.post.is_liked : !props.post.is_bookmarked
  if (isActivating) playReactionPulse(kind)
  emit('react', props.post, kind)
}

onBeforeUnmount(() => {
  if (reactionPulseFrame !== null)
    window.cancelAnimationFrame(reactionPulseFrame)
  if (reactionPulseTimer !== null) window.clearTimeout(reactionPulseTimer)
})
</script>

<template>
  <SkyGlass :highlight="false" class="feather-post-glass">
    <article class="feather-post" @click="$emit('open', post)">
      <SkyButton
        variant="content"
        class="feather-avatar"
        type="button"
        @click.stop="$emit('profile', post.profile_id)"
      >
        <img v-if="post.avatar_url" :src="post.avatar_url" alt="" />
        <SkyIcon :icon="UserRound" v-else :size="21" />
      </SkyButton>

      <div class="feather-post__body">
        <header class="feather-post__header">
          <SkyButton
            variant="content"
            class="feather-post__author"
            type="button"
            @click.stop="$emit('profile', post.profile_id)"
          >
            <span class="feather-post__name">
              <strong>{{ post.display_name }}</strong>
              <SkyIcon
                :icon="CheckCircle2"
                v-if="post.verified"
                :size="13"
                class="feather-verified"
                :aria-label="phone.t('Apps.feather.verified')"
              />
            </span>
            <span class="feather-post__meta">
              @{{ post.handle }} · {{ relativeTime(post.created_at) }}
            </span>
          </SkyButton>
          <SkyButton
            v-if="!post.is_owner && !post.is_following"
            outline
            inline
            small
            rounded
            class="feather-follow"
            @click.stop="$emit('follow', post)"
          >
            {{ phone.t('Apps.feather.follow') }}
          </SkyButton>
          <SkyButton
            icon-only
            rounded
            small
            tonal
            class="feather-more"
            :aria-label="phone.t('Apps.feather.moreActions')"
            @click.stop="$emit('menu', post)"
          >
            <SkyIcon><SkyIcon :icon="MoreHorizontal" :size="18" /></SkyIcon>
          </SkyButton>
        </header>

        <p v-if="post.body" class="feather-post__text">
          <span v-if="leadingMention" class="feather-post__mention">{{
            leadingMention
          }}</span
          >{{ visibleBodyAfterMention }}
          <SkyButton
            variant="content"
            v-if="shouldTruncate && !expanded"
            type="button"
            class="feather-post__more-text"
            @click.stop="expanded = true"
          >
            {{ phone.t('Apps.feather.showMore') }}
          </SkyButton>
        </p>
        <div
          v-if="post.media.length"
          class="feather-media"
          :class="`feather-media--${Math.min(post.media.length, 4)}`"
        >
          <SkyButton
            variant="content"
            v-for="(item, index) in post.media"
            :key="item.id"
            type="button"
            class="feather-media__item"
            :aria-label="
              phone.t('Apps.feather.openImage', {
                number: String(index + 1),
              })
            "
            @click.stop="$emit('media', post, index)"
          >
            <img :src="item.url" alt="" />
          </SkyButton>
        </div>

        <footer class="feather-actions">
          <SkyButton
            variant="content"
            type="button"
            @click.stop="$emit('reply', post)"
          >
            <SkyIcon :icon="MessageCircle" :size="17" />
            <span v-if="post.reply_count">{{ post.reply_count }}</span>
          </SkyButton>
          <SkyButton
            variant="content"
            type="button"
            class="feather-action feather-action--like"
            :class="{
              'is-liked': post.is_liked,
              'is-pulsing': reactionPulse === 'like',
            }"
            @click.stop="react('like')"
          >
            <SkyIcon
              :icon="Heart"
              :size="17"
              :fill="post.is_liked ? 'currentColor' : 'none'"
            />
            <span v-if="post.like_count">{{ post.like_count }}</span>
          </SkyButton>
          <SkyButton
            variant="content"
            type="button"
            class="feather-action feather-action--bookmark"
            :class="{
              'is-bookmarked': post.is_bookmarked,
              'is-pulsing': reactionPulse === 'bookmark',
            }"
            @click.stop="react('bookmark')"
          >
            <SkyIcon
              :icon="Bookmark"
              :size="17"
              :fill="post.is_bookmarked ? 'currentColor' : 'none'"
            />
          </SkyButton>
          <SkyButton
            variant="content"
            type="button"
            @click.stop="$emit('share', post)"
          >
            <SkyIcon :icon="Share2" :size="17" />
          </SkyButton>
        </footer>
      </div>
    </article>
  </SkyGlass>
</template>

<style scoped>
.feather-post {
  display: flex;
  gap: 11px;
  padding: 11px 13px 8px;
  cursor: pointer;
}
.feather-post-glass {
  display: block;
  width: 100%;
  overflow: hidden;
  border-radius: 17px;
}
.feather-post:active {
  background: color-mix(in srgb, currentColor 4%, transparent);
}

.feather-avatar {
  display: grid;
  place-items: center;
  width: 42px;
  height: 42px;
  flex: 0 0 42px;
  overflow: hidden;
  border: 0;
  border-radius: 50%;
  color: #fff;
  background: linear-gradient(145deg, #72c9ff, #377be7);
}

.feather-avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.feather-post__body {
  min-width: 0;
  flex: 1;
}
.feather-post__header {
  display: flex;
  align-items: flex-start;
  gap: 3px;
  min-height: 32px;
}
.feather-post__author {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
  align-items: flex-start;
  border: 0;
  padding: 0;
  color: inherit;
  background: none;
  text-align: left;
}
.feather-post__name {
  display: flex;
  width: 100%;
  min-width: 0;
  align-items: center;
  gap: 3px;
}
.feather-post__name strong {
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  font-size: 13.5px;
  letter-spacing: -0.12px;
  white-space: nowrap;
}
.feather-post__meta {
  display: block;
  width: 100%;
  overflow: hidden;
  color: #71767b;
  font-size: 11.5px;
  line-height: 1.25;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.feather-verified {
  flex: none;
  color: #438cf5;
}
.feather-follow {
  --sky-app-accent: var(--feather-blue, #1d9bf0);
  --sky-app-accent-soft: color-mix(
    in srgb,
    var(--feather-blue, #1d9bf0) 14%,
    transparent
  );
  width: auto;
  min-width: 58px;
  max-width: 68px;
  flex: 0 0 auto;
  margin-left: auto;
  height: 25px;
  border-color: color-mix(
    in srgb,
    var(--feather-blue, #1d9bf0) 72%,
    transparent
  );
  padding-inline: 9px;
  color: var(--feather-blue, #1d9bf0);
  background: transparent;
  box-shadow: none;
  font-size: 10.5px;
  font-weight: 800;
  letter-spacing: 0.1px;
}
.feather-more {
  --sky-button-text: #71767b;
  --sky-app-accent: #71767b;
  --sky-app-accent-soft: color-mix(in srgb, currentColor 10%, transparent);
  flex: 0 0 auto;
  margin-left: 0;
  width: 27px;
  min-width: 27px;
  height: 27px;
  min-height: 27px;
  border: 1px solid color-mix(in srgb, currentColor 12%, transparent);
  padding: 0;
  color: var(--sky-button-text, #ffffff);
  background: color-mix(in srgb, currentColor 7%, transparent);
}
.feather-post__text {
  margin: 2px 0 8px;
  font-size: 13.5px;
  line-height: 1.42;
  white-space: pre-wrap;
  overflow-wrap: anywhere;
}
.feather-post__mention {
  color: var(--feather-blue, #1d9bf0);
  font-weight: 700;
}
.feather-post__more-text {
  border: 0;
  padding: 0;
  color: #1d9bf0;
  background: transparent;
  font: inherit;
}
.feather-media {
  display: grid;
  gap: 2px;
  max-height: 250px;
  margin: 7px 0 8px;
  overflow: hidden;
  border: 0.5px solid color-mix(in srgb, currentColor 12%, transparent);
  border-radius: 14px;
}
.feather-media__item {
  min-width: 0;
  min-height: 105px;
  overflow: hidden;
  border: 0;
  padding: 0;
  background: transparent;
  cursor: pointer;
}
.feather-media__item img {
  display: block;
  width: 100%;
  height: 100%;
  min-height: 105px;
  object-fit: cover;
}
.feather-media--2,
.feather-media--3,
.feather-media--4 {
  grid-template-columns: repeat(2, 1fr);
}
.feather-media--3 .feather-media__item:first-child {
  grid-row: span 2;
}
.feather-actions {
  display: flex;
  justify-content: space-between;
  margin-top: 1px;
  padding-right: 5px;
  color: #71767b;
}
.feather-actions button {
  position: relative;
  display: flex;
  align-items: center;
  gap: 4px;
  min-width: 34px;
  border: 0;
  padding: 6px 0 4px;
  color: inherit;
  background: none;
  font-size: 10.5px;
}
.feather-actions button:active {
  color: #438cf5;
}
.feather-actions .is-liked {
  color: #f04f87;
}
.feather-actions .is-bookmarked {
  color: #438cf5;
}
.feather-actions .feather-action.is-pulsing svg {
  animation: feather-reaction-pop 520ms cubic-bezier(0.22, 1.45, 0.36, 1) both;
}
.feather-actions .feather-action.is-pulsing::after {
  position: absolute;
  top: 50%;
  left: 8px;
  width: 24px;
  height: 24px;
  border: 2px solid currentColor;
  border-radius: 50%;
  content: '';
  pointer-events: none;
  animation: feather-reaction-ring 520ms ease-out both;
}
.feather-actions .feather-action--like.is-pulsing {
  color: #f04f87;
}
.feather-actions .feather-action--bookmark.is-pulsing {
  color: #438cf5;
}
@keyframes feather-reaction-pop {
  0% {
    transform: scale(0.78) rotate(-8deg);
  }
  48% {
    transform: scale(1.42) rotate(7deg);
  }
  72% {
    transform: scale(0.94) rotate(-2deg);
  }
  100% {
    transform: scale(1) rotate(0);
  }
}
@keyframes feather-reaction-ring {
  0% {
    opacity: 0.5;
    transform: translate(-50%, -50%) scale(0.35);
  }
  100% {
    opacity: 0;
    transform: translate(-50%, -50%) scale(1.65);
  }
}
@media (prefers-reduced-motion: reduce) {
  .feather-actions .feather-action.is-pulsing svg,
  .feather-actions .feather-action.is-pulsing::after {
    animation: none;
  }
}
@supports not (color: color-mix(in srgb, white, black)) {
  .feather-post:active {
    background: rgb(127 127 127 / 4%);
  }
  .feather-follow {
    border-color: var(--feather-blue, #1d9bf0);
  }
  .feather-media {
    border-color: rgb(127 127 127 / 18%);
  }
}
</style>
