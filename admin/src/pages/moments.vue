<template>
  <div class="page-container">
    <el-alert
      type="info"
      show-icon
      :closable="false"
      class="page-tip"
      title="说明"
      description="本页展示的是服务端数据库中的时光。仅「用户 ID」为必填；其它条件不填表示不按该维度过滤（默认：全部类型、不限时间、不搜关键词、不含已删除）。若 App 里能看到记录但此处为空，请到 App 登录对应账号并执行「同步到云端」，或从用户管理点击「查看时光」自动带上该用户 ID。"
    />

    <el-card class="search-card">
      <el-form :inline="true" :model="filters" @submit.prevent="handleSearch">
        <el-form-item required>
          <template #label>
            <span>用户 ID</span>
            <el-tooltip
              content="必填。与「用户管理」列表中的 ID 一致；须与 App 登录账号对应。"
              placement="top"
            >
              <el-icon class="label-help"><QuestionFilled /></el-icon>
            </el-tooltip>
          </template>
          <el-input
            v-model="userIdInput"
            placeholder="必填，例如从用户管理复制"
            clearable
            style="width: 200px"
            @keyup.enter="handleSearch"
          />
        </el-form-item>
        <el-form-item>
          <template #label>
            <span>媒体类型</span>
            <span class="label-optional">（选填）</span>
          </template>
          <el-select v-model="filters.mediaType" placeholder="默认：全部" clearable style="width: 130px">
            <el-option label="全部类型" value="" />
            <el-option label="文字" value="text" />
            <el-option label="图片" value="image" />
            <el-option label="音频" value="audio" />
            <el-option label="视频" value="video" />
            <el-option label="混合" value="mixed" />
          </el-select>
        </el-form-item>
        <el-form-item>
          <template #label>
            <span>创建起</span>
            <span class="label-optional">（选填）</span>
          </template>
          <el-date-picker
            v-model="filters.createdFrom"
            type="date"
            value-format="YYYY-MM-DD"
            placeholder="默认：不限制"
            style="width: 150px"
          />
        </el-form-item>
        <el-form-item>
          <template #label>
            <span>创建止</span>
            <span class="label-optional">（选填）</span>
          </template>
          <el-date-picker
            v-model="filters.createdTo"
            type="date"
            value-format="YYYY-MM-DD"
            placeholder="默认：不限制"
            style="width: 150px"
          />
        </el-form-item>
        <el-form-item>
          <template #label>
            <span>关键词</span>
            <span class="label-optional">（选填）</span>
          </template>
          <el-input
            v-model="filters.keyword"
            placeholder="默认：不筛选正文"
            clearable
            style="width: 180px"
            @keyup.enter="handleSearch"
          />
        </el-form-item>
        <el-form-item>
          <template #label>
            <span>含已删</span>
            <span class="label-optional">（选填）</span>
          </template>
          <el-switch v-model="filters.includeDeleted" active-text="是" inactive-text="默认否" />
        </el-form-item>
        <el-form-item>
          <el-button type="primary" @click="handleSearch">查询</el-button>
          <el-button @click="handleReset">重置筛选</el-button>
        </el-form-item>
      </el-form>

      <div v-if="currentUser" class="user-banner">
        <span>当前用户：</span>
        <strong>{{ currentUser.nickname }}</strong>
        <span class="muted">（{{ currentUser.username }}，ID {{ currentUser.id }}）</span>
        <el-button type="primary" link @click="goUsers">返回用户管理</el-button>
      </div>
    </el-card>

    <el-card class="table-card">
      <template #header>
        <span>时光列表</span>
      </template>

      <el-empty v-if="!hasQueried" description="请填写上方「用户 ID」后点击「查询」（仅 ID 必填）" />

      <template v-else>
        <el-alert
          v-if="listError"
          type="error"
          :title="listError"
          show-icon
          :closable="false"
          class="table-alert"
        />
        <template v-else>
          <el-empty
            v-if="!loading && tableData.length === 0"
            description="该用户在服务端暂无符合条件的时光记录。若 App 中有数据，请先同步到云端后再查。"
          />
          <template v-else>
            <el-table :data="tableData" v-loading="loading" stripe @row-click="openDetail">
              <el-table-column prop="id" label="ID" width="80" />
              <el-table-column label="摘要" min-width="200">
                <template #default="{ row }">
                  <el-tooltip :content="row.content" placement="top" :show-after="400">
                    <span class="ellipsis">{{ contentPreview(row.content) }}</span>
                  </el-tooltip>
                </template>
              </el-table-column>
              <el-table-column prop="media_type" label="类型" width="90">
                <template #default="{ row }">
                  {{ mediaTypeLabel(row.media_type) }}
                </template>
              </el-table-column>
              <el-table-column label="媒体数" width="80">
                <template #default="{ row }">
                  {{ (row.media_paths && row.media_paths.length) || 0 }}
                </template>
              </el-table-column>
              <el-table-column prop="created_at" label="创建时间" width="170" />
              <el-table-column prop="updated_at" label="更新时间" width="170" />
              <el-table-column label="状态" width="90">
                <template #default="{ row }">
                  <el-tag v-if="row.deleted_at" type="info" size="small">已删除</el-tag>
                  <el-tag v-else type="success" size="small">正常</el-tag>
                </template>
              </el-table-column>
              <el-table-column label="操作" width="100" fixed="right">
                <template #default="{ row }">
                  <el-button
                    v-if="canViewMoments"
                    type="primary"
                    link
                    @click.stop="openDetail(row)"
                  >
                    详情
                  </el-button>
                </template>
              </el-table-column>
            </el-table>

            <el-pagination
              v-if="tableData.length > 0"
              v-model:current-page="pagination.page"
              v-model:page-size="pagination.pageSize"
              :total="pagination.total"
              :page-sizes="[10, 20, 50, 100]"
              layout="total, sizes, prev, pager, next, jumper"
              class="pagination"
              @size-change="loadData"
              @current-change="loadData"
            />
          </template>
        </template>
      </template>
    </el-card>

    <el-drawer v-model="drawerVisible" title="时光详情" size="480px" destroy-on-close>
      <template v-if="detailRow">
        <p class="detail-meta">ID：{{ detailRow.id }}</p>
        <p class="detail-meta">创建：{{ detailRow.created_at }} · 更新：{{ detailRow.updated_at }}</p>
        <p v-if="detailRow.deleted_at" class="detail-meta">删除：{{ detailRow.deleted_at }}</p>
        <el-divider content-position="left">正文</el-divider>
        <div class="detail-content">{{ detailRow.content }}</div>
        <el-divider v-if="detailRow.media_paths?.length" content-position="left">媒体</el-divider>
        <ul v-if="detailRow.media_paths?.length" class="media-list">
          <li v-for="(p, i) in detailRow.media_paths" :key="i">
            <template v-if="mediaKind(p) === 'image'">
              <a :href="mediaHref(p)" target="_blank" rel="noopener">
                <img :src="mediaHref(p)" class="media-preview-image" />
              </a>
            </template>
            <template v-else-if="mediaKind(p) === 'audio'">
              <audio :src="mediaHref(p)" controls preload="metadata" class="media-preview-audio" />
            </template>
            <template v-else-if="mediaKind(p) === 'video'">
              <video :src="mediaHref(p)" controls preload="metadata" class="media-preview-video" />
            </template>
            <a :href="mediaHref(p)" target="_blank" rel="noopener">{{ mediaHref(p) }}</a>
          </li>
        </ul>
      </template>
    </el-drawer>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted, watch, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { QuestionFilled } from '@element-plus/icons-vue'
