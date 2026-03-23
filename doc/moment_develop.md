# 拾光记 (Moment) - 开发步骤

> 基于 [project_develop_detail.md](./project_develop_detail.md) 拆解的具体开发步骤，按阶段与依赖顺序执行。

---

## 开发阶段总览

| 阶段 | 名称 | 预估 | 依赖 |
|------|------|------|------|
| 1 | 项目初始化与基础设施 | 1-2 天 | - |
| 2 | 后端基础框架 | 2-3 天 | 阶段 1 |
| 3 | 后端核心业务 | 2-3 天 | 阶段 2 |
| 4 | Flutter App 基础 | 2-3 天 | 阶段 2 |
| 5 | Flutter App 完整功能 | 2-3 天 | 阶段 3、4 |
| 6 | Web 管理端 | 3-4 天 | 阶段 3 |
| 7 | 联调与优化 | 2-3 天 | 阶段 5、6 |

---

## 阶段 1：项目初始化与基础设施

### 1.1 目录与仓库

- [ ] 创建根目录结构：`app/`、`server/`、`admin/`、`doc/`、`docker/`
- [ ] 若现有 `lib/` 为旧代码，迁移到 `app/lib/` 或按需废弃
- [ ] 配置 `.gitignore`（含 `node_modules`、`build`、`.env` 等）
- [ ] 建立 `develop` 分支，后续在 `feature/*` 开发

### 1.2 开发环境

- [ ] 安装 Flutter 3.22.1-ohos-1.0.1，配置 Android SDK
- [ ] 安装 Go 1.21+、Node 18+
- [ ] 安装 MySQL 8 或 PostgreSQL、Redis
- [ ] （可选）安装 Docker、Docker Compose

### 1.3 数据库初始化

- [ ] 创建数据库 `moment`
- [ ] 编写 `server/migrations/001_init.sql`：
  - `users` 表
  - `moments` 表
  - `roles`、`permissions`、`user_roles`（RBAC 基础）
  - `operation_logs` 表
- [ ] 执行迁移，验证表结构

---

## 阶段 2：后端基础框架

### 2.1 项目骨架

- [ ] `cd server && go mod init github.com/xxx/moment-server`
- [ ] 引入依赖：gin、gorm、viper、zap、golang-jwt/jwt
- [ ] 创建 `cmd/server/main.go` 入口
- [ ] 创建 `configs/config.yaml`（数据库、Redis、JWT 等）
- [ ] 实现 `pkg/config` 加载配置

### 2.2 数据库连接

- [ ] 实现 `internal/model/` 下 User、Moment 等模型
- [ ] 实现 `internal/repository/db.go` 初始化 GORM
- [ ] 配置连接池、日志

### 2.3 通用组件

- [ ] `pkg/response`：统一响应格式 `{code, msg, data}`
- [ ] `pkg/jwt`：生成、解析 Token
- [ ] `internal/middleware/auth.go`：JWT 鉴权中间件
- [ ] `internal/middleware/logger.go`：请求日志
- [ ] `internal/middleware/cors.go`：跨域

### 2.4 路由与健康检查

- [ ] 注册路由组：`/v1/auth`、`/v1/users`、`/v1/moments`、`/v1/upload`、`/v1/stats`
- [ ] `GET /health` 健康检查
- [ ] 验证 `go run ./cmd/server` 可启动

---

## 阶段 3：后端核心业务

### 3.1 认证模块

- [ ] `POST /v1/auth/register`：注册（用户名、密码、昵称）
- [ ] `POST /v1/auth/login`：登录，返回 access_token、refresh_token
- [ ] `POST /v1/auth/refresh`：刷新 Token
- [ ] 密码使用 bcrypt 加密存储
- [ ] 编写 handler、service、repository 分层

### 3.2 用户模块

- [ ] `GET /v1/users/me`：当前用户信息（需鉴权）
- [ ] `PUT /v1/users/me`：更新昵称、头像（可选）

### 3.3 记录模块

