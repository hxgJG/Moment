import request from '../utils/request'

// 获取角色列表
export function getRoleList() {
  return request({
    url: '/admin/roles',
    method: 'get'
  })
}

// 创建角色
export function createRole(data) {
  return request({
    url: '/admin/roles',
    method: 'post',
    data
  })
}

// 更新角色
export function updateRole(id, data) {
  return request({
    url: `/admin/roles/${id}`,
    method: 'put',
    data
  })
}

// 删除角色
export function deleteRole(id) {
  return request({
    url: `/admin/roles/${id}`,
    method: 'delete'
  })
}

// 分配角色权限
export function assignRolePermissions(id, data) {
  return request({
    url: `/admin/roles/${id}/permissions`,
    method: 'put',
    data
  })
}