import { getUserMoments } from '../api/moment'
import { useAdminStore } from '../stores/admin'

const route = useRoute()
const router = useRouter()
const adminStore = useAdminStore()

const userIdInput = ref('')
const currentUser = ref(null)
const tableData = ref([])
const loading = ref(false)
const hasQueried = ref(false)
const listError = ref('')
const drawerVisible = ref(false)
const detailRow = ref(null)

const filters = reactive({
  mediaType: '',
  createdFrom: '',
  createdTo: '',
  keyword: '',
  includeDeleted: false
})

const pagination = reactive({
  page: 1,
  pageSize: 10,
  total: 0
})
const canViewMoments = computed(() => adminStore.hasPermission('moment:list'))

const mediaMap = {
  text: '文字',
  image: '图片',
  audio: '音频',
  video: '视频',
  mixed: '混合'
}

function mediaTypeLabel(t) {
  return mediaMap[t] || t
}

function contentPreview(s) {
  if (!s) return ''
  return s.length > 80 ? s.slice(0, 80) + '…' : s
}

function isAbsoluteUrl(s) {
  return /^https?:\/\//i.test(s)
}

function mediaHref(s) {
  if (!s) return ''
  if (isAbsoluteUrl(s)) return s
  if (s.startsWith('/')) return `${window.location.origin}${s}`
  return s
}

function mediaKind(s) {
  const path = (isAbsoluteUrl(s) ? new URL(s).pathname : s).toLowerCase()
  if (/\.(jpg|jpeg|png|gif|webp|bmp)$/.test(path)) return 'image'
  if (/\.(mp3|m4a|aac|wav)$/.test(path)) return 'audio'
  if (/\.(mp4|mov|avi|mkv|webm)$/.test(path)) return 'video'
  return 'file'
}

