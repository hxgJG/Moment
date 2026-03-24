import { defineStore } from 'pinia'
import { ref } from 'vue'

export const useAdminStore = defineStore('admin', () => {
  const token = ref(localStorage.getItem('admin_token') || '')
  const refreshToken = ref(localStorage.getItem('admin_refresh_token') || '')
  const user = ref(JSON.parse(localStorage.getItem('admin_user') || 'null'))

  function setToken(newToken) {
    token.value = newToken
    localStorage.setItem('admin_token', newToken)
  }

  function setRefreshToken(newRefresh) {
    refreshToken.value = newRefresh || ''
    if (newRefresh) {
      localStorage.setItem('admin_refresh_token', newRefresh)
    } else {
      localStorage.removeItem('admin_refresh_token')
    }
  }

  function setTokens(access, refresh) {
    setToken(access)
    setRefreshToken(refresh)
  }

  function setUser(newUser) {
    user.value = newUser
    localStorage.setItem('admin_user', JSON.stringify(newUser))
  }

  function logout() {
    token.value = ''
    refreshToken.value = ''
    user.value = null
    localStorage.removeItem('admin_token')
    localStorage.removeItem('admin_refresh_token')
    localStorage.removeItem('admin_user')
  }

  return {
    token,
    refreshToken,
    user,
    setToken,
    setRefreshToken,
    setTokens,
    setUser,
    logout
  }
})
