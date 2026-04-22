<template>
  <div class="page-container">
    <!-- 搜索栏 -->
    <el-card class="search-card">
      <el-form :inline="true" :model="searchForm">
        <el-form-item label="用户名">
          <el-input
            v-model="searchForm.username"
            placeholder="搜索用户名"
            clearable
            @keyup.enter="handleSearch"
          />
        </el-form-item>
        <el-form-item label="模块">
          <el-select v-model="searchForm.module" placeholder="请选择" clearable>
            <el-option label="用户管理" value="user" />
            <el-option label="角色管理" value="role" />
            <el-option label="权限管理" value="permission" />
            <el-option label="时光管理" value="moment" />
            <el-option label="系统" value="system" />
          </el-select>
        </el-form-item>
        <el-form-item label="时间范围">
          <el-date-picker
            v-model="dateRange"
            type="daterange"
            range-separator="至"
            start-placeholder="开始日期"
            end-placeholder="结束日期"
            value-format="YYYY-MM-DD"
          />
        </el-form-item>
        <el-form-item>
          <el-button type="primary" @click="handleSearch">搜索</el-button>
          <el-button @click="handleReset">重置</el-button>
        </el-form-item>
      </el-form>
    </el-card>

    <!-- 表格 -->
    <el-card class="table-card">
      <el-table :data="tableData" v-loading="loading" stripe>
        <el-table-column prop="id" label="ID" width="80" />
        <el-table-column prop="username" label="操作用户" width="120" />
        <el-table-column prop="module" label="模块" width="100">
          <template #default="{ row }">
            <el-tag size="small">{{ getModuleLabel(row.module) }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="action" label="动作" width="100" />
        <el-table-column prop="method" label="请求方法" width="100">
          <template #default="{ row }">
            <el-tag
              size="small"
              :type="getMethodType(row.method)"
            >
              {{ row.method }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="path" label="请求路径" show-overflow-tooltip />
        <el-table-column prop="ip" label="IP地址" width="140" />
        <el-table-column prop="status" label="状态" width="80">
          <template #default="{ row }">
            <el-tag :type="row.status === 200 ? 'success' : 'danger'" size="small">
              {{ row.status }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="duration" label="耗时(ms)" width="100" />
        <el-table-column prop="created_at" label="操作时间" width="180" />
        <el-table-column label="操作" width="90" fixed="right">
          <template #default="{ row }">
            <el-button type="primary" link @click="openDetail(row)">详情</el-button>
          </template>
        </el-table-column>
      </el-table>

      <el-pagination
        v-model:current-page="pagination.page"
        v-model:page-size="pagination.pageSize"
        :total="pagination.total"
        :page-sizes="[10, 20, 50, 100]"
        layout="total, sizes, prev, pager, next, jumper"
        class="pagination"
        @size-change="loadData"
        @current-change="loadData"
      />
    </el-card>

    <el-drawer
      v-model="drawerVisible"
      title="日志详情"
      size="520px"
      destroy-on-close
    >
      <template v-if="detailRow">
        <p class="detail-meta">用户：{{ detailRow.username || '-' }}</p>
        <p class="detail-meta">
          模块：{{ getModuleLabel(detailRow.module) }} · 动作：{{ detailRow.action }}
        </p>
        <p class="detail-meta">
          请求：{{ detailRow.method }} {{ detailRow.path }}
        </p>
        <p class="detail-meta">
          状态：{{ detailRow.status }} · 耗时：{{ detailRow.duration }} ms
        </p>
        <p class="detail-meta">IP：{{ detailRow.ip || '-' }}</p>
        <p class="detail-meta">时间：{{ detailRow.created_at }}</p>

        <el-divider content-position="left">请求参数</el-divider>
        <pre class="detail-block">{{ formatParams(detailRow.params) }}</pre>
      </template>
    </el-drawer>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted } from 'vue'
import { getOperationLogList } from '../api/log'

const loading = ref(false)
const tableData = ref([])
const dateRange = ref([])
const drawerVisible = ref(false)
const detailRow = ref(null)

const searchForm = reactive({
  username: '',
  module: ''
})

const pagination = reactive({
  page: 1,
  pageSize: 10,
  total: 0
})

function getMethodType(method) {
  const map = {
    GET: '',
    POST: 'success',
    PUT: 'warning',
    DELETE: 'danger',
    PATCH: 'info'
  }
  return map[method] || ''
}

function getModuleLabel(module) {
  const map = {
    user: '用户管理',
    role: '角色管理',
    permission: '权限管理',
    moment: '时光管理',
    system: '系统'
  }
  return map[module] || module || '-'
}

function openDetail(row) {
  detailRow.value = row
  drawerVisible.value = true
}

function formatParams(raw) {
  if (!raw) {
    return '无'
  }

  try {
    const parsed = JSON.parse(raw)
    if (Array.isArray(parsed) && parsed.length === 0) {
      return '无'
    }
    return JSON.stringify(parsed, null, 2)
  } catch (_) {
    return raw
  }
}

async function loadData() {
  loading.value = true
  try {
    const params = {
      page: pagination.page,
      page_size: pagination.pageSize
    }
    if (searchForm.username) {
      params.username = searchForm.username
    }
    if (searchForm.module) {
      params.module = searchForm.module
    }
    if (dateRange.value && dateRange.value.length === 2) {
      params.start_date = dateRange.value[0]
      params.end_date = dateRange.value[1]
    }

    const res = await getOperationLogList(params)
    tableData.value = res.data.logs
    pagination.total = res.data.total
  } catch (error) {
    console.error('加载数据失败:', error)
  } finally {
    loading.value = false
  }
}

function handleSearch() {
  pagination.page = 1
  loadData()
}

function handleReset() {
  searchForm.username = ''
  searchForm.module = ''
  dateRange.value = []
  pagination.page = 1
  loadData()
}

onMounted(() => {
  loadData()
})
</script>

<style scoped>
.page-container {
  height: 100%;
}

.search-card {
  margin-bottom: 16px;
}

.table-card {
  margin-bottom: 16px;
}

.pagination {
  margin-top: 16px;
  justify-content: flex-end;
}

.detail-meta {
  margin: 0 0 10px;
  color: #606266;
  line-height: 1.6;
}

.detail-block {
  margin: 0;
  padding: 12px;
  background: #f6f8fa;
  border-radius: 8px;
  white-space: pre-wrap;
  word-break: break-word;
  font-size: 13px;
  line-height: 1.5;
  color: #303133;
}
</style>
