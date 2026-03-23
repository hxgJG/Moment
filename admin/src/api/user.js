import request from '../utils/request'

// 获取用户列表
export function getUserList(params) {
  return request({
    url: '/admin/users',
    method: 'get',
    params
  })
}

// 创建用户
export function createUser(data) {
  return request({
    url: '/admin/users',
    method: 'post',
    data
  })
}

// 更新用户
export function updateUser(id, data) {
  return request({
    url: `/admin/users/${id}`,
    method: 'put',
    data
  })
}

// 删除用户
export function deleteUser(id) {
  return request({
    url: `/admin/users/${id}`,
    method: 'delete'
  })
}

// 切换用户状态
export function toggleUserStatus(id) {
  return request({
    url: `/admin/users/${id}/toggle-status`,
    method: 'patch'
  })
}

// 分配用户角色
export function assignUserRoles(id, data) {
  return request({
    url: `/admin/users/${id}/roles`,
    method: 'put',
    data
  })
}
