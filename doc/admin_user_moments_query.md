# 后台管理：按用户查询其全部发布内容 — 需求与开发计划

> 文档版本：v1.1  
> 关联文档：[project_develop_detail.md](./project_develop_detail.md)、[moment_develop.md](./moment_develop.md)  
> 范围：Web 管理端 + 管理端 API；不包含 App 端改动。

---

## 〇、与现有工程约定对齐（实现时必须遵守）

| 维度 | 现有约定 | 本需求遵循方式 |
|------|----------|----------------|
| 管理端 API 前缀 | `server/cmd/server/main.go` 中 `/v1/admin/*` | 新接口挂在同一 `admin` 路由组，使用 **管理员 JWT**（`middleware.Auth()`，与现有 `GET /v1/admin/users` 等一致） |
| 管理员登录 | `POST /v1/admin/login`、`POST /v1/admin/refresh` | 不变 |
| 统一响应 | `pkg/response`：`{ code, msg, data }` | 不变 |
| 管理端分页 Query | `page`（默认 1）、`page_size`（默认 10，非法或超大时回落，**上限 100**） | 与 `AdminHandler.ListUsers` 等 handler 一致 |
| 管理端列表 **data** 形状 | 用户列表：`Success` + `data` 为 `{ total, page, page_size, users }`（见 `UserListResponse`） | **本接口采用同一风格**：`Success` + `data` 为 `{ total, page, page_size, moments }`（**不使用** C 端 `SuccessPage` 的 `list` / `total_pages`，避免管理端混用两套解析） |
| C 端时光列表 | `GET /v1/moments` + `SuccessPage`（`list`、`total_pages`） | **不修改**；管理端查询走独立 admin 接口 |
| 权限种子 | `server/migrations/001_init.sql`：`moment` 菜单 `path` = **`/moments`**；`moment:list` 等 | **不新增权限码**；菜单 path 与前端路由一致为 **`/moments`** |
| 管理端前端路由 | `admin/src/router/index.js`：`/users`、`/roles`、`/permissions`、`/logs`（**非** DB 里 `system:user` 的 `/system/users`） | 新增子路由 **`/moments`**；从用户页返回用 **`/users`**，与现网侧栏 `index` 一致 |
| 实体字段 | `internal/model/moment.go`、`service.MomentResponse` | 列表项与 `MomentResponse` 一致；管理端扩展字段（如 `deleted_at`）在文档与 Swagger 中注明 |

---

## 一、背景与目标

### 1.1 背景

拾光记 App 用户产生的「时光记录」存储于 `moments` 表，与 `users` 通过 `user_id` 关联。当前管理端已实现用户、角色、权限、日志等模块，但缺少**从运营/合规视角按用户维度查看其全部已发布记录**的能力。

### 1.2 目标

1. 管理员可在后台**定位某一用户**，并**分页查看该用户名下全部时光记录**（与 App 侧「我的记录」数据域一致，含已软删记录的策略见下文）。  
2. 支持**基础筛选与排序**，便于排查问题、内容审核与统计核对。  
3. 行为受 **RBAC 权限** 约束，关键操作可记录**操作日志**（若现有日志能力可覆盖则复用）。

### 1.3 成功标准（验收）

- 具备合法权限的管理员登录后，可通过明确入口进入「某用户的时光列表」，列表数据与后端 `moments` 中该 `user_id` 一致（在「是否含软删」规则确定后一致）。  
- 分页、筛选、详情查看在约定边界内响应正常；无权限用户无法访问接口与菜单。  
- 需求中约定的异常场景（用户不存在、无数据等）有清晰的前后端提示。

---

## 二、名词与数据范围

| 名词 | 说明 |
|------|------|
| 发布内容 / 时光记录 | 对应业务实体 `Moment`：`content`、`media_type`、`media_paths`、`created_at`、`updated_at` 等 |
| 用户 | 管理端「用户管理」中的 App 用户（非管理员账号），以 `users.id` 为准 |
| 软删除 | `moments.deleted_at` 非空表示用户侧或业务删除后的记录（若当前 App 删除走软删，则库内仍存在） |

