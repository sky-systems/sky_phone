<script setup lang="ts">
import { SkyIcon } from '@/ui'

import {
  Check,
  ChevronRight,
  MessageCircle,
  UserRound,
  UserPlus,
} from 'lucide-vue-next'
import { computed, ref, watch } from 'vue'

import type { SmsSharedContact } from '@/types/messages'
import { SkyButton } from '@/ui'

const props = defineProps<{
  addLabel: string
  contact: SmsSharedContact
  messageLabel: string
  saved: boolean
  savedLabel: string
}>()
const emit = defineEmits<{ message: []; save: [] }>()
const imageFailed = ref(false)
watch(
  () => props.contact.avatar_url,
  () => {
    imageFailed.value = false
  },
)
const displayName = computed(
  () => props.contact.name.trim() || props.contact.phone_number,
)
const showNumber = computed(() => Boolean(props.contact.name.trim()))
const initials = computed(() =>
  displayName.value
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase())
    .join(''),
)
</script>

<template>
  <div class="message-contact-card">
    <div class="message-contact-card__identity">
      <span class="message-contact-card__avatar">
        <img
          v-if="contact.avatar_url && !imageFailed"
          :src="contact.avatar_url"
          alt=""
          @error="imageFailed = true"
        />
        <b v-else-if="initials">{{ initials }}</b>
        <SkyIcon :icon="UserRound" v-else :size="28" />
      </span>
      <div>
        <strong>{{ displayName }}</strong>
        <small v-if="contact.organization">{{ contact.organization }}</small>
        <small v-if="showNumber">({{ contact.phone_number }})</small>
      </div>
      <SkyIcon
        :icon="ChevronRight"
        :size="20"
        class="message-contact-card__chevron"
      />
    </div>
    <div class="message-contact-card__actions">
      <SkyButton rounded small tonal @click.stop="emit('message')">
        <SkyIcon :icon="MessageCircle" :size="17" />
        {{ messageLabel }}
      </SkyButton>
      <SkyButton
        rounded
        small
        tonal
        :disabled="saved"
        @click.stop="emit('save')"
      >
        <SkyIcon :icon="Check" v-if="saved" :size="17" />
        <SkyIcon :icon="UserPlus" v-else :size="17" />
        {{ saved ? savedLabel : addLabel }}
      </SkyButton>
    </div>
  </div>
</template>

<style scoped>
.message-contact-card {
  width: min(258px, 100%);
  width: min(258px, 72cqw);
  overflow: hidden;
  border: 1px solid var(--sky-hairline);
  border-radius: 21px;
  color: var(--sky-text);
  background: linear-gradient(
    155deg,
    var(--sky-surface-tint),
    var(--sky-surface)
  );
  box-shadow: 0 8px 24px rgb(0 0 0 / 16%);
}

.message-contact-card__identity {
  display: grid;
  grid-template-columns: 58px minmax(0, 1fr) 20px;
  align-items: center;
  gap: 11px;
  min-height: 82px;
  padding: 13px 12px;
}

.message-contact-card__avatar {
  width: 58px;
  height: 58px;
  overflow: hidden;
  border-radius: 50%;
  display: grid;
  place-items: center;
  color: #ffffff;
  background: linear-gradient(145deg, var(--sky-success), #248a3d);
  box-shadow: 0 4px 14px rgb(52 199 89 / 24%);
}

.message-contact-card__avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.message-contact-card__identity b {
  font-size: 18px;
}

.message-contact-card__identity div,
.message-contact-card__identity strong,
.message-contact-card__identity small {
  min-width: 0;
}

.message-contact-card__identity strong,
.message-contact-card__identity small {
  display: block;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.message-contact-card__identity strong {
  font-size: 16px;
  line-height: 1.2;
}

.message-contact-card__identity small {
  margin-top: 3px;
  color: var(--sky-muted);
  font-size: 11.5px;
}

.message-contact-card__chevron {
  color: var(--sky-muted);
}

.message-contact-card__actions {
  display: grid;
  gap: 1px;
  padding: 8px;
  border-top: 1px solid var(--sky-hairline);
  background: var(--sky-surface-muted);
}

.message-contact-card__actions :deep(.sky-button) {
  width: 100%;
  margin: 0;
  min-height: 36px;
  justify-content: flex-start;
  padding-inline: 14px;
  font-size: 13px;
}
</style>
