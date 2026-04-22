# 拾光记 (Moment)

拾光记是一个全栈生活记录项目，包含 Flutter 客户端、Go 后端和 Vue 管理端。客户端支持文字、图片、音频、视频和混合媒体记录，并提供本地离线保存、登录态同步、媒体上传和云端拉取合并。

## 仓库组成

| 目录 | 说明 |
| --- | --- |
| `lib/` | Flutter App 主代码，含认证、记录 CRUD、本地 SQLite、媒体展示和同步逻辑 |
| `server/` | Go + Gin 后端，提供认证、时光、上传、用户和管理端 API |
| `admin/` | Vue 3 + Element Plus 管理端，提供用户、时光、角色、权限、日志页面 |
| `server/migrations/` | MySQL 初始化脚本 |
| `doc/` | 调试、部署、开发和待完善清单文档 |
| `test/` | Flutter 侧 smoke test 和 SQLite 迁移/隔离测试 |

## 当前能力

- 客户端支持注册、登录、refresh token 自动刷新、退出登录。
- 本地 SQLite 已按 `user_id` 隔离，并包含 `server_id`、`sync_status`、`last_synced_at` 等同步元数据。
- 记录支持文字、图片、音频、视频、混合媒体类型；同步到服务端后管理端可预览媒体。
- App 登录后会拉取云端记录并按 `server_id` 合并；本地未同步记录可上传，服务端记录的本地修改会走更新接口。
- 后端用户侧时光接口已要求认证并校验归属；管理端接口已使用管理员鉴权边界。
- 后端本地上传会返回可访问 URL，并通过 `/uploads/**` 暴露静态资源。
- 管理端支持按用户查询时光，可按媒体类型、关键词、时间和软删除状态筛选。

## 本地开发

### 前置要求

| 组件 | 建议版本 / 说明 |
| --- | --- |
| Flutter | Dart SDK `>=3.4.0 <4.0.0`，项目可运行 Android、iOS、鸿蒙和桌面调试环境 |
| Go | 1.21+ |
| Node.js | 18+ |
| Docker | Docker Compose v2，用于 MySQL 和 Redis |

### 标准启动顺序

1. 启动依赖服务：

```bash
cp .env.example .env
docker compose up -d mysql redis
```

2. 启动 Go 后端：

```bash
cd server
go run ./cmd/migrate
go run ./cmd/server
```

后端默认监听 `http://127.0.0.1:8080`，健康检查为 `GET /health`，业务 API 前缀为 `/v1`。

3. 启动管理端：

```bash
cd admin
npm install
npm run dev
```

开发地址默认是 `http://localhost:5173`。默认管理员账号来自初始化脚本：`admin / admin123`。

4. 启动 Flutter 客户端：

```bash
flutter pub get
flutter run
```

客户端 API 地址在 `lib/config/env.dart`。Android 真机或模拟器推荐先执行 `adb reverse tcp:8080 tcp:8080`，再使用默认的 `http://127.0.0.1:8080/v1`。

## 构建与验证

常用检查命令：

```bash
flutter analyze
flutter test

cd server
go test ./...
go run ./cmd/migrate

cd admin
npm run build
```

全栈容器模式需要先构建管理端静态文件：

```bash
cd admin
npm run build
cd ..
docker compose up -d
```

## 配置说明

- `server/configs/config.yaml` 默认连接 Docker Compose 中的 MySQL：`moment / moment_password`。
- 如果连接本机或外部 MySQL，复制 `server/configs/config.local.example.yaml` 为 `server/configs/config.local.yaml` 并覆盖数据库配置。
- `.env` 仅供 Docker Compose 读取，生产环境必须替换 `JWT_SECRET`、数据库密码等敏感配置。
- Redis 当前主要是环境和配置预留，业务代码尚未深度依赖；短期可以按 Compose 标准启动，后续适合承载 token 黑名单、限流或缓存。

## 已知限制

- 成功响应仍统一使用 `{ code, msg, data }` 包装；错误响应已回归标准 HTTP 状态码，但客户端和管理端短期内仍保留对 `body.code` 的兼容解析。
- 同步冲突策略仍是基础版：本地未同步记录优先保留，已同步记录以远端更新覆盖；多端并发编辑还没有冲突队列。
- 媒体删除策略尚未做远端资产清理、引用计数或延迟回收。
- 管理端已有角色/权限页面和管理员边界，但按钮级、菜单级、接口权限码三层闭环还需继续细化。

## 相关文档

- `doc/moment_debug.md`：本地联调、端口、真机访问和常见问题。
- `doc/deploy.md`：Docker Compose 部署说明。
- `doc/moment_develop.md`：开发阶段拆解。
- `doc/待完善清单.md`：当前风险点和后续优先级。
