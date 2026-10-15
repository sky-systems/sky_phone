import { createPinia } from 'pinia'
import { createApp } from 'vue'

import App from './App.vue'
import router from './router'
import { initializeSkyGraphics } from './ui/graphics'
import './assets/main.css'
import './ui/tokens.css'
import './ui/foundation.css'
import './ui/controls.css'
import './ui/settings.css'
import './ui/overlays.css'

initializeSkyGraphics()
createApp(App).use(createPinia()).use(router).mount('#app')