- [ ] `GET /v1/moments`：分页列表，支持 `page`、`page_size`、`user_id`（鉴权后过滤）
- [ ] `POST /v1/moments`：创建记录（content、media_type、media_paths）
- [ ] `GET /v1/moments/:id`：详情
- [ ] `PUT /v1/moments/:id`：更新
- [ ] `DELETE /v1/moments/:id`：删除（校验归属）
- [ ] 实现 service 层业务逻辑、repository 层 CRUD

### 3.4 上传与存储

- [ ] 配置 MinIO 或本地文件存储
- [ ] `POST /v1/upload`： multipart 上传，支持 image/audio/video
- [ ] 返回文件 URL 或相对路径
- [ ] 限制文件大小、类型（如 图片 10MB、视频 100MB）

### 3.5 统计接口

- [ ] `GET /v1/stats`：返回记录总数、按 media_type 分组统计
- [ ] 需鉴权，仅统计当前用户

### 3.6 接口文档

- [ ] 使用 Swagger/OpenAPI 生成 API 文档
- [ ] 或编写 `doc/api.md` 记录请求/响应示例

---

## 阶段 4：Flutter App 基础

### 4.1 项目结构

- [ ] 确认 `app/` 为 Flutter 项目根目录（或从根目录 `lib/` 迁移）
- [ ] 创建 `lib/config/env.dart`（API Base URL 等）
- [ ] 配置 `pubspec.yaml`：dio、provider、go_router、sqflite、shared_preferences、path_provider

### 4.2 网络层

- [ ] `lib/services/api_service.dart`：封装 dio 实例
- [ ] 配置 baseUrl、超时、拦截器
- [ ] 请求头自动附加 `Authorization`
- [ ] 统一错误处理（401 跳转登录等）

### 4.3 本地存储

- [ ] `lib/services/database_service.dart`：sqflite 单例
- [ ] 表 `moments`：id、content、created_at、media_type、media_paths、synced
- [ ] 提供 insert、delete、update、query、count 方法
- [ ] `lib/services/storage_service.dart`：shared_preferences 存 token、用户信息

### 4.4 数据模型

- [ ] `lib/models/moment_record.dart`：id、content、createdAt、mediaType、mediaPaths
- [ ] `lib/models/user.dart`：id、username、nickname、avatarUrl
- [ ] 实现 fromJson、toJson

### 4.5 状态管理

- [ ] `lib/providers/auth_provider.dart`：登录状态、token、用户信息
- [ ] `lib/providers/moment_provider.dart`：记录列表、CRUD、统计
- [ ] 在 `main.dart` 挂载 Provider

### 4.6 路由

- [ ] 配置 go_router：`/`（首页）、`/login`、`/add`、`/detail/:id`
- [ ] 未登录访问需鉴权页面时重定向到 `/login`

### 4.7 底部 Tab 与首页框架

- [ ] `lib/screens/home_screen.dart`：BottomNavigationBar 两个 Tab
- [ ] 使用 IndexedStack 保持 Tab 状态，禁止滑动
- [ ] Tab1：时光；Tab2：我的
- [ ] 右下角 FAB 进入添加记录页

---

## 阶段 5：Flutter App 完整功能

### 5.1 时光 Tab

- [ ] `lib/screens/moments_tab.dart`：ListView 展示记录
- [ ] 每条显示文案摘要（截断）、创建时间
- [ ] 点击进入详情页
- [ ] 下拉刷新
- [ ] 上拉加载更多（分页）
- [ ] 支持本地 + 远程数据（登录后优先远程）

### 5.2 我的 Tab

- [ ] `lib/screens/my_tab.dart`：展示统计卡片（总数、各类型数量）
- [ ] 设置入口：账号、通知、隐私等（可先做占位）
- [ ] 退出登录

### 5.3 添加记录页

- [ ] `lib/screens/add_moment_screen.dart`
- [ ] 多行文本输入
- [ ] 图片：image_picker 相册/拍照，多选，压缩后保存
- [ ] 音频：record 录音，保存到本地/上传
- [ ] 视频：image_picker 选择/录像
- [ ] 提交时：先上传媒体获取 URL，再调用创建记录接口
- [ ] 未登录时仅本地保存

