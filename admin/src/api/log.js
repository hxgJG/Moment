import request from '../utils/request'

// 获取操作日志列表
export function getOperationLogList(params) {
  return request({
    url: '/admin/logs',
    method: 'get',
    params
  })
}
