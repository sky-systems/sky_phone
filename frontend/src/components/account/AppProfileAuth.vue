<script setup lang="ts">
import {
  ArrowRight,
  Camera,
  Images,
  LockKeyhole,
  Mail,
  UserRound,
} from 'lucide-vue-next'
import {
  SkyButton,
  SkyField,
  SkyGlass,
  SkyList,
  SkySegmented,
  SkySegmentedButton,
  SkySpinner,
} from '@/ui'
import { computed } from 'vue'

const props = withDefaults(
  defineProps<{
    avatarUrl: string | null
    body: string
    cameraLabel: string
    email: string
    emailAsField?: boolean
    emailLabel: string
    error: string
    eyebrow: string
    galleryLabel: string
    loginLabel: string
    loginModeLabel?: string
    maxUsernameLength?: number
    minUsernameLength?: number
    mode: 'login' | 'register'
    movingModeHighlight?: boolean
    password?: string
    passwordLabel?: string
    passwordPlaceholder?: string
    pending: boolean
    registerLabel: string
    registerModeLabel?: string
    requirePassword?: boolean
    submitEnabled?: boolean
    title: string
    username: string
    usernameAutocomplete?: string
    usernameHelp?: string
    usernameInputType?: 'password' | 'text'
    usernameLabel: string
    usernamePlaceholder?: string
    variant?: 'default' | 'centered'
    confirmPassword?: string
    confirmPasswordError?: boolean | string
    confirmPasswordLabel?: string
    confirmPasswordPlaceholder?: string
    showConfirmPassword?: boolean
  }>(),
  {
    confirmPassword: '',
    confirmPasswordError: false,
    confirmPasswordLabel: '',
    confirmPasswordPlaceholder: '',
    emailAsField: false,
    maxUsernameLength: 40,
    minUsernameLength: 2,
    loginModeLabel: '',
    movingModeHighlight: false,
    password: '',
    passwordLabel: 'Password',
    passwordPlaceholder: '',
    requirePassword: false,
    registerModeLabel: '',
    showConfirmPassword: false,
    submitEnabled: undefined,
    usernameAutocomplete: 'username',
    usernameHelp: '',
    usernameInputType: 'text',
    usernamePlaceholder: '',
    variant: 'default',
  },
)
const emit = defineEmits<{
  camera: []
  gallery: []
  submit: []
  'update:confirmPassword': [value: string]
  'update:mode': [value: 'login' | 'register']
  'update:password': [value: string]
  'update:username': [value: string]
}>()

const canSubmit = computed(() => {
  const length = props.username.trim().length
  const validUsername =
    length >= props.minUsernameLength && length <= props.maxUsernameLength
  return (
    props.submitEnabled ??
    Boolean(
      props.email &&
        (props.mode === 'login' && props.requirePassword
          ? true
          : validUsername) &&
        (!props.requirePassword ||
          (props.password.length >= 8 && props.password.length <= 72)),
    )
  )
})
const modeLoginLabel = computed(() => props.loginModeLabel || props.loginLabel)
const modeRegisterLabel = computed(
  () => props.registerModeLabel || props.registerLabel,
)
</script>