**数据范围说明（需在实现时二选一并在接口文档中写死）：**

- **方案 A（推荐）**：列表默认**仅 `deleted_at IS NULL`**；提供筛选项「包含已删除」时展示软删记录（便于审计）。  
- **方案 B**：列表始终包含软删记录，并用列或标签标明「已删除」。

下文功能描述以 **方案 A** 为默认表述；若选 B，仅调整默认筛选与 UI 文案。

---

## 三、角色与权限

### 3.1 角色

沿用现有「管理员 / 超级管理员」及 RBAC；不新增终端用户角色。

### 3.2 权限（与现有种子严格一致）

数据库种子中已存在与时光相关的权限（`001_init.sql`，中文名以 `003_fix_chinese_mojibake.sql` 为准）：

| 类型 | code | `path`（菜单） |
|------|------|----------------|
| 菜单 | `moment` | **`/moments`** |
| 按钮 | `moment:list` / `moment:add` / `moment:edit` / `moment:delete` | （按钮无 path） |

**本需求最低要求：**

| 能力 | 权限码 | 说明 |
|------|--------|------|
| 查看某用户的时光列表（只读） | `moment:list` | 与种子「查看时光」一致 |
| 侧栏「时光管理」菜单 | `moment` | 与种子菜单 path **`/moments`** 一致 |
| 从用户管理跳转查看 | `moment:list` + 能进入用户列表即可（现有侧栏无菜单级 `system:user`，与 `users` 页一致由登录态与后端控制） | 跳转目标：`/moments?user_id={id}` |
| 后台代用户新增/编辑/删除 | `moment:add` / `moment:edit` / `moment:delete` | **本期不实现**；种子中已预留 |

**不新增** `moment:list:all_users` 等扩展码，与当前 RBAC 表结构保持一致。

### 3.3 安全要求

- 所有管理端时光查询接口必须走 **管理员 JWT**，并校验角色/权限（与现有 `admin` 路由组一致）。  
- **禁止**通过改 `user_id` 越权拉取其他用户数据：服务端必须校验当前管理员具备 `moment:list`（及路由层统一鉴权）。  
- 响应中**不返回**用户密码等敏感字段；用户维度接口仅返回用户展示字段（昵称、用户名、id 等）。

---

## 四、功能需求

### 4.1 入口与导航

| 编号 | 需求 | 优先级 | 说明 |
|------|------|--------|------|
| F1 | 侧边栏增加「时光管理」菜单 | P0 | 与权限 `moment` 菜单绑定；无权限则不展示 |
| F2 | 用户管理列表操作列增加「查看时光」 | P0 | 跳转至时光列表页并带上 `user_id`（或用户名再解析为 id，推荐 id） |
| F3 | 时光列表页支持不经过用户页进入 | P1 | 提供用户 ID 输入/选择器，便于客服直接查号 |

### 4.2 列表页

| 编号 | 需求 | 优先级 | 说明 |
|------|------|--------|------|
| F4 | 指定 `user_id` 后分页展示该用户时光 | P0 | 默认按 `created_at` 倒序 |
| F5 | 分页参数 | P0 | 与现有风格一致：`page`、`page_size`，上限建议与 C 端列表一致（如最大 100） |
| F6 | 列表字段 | P0 | ID、`content` 摘要（如前 80 字）、`media_type`、媒体数量或首图缩略（可选）、`created_at`、`updated_at`、软删标记（若方案 A 且勾选含已删） |
| F7 | 筛选 | P1 | `media_type`：全部 / text / image / audio / video |
| F8 | 时间范围 | P1 | 按 `created_at` 区间过滤（闭区间或 [start, end) 需在接口注明） |
| F9 | 关键词 | P2 | 对 `content` 模糊搜索（大数据量时需约束索引或限制频率，见非功能） |
| F10 | 包含已删除 | P1 | 与第二节方案 A 对应；开关默认关 |

### 4.3 详情

