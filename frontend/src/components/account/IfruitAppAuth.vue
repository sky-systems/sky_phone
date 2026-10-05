<script setup lang="ts">
import {
  SkyButton as kButton,
  SkyField as kListInput,
  SkyList as kList,
  SkySegmented as kSegmented,
  SkySegmentedButton as kSegmentedButton,
  SkySpinner as kPreloader,
} from '@/ui'
import { computed, ref } from 'vue'

import { useAccountStore } from '@/stores/account'
import { useAppAuthStore, type AppAuthId } from '@/stores/app-auth'
import { usePhoneStore } from '@/stores/phone'
import {
  filterMailAddressInput,
  MAIL_ADDRESS_INPUT_MAX_LENGTH,
  normalizeMailAddress,
} from '@/utils/mail'

const props = defineProps<{
  appId: AppAuthId
  appName: string
}>()
const emit = defineEmits<{ signedIn: [] }>()

const account = useAccountStore()
const appAuth = useAppAuthStore()
const phone = usePhoneStore()
const mode = ref<'login' | 'register'>('login')
const email = ref(account.email)
const password = ref('')
const confirm = ref('')
const pending = ref(false)
const error = ref('')

const canSubmit = computed(() => {
  const normalized = normalizeMailAddress(email.value, phone.mailDomain)
  const passwordValid =
    password.value.length >= 6 && password.value.length <= 64
  return Boolean(
    normalized &&
      passwordValid &&
      (mode.value === 'login' ||
        (confirm.value && confirm.value === password.value)),
  )
})

function setMode(next: 'login' | 'register'): void {
  mode.value = next
  confirm.value = ''
  error.value = ''
}

function updateEmail(event: Event): void {
  email.value = filterMailAddressInput((event.target as HTMLInputElement).value)
}

function errorMessage(key?: string): string {
  const known = [
    'invalid_email',
    'invalid_password',
    'invalid_credentials',
    'email_taken',
    'rate_limited',
  ]
  return phone.t(
    `Common.appAuth.errors.${key && known.includes(key) ? key : 'default'}`,
  )
}

async function submit(): Promise<void> {
  if (!canSubmit.value || pending.value) return
  const normalized = normalizeMailAddress(email.value, phone.mailDomain)
  if (!normalized) return

  pending.value = true
  error.value = ''
  const response =
    mode.value === 'login'
      ? await account.login(normalized, password.value)
      : await account.register(normalized, password.value)
  pending.value = false
  if (!response.success || !response.data) {
    error.value = errorMessage(response.error)
    return
  }

  appAuth.signIn(props.appId, response.data.email)
  password.value = ''
  confirm.value = ''
  emit('signedIn')
}
</script>

<template>
  <section class="ifruit-app-auth">
    <small>{{ phone.t('Common.appAuth.eyebrow') }}</small>
    <h2>{{ phone.t('Common.appAuth.title', { app: appName }) }}</h2>
    <p>{{ phone.t('Common.appAuth.body', { app: appName }) }}</p>

    <k-segmented raised class="ifruit-app-auth__mode">
      <k-segmented-button :active="mode === 'login'" @click="setMode('login')">
        {{ phone.t('Common.appAuth.login') }}
      </k-segmented-button>
      <k-segmented-button
        :active="mode === 'register'"
        @click="setMode('register')"
      >
        {{ phone.t('Common.appAuth.register') }}
      </k-segmented-button>
    </k-segmented>

    <k-list inset strong class="ifruit-app-auth__fields">
      <k-list-input
        input-id="ifruit-app-auth-email"
        :label="phone.t('Common.appAuth.email')"
        :value="email"
        :maxlength="MAIL_ADDRESS_INPUT_MAX_LENGTH"
        autocomplete="username"
        inputmode="email"
        outline
        @input="updateEmail"
      />
      <k-list-input
        input-id="ifruit-app-auth-password"
        :label="phone.t('Common.appAuth.password')"
        :value="password"
        type="password"
        maxlength="64"
        :autocomplete="mode === 'login' ? 'current-password' : 'new-password'"
        outline
        @input="password = ($event.target as HTMLInputElement).value"
      />
      <k-list-input
        v-if="mode === 'register'"
        input-id="ifruit-app-auth-confirm"
        :label="phone.t('Common.appAuth.confirm')"
        :value="confirm"
        type="password"
        maxlength="64"
        autocomplete="new-password"
        outline
        @input="confirm = ($event.target as HTMLInputElement).value"
      />
    </k-list>

    <p v-if="error" class="ifruit-app-auth__error" role="alert">{{ error }}</p>
    <k-button large rounded :disabled="!canSubmit || pending" @click="submit">
      <k-preloader v-if="pending" />
      <template v-else>
        {{
          phone.t(
            mode === 'login'
              ? 'Common.appAuth.loginAction'
              : 'Common.appAuth.registerAction',
          )
        }}
      </template>
    </k-button>
  </section>
</template>

<style scoped>
.ifruit-app-auth {
  width: 100%;
  max-width: 310px;
  margin: auto;
  padding: 18px 10px;
  text-align: center;
}
.ifruit-app-auth > small {
  color: var(--sky-app-accent);
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}
.ifruit-app-auth h2 {
  margin: 6px 0 4px;
  font-size: 21px;
}
.ifruit-app-auth > p {
  margin: 0 auto 14px;
  color: #8e8e93;
  font-size: 12px;
  line-height: 1.4;
}
.ifruit-app-auth__mode {
  margin: 0 8px 12px;
}
.ifruit-app-auth__fields {
  margin-top: 0;
  margin-bottom: 12px;
  text-align: left;
}
.ifruit-app-auth .ifruit-app-auth__error {
  margin: -4px 12px 10px;
  color: #ff453a;
  font-size: 11px;
}
</style>