function goUsers() {
  router.push('/users')
}

/** 执行查询前校验：仅用户 ID 必填 */
function validateUserIdForSearch() {
  const id = String(userIdInput.value || '').trim()
  if (!id) {
    ElMessage.warning('请先填写「用户 ID」后再查询（其它筛选均为选填，可不填）')
    return false
  }
  if (!/^\d+$/.test(id)) {
    ElMessage.warning('用户 ID 须为正整数')
    return false
  }
  return true
}

async function loadData() {
  const id = String(userIdInput.value || '').trim()
  if (!id || !/^\d+$/.test(id)) {
    ElMessage.warning('请先填写有效的用户 ID')
    return
  }

  loading.value = true
  hasQueried.value = true
  listError.value = ''
  try {
    const res = await getUserMoments(id, {
      page: pagination.page,
      page_size: pagination.pageSize,
      media_type: filters.mediaType || undefined,
      keyword: filters.keyword || undefined,
      created_from: filters.createdFrom || undefined,
      created_to: filters.createdTo || undefined,
      include_deleted: filters.includeDeleted ? '1' : undefined
    })
    tableData.value = res.data.moments || []
    pagination.total = res.data.total ?? 0
    currentUser.value = res.data.user
  } catch (e) {
    tableData.value = []
    pagination.total = 0
    currentUser.value = null
    listError.value = e?.message || '加载失败，请检查网络或登录状态'
  } finally {
    loading.value = false
  }
}

function handleSearch() {
  if (!validateUserIdForSearch()) return
  pagination.page = 1
  const id = String(userIdInput.value || '').trim()
  if (String(route.query.user_id || '') === id) {
    loadData()
  } else {
    router.replace({ path: '/moments', query: { user_id: id } })
  }
}

/** 重置选填筛选为默认逻辑；已填用户 ID 时立即按默认条件重新查询 */
function handleReset() {
  filters.mediaType = ''
  filters.createdFrom = ''
  filters.createdTo = ''
  filters.keyword = ''
  filters.includeDeleted = false
  pagination.page = 1
  const id = String(userIdInput.value || '').trim()
  if (!id || !/^\d+$/.test(id)) {
    ElMessage.info('筛选已恢复默认（全部类型、不限时间、不搜关键词、不含已删）。填写用户 ID 后点击「查询」。')
    return
  }
  loadData()
}

function openDetail(row) {
  detailRow.value = row
  drawerVisible.value = true
}

function syncFromRoute() {
  const q = route.query.user_id
  if (q != null && q !== '') {
    userIdInput.value = String(q)
  }
}

onMounted(() => {
  syncFromRoute()
  if (route.query.user_id) {
    loadData()
  }
})

watch(
  () => route.query.user_id,
  (v) => {
    if (v != null && v !== '') {
      userIdInput.value = String(v)
      pagination.page = 1
      listError.value = ''
      loadData()
    }
  }
)
</script>

<style scoped>
.page-container {
  height: 100%;
}

.page-tip {
  margin-bottom: 16px;
}

.label-optional {
  margin-left: 2px;
  font-size: 12px;
  color: #909399;
  font-weight: normal;
}

.label-help {
  margin-left: 4px;
  vertical-align: middle;
  color: #909399;
  cursor: help;
}

.table-alert {
  margin-bottom: 12px;
}

.search-card {
  margin-bottom: 16px;
}

.user-banner {
  margin-top: 8px;
  font-size: 14px;
}

.user-banner .muted {
  color: #909399;
  margin: 0 8px;
}

.table-card {
  margin-bottom: 16px;
}

.pagination {
  margin-top: 16px;
  justify-content: flex-end;
}

.ellipsis {
  display: inline-block;
  max-width: 100%;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  vertical-align: bottom;
}

.detail-meta {
  margin: 0 0 8px;
  font-size: 13px;
  color: #606266;
}

.detail-content {
  white-space: pre-wrap;
  word-break: break-word;
  line-height: 1.6;
}

.media-list {
  margin: 0;
  padding-left: 1.2em;
  word-break: break-all;
}

.media-list li {
  margin-bottom: 12px;
}

.media-preview-image,
.media-preview-video {
  display: block;
  width: 100%;
  max-width: 360px;
  border-radius: 8px;
  background: #f5f7fa;
}

.media-preview-audio {
  display: block;
  width: 100%;
  max-width: 360px;
  margin-bottom: 8px;
}
</style>