| 编号 | 需求 | 优先级 | 说明 |
|------|------|--------|------|
| F11 | 点击行进入详情 | P0 | 抽屉或新页：完整 `content`、全部 `media_paths`（URL 需可访问，与现有存储域名一致） |
| F12 | 媒体展示 | P1 | 图片预览、音频/视频播放（可用 Element Plus 组件或链接新窗口） |

### 4.4 用户上下文展示

| 编号 | 需求 | 优先级 | 说明 |
|------|------|--------|------|
| F13 | 页头展示当前查询用户 | P0 | 昵称、用户名、`user_id`；若用户不存在则错误提示并清空列表 |
| F14 | 返回用户管理 | P2 | 链接返回 **`/users`**（与 `admin/src/router` 一致）或浏览器返回 |

### 4.5 操作日志（可选）

| 编号 | 需求 | 优先级 | 说明 |
|------|------|--------|------|
| F15 | 记录「管理员查看用户时光列表」 | P2 | 若现有 `operation_logs` 仅记录写操作，本期可省略；若需审计，记录 `user_id`、管理员 id、时间 |

### 4.6 本期明确不包含（防范围蔓延）

- App 端任何改动。  
- 普通用户 C 端接口行为变更（`/v1/moments` 仍仅当前用户）。  
- 批量导出、批量删除（可作为后续迭代）。  
- 除非单独立项，否则不在本期实现管理端「代用户新增/编辑/删除」时光（权限码可已存在但 UI 可不开放）。

---

## 五、接口约定（实现时以 OpenAPI/Swagger 为准）

以下均为 **管理端** 路由，挂在 **`/v1/admin`** 下，**Admin JWT**；权限校验方式与现有 `AdminHandler` 一致。

### 5.1 查询某用户的时光列表

- **方法/路径**：`GET /v1/admin/users/:user_id/moments`  
- **Query**：`page`、`page_size`、`media_type`（可选）、`created_from`、`created_to`（可选，ISO8601 或 `YYYY-MM-DD`）、`keyword`（可选）、`include_deleted`（可选，`0|1`，默认 `0`）  
- **响应**：`response.Success`，`data` 形状与 **`UserListResponse` 同级约定** 一致：  
  `{ "total": number, "page": number, "page_size": number, "moments": [ ... ] }`  
  其中每项与 `MomentResponse` 对齐，按需增加 `deleted_at`（RFC3339 或 null）供 UI 标记。  

**错误**：`user_id` 不存在 → `NotFound`（与 `UpdateUser` 等一致）；无权限 → 403。

### 5.1.1 与用户列表接口对照

| 接口 | data 内列表字段名 |
|------|-------------------|
| `GET /v1/admin/users` | `users` |
| `GET /v1/admin/users/:user_id/moments` | `moments` |

### 5.2 （可选）用户简要信息

- 若列表页需展示昵称：可 **扩展** `GET /v1/admin/users/:id` 已有能力，或列表接口 `meta.user` 内嵌 `{ id, username, nickname }`，避免前端二次请求（二选一写进实现说明）。

### 5.3 （可选）详情

- **方案 1**：列表数据已足够，点击详情仅用行数据渲染。  
- **方案 2**：`GET /v1/admin/moments/:id` 返回单条并校验该记录归属与管理员权限（便于后续扩展审核字段）。

---

## 六、前端（admin）交互细节

1. **路由**：在 `admin/src/router/index.js` 的 layout `children` 中增加 **`path: 'moments'`** → **`/moments`**；支持 **`/moments?user_id=123`** 深链；从 `users.vue` 跳转时带 query。  
2. **侧栏**：在 `admin/src/layouts/main.vue` 中增加菜单项 **`index="/moments"`**，文案与权限 **`moment`** 一致（「时光管理」）。  
3. **未选用户**：列表区显示空态说明「请选择或输入用户 ID」；从用户页跳入时自动加载。  
4. **加载与错误**：请求 loading；接口失败用 Element Plus Message 提示文案（含权限不足、用户不存在）。  
5. **表格**：Element Plus Table + Pagination；解析 `data.moments`、`data.total`、`data.page`、`data.page_size`（与用户页的 `users` 解析方式对称）。  
6. **权限**：菜单与「查看时光」按钮与现有 **users/roles** 页的权限显隐方式一致（若当前为全量展示菜单，实现本需求时一并按后端权限收敛亦可，不在本文档强制）。

