<script setup lang="ts">
import AppProfileAuth from '@/components/account/AppProfileAuth.vue'
import { usePhoneStore } from '@/stores/phone'

defineProps<{
  avatarUrl: string | null
  confirmPassword: string
  email: string
  error: string
  mode: 'login' | 'register'
  password: string
  pending: boolean
}>()
const emit = defineEmits<{
  camera: []
  gallery: []
  submit: []
  'update:confirmPassword': [value: string]
  'update:mode': [value: 'login' | 'register']
  'update:password': [value: string]
}>()

const phone = usePhoneStore()
</script>

<template>
  <AppProfileAuth
    class="citymarkt-auth"
    :style="{ '--auth-accent': phone.isDarkMode ? 'var(--yellow)' : '#866600' }"
    :avatar-url="avatarUrl"
    :body="
      phone.t(
        mode === 'login'
          ? 'Apps.citymarkt.authLoginBody'
          : 'Apps.citymarkt.authRegisterBody',
      )
    "
    :camera-label="phone.t('Apps.citymarkt.takePhoto')"
    :confirm-password="confirmPassword"
    :confirm-password-error="
      confirmPassword && confirmPassword !== password
        ? phone.t('Apps.citymarkt.passwordsMismatch')
        : false
    "
    :confirm-password-label="phone.t('Apps.citymarkt.authConfirmPassword')"
    :confirm-password-placeholder="phone.t('Apps.citymarkt.authConfirmPlaceholder')"
    :email="email"
    email-as-field
    :email-label="phone.t('Apps.citymarkt.profileEmail')"
    :error="error"
    :eyebrow="phone.t('Apps.citymarkt.authEyebrow')"
    :gallery-label="phone.t('Apps.citymarkt.chooseGallery')"
    :login-label="phone.t('Apps.citymarkt.login')"
    :mode="mode"
    :username="password"
    username-input-type="password"
    :username-autocomplete="
      mode === 'login' ? 'current-password' : 'new-password'
    "
    :username-label="phone.t('Apps.citymarkt.authPassword')"
    :username-placeholder="phone.t('Apps.citymarkt.authPasswordPlaceholder')"
    :username-help="
      mode === 'register' ? phone.t('Apps.citymarkt.authPasswordHelp') : ''
    "
    :min-username-length="6"
    :max-username-length="64"
    :show-confirm-password="mode === 'register'"
    :submit-enabled="
      Boolean(
        email &&
          password.length >= 6 &&
          password.length <= 64 &&
          (mode === 'login' || confirmPassword === password),
      )
    "
    :pending="pending"
    :register-label="phone.t('Apps.citymarkt.register')"
    :title="
      phone.t(
        mode === 'login'
          ? 'Apps.citymarkt.authLoginTitle'
          : 'Apps.citymarkt.authRegisterTitle',
      )
    "
    @camera="emit('camera')"
    @gallery="emit('gallery')"
    @submit="emit('submit')"
    @update:confirm-password="emit('update:confirmPassword', $event)"
    @update:mode="emit('update:mode', $event)"
    @update:username="emit('update:password', $event)"
  />
</template>

<style scoped>
.citymarkt-auth {
  --auth-accent: var(--yellow);
  --sky-segmented-active-text: #171816;
  --sky-app-accent: var(--yellow);
}
.citymarkt-auth :deep(.app-profile-auth__card) {
  display: grid;
  gap: 12px;
  padding: 14px;
}
.citymarkt-auth :deep(.app-profile-auth__mode) {
  height: 44px;
  min-height: 44px;
  margin: 0;
  gap: 4px;
  padding: 3px;
  border-radius: 15px;
}
.citymarkt-auth :deep(.app-profile-auth__mode-button) {
  height: 100%;
  min-height: 0;
  border-radius: 11px !important;
  transition:
    background-color 160ms ease,
    color 160ms ease,
    transform 160ms ease;
}
.citymarkt-auth
  :deep(.app-profile-auth__mode-button:not(.app-profile-auth__mode-button--active):hover) {
  background: #ffffff0d;
  color: #ffe06a;
}
.citymarkt-auth
  :deep(.app-profile-auth__mode-button:not(.app-profile-auth__mode-button--active):active) {
  transform: scale(0.98);
}
.citymarkt-auth
  :deep(.app-profile-auth__mode-button--active) {
  border-radius: 11px !important;
  color: #171816;
}
.citymarkt-auth :deep(.app-profile-auth__submit) {
  color: #171816 !important;
  background: var(--yellow) !important;
}
.citymarkt-auth :deep(.app-profile-auth__fields) {
  overflow: visible;
  background: transparent !important;
}
.citymarkt-auth :deep(.app-profile-auth__fields > .sky-list__items) {
  display: grid;
  gap: 9px;
}
.citymarkt-auth :deep(.app-profile-auth__fields .sky-field) {
  min-height: 60px;
  margin: 0;
  padding: 0 13px;
  border: 1px solid #ffffff1f;
  border-radius: 14px;
  background: #ffffff0a;
  color: inherit;
}
.citymarkt-auth :deep(.app-profile-auth__fields .sky-field:focus-within) {
  border-color: color-mix(in srgb, var(--yellow) 68%, transparent);
  background: #ffffff10;
}
.citymarkt-auth :deep(.app-profile-auth__fields .sky-field__border) {
  display: none;
}
.citymarkt-auth :deep(.app-profile-auth__fields .sky-field__media) {
  margin-right: 11px;
  padding: 0;
  color: var(--yellow);
}
.citymarkt-auth :deep(.app-profile-auth__fields .sky-field__inner) {
  padding: 8px 0;
}
.citymarkt-auth :deep(.app-profile-auth__fields .sky-field__label) {
  display: block;
  margin: 0;
  color: var(--muted);
  font-size: 10px;
  font-weight: 750;
  line-height: 14px;
}
.citymarkt-auth :deep(.app-profile-auth__fields .sky-field__label-text) {
  position: static;
  margin: 0;
  padding: 0;
  background: transparent;
}
.citymarkt-auth :deep(.app-profile-auth__fields .sky-field__control) {
  margin: 0;
}
.citymarkt-auth :deep(.app-profile-auth__fields .sky-field__input) {
  height: 28px;
  min-height: 28px;
  color: inherit;
  font-size: 14px;
  line-height: 20px;
}
.citymarkt-auth
  :deep(.app-profile-auth__email-field .sky-field__input) {
  color: var(--muted);
  font-weight: 650;
}
.citymarkt-auth :deep(.app-profile-auth__fields .sky-field__help),
.citymarkt-auth :deep(.app-profile-auth__fields .sky-field__error) {
  margin-top: 2px;
  font-size: 9px;
  line-height: 12px;
}
.citymarkt-auth :deep(.app-profile-auth__photo),
.citymarkt-auth :deep(.app-profile-auth__identity),
.citymarkt-auth :deep(.app-profile-auth__fields),
.citymarkt-auth :deep(.app-profile-auth__error) {
  margin: 0;
}
</style>
