<script setup lang="ts">
import { Camera, CircleArrowUp } from 'lucide-vue-next'
import { computed, nextTick, onMounted, ref } from 'vue'

import {
  SkyIcon,
  SkyLink,
  SkyMessage,
  SkyMessagebar,
  SkyMessages,
  SkyMessagesTitle,
  SkyToolbarPane,
} from '@/ui'

import blueNinjaAvatar from '../assets/people-100x100-7.jpg'
import kateAvatar from '../assets/people-100x100-9.jpg'
import SkyUiDemoPage from '../SkyUiDemoPage.vue'

interface DemoMessage {
  avatar?: string
  name?: string
  text: string
  type: 'received' | 'sent'
}

const messageText = ref('')
const messagesEnd = ref<HTMLElement | null>(null)
const messagesData = ref<DemoMessage[]>([
  { text: 'Hi, Kate', type: 'sent' },
  { text: 'How are you?', type: 'sent' },
  {
    avatar: kateAvatar,
    name: 'Kate',
    text: 'Hi, I am good!',
    type: 'received',
  },
  {
    avatar: blueNinjaAvatar,
    name: 'Blue Ninja',
    text: 'Hi there, I am also fine, thanks! And how are you?',
    type: 'received',
  },
  { text: 'Hey, Blue Ninja! Glad to see you ;)', type: 'sent' },
  {
    text: 'How do you feel about going to the movies today?',
    type: 'sent',
  },
  {
    avatar: kateAvatar,
    name: 'Kate',
    text: 'Oh, great idea!',
    type: 'received',
  },
  {
    avatar: kateAvatar,
    name: 'Kate',
    text: 'What cinema are we going to?',
    type: 'received',
  },
  {
    avatar: blueNinjaAvatar,
    name: 'Blue Ninja',
    text: 'Great. And what movie?',
    type: 'received',
  },
  {
    avatar: blueNinjaAvatar,
    name: 'Blue Ninja',
    text: 'What time?',
    type: 'received',
  },
])

const canSend = computed(() => messageText.value.trim().length > 0)
const currentDate = new Date()
const currentDay = new Intl.DateTimeFormat('en-US', {
  day: 'numeric',
  month: 'short',
  weekday: 'long',
}).format(currentDate)
const currentTime = new Intl.DateTimeFormat('en-US', {
  hour: '2-digit',
  hour12: false,
  minute: '2-digit',
}).format(currentDate)

function scrollToBottom(animate = true): void {
  const scrollArea = messagesEnd.value?.closest('.sky-scroll-area')
  if (!(scrollArea instanceof HTMLElement)) return

  scrollArea.scrollTo({
    top: scrollArea.scrollHeight - scrollArea.clientHeight,
    behavior: animate ? 'smooth' : 'auto',
  })
}

async function sendMessage(): Promise<void> {
  const text = messageText.value.trim()
  if (!text) return

  messagesData.value.push({ text, type: 'sent' })
  messageText.value = ''
  await nextTick()
  scrollToBottom()
}

function handleMessageKeydown(event: KeyboardEvent): void {
  if (
    event.key !== 'Enter' ||
    event.shiftKey ||
    event.isComposing ||
    !canSend.value
  ) {
    return
  }

  event.preventDefault()
  void sendMessage()
}

function messageLines(text: string): string[] {
  return text.split('\n')
}

onMounted(async () => {
  await nextTick()
  scrollToBottom(false)
})
</script>

<template>
  <SkyUiDemoPage title="Messages">
    <SkyMessages>
      <SkyMessagesTitle
        ><b>{{ currentDay }}</b
        >, {{ currentTime }}</SkyMessagesTitle
      >
      <SkyMessage
        v-for="(message, index) in messagesData"
        :key="`${index}-${message.text}`"
        :name="message.name"
        :text="message.text"
        :type="message.type"
      >
        <template #text>
          <template
            v-for="(line, lineIndex) in messageLines(message.text)"
            :key="`${lineIndex}-${line}`"
          >
            {{ line
            }}<br v-if="lineIndex < messageLines(message.text).length - 1" />
          </template>
        </template>
        <template v-if="message.type === 'received'" #avatar>
          <img
            class="sky-ui-demo-messages__avatar"
            :src="message.avatar"
            alt=""
          />
        </template>
      </SkyMessage>
    </SkyMessages>
    <span
      ref="messagesEnd"
      class="sky-ui-demo-messages__end"
      aria-hidden="true"
    />

    <template #fixed>
      <SkyMessagebar
        v-model="messageText"
        aria-label="Message"
        class="sky-ui-demo-messages__bar"
        placeholder="Message"
        @keydown="handleMessageKeydown"
      >
        <template #left>
          <SkyToolbarPane>
            <SkyLink
              aria-label="Open camera"
              component="button"
              icon-only
              type="button"
            >
              <SkyIcon :size="20"><Camera /></SkyIcon>
            </SkyLink>
          </SkyToolbarPane>
        </template>
        <template #right>
          <SkyToolbarPane>
            <SkyLink
              aria-label="Send message"
              component="button"
              :disabled="!canSend"
              icon-only
              type="button"
              :style="{ opacity: canSend ? 1 : 0.3 }"
              @click="sendMessage"
            >
              <SkyIcon :size="28"><CircleArrowUp /></SkyIcon>
            </SkyLink>
          </SkyToolbarPane>
        </template>
      </SkyMessagebar>
    </template>
  </SkyUiDemoPage>
</template>

<style scoped>
.sky-ui-demo-messages__avatar {
  width: 32px;
  height: 32px;
  display: block;
  border-radius: 50%;
  object-fit: cover;
}

.sky-ui-demo-messages__end {
  width: 1px;
  height: 36px;
  display: block;
}

.sky-ui-demo-messages__bar {
  position: absolute;
  z-index: 20;
  right: 0;
  bottom: 0;
  left: 0;
}
</style>
