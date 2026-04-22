<template>
  <el-container class="layout-container">
    <el-aside width="200px" class="sidebar">
      <div class="logo">
        <el-icon size="28" color="#409EFF"><AccessTime /></el-icon>
        <span>拾光记</span>
      </div>

      <el-menu
        :default-active="activeMenu"
        router
        class="sidebar-menu"
        background-color="#304156"
        text-color="#bfcbd9"
        active-text-color="#409EFF"
      >
        <el-menu-item
          v-for="item in visibleMenuItems"
          :key="item.path"
          :index="item.path"
        >
          <el-icon><component :is="iconMap[item.path]" /></el-icon>
          <span>{{ item.title }}</span>
        </el-menu-item>
      </el-menu>
    </el-aside>

    <el-container>
      <el-header class="header">
        <div class="header-left">
          <h2>{{ currentTitle }}</h2>
        </div>

        <div class="header-right">
          <el-dropdown @command="handleCommand">
            <span class="user-info">
              <el-icon><Avatar /></el-icon>
              {{ adminStore.user?.nickname || '管理员' }}
              <el-icon><ArrowDown /></el-icon>
            </span>
            <template #dropdown>
              <el-dropdown-menu>
                <el-dropdown-item command="logout">
                  <el-icon><SwitchButton /></el-icon>
                  退出登录
                </el-dropdown-item>
              </el-dropdown-menu>
            </template>
          </el-dropdown>
        </div>
      </el-header>

      <el-main class="main-content">
        <router-view />
      </el-main>
    </el-container>
  </el-container>
</template>

<script setup>
import { computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
import { useAdminStore } from '../stores/admin'
import { getAdminInfo } from '../api/login'
import {
  adminMenuItems,
  firstAccessibleAdminPath,
  titleForAdminPath
} from '../constants/admin-menu'

const route = useRoute()
const router = useRouter()
const adminStore = useAdminStore()

const activeMenu = computed(() => route.path)
const visibleMenuItems = computed(() =>
  adminMenuItems.filter((item) => adminStore.hasPermission(item.permission))
)
const iconMap = {
  '/users': 'User',
  '/moments': 'Clock',
  '/roles': 'Key',
  '/permissions': 'Grid',
  '/logs': 'Document'
}

const currentTitle = computed(() => titleForAdminPath(route.path))

function ensureRouteAccess() {
  const currentItem = adminMenuItems.find((item) => item.path === route.path)
  if (!currentItem || adminStore.hasPermission(currentItem.permission)) {
    return
  }
  const fallback = firstAccessibleAdminPath((permission) =>
    adminStore.hasPermission(permission)
  )
  if (!fallback) {
    ElMessage.warning('当前账号没有可访问的管理菜单')
    return
  }
  if (fallback !== route.path) {
    router.replace(fallback)
  }
}

async function hydrateAdminProfile() {
  if (!adminStore.token || adminStore.hasPermissionData) {
    return
  }
  try {
    const res = await getAdminInfo()
    adminStore.setUser(res.data)
    ensureRouteAccess()
  } catch (error) {
    console.error('加载管理员信息失败:', error)
  }
}

function handleCommand(command) {
  if (command === 'logout') {
    ElMessageBox.confirm('确定要退出登录吗？', '提示', {
      type: 'warning'
    }).then(() => {
      adminStore.logout()
      router.push('/login')
    }).catch(() => {})
  }
}

onMounted(() => {
  hydrateAdminProfile()
  ensureRouteAccess()
})

watch(
  () => route.path,
  () => {
    ensureRouteAccess()
  }
)
</script>

<style scoped>
.layout-container {
  height: 100vh;
}

.sidebar {
  background-color: #304156;
}

.logo {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 20px;
  color: white;
  font-size: 18px;
  font-weight: bold;
  border-bottom: 1px solid #3d4a5c;
}

.sidebar-menu {
  border-right: none;
}

.header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  background: white;
  border-bottom: 1px solid #e6e6e6;
  padding: 0 24px;
}

.header h2 {
  font-size: 18px;
  font-weight: 500;
  color: #333;
}

.user-info {
  display: flex;
  align-items: center;
  gap: 4px;
  cursor: pointer;
  padding: 8px 12px;
  border-radius: 4px;
}

.user-info:hover {
  background: #f5f7fa;
}

.main-content {
  background: #f5f7fa;
  padding: 20px;
}
</style>
