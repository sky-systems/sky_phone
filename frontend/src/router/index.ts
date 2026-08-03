import { createRouter, createWebHashHistory } from 'vue-router'

import PhoneHomeView from '@/views/PhoneHomeView.vue'

export default createRouter({
  history: createWebHashHistory(),
  routes: [
    {
      component: PhoneHomeView,
      path: '/',
    },
  ],
})
