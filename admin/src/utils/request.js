import axios from 'axios'
import { ElMessage } from 'element-plus'
import router from '../router'
import { useAdminStore } from '../stores/admin'

const request = axios.create({
  baseURL: '/api/v1',
  timeout: 30000
})

const refreshClient = axios.create({
  baseURL: '/api/v1',
  timeout: 30000,
  headers: { 'Content-Type': 'application/json' }
})

let refreshing = false
const refreshWaiters = []

function isAdminAuthPath(url) {
  return url && (url.includes('/admin/login') || url.includes('/admin/refresh'))
}

function clearAdminSession() {
  const store = useAdminStore()
  store.logout()
}

async function tryRefreshAdminToken() {
  const rt = localStorage.getItem('admin_refresh_token')
  if (!rt) {
    return null
  }
  const { data: body } = await refreshClient.post('/admin/refresh', {
    refresh_token: rt
  })
  if (body.code !== 200 || !body.data?.token) {
    return null
  }
  const store = useAdminStore()
  store.setTokens(body.data.token, body.data.refresh_token)
  if (body.data.user) {
    store.setUser(body.data.user)
  }
  return body.data.token
}

// 请求拦截器
request.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('admin_token')
    if (token) {
      config.headers.Authorization = `Bearer ${token}`
    }
    return config
  },
  (error) => {
    return Promise.reject(error)
  }
)

// 响应拦截器
request.interceptors.response.use(
  async (response) => {
    const res = response.data
    const cfg = response.config

    if (res.code === 401 && !cfg._authRetry && !isAdminAuthPath(cfg.url)) {
      const rt = localStorage.getItem('admin_refresh_token')
      if (!rt) {
        ElMessage.error(res.msg || '登录已过期，请重新登录')
        clearAdminSession()
        router.push('/login')
        return Promise.reject(new Error(res.msg || '未登录'))
      }

      if (refreshing) {
        return new Promise((resolve, reject) => {
          refreshWaiters.push({ resolve, reject, config: cfg })
        })
      }

      refreshing = true
      cfg._authRetry = true

      try {
        const newAccess = await tryRefreshAdminToken()
        if (!newAccess) {
          throw new Error('refresh failed')
        }
        const queued = refreshWaiters.splice(0, refreshWaiters.length)
        for (const q of queued) {
          q.config.headers.Authorization = `Bearer ${newAccess}`
        }
        cfg.headers.Authorization = `Bearer ${newAccess}`
        const waiterPromises = queued.map((q) =>
          request(q.config).then(q.resolve, q.reject)
        )
        const mainResult = await request(cfg)
        await Promise.all(waiterPromises)
        return mainResult
      } catch {
        refreshWaiters.splice(0).forEach(({ reject }) => {
          reject(new Error('登录已过期'))
        })
        ElMessage.error('登录已过期，请重新登录')
        clearAdminSession()
        router.push('/login')
        return Promise.reject(new Error('登录已过期'))
      } finally {
        refreshing = false
      }
    }

    if (res.code !== 200) {
      ElMessage.error(res.msg || '请求失败')
      return Promise.reject(new Error(res.msg || '请求失败'))
    }
    return res
  },
  (error) => {
    if (error.response) {
      const { status, data } = error.response
      if (status === 401) {
        clearAdminSession()
        router.push('/login')
        ElMessage.error('登录已过期，请重新登录')
      } else if (status === 403) {
        ElMessage.error('没有权限')
      } else if (status === 404) {
        ElMessage.error('资源不存在')
      } else if (status >= 500) {
        ElMessage.error('服务器错误')
      } else {
        ElMessage.error(data?.msg || '请求失败')
      }
    } else {
      ElMessage.error('网络错误')
    }
    return Promise.reject(error)
  }
)

export default request
