# 拾光记管理后台 Web（`admin/`）— 登录后空白问题与完善需求

> 本文档整理现象、技术背景、根因假设、功能与体验需求，以及**可执行的开发步骤**。  
> 对应入口：`http://localhost:5173`（Vite 默认端口，见 `admin/vite.config.js`）。

---

## 一、问题描述

### 1.1 现象

- 浏览器打开管理后台并完成登录后，**主内容区域无有效界面**（用户感知为「空白」或仅有布局壳子无列表/表单）。
- 技术栈：`Vue 3` + `Vue Router` + `Pinia` + `Element Plus` + `Axios`，开发服务器端口 **5173**。

### 1.2 当前信息架构（便于对照）

| 层级 | 说明 |
|------|------|
| 根路由 `/` | 使用布局 `layouts/main.vue`，`redirect` 到 `/users` |
| 子路由 | `/users`、`/roles`、`/permissions`、`/logs` |
| 鉴权 | `router.beforeEach`：无 `adminStore.token` 则跳转 `/login` |
| API | `axios` `baseURL: '/api/v1'`，Vite 将 `/api` 代理到 `http://localhost:8080` 并去掉 `/api` 前缀，实际请求形如 `GET http://localhost:8080/v1/admin/users` |

---

## 二、根因分析（代码审查结论）

### 2.1 高概率直接原因：`admin/src/pages/users.vue` 脚本错误

登录成功后 `router.push('/')`，路由重定向到 **`/users`**，会加载 `users.vue`。

该文件中存在：

1. **未从 `vue` 导入 `computed`**，却使用 `const dialogTitle = computed(() => …)`。
2. **多余且有害的函数声明** `function computed() { return { dialogTitle } }`。  
   在 JavaScript 中，函数声明会被提升；执行 `const dialogTitle = computed(…)` 时，标识符 `computed` 指向该本地函数。该函数体返回 `{ dialogTitle }`，在 `dialogTitle` 尚未完成初始化时访问，会触发 **Temporal Dead Zone** 类错误（典型为 `ReferenceError`），导致 **`users` 页面组件无法完成 setup**，嵌套在 `main.vue` 的 `<router-view />` 中**不渲染或渲染失败**，表现为登录后「没有内容」。

### 2.2 对比：其他页面

- `roles.vue`：**已正确** `import { …, computed } from 'vue'`，且无上述冲突函数。
- `permissions.vue`、`logs.vue`：需在实际开发阶段顺带做**冒烟检查**（接口字段、空态、错误提示是否与后端一致）。

### 2.3 非首要但需排查项（完善阶段）

| 项 | 说明 |
|----|------|
| 后端未启动或代理失败 | 列表接口失败时，若仅 `console.error` 而无 UI 提示，用户可能误以为「空白」；需在需求中明确**错误态与空态**。 |
| 401 与 token | `request.js` 在 401 时会清 token 并跳登录；若 JWT 与中间件不一致，可能出现闪跳或反复登录，需联调验证。 |
| 响应结构 | 前端统一假设 `res.code === 200` 且业务数据在 `res.data`；后端 `pkg/response` 与此一致，但各接口字段名（如 `users`、`roles`、`permissions`）必须与页面一致。 |

---

## 三、需求目标（要达成什么）

### 3.1 必须达成（P0）

1. **登录后能稳定进入默认页**（`/users`），页面脚本报错为 0，表格/搜索/分页等区域正常展示（无数据时显示**空状态**，而非静默空白）。
2. **修复 `users.vue` 中与 `computed` 相关的错误**：从 `vue` 正确导入 `computed`，删除错误的本地 `function computed`，保证 `dialogTitle` 为合法的 `ComputedRef`。
3. **侧边栏切换**至角色、权限、日志等路由时，页面均可加载；接口异常时有**可见反馈**（Element Plus `ElMessage` 或页面内错误/重试区，与现有 `request.js` 行为协调，避免重复刷屏）。

### 3.2 建议达成（P1）

1. **开发/联调体验**：在 `.env.development` 或文档中明确 `VITE_` 代理目标（与 `moment_debug.md` 一致：后端默认 `8080`）。
2. **路由与标题**：`document.title` 或页头标题与 `meta.title` 同步（可选，小改动）。
3. **登录后拉取 `/admin/me`**（已有 `api/login.js` 中 `getAdminInfo`）：刷新页面时恢复用户信息，避免仅依赖 `localStorage` 与登录当次响应不一致（可选）。

