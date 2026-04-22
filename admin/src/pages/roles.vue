<template>
  <div class="page-container">
    <el-card class="table-card">
      <template #header>
        <div class="card-header">
          <span>角色列表</span>
          <el-button v-if="canManageRoles" type="primary" @click="handleAdd">
            <el-icon><Plus /></el-icon>
            新增角色
          </el-button>
        </div>
      </template>

      <el-table :data="tableData" v-loading="loading" stripe>
        <el-table-column prop="id" label="ID" width="80" />
        <el-table-column prop="name" label="角色名称" />
        <el-table-column prop="code" label="角色代码" />
        <el-table-column prop="description" label="描述" show-overflow-tooltip />
        <el-table-column prop="status" label="状态" width="100">
          <template #default="{ row }">
            <el-tag :type="row.status === 1 ? 'success' : 'danger'">
              {{ row.status === 1 ? '正常' : '禁用' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="created_at" label="创建时间" width="180" />
        <el-table-column label="操作" width="200" fixed="right">
          <template #default="{ row }">
            <el-button v-if="canManageRoles" type="primary" link @click="handleEdit(row)">
              编辑
            </el-button>
            <el-button
              v-if="canManageRoles"
              type="primary"
              link
              @click="handleAssignPermissions(row)"
            >
              分配权限
            </el-button>
            <el-button v-if="canManageRoles" type="danger" link @click="handleDelete(row)">
              删除
            </el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <!-- 角色表单弹窗 -->
    <el-dialog
      v-model="dialogVisible"
      :title="dialogTitle"
      width="500px"
      @close="handleDialogClose"
    >
      <el-form ref="formRef" :model="form" :rules="formRules" label-width="80px">
        <el-form-item label="角色名称" prop="name">
          <el-input v-model="form.name" />
        </el-form-item>
        <el-form-item label="角色代码" prop="code">
          <el-input v-model="form.code" :disabled="!!form.id" />
        </el-form-item>
        <el-form-item label="描述" prop="description">
          <el-input v-model="form.description" type="textarea" :rows="3" />
        </el-form-item>
      </el-form>

      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" @click="handleSubmit" :loading="submitting">
          确定
        </el-button>
      </template>
    </el-dialog>

    <!-- 权限分配弹窗 -->
    <el-dialog
      v-model="permDialogVisible"
      title="分配权限"
      width="600px"
    >
      <el-tree
        ref="permTreeRef"
        :data="permTreeData"
        :props="{ label: 'name', children: 'children' }"
        node-key="id"
        show-checkbox
        default-expand-all
        check-strictly
      />

      <template #footer>
        <el-button @click="permDialogVisible = false">取消</el-button>
        <el-button type="primary" @click="handlePermSubmit" :loading="permSubmitting">
          确定
        </el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted, computed, nextTick } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { getRoleList, createRole, updateRole, deleteRole, assignRolePermissions } from '../api/role'
import { getPermissionList } from '../api/permission'
import { useAdminStore } from '../stores/admin'

const adminStore = useAdminStore()
const loading = ref(false)
const tableData = ref([])
const dialogVisible = ref(false)
const permDialogVisible = ref(false)
const submitting = ref(false)
const permSubmitting = ref(false)
const formRef = ref()
const permTreeRef = ref()

const form = reactive({
  id: null,
  name: '',
  code: '',
  description: ''
})

const formRules = {
  name: [{ required: true, message: '请输入角色名称', trigger: 'blur' }],
  code: [{ required: true, message: '请输入角色代码', trigger: 'blur' }]
}

const permTreeData = ref([])
const currentRoleId = ref(null)

const dialogTitle = computed(() => form.id ? '编辑角色' : '新增角色')
const canManageRoles = computed(() => adminStore.hasPermission('system:role'))

async function loadData() {
  loading.value = true
  try {
    const res = await getRoleList()
    tableData.value = res.data.roles
  } catch (error) {
    console.error('加载数据失败:', error)
  } finally {
    loading.value = false
  }
}

async function loadPermissions() {
  try {
    const res = await getPermissionList()
    permTreeData.value = res.data.permissions
  } catch (error) {
    console.error('加载权限失败:', error)
  }
}

function handleAdd() {
  form.id = null
  form.name = ''
  form.code = ''
  form.description = ''
  dialogVisible.value = true
}

function handleEdit(row) {
  form.id = row.id
  form.name = row.name
  form.code = row.code
  form.description = row.description
  dialogVisible.value = true
}

async function handleAssignPermissions(row) {
  currentRoleId.value = row.id
  await loadPermissions()

  // 设置已选中的权限
  nextTick(() => {
    if (permTreeRef.value) {
      permTreeRef.value.setCheckedKeys(row.permissions || [])
    }
  })

  permDialogVisible.value = true
}

async function handleDelete(row) {
  try {
    await ElMessageBox.confirm(`确定要删除角色 ${row.name} 吗？`, '警告', {
      type: 'warning'
    })
    await deleteRole(row.id)
    ElMessage.success('删除成功')
    loadData()
  } catch (error) {
    if (error !== 'cancel') {
      console.error('删除失败:', error)
    }
  }
}

async function handleSubmit() {
  const valid = await formRef.value.validate().catch(() => false)
  if (!valid) return

  submitting.value = true
  try {
    if (form.id) {
      await updateRole(form.id, form)
      ElMessage.success('更新成功')
    } else {
      await createRole(form)
      ElMessage.success('创建成功')
    }
    dialogVisible.value = false
    loadData()
  } catch (error) {
    console.error('提交失败:', error)
  } finally {
    submitting.value = false
  }
}

async function handlePermSubmit() {
  permSubmitting.value = true
  try {
    const checkedKeys = permTreeRef.value.getCheckedKeys()
    await assignRolePermissions(currentRoleId.value, {
      permission_ids: checkedKeys
    })
    ElMessage.success('分配成功')
    permDialogVisible.value = false
    loadData()
  } catch (error) {
    console.error('分配失败:', error)
  } finally {
    permSubmitting.value = false
  }
}

function handleDialogClose() {
  formRef.value.resetFields()
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

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
</style>