<template>
  <section
    class="app-profile-auth"
    :class="{ 'app-profile-auth--centered': variant === 'centered' }"
  >
    <header class="app-profile-auth__hero">
      <span class="app-profile-auth__mark"><UserRound :size="23" /></span>
      <div>
        <small>{{ eyebrow }}</small>
        <h2>{{ title }}</h2>
      </div>
      <p>{{ body }}</p>
    </header>

    <SkyGlass class="app-profile-auth__card">
      <SkySegmented
        :active-index="movingModeHighlight ? (mode === 'login' ? 0 : 1) : undefined"
        :aria-label="eyebrow"
        :item-count="movingModeHighlight ? 2 : undefined"
        raised
        :rounded="movingModeHighlight"
        :strong="movingModeHighlight"
        class="app-profile-auth__mode"
        :class="{
          'app-profile-auth__mode--moving-highlight': movingModeHighlight,
          'app-profile-auth__mode--register': mode === 'register',
        }"
      >
        <SkySegmentedButton
          class="app-profile-auth__mode-button app-profile-auth__mode-button--login"
          :class="{
            'app-profile-auth__mode-button--active': mode === 'login',
          }"
          :active="mode === 'login'"
          @click="emit('update:mode', 'login')"
        >
          {{ modeLoginLabel }}
        </SkySegmentedButton>
        <SkySegmentedButton
          class="app-profile-auth__mode-button app-profile-auth__mode-button--register"
          :class="{
            'app-profile-auth__mode-button--active': mode === 'register',
          }"
          :active="mode === 'register'"
          @click="emit('update:mode', 'register')"
        >
          {{ modeRegisterLabel }}
        </SkySegmentedButton>
      </SkySegmented>

      <div v-if="mode === 'register'" class="app-profile-auth__photo">
        <span class="app-profile-auth__avatar">
          <img v-if="avatarUrl" :src="avatarUrl" alt="" />
          <UserRound v-else :size="28" />
          <i><Camera :size="11" /></i>
        </span>
        <div>
          <SkyButton rounded outline @click="emit('gallery')">
            <Images :size="15" />{{ galleryLabel }}
          </SkyButton>
          <SkyButton rounded outline @click="emit('camera')">
            <Camera :size="15" />{{ cameraLabel }}
          </SkyButton>
        </div>
      </div>

      <div v-if="!emailAsField" class="app-profile-auth__identity">
        <span><Mail :size="17" /></span>
        <div>
          <small>{{ emailLabel }}</small>
          <strong>{{ email }}</strong>
        </div>
        <LockKeyhole :size="15" />
      </div>

      <SkyList inset strong class="app-profile-auth__fields">
        <SkyField
          v-if="emailAsField"
          class="app-profile-auth__email-field"
          input-id="app-profile-auth-email"
          :label="emailLabel"
          :value="email"
          type="email"
          autocomplete="email"
          inputmode="email"
          readonly
          outline
        >
          <template #leading><Mail :size="17" /></template>
          <template #trailing><LockKeyhole :size="15" /></template>
        </SkyField>
        <SkyField
          v-if="variant !== 'centered' || mode === 'register' || !requirePassword"
          class="app-profile-auth__credential-field"
          input-id="app-profile-auth-username"
          :label="usernameLabel"
          :value="username"
          :maxlength="maxUsernameLength"
          :minlength="minUsernameLength"
          :placeholder="usernamePlaceholder"
          :help="usernameHelp"
          :type="usernameInputType"
          :autocomplete="usernameAutocomplete"
          autocapitalize="none"
          autocorrect="off"
          spellcheck="false"
          outline
          @input="
            emit('update:username', ($event.target as HTMLInputElement).value)
          "
          @keydown.enter="emit('submit')"
        >
          <template v-if="usernameInputType === 'password'" #leading>
            <LockKeyhole :size="17" />
          </template>
        </SkyField>
        <SkyField
          v-if="requirePassword"
          class="app-profile-auth__credential-field"
          input-id="app-profile-auth-password"
          :label="passwordLabel"
          :value="password"
          type="password"
          maxlength="72"
          minlength="8"
          :placeholder="passwordPlaceholder"
          :autocomplete="
            mode === 'login' ? 'current-password' : 'new-password'
          "
          autocapitalize="none"
          autocorrect="off"
          spellcheck="false"
          outline
          @input="
            emit('update:password', ($event.target as HTMLInputElement).value)
          "
          @keydown.enter="emit('submit')"
        >
          <template #leading><LockKeyhole :size="17" /></template>
        </SkyField>
        <SkyField
          v-if="showConfirmPassword"
          class="app-profile-auth__credential-field"
          input-id="app-profile-auth-confirm-password"
          :label="confirmPasswordLabel"
          :value="confirmPassword"
          type="password"
          :maxlength="maxUsernameLength"
          :minlength="minUsernameLength"
          :placeholder="confirmPasswordPlaceholder"
          :error="confirmPasswordError"
          autocomplete="new-password"
          autocapitalize="none"
          autocorrect="off"
          spellcheck="false"
          outline
          @input="
            emit(
              'update:confirmPassword',
              ($event.target as HTMLInputElement).value,
            )
          "
          @keydown.enter="emit('submit')"
        >
          <template #leading><LockKeyhole :size="17" /></template>
        </SkyField>
      </SkyList>

      <div v-if="error" class="app-profile-auth__error" role="alert">
        {{ error }}
      </div>
      <SkyButton
        large
        rounded
        class="app-profile-auth__submit"
        :disabled="!canSubmit || pending"
        @click="emit('submit')"
      >
        <SkySpinner v-if="pending" />
        <template v-else>
          <span>{{ mode === 'login' ? loginLabel : registerLabel }}</span>
          <ArrowRight :size="18" />
        </template>
      </SkyButton>
    </SkyGlass>
  </section>
