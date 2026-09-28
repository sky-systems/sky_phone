<script setup lang="ts">
import { computed, reactive, ref } from 'vue'

import { SkyBlock, SkyBlockTitle, SkyField, SkyKeyCapture, SkyList } from '@/ui'
import {
  KEYBOARD_MAPPING_KEYS,
  keyboardMappingFromEvent,
} from '@/utils/keyboardMapping'

import SkyUiDemoPage from '../SkyUiDemoPage.vue'
import demoIcon from '../assets/demo-icon.png'

type DemoFieldType =
  | 'date'
  | 'datetime-local'
  | 'email'
  | 'password'
  | 'select'
  | 'tel'
  | 'text'
  | 'textarea'
  | 'url'

interface DemoField {
  key: string
  label: string
  options?: readonly { label: string; value: string }[]
  placeholder: string
  type: DemoFieldType
}

const genderOptions = [
  { label: 'Male', value: 'Male' },
  { label: 'Female', value: 'Female' },
] as const

const defaultFields: readonly DemoField[] = [
  { key: 'name', label: 'Name', placeholder: 'Your name', type: 'text' },
  {
    key: 'password',
    label: 'Password',
    placeholder: 'Your password',
    type: 'password',
  },
  {
    key: 'email',
    label: 'E-mail',
    placeholder: 'Your e-mail',
    type: 'email',
  },
  { key: 'url', label: 'URL', placeholder: 'URL', type: 'url' },
  {
    key: 'phone',
    label: 'Phone',
    placeholder: 'Your phone number',
    type: 'tel',
  },
  {
    key: 'gender',
    label: 'Gender',
    options: genderOptions,
    placeholder: 'Please choose...',
    type: 'select',
  },
  {
    key: 'birthday',
    label: 'Birthday',
    placeholder: 'Please choose...',
    type: 'date',
  },
  {
    key: 'datetime',
    label: 'Date time',
    placeholder: 'Please choose...',
    type: 'datetime-local',
  },
  {
    key: 'textarea',
    label: 'Textarea',
    placeholder: 'Bio',
    type: 'textarea',
  },
]

const floatingFields = defaultFields.slice(0, 5)
const shortFields = defaultFields.slice(0, 4)

function initialValues(): Record<string, string> {
  return {
    birthday: '2014-04-30',
    datetime: '',
    email: '',
    gender: 'Male',
    name: '',
    password: '',
    phone: '',
    textarea: '',
    url: '',
  }
}

const defaultValues = reactive(initialValues())
const outlineValues = reactive(initialValues())
const floatingValues = reactive(initialValues())
const floatingOutlineValues = reactive(initialValues())
const iconValues = reactive(initialValues())
const labelValues = reactive(initialValues())
const inputValues = reactive(initialValues())
const infoValues = reactive(initialValues())
const name = ref('')
const nameChanged = ref(false)
const demoValue = ref('')
const keyboardKey = ref('F1')
const keyboardOptions = KEYBOARD_MAPPING_KEYS.map((value) => ({
  value,
  label: value,
}))
const nameError = computed(() =>
  nameChanged.value && !name.value.trim() ? 'Please specify your name' : '',
)
</script>

