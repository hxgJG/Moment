import request from '../utils/request'

// 获取权限列表
export function getPermissionList() {
  return request({
    url: '/admin/permissions',
    method: 'get'
  })
}
