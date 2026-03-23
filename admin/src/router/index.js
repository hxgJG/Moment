import { createRouter, createWebHistory } from 'vue-router'
import { useAdminStore } from '../stores/admin'

const routes = [
  {
    path: '/login',
    name: 'Login',
    component: () => import('../pages/login.vue'),
    meta: { title: '登录' }
  },
  {
    path: '/',
    component: () => import('../layouts/main.vue'),
    redirect: '/users',
    children: [
      {
        path: 'users',
        name: 'Users',
        component: () => import('../pages/users.vue'),
        meta: { title: '用户管理' }
      },
      {
        path: 'roles',
        name: 'Roles',
        component: () => import('../pages/roles.vue'),
        meta: { title: '角色管理' }
      },
      {
        path: 'permissions',
        name: 'Permissions',
        component: () => import('../pages/permissions.vue'),
        meta: { title: '权限管理' }
      },
      {
        path: 'logs',
        name: 'Logs',
        component: () => import('../pages/logs.vue'),
        meta: { title: '日志管理' }
      }
    ]
  }
]

const router = createRouter({
  history: createWebHistory(),
  routes
})

// 路由守卫
router.beforeEach((to, from, next) => {
  const adminStore = useAdminStore()

  if (to.path !== '/login' && !adminStore.token) {
    next('/login')
  } else if (to.path === '/login' && adminStore.token) {
    next('/')
  } else {
    next()
  }
})

export default router
