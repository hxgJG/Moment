export const adminMenuItems = [
  {
    path: '/users',
    title: '用户管理',
    permission: 'system:user'
  },
  {
    path: '/moments',
    title: '时光管理',
    permission: 'moment:list'
  },
  {
    path: '/roles',
    title: '角色管理',
    permission: 'system:role'
  },
  {
    path: '/permissions',
    title: '权限管理',
    permission: 'system:permission'
  },
  {
    path: '/logs',
    title: '日志管理',
    permission: 'system:log'
  }
]

export function titleForAdminPath(path) {
  return adminMenuItems.find((item) => item.path === path)?.title || '管理后台'
}

export function firstAccessibleAdminPath(canAccess) {
  return adminMenuItems.find((item) => canAccess(item.permission))?.path || null
}