<template>
  <SkyUiDemoPage title="Form Inputs">
    <SkyBlockTitle>Keyboard capture</SkyBlockTitle>
    <SkyBlock>
      <SkyKeyCapture
        v-model="keyboardKey"
        label="Keyboard key"
        :options="keyboardOptions"
        :resolve-key="keyboardMappingFromEvent"
        :labels="{
          capture: 'Record key',
          listening: 'Press one key. Escape cancels; Tab leaves capture.',
          cancel: 'Cancel capture',
          unsupported: 'Choose one supported keyboard key.',
        }"
      />
    </SkyBlock>
    <SkyBlockTitle>Default</SkyBlockTitle>
    <SkyList inset strong>
      <SkyField
        v-for="field in defaultFields"
        :key="field.key"
        v-model="defaultValues[field.key]"
        :input-style="
          field.type === 'textarea'
            ? { height: '80px', resize: 'none' }
            : undefined
        "
        :label="field.label"
        :dropdown="field.type === 'select'"
        :options="field.options"
        :placeholder="field.placeholder"
        :type="field.type"
      >
        <template #media>
          <img class="form-inputs-demo__icon" :src="demoIcon" alt="icon" />
        </template>
      </SkyField>
    </SkyList>

    <SkyBlockTitle>Outline</SkyBlockTitle>
    <SkyList inset strong>
      <SkyField
        v-for="field in defaultFields"
        :key="field.key"
        v-model="outlineValues[field.key]"
        :input-style="
          field.type === 'textarea'
            ? { height: '80px', resize: 'none' }
            : undefined
        "
        :label="field.label"
        :dropdown="field.type === 'select'"
        :options="field.options"
        outline
        :placeholder="field.placeholder"
        :type="field.type"
      >
        <template #media>
          <img class="form-inputs-demo__icon" :src="demoIcon" alt="icon" />
        </template>
      </SkyField>
    </SkyList>

    <SkyBlockTitle>Floating Labels</SkyBlockTitle>
    <SkyList inset strong>
      <SkyField
        v-for="field in floatingFields"
        :key="field.key"
        v-model="floatingValues[field.key]"
        floating-label
        :label="field.label"
        :placeholder="field.placeholder"
        :type="field.type"
      >
        <template #media>
          <img class="form-inputs-demo__icon" :src="demoIcon" alt="icon" />
        </template>
      </SkyField>
    </SkyList>

    <SkyBlockTitle>Outline + Floating Labels</SkyBlockTitle>
    <SkyList inset strong>
      <SkyField
        v-for="field in floatingFields"
        :key="field.key"
        v-model="floatingOutlineValues[field.key]"
        floating-label
        :label="field.label"
        outline
        :placeholder="field.placeholder"
        :type="field.type"
      >
        <template #media>
          <img class="form-inputs-demo__icon" :src="demoIcon" alt="icon" />
        </template>
      </SkyField>
    </SkyList>

    <SkyBlockTitle>Validation + Additional Info</SkyBlockTitle>
    <SkyList inset strong>
      <SkyField
        v-model="name"
        :error="nameError"
        info="Basic string checking"
        label="Name"
        placeholder="Your name"
        type="text"
        @input="nameChanged = true"
      >
        <template #media>
          <img class="form-inputs-demo__icon" :src="demoIcon" alt="icon" />
        </template>
      </SkyField>
    </SkyList>

    <SkyBlockTitle>Clear Button</SkyBlockTitle>
    <SkyList inset strong>
      <SkyField
        v-model="demoValue"
        :clear-button="demoValue.length > 0"
        clear-label="Clear TV show"
        info="Type something to see clear button"
        label="TV Show"
        placeholder="Your favorite TV show"
        type="text"
      >
        <template #media>
          <img class="form-inputs-demo__icon" :src="demoIcon" alt="icon" />
        </template>
      </SkyField>
    </SkyList>

    <SkyBlockTitle>Icon + Input</SkyBlockTitle>
    <SkyList inset strong>
      <SkyField
        v-for="field in shortFields"
        :key="field.key"
        v-model="iconValues[field.key]"
        :aria-label="field.label"
        :placeholder="field.placeholder"
        :type="field.type"
      >
        <template #media>
          <img class="form-inputs-demo__icon" :src="demoIcon" alt="icon" />
        </template>
      </SkyField>
    </SkyList>

    <SkyBlockTitle>Label + Input</SkyBlockTitle>
    <SkyList inset strong>
      <SkyField
        v-for="field in shortFields"
        :key="field.key"
        v-model="labelValues[field.key]"
        :label="field.label"
        :placeholder="field.placeholder"
        :type="field.type"
      />
    </SkyList>

    <SkyBlockTitle>Only Inputs</SkyBlockTitle>
    <SkyList inset strong>
      <SkyField
        v-for="field in shortFields"
        :key="field.key"
        v-model="inputValues[field.key]"
        :aria-label="field.label"
        :placeholder="field.placeholder"
        :type="field.type"
      />
    </SkyList>

    <SkyBlockTitle>Inputs + Additional Info</SkyBlockTitle>
    <SkyList inset strong>
      <SkyField
        v-for="(field, index) in shortFields"
        :key="field.key"
        v-model="infoValues[field.key]"
        :aria-label="field.label"
        :info="
          [
            'Full name please',
            '8 characters minimum',
            'Your work e-mail address',
            'Your website URL',
          ][index]
        "
        :placeholder="field.placeholder"
        :type="field.type"
      />
    </SkyList>
  </SkyUiDemoPage>
</template>

<style scoped>
.form-inputs-demo__icon {
  width: 28px;
  height: 28px;
  display: block;
}
</style>
