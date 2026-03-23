<template>
  <div class="page-container">
    <el-card class="table-card">
      <template #header>
        <span>权限列表</span>
      </template>

      <el-tree
        :data="treeData"
        :props="{ label: 'name', children: 'children' }"
        node-key="id"
        default-expand-all
      >
        <template #default="{ node, data }">
          <span class="custom-tree-node">
            <span>
              <el-icon v-if="data.type === 'menu'"><Folder /></el-icon>
              <el-icon v-else-if="data.type === 'button'"><Operation /></el-icon>
              <el-icon v-else><Connection /></el-icon>
              {{ node.label }}
            </span>
            <span class="perm-code">{{ data.code }}</span>
            <el-tag size="small" :type="getTypeTag(data.type)">
              {{ getTypeName(data.type) }}
            </el-tag>
          </span>
        </template>
      </el-tree>
    </el-card>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { getPermissionList } from '../api/permission'

const treeData = ref([])

function getTypeName(type) {
  const map = {
    menu: '菜单',
    button: '按钮',
    api: 'API'
  }
  return map[type] || type
}

function getTypeTag(type) {
  const map = {
    menu: '',
    button: 'warning',
    api: 'info'
  }
  return map[type] || ''
}

async function loadData() {
  try {
    const res = await getPermissionList()
    treeData.value = res.data.permissions
  } catch (error) {
    console.error('加载数据失败:', error)
  }
}

onMounted(() => {
  loadData()
})
</script>

<style scoped>
.page-container {
  height: 100%;
}

.table-card {
  margin-bottom: 16px;
}

.custom-tree-node {
  display: flex;
  align-items: center;
  gap: 8px;
  width: 100%;
}

.perm-code {
  color: #909399;
  font-size: 12px;
  margin-left: auto;
  margin-right: 16px;
}
</style>
