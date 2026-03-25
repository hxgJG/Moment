import request from '../utils/request'

/** 管理端：查询指定用户的时光列表 */
export function getUserMoments(userId, params) {
  return request({
    url: `/admin/users/${userId}/moments`,
    method: 'get',
    params
  })
}