### 5.4 记录详情页

- [ ] `lib/screens/moment_detail_screen.dart`
- [ ] 展示完整文案
- [ ] 图片：多图展示，支持缩放（如 photo_view）
- [ ] 音频：audioplayers 播放，进度条、播放/暂停
- [ ] 视频：video_player 播放
- [ ] 编辑、删除按钮（P1）

### 5.5 登录/注册页

- [ ] 登录表单：用户名、密码
- [ ] 注册表单：用户名、密码、确认密码、昵称
- [ ] 调用 `/auth/login`、`/auth/register`
- [ ] 成功后保存 token，跳转首页

### 5.6 离线与同步

- [ ] 未登录：记录仅存本地 sqflite
- [ ] 登录后：拉取远程列表，与本地合并（按时间、去重）
- [ ] 本地未同步记录在联网后上传
- [ ] （可选）冲突策略：以最新时间为准

### 5.7 多端验证

- [ ] Android：`flutter run -d android` 全流程测试
- [ ] iOS：配置权限描述，`flutter run -d ios` 测试
- [ ] 鸿蒙：`flutter run -d ohos` 测试（如有设备/模拟器）

---

## 阶段 6：Web 管理端

### 6.1 项目初始化

- [ ] `npm create vite@latest admin -- --template vue`（或 react）
- [ ] 安装 Element Plus、Vue Router、Pinia、axios
- [ ] 配置代理指向后端 API

### 6.2 登录与布局

- [ ] 登录页：调用 `/auth/login`（或管理端专用接口）
- [ ] 主布局：侧边栏 + 顶栏 + 内容区
- [ ] 路由守卫：未登录跳转登录页

### 6.3 用户管理

- [ ] 用户列表：分页、搜索
- [ ] 新增用户、编辑用户、禁用/启用、删除
- [ ] 调用后端用户管理 API（需在阶段 3 扩展）

### 6.4 角色与权限

- [ ] 角色列表、新增/编辑角色
- [ ] 权限树勾选
- [ ] 用户分配角色
- [ ] 菜单、按钮按权限显隐

### 6.5 日志管理

- [ ] 操作日志列表：用户、动作、模块、时间、IP
- [ ] 登录日志
- [ ] 支持筛选、导出（可选）

### 6.6 系统配置

- [ ] 系统参数配置（键值对）
- [ ] 字典管理（可选）

### 6.7 后端扩展

- [ ] 实现管理端专用 API：用户 CRUD、角色 CRUD、权限、日志查询
- [ ] 管理端使用独立角色（如 admin），与 App 用户隔离

---

## 阶段 7：联调与优化

### 7.1 端到端联调

- [ ] App 登录 → 创建记录 → 列表 → 详情 → 删除 全流程
- [ ] Web 管理端用户、角色、日志流程
- [ ] 检查三端（Android/iOS/鸿蒙）核心功能

### 7.2 性能与体验

- [ ] 图片列表懒加载、缩略图
- [ ] 接口超时、重试、错误提示
- [ ] 加载态、空态、错误态 UI

### 7.3 安全

- [ ] 生产环境 HTTPS
- [ ] 敏感配置不提交仓库（.env）
- [ ] 密码、Token 存储安全

### 7.4 部署准备

- [ ] 编写 `docker-compose.yml`
- [ ] 后端 Dockerfile
- [ ] 管理端构建 `npm run build`，Nginx 静态部署
- [ ] 环境变量配置说明

---

## 检查清单（每阶段结束）

| 阶段 | 关键产出 |
|------|----------|
| 1 | 目录结构、数据库表、环境可运行 |
| 2 | 后端可启动、健康检查通过、中间件生效 |
| 3 | 认证、记录、上传、统计接口可用 |
| 4 | App 可运行、Tab 切换、路由、网络层就绪 |
| 5 | 记录列表、详情、添加、登录、多端可测 |
| 6 | 管理端登录、用户/角色/日志管理可用 |
| 7 | 全流程联调通过、部署文档就绪 |

---

*文档版本：1.0 | 基于 project_develop_detail.md*
