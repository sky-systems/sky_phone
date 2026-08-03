import { createRouter, createWebHashHistory } from 'vue-router'

import { isPhoneAppId } from '@/config/apps'
import PhoneAppWindow from '@/views/PhoneAppWindow.vue'
import SpringboardView from '@/views/SpringboardView.vue'

export default createRouter({
  history: createWebHashHistory(),
  routes: [
    {
      component: SpringboardView,
      name: 'home',
      path: '/',
    },
    {
      beforeEnter: (to) =>
        typeof to.params.appId === 'string' && isPhoneAppId(to.params.appId)
          ? true
          : '/',
      component: PhoneAppWindow,
      name: 'app',
      path: '/apps/:appId',
    },
  ],
})