---

## 七、非功能需求

| 类型 | 要求 |
|------|------|
| 性能 | 列表查询应对 `user_id` + `created_at` 有索引（现有 `user_id` 索引需确认）；`keyword` 全表模糊若数据量大需分页强制 + 超时保护 |
| 一致性 | 时区：展示建议统一为服务器存储的 UTC 或配置时区，与 App 一致 |
| 安全 | 管理接口仅 HTTPS；鉴权失败不泄露用户是否存在（可选统一 403/404 策略，产品定调） |

---

## 八、开发计划

按依赖顺序执行；估时为 **人天级参考**（1 人全职），可并行处已标注。

### 阶段 0：澄清（0.5 天）

- [ ] 确认软删默认策略（第二节方案 A/B）。  
- [ ] 确认本期是否只做只读（推荐是），以及是否记录查看日志（F15）。  
- [ ] 确认 `keyword` 是否纳入一期（否则可移到 P2 迭代）。

### 阶段 1：后端（1～1.5 天）

- [ ] 在 `MomentRepository` / `MomentService` 增加 **按 user_id + 筛选 + 分页** 的查询（复用或扩展现有 `MomentFilter`）。  
- [ ] 在 `AdminHandler` 中新增方法并注册 **`GET /v1/admin/users/:user_id/moments`**（与现有 `ListUsers` 同文件风格一致）。  
- [ ] 响应使用 **`response.Success`**，`data` 为 **`{ total, page, page_size, moments }`**（见第五节）。  
- [ ] 校验目标用户存在；管理员鉴权与现有 admin 路由一致。  
- [ ] 单元测试或接口手动测试用例（Postman/curl）。  
- [ ] 更新 Swagger / `doc/api.md`（若项目有维护）。

### 阶段 2：数据库与权限种子（0.5 天，可与阶段 1 并行部分）

- [ ] 确认 `moments` 上 `(user_id, created_at)` 联合索引是否需新增迁移（视 explain 与数据量）。  
- [ ] **权限种子**：保持 `moment` 的 `path = '/moments'`，与前端路由一致；**无需**为「用户时光」单开子菜单或改码，除非产品后续要求拆分。  
- [ ] 为「管理员」角色（非超管）配置是否默认拥有 `moment:list`（产品决策）。

### 阶段 3：管理端 Web（1～1.5 天）

- [ ] `layouts/main.vue` 增加「时光管理」菜单项 **`/moments`**。  
- [ ] 新增 `admin/src/pages/moments.vue`：筛选表单、表格、分页、详情抽屉。  
- [ ] `pages/users.vue` 增加「查看时光」跳转至 **`/moments?user_id=...`**。  
- [ ] `router/index.js` 注册 `moments` 子路由；`main.vue` 中 `menuMap` 增加 **`'/moments': '时光管理'`**（与现有 `/users` 等标题写法一致）。  
- [ ] 联调真实后端环境。

### 阶段 4：联调与验收（0.5 天）

- [ ] 按第四节验收清单走查；边界：无数据、用户不存在、超大 `content`、多图 URL。  
- [ ] （可选）补充操作日志 F15。

### 里程碑汇总

| 里程碑 | 交付物 |
|--------|--------|
| M1 | 后端接口可用 + 文档 |
| M2 | 管理端页面与菜单上线（测试环境） |
| M3 | 验收通过，可合并主干 |

---

## 九、后续迭代（不在本期）

- 管理端代用户 CRUD 时光。  
- 导出 Excel / CSV。  
- 全文检索接入 ES。  
- 违规内容标记、审核流。

---

## 十、修订记录

| 版本 | 日期 | 说明 |
|------|------|------|
| v1.0 | 2025-03-25 | 初稿：需求说明 + 开发计划 |
| v1.1 | 2025-03-25 | 与仓库对齐：管理端路由/响应结构/权限种子/文件路径统一 |