</template>

<style scoped>
.app-profile-auth {
  width: 100%;
  max-width: 320px;
  margin: 0 auto;
  padding: 12px 4px 18px;
  color: inherit;
  text-align: center;
}
.app-profile-auth__hero {
  position: relative;
  z-index: 1;
  display: grid;
  grid-template-columns: 46px minmax(0, 1fr);
  gap: 0 11px;
  margin: 0 12px 14px;
  text-align: left;
}
.app-profile-auth__mark {
  display: grid;
  width: 46px;
  height: 46px;
  grid-row: 1 / span 2;
  place-items: center;
  border: 1px solid rgba(255, 214, 62, 0.46);
  border-color: color-mix(
    in srgb,
    var(--auth-accent, #ffd63e) 46%,
    transparent
  );
  border-radius: 15px;
  color: var(--auth-accent, var(--yellow, #ffd63e));
  background: rgba(255, 214, 62, 0.14);
  background: color-mix(in srgb, var(--auth-accent, #ffd63e) 14%, transparent);
  box-shadow: 0 10px 28px rgba(255, 214, 62, 0.16);
  box-shadow: 0 10px 28px
    color-mix(in srgb, var(--auth-accent, #ffd63e) 16%, transparent);
}
.app-profile-auth__hero small {
  color: var(--auth-accent, var(--yellow, #ffd63e));
  font-size: 9px;
  font-weight: 850;
  letter-spacing: 0.1em;
  text-transform: uppercase;
}
.app-profile-auth__hero h2 {
  margin: 3px 0 0;
  color: inherit;
  font-size: 20px;
  line-height: 1.08;
}
.app-profile-auth__hero p {
  grid-column: 2;
  margin: 6px 0 0;
  color: var(--muted, #9ba4aa);
  font-size: 11px;
  line-height: 1.35;
}
.app-profile-auth__card {
  position: relative;
  display: block;
  padding: 12px;
  overflow: hidden;
  border: 1px solid rgba(255, 255, 255, 0.1);
  border-radius: 24px;
  background: var(--panel, #20262c);
  background: color-mix(in srgb, var(--panel, #20262c) 90%, transparent);
  box-shadow: 0 22px 50px rgba(0, 0, 0, 0.2);
  backdrop-filter: blur(22px) saturate(1.15);
}
.app-profile-auth__card::before {
  position: absolute;
  top: -80px;
  right: -55px;
  width: 170px;
  height: 150px;
  border-radius: 50%;
  background: rgba(255, 214, 62, 0.16);
  background: color-mix(in srgb, var(--auth-accent, #ffd63e) 16%, transparent);
  filter: blur(38px);
  content: '';
  pointer-events: none;
}
.app-profile-auth__mode {
  position: relative;
  z-index: 1;
  margin: 0 0 12px;
}
.app-profile-auth__mode:not(.app-profile-auth__mode--moving-highlight) {
  padding: 3px;
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 14px;
  background: rgba(0, 0, 0, 0.16);
}
.app-profile-auth__mode:not(.app-profile-auth__mode--moving-highlight)
  :deep(.app-profile-auth__mode-button) {
  border-radius: 3px;
}
.app-profile-auth__mode:not(.app-profile-auth__mode--moving-highlight)
  :deep(
    .app-profile-auth__mode-button--login.app-profile-auth__mode-button--active
  ) {
  border-radius: 10px 3px 3px 10px;
}
.app-profile-auth__mode:not(.app-profile-auth__mode--moving-highlight)
  :deep(
    .app-profile-auth__mode-button--register.app-profile-auth__mode-button--active
  ) {
  border-radius: 3px 10px 10px 3px;
}
.app-profile-auth__photo {
  display: flex;
  align-items: center;
  gap: 12px;
  margin: 0 2px 11px;
  padding: 8px;
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 18px;
  background: rgba(255, 255, 255, 0.035);
  text-align: left;
}
.app-profile-auth__avatar {
  position: relative;
  display: grid;
  width: 66px;
  height: 66px;
  aspect-ratio: 1;
  flex: none;
  place-items: center;
  border: 2px solid rgba(255, 214, 62, 0.58);
  border-color: color-mix(
    in srgb,
    var(--auth-accent, #ffd63e) 58%,
    transparent
  );
  border-radius: 50%;
  color: var(--auth-accent, var(--yellow, #ffd63e));
  background: var(--panel, #20262c);
  background: color-mix(
    in srgb,
    var(--auth-accent, #ffd63e) 10%,
    var(--panel, #20262c)
  );
  box-shadow: 0 8px 22px rgba(0, 0, 0, 0.22);
}
.app-profile-auth__photo img {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  object-fit: cover;
  border-radius: inherit;
}
.app-profile-auth__avatar i {
  position: absolute;
  right: -2px;
  bottom: -1px;
  display: grid;
  width: 22px;
  height: 22px;
  place-items: center;
  border: 2px solid var(--panel, #20262c);
  border-radius: 50%;
  color: #fff;
  background: var(--auth-accent, #ffd63e);
  z-index: 1;
}
.app-profile-auth__photo > div {
  display: grid;
  min-width: 0;
  flex: 1;
  gap: 6px;
}
.app-profile-auth__photo :deep(.sky-button) {
  min-height: 32px;
  justify-content: flex-start;
  gap: 6px;
  border-color: rgba(255, 255, 255, 0.12);
  color: inherit;
  background: rgba(255, 255, 255, 0.04);
  font-size: 11px;
}
.app-profile-auth__identity {
  position: relative;
  display: grid;
  grid-template-columns: 34px minmax(0, 1fr) 18px;
  align-items: center;
  gap: 9px;
  margin-bottom: 9px;
  padding: 9px 11px;
  border: 1px solid rgba(255, 255, 255, 0.09);
  border-radius: 15px;
  background: rgba(255, 255, 255, 0.045);
  text-align: left;
}
.app-profile-auth__identity > span {
  display: grid;
  width: 34px;
  height: 34px;
  place-items: center;
  border-radius: 11px;
  color: var(--auth-accent, #ffd63e);
  background: rgba(255, 214, 62, 0.13);
  background: color-mix(in srgb, var(--auth-accent, #ffd63e) 13%, transparent);
}
.app-profile-auth__identity div {
  min-width: 0;
}
.app-profile-auth__identity small {
  display: block;
  margin-bottom: 1px;
  color: var(--muted, #9ba4aa);
  font-size: 9px;
}
.app-profile-auth__identity strong {
  display: block;
  overflow: hidden;
  font-size: 12px;
  font-weight: 700;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.app-profile-auth__identity > svg {
  color: var(--muted, #9ba4aa);
}
.app-profile-auth__username-field {
  display: grid;
  grid-template-columns: 34px minmax(0, 1fr);
  align-items: center;
  gap: 9px;
  margin-bottom: 11px;
  padding: 9px 11px;
  border: 1px solid rgba(255, 255, 255, 0.09);
  border-radius: 15px;
  background: rgba(255, 255, 255, 0.045);
  text-align: left;
}
.app-profile-auth__password-field {
  display: grid;
  grid-template-columns: 34px minmax(0, 1fr);
  align-items: center;
  gap: 9px;
  margin-bottom: 11px;
  padding: 9px 11px;
  border: 1px solid rgba(255, 255, 255, 0.09);
  border-radius: 15px;
  background: rgba(255, 255, 255, 0.045);
  text-align: left;
}
.app-profile-auth__password-field > span {
  display: grid;
  width: 34px;
  height: 34px;
  place-items: center;
  border-radius: 11px;
  color: var(--auth-accent, #ffd63e);
  background: color-mix(in srgb, var(--auth-accent, #ffd63e) 13%, transparent);
}
.app-profile-auth__password-field div {
  min-width: 0;
}
.app-profile-auth__password-field small {
  display: block;
  margin-bottom: 1px;
  color: var(--muted, #9ba4aa);
  font-size: 9px;
}
.app-profile-auth__password-field input {
  box-sizing: border-box;
  width: 100%;
  min-width: 0;
  padding: 0;
  border: 0;
  outline: 0;
  color: inherit;
  background: transparent;
  font: inherit;
  font-size: 12px;
  font-weight: 700;
  line-height: 18px;
}
.app-profile-auth__password-field input::placeholder {
  color: var(--muted, #9ba4aa);
  opacity: 0.72;
}
.app-profile-auth__username-field > span {
  display: grid;
  width: 34px;
  height: 34px;
  place-items: center;
  border-radius: 11px;
  color: var(--auth-accent, #ffd63e);
  background: color-mix(in srgb, var(--auth-accent, #ffd63e) 13%, transparent);
}
.app-profile-auth__username-field div {
  min-width: 0;
}
.app-profile-auth__username-field small {
  display: block;
  margin-bottom: 1px;
  color: var(--muted, #9ba4aa);
  font-size: 9px;
}
.app-profile-auth__username-field input {
  box-sizing: border-box;
  width: 100%;
  min-width: 0;
  padding: 0;
  border: 0;
  outline: 0;
  color: inherit;
  background: transparent;
  font: inherit;
  font-size: 12px;
  font-weight: 700;
  line-height: 18px;
}
.app-profile-auth__username-field input::placeholder {
  color: var(--muted, #9ba4aa);
  opacity: 0.72;
}
.app-profile-auth__fields {
  margin-top: 0;
  margin-right: 0;
  margin-bottom: 11px;
  margin-left: 0;
  color: inherit;
  background: rgba(255, 255, 255, 0.045) !important;
  text-align: left;
}
.app-profile-auth__fields :deep(.text-black) {
  color: inherit !important;
}
.app-profile-auth__fields :deep(.text-xs > div) {
  background: var(--panel, #20262c) !important;
  background: color-mix(
    in srgb,
    var(--panel, #20262c) 94%,
    transparent
  ) !important;
}
.app-profile-auth__error {
  margin: -2px 1px 10px;
  padding: 8px 10px;
  border: 1px solid rgba(255, 105, 97, 0.22);
  border-radius: 11px;
  color: #ff6961;
  background: rgba(255, 105, 97, 0.08);
  font-size: 11px;
}
.app-profile-auth__submit {
  --sky-app-accent: var(--auth-accent, var(--yellow, #ffd63e));
  --sky-button-text: #fff;
  width: 100%;
  min-height: 44px;
  display: flex;
  justify-content: space-between;
  padding: 0 17px;
  color: #fff !important;
  background: var(--auth-accent, var(--yellow, #ffd63e)) !important;
  box-shadow: 0 10px 26px rgba(255, 214, 62, 0.25);
  box-shadow: 0 10px 26px
    color-mix(in srgb, var(--auth-accent, #ffd63e) 25%, transparent);
  font-weight: 750;
}
.app-profile-auth__submit:disabled {
  opacity: 0.46;
}
.app-profile-auth--centered {
  max-width: 340px;
  padding: 0;
}
.app-profile-auth--centered .app-profile-auth__hero {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 7px;
  margin: 0 18px 18px;
  text-align: center;
}
.app-profile-auth--centered .app-profile-auth__mark {
  width: 54px;
  height: 54px;
  margin-bottom: 3px;
  border-radius: 18px;
}
.app-profile-auth--centered .app-profile-auth__hero h2 {
  margin: 0;
  font-size: 24px;
}
.app-profile-auth--centered .app-profile-auth__hero p {
  max-width: 285px;
  margin: 0;
  font-size: 12px;
  line-height: 1.45;
}
.app-profile-auth--centered .app-profile-auth__card {
  box-sizing: border-box;
  width: 100%;
  margin-inline: auto;
  padding: 14px;
  border-radius: 28px;
}
.app-profile-auth--centered
  .app-profile-auth__mode:not(.app-profile-auth__mode--moving-highlight) {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 4px;
  padding: 4px;
  border-radius: 15px;
}
.app-profile-auth__mode-choice {
  min-width: 0;
  min-height: 40px;
  padding: 0 12px;
  border: 0;
  border-radius: 11px;
  display: grid;
  place-items: center;
  color: #b8c5ce;
  background: transparent;
  font: inherit;
  font-size: 14px;
  font-weight: 650;
  line-height: 1;
  cursor: pointer;
  transition:
    color 160ms ease,
    background 160ms ease,
    box-shadow 160ms ease;
}
.app-profile-auth__mode-choice--active {
  color: #fff;
  background: var(--auth-accent, #ffd63e);
  box-shadow: 0 6px 16px
    color-mix(in srgb, var(--auth-accent, #ffd63e) 28%, transparent);
  font-weight: 750;
}
.app-profile-auth--centered .app-profile-auth__identity,
.app-profile-auth--centered .app-profile-auth__username-field,
.app-profile-auth--centered .app-profile-auth__password-field {
  grid-template-columns: 38px minmax(0, 1fr) 18px;
  min-height: 58px;
  margin-bottom: 10px;
  padding: 8px 12px;
  border-radius: 17px;
}
.app-profile-auth--centered .app-profile-auth__username-field {
  grid-template-columns: 38px minmax(0, 1fr);
}
.app-profile-auth--centered .app-profile-auth__password-field {
  grid-template-columns: 38px minmax(0, 1fr);
}
.app-profile-auth--centered .app-profile-auth__identity > span,
.app-profile-auth--centered .app-profile-auth__username-field > span,
.app-profile-auth--centered .app-profile-auth__password-field > span {
  width: 38px;
  height: 38px;
  border-radius: 12px;
}
.app-profile-auth--centered .app-profile-auth__identity small,
.app-profile-auth--centered .app-profile-auth__username-field small,
.app-profile-auth--centered .app-profile-auth__password-field small {
  font-size: 10px;
}
.app-profile-auth--centered .app-profile-auth__identity strong,
.app-profile-auth--centered .app-profile-auth__username-field input,
.app-profile-auth--centered .app-profile-auth__password-field input {
  font-size: 14px;
  line-height: 20px;
}
.app-profile-auth--centered .app-profile-auth__submit {
  min-height: 48px;
  border-radius: 16px;
}
</style>
