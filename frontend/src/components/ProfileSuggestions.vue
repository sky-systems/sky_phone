<script setup lang="ts">
import { ChevronRight, Check } from 'lucide-vue-next'
import { SkyButton, SkyGlass, SkySpinner } from '@/ui'
import { usePhoneStore } from '@/stores/phone'
defineProps<{
  profiles: {
    id: string | number
    display_name: string
    handle: string
    avatar_url?: string | null
    verified?: boolean
  }[]
  search: string
  loading: boolean
  error: boolean
  isLive: (id: string | number) => boolean
}>()
const emit = defineEmits<{
  profile: [id: string | number]
  avatar: [id: string | number]
  retry: []
}>()
const phone = usePhoneStore()
</script>
<template>
  <section class="profile-suggestions" :aria-busy="loading">
    <h2>
      {{
        phone.t(search.trim() ? 'Realtime.people' : 'Realtime.suggestedPeople')
      }}
    </h2>
    <p v-if="loading" class="profile-suggestions__status">
      <SkySpinner :size="20" />{{ phone.t('Common.loading') }}
    </p>
    <SkyButton v-else-if="error" glass rounded @click="emit('retry')">{{
      phone.t('Realtime.retryPeople')
    }}</SkyButton>
    <p v-else-if="!profiles.length" class="profile-suggestions__status">
      {{
        phone.t(
          search.trim() ? 'Realtime.noPeopleFound' : 'Realtime.noPeopleYet',
        )
      }}
    </p>
    <SkyGlass v-else class="profile-suggestions__list">
      <div
        v-for="profile in profiles"
        :key="profile.id"
        class="profile-suggestions__row"
      >
        <SkyButton
          clear
          rounded
          icon-only
          class="profile-suggestions__avatar"
          :class="{ 'realtime-live-avatar': isLive(profile.id) }"
          :aria-label="
            isLive(profile.id)
              ? phone.t('Realtime.joinLive', { name: profile.display_name })
              : profile.display_name
          "
          @click="emit('avatar', profile.id)"
        >
          <img
            v-if="profile.avatar_url"
            :src="profile.avatar_url"
            alt=""
          /><span v-else>{{ profile.display_name.slice(0, 1) }}</span>
        </SkyButton>
        <SkyButton
          clear
          class="profile-suggestions__name"
          @click="emit('profile', profile.id)"
        >
          <span
            ><strong
              >{{ profile.display_name
              }}<Check v-if="profile.verified" :size="14" /></strong
            ><small>@{{ profile.handle }}</small></span
          ><ChevronRight :size="18" />
        </SkyButton>
      </div>
    </SkyGlass>
  </section>
</template>
<style scoped>
.profile-suggestions {
  padding: var(--sky-space-4) 0;
}
.profile-suggestions h2 {
  margin: 0 0 var(--sky-space-3);
  color: var(--sky-text);
  font-size: var(--sky-font-title);
  text-align: left;
}
.profile-suggestions__list {
  border-radius: var(--sky-radius-card);
  padding: var(--sky-space-2) var(--sky-space-3);
  background: var(--sky-glass);
}
.profile-suggestions__row {
  display: flex;
  align-items: center;
  gap: var(--sky-space-3);
  padding: var(--sky-space-2) 0;
}
.profile-suggestions__row + .profile-suggestions__row {
  border-top: 1px solid var(--sky-hairline);
}
.profile-suggestions__avatar {
  flex-shrink: 0;
  color: var(--sky-text);
  background: var(--sky-surface-variant);
}
.profile-suggestions__avatar img {
  width: 100%;
  height: 100%;
  border-radius: inherit;
  object-fit: cover;
}
.profile-suggestions__name.sky-button {
  flex: 1;
  display: flex;
  justify-content: space-between;
  height: auto;
  min-height: var(--sky-touch-target);
  min-width: 0;
  padding: 0;
  color: var(--sky-text);
  text-align: left;
}
.profile-suggestions__name span {
  display: grid;
  gap: var(--sky-space-1);
  min-width: 0;
}
.profile-suggestions__name strong {
  display: flex;
  align-items: center;
  gap: var(--sky-space-1);
  font-size: var(--sky-font-body);
  overflow: hidden;
  text-overflow: ellipsis;
}
.profile-suggestions__name small {
  color: var(--sky-muted);
  font-size: var(--sky-font-caption);
}
.profile-suggestions__status {
  display: flex;
  align-items: center;
  gap: var(--sky-space-2);
  color: var(--sky-muted);
  font-size: var(--sky-font-caption);
}
</style>
