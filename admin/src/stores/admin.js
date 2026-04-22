import { defineStore } from 'pinia'
import { computed, ref } from 'vue'

export const useAdminStore = defineStore('admin', () => {
  const token = ref(localStorage.getItem('admin_token') || '')
  const refreshToken = ref(localStorage.getItem('admin_refresh_token') || '')
  const user = ref(JSON.parse(localStorage.getItem('admin_user') || 'null'))
  const permissionCodes = computed(() => {
    if (!Array.isArray(user.value?.permission_codes)) {
      return []
    }
    return user.value.permission_codes
  })
  const hasPermissionData = computed(() => Array.isArray(user.value?.permission_codes))

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

  function hasPermission(code) {
    if (!code) {
      return true
    }
    if (!hasPermissionData.value) {
      return true
    }
    return permissionCodes.value.includes(code)
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
    permissionCodes,
    hasPermissionData,
    setToken,
    setRefreshToken,
    setTokens,
    setUser,
    hasPermission,
    logout
  }
})
