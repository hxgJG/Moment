import { createRouter, createWebHistory } from 'vue-router'
import { useAdminStore } from '../stores/admin'
import { firstAccessibleAdminPath } from '../constants/admin-menu'

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
        meta: { title: '用户管理', permission: 'system:user' }
      },
      {
        path: 'roles',
        name: 'Roles',
        component: () => import('../pages/roles.vue'),
        meta: { title: '角色管理', permission: 'system:role' }
      },
      {
        path: 'permissions',
        name: 'Permissions',
        component: () => import('../pages/permissions.vue'),
        meta: { title: '权限管理', permission: 'system:permission' }
      },
      {
        path: 'logs',
        name: 'Logs',
        component: () => import('../pages/logs.vue'),
        meta: { title: '日志管理', permission: 'system:log' }
      },
      {
        path: 'moments',
        name: 'Moments',
        component: () => import('../pages/moments.vue'),
        meta: { title: '时光管理', permission: 'moment:list' }
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
  const requiredPermission = to.meta?.permission

  if (to.path !== '/login' && !adminStore.token) {
    next('/login')
  } else if (to.path === '/login' && adminStore.token) {
    next('/')
  } else if (
    requiredPermission &&
    adminStore.hasPermissionData &&
    !adminStore.hasPermission(requiredPermission)
  ) {
    const fallback = firstAccessibleAdminPath((permission) =>
      adminStore.hasPermission(permission)
    )
    next(fallback && fallback !== to.path ? fallback : false)
  } else {
    next()
  }
})

export default router
