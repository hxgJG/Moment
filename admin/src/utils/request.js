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

function isSuccessEnvelope(body) {
  return !!body && typeof body === 'object' && body.code === 200
}

function envelopeMessage(body) {
  if (!body || typeof body !== 'object') {
    return null
  }
  return body.msg || body.message || null
}

function unwrapEnvelopeData(body) {
  if (!isSuccessEnvelope(body) || !body.data || typeof body.data !== 'object') {
    return null
  }
  return body.data
}

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
  const data = unwrapEnvelopeData(body)
  if (!data?.token) {
    return null
  }
  const store = useAdminStore()
  store.setTokens(data.token, data.refresh_token)
  if (data.user) {
    store.setUser(data.user)
  }
  return data.token
}

function rejectQueuedRefreshWaiters(message) {
  refreshWaiters.splice(0).forEach(({ reject }) => {
    reject(new Error(message))
  })
}

async function retryWithRefreshedToken(config) {
  const rt = localStorage.getItem('admin_refresh_token')
  if (!rt) {
    clearAdminSession()
    router.push('/login')
    ElMessage.error('登录已过期，请重新登录')
    throw new Error('登录已过期')
  }

  if (refreshing) {
    return new Promise((resolve, reject) => {
      refreshWaiters.push({ resolve, reject, config })
    })
  }

  refreshing = true
  config._authRetry = true

  try {
    const newAccess = await tryRefreshAdminToken()
    if (!newAccess) {
      throw new Error('refresh failed')
    }

    const queued = refreshWaiters.splice(0, refreshWaiters.length)
    for (const waiter of queued) {
      waiter.config.headers = waiter.config.headers || {}
      waiter.config.headers.Authorization = `Bearer ${newAccess}`
    }

    config.headers = config.headers || {}
    config.headers.Authorization = `Bearer ${newAccess}`

    const waiterPromises = queued.map((waiter) =>
      request(waiter.config).then(waiter.resolve, waiter.reject)
    )
    const mainResult = await request(config)
    await Promise.all(waiterPromises)
    return mainResult
  } catch (error) {
    rejectQueuedRefreshWaiters('登录已过期')
    clearAdminSession()
    router.push('/login')
    ElMessage.error('登录已过期，请重新登录')
    throw error
  } finally {
    refreshing = false
  }
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
  (response) => {
    const res = response.data
    if (!isSuccessEnvelope(res)) {
      const message = envelopeMessage(res) || '请求失败'
      ElMessage.error(message)
      return Promise.reject(new Error(message))
    }
    return res
  },
  async (error) => {
    if (error.response) {
      const { status, data, config } = error.response
      if (status === 401) {
        if (!config?._authRetry && !isAdminAuthPath(config?.url)) {
          try {
            return await retryWithRefreshedToken(config)
          } catch (refreshError) {
            return Promise.reject(refreshError)
          }
        }
        clearAdminSession()
        router.push('/login')
        ElMessage.error(data?.msg || '登录已过期，请重新登录')
      } else if (status === 403) {
        ElMessage.error(data?.msg || '没有权限')
      } else if (status === 404) {
        ElMessage.error(data?.msg || '资源不存在')
      } else if (status >= 500) {
        ElMessage.error(data?.msg || '服务器错误')
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