### 3.3 可选（P2）

- 权限菜单按角色裁剪（需后端返回权限列表并与路由 meta 绑定）。
- 表格列格式化（时间时区、状态枚举文案统一）。

---

## 四、具体开发步骤（按顺序执行）

### 步骤 1：复现与确认

1. 启动后端：`server` 可访问 `http://127.0.0.1:8080/health`。
2. 启动管理端：`admin/` 下 `npm install`（若未安装）、`npm run dev`，打开 `http://localhost:5173`。
3. 打开浏览器**开发者工具 Console**，登录后观察是否在加载 `/users` 时出现 **ReferenceError** 或其它报错；与本文档第二节对照。

### 步骤 2：修复 `users.vue`（P0）

1. 在 `<script setup>` 中：`import { ref, reactive, onMounted, computed } from 'vue'`（补上 `computed`）。
2. **删除**错误的 `function computed() { return { dialogTitle } }` 整段。
3. 保留 `const dialogTitle = computed(() => (form.id ? '编辑用户' : '新增用户'))`（或等价写法）。
4. 保存后热更新，确认 Console 无报错，弹窗标题随新增/编辑切换正确。

### 步骤 3：用户列表页联调（P0）

1. 确认 `getUserList` 返回结构为 `res.data.users`、`res.data.total` 等，与 `server` 中 `UserListResponse` 字段一致。
2. 无数据时：`el-table` 使用 `empty` 插槽或 Element Plus 默认空状态，避免大面积留白无说明。
3. 请求失败：在 `loadData` 的 `catch` 中除 `console.error` 外，增加用户可见提示（与全局拦截器配合，避免同一次失败两次弹窗）。

### 步骤 4：其它路由冒烟（P0）

1. **角色** `roles.vue`：列表、弹窗、分配权限树加载与提交。
2. **权限** `permissions.vue`：树形数据与图标组件是否正常（`Folder`、`Operation`、`Connection` 已在 `main.js` 全局注册）。
3. **日志** `logs.vue`：筛选、分页、日期范围参数与后端查询参数命名一致。

### 步骤 5：鉴权与刷新场景（P1）

1. 登录后**手动刷新**浏览器，确认 `localStorage` 中 `admin_token` 仍存在时，路由守卫能进入主布局且子页能带 Token 请求。
2. Token 过期或无效：确认跳转登录与提示文案合理。

### 步骤 6：回归与文档（P1）

1. 在 `doc/moment_debug.md` 中可增加一句：**管理端若登录后内容空白，优先检查浏览器 Console 与 `users.vue` 的 `computed` 用法**（可选，避免与本文重复可只链到本文）。
2. 自测清单：登录 → 四菜单切换 → 用户 CRUD 一条 → 角色与权限各至少一次读列表。

---

## 五、验收标准（Checklist）

- [ ] 登录后默认进入用户管理页，**无 Console 报错**，列表区域有表格或明确空状态。
- [ ] `users.vue` 新增/编辑用户弹窗标题正确，表单校验与提交正常。
- [ ] `/roles`、`/permissions`、`/logs` 均可打开，接口异常时有提示而非静默失败。
- [ ] 后端不可用时，用户能理解「服务不可用」而非「空白页」。

---

## 六、涉及文件索引（实施时优先改动）

| 文件 | 说明 |
|------|------|
| `admin/src/pages/users.vue` | **必选修复**：`computed` 导入与删除冲突函数 |
| `admin/src/utils/request.js` | 按需协调全局错误提示与页面级 catch |
| `admin/src/pages/roles.vue`、`permissions.vue`、`logs.vue` | 冒烟与空态/错误态 |
| `admin/vite.config.js` | 代理目标与端口 |
| `doc/moment_debug.md` | 可选补充交叉引用 |

---

## 七、说明

- 本文档仅做**需求与步骤整理**；**不包含具体代码补丁**，实施时以当时仓库代码为准再做 diff。
- 若修复 P0 后仍有空白，应按「Console 报错 → 网络面板 → 响应 JSON 结构」顺序继续排查，并把新结论追加到本文档「根因分析」小节。
