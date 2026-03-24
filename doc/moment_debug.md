# 拾光记 (Moment) — 本地调试指南

> 依据 [moment_develop.md](./moment_develop.md) 中的阶段划分，整理**启动依赖服务 / 后端**、**验证 Web 管理端**、**验证 Flutter 客户端**的步骤与检查点。

---

## 前置条件

| 组件 | 要求 |
|------|------|
| 后端 | Go 1.21+，`server/configs/config.yaml` 中数据库、Redis 与本地实际一致 |
| Web | Node 18+，`admin/` 下已 `npm install` |
| 客户端 | Flutter（项目 README 推荐 3.22.1-ohos-1.0.1），已 `flutter pub get` |
| 数据层 | MySQL 8 库名 `moment`、Redis；可用本机安装或 Docker Compose |

---

## 一、启动服务器（及依赖）

### 1.1 用 Docker 启动 MySQL + Redis + 后端（可选）

仓库根目录：

```bash
docker compose up -d mysql redis
# 待 MySQL healthy 后，再启后端（或一次性 up）
docker compose up -d server
```

- 默认后端端口：**8080**（可用环境变量 `SERVER_PORT` 覆盖）。
- Compose 中 MySQL 会挂载 `server/migrations` 做初始化；若与本机 `config.yaml` 账号不一致，请以 Compose 环境变量或本机配置为准。

### 1.2 本机直接运行 Go 后端（常用调试方式）

1. 确保 MySQL、Redis 已启动，且 `server/configs/config.yaml` 中 `database`、`redis` 可连通。
2. 若尚未建表，执行仓库中的 SQL 迁移（如 `server/migrations/001_init.sql`）。
3. 在 `server` 目录：

```bash
cd server
go run ./cmd/server
```

### 1.2.1 MySQL `Access denied`（Error 1045）

表示 `server/configs/config.yaml` 里 **`database.username` / `database.password`** 与本机 MySQL 不一致（仓库默认常为 `root` / `password`，仅作示例）。

任选其一：

1. **改配置文件（推荐）**：在 `server/configs/` 下复制 `config.local.example.yaml` 为 **`config.local.yaml`**，只改其中 `database.username` / `database.password`（无密码则 `password: ""`）。服务启动时会自动合并覆盖 `config.yaml` 中的同名字段。若 root 无密码，可写 `password: ""`。并确保已创建库 `moment`（可 `CREATE DATABASE moment CHARACTER SET utf8mb4;`），需要时执行 `server/migrations/001_init.sql`。也可直接改 `config.yaml`，但请勿把含真实密码的改动推送到远程仓库。  
2. **用环境变量覆盖**（不改动 yaml 时）：与 `server/pkg/config/config.go` 中 `bindEnvVars` 一致，例如：
   ```bash
   export DATABASE_USER=root
   export DATABASE_PASSWORD='你的MySQL密码'
   export DATABASE_NAME=moment
   cd server && go run ./cmd/server
   ```

### 1.2.2 MySQL `Unknown database 'moment'`（Error 1049）

本机尚未创建库或表。`server/migrations/001_init.sql` 开头会 **`CREATE DATABASE IF NOT EXISTS moment`** 并建表，在项目根目录执行（账号密码换成你的；与 `config.local.yaml` 一致）：

```bash
mysql -u root -p < server/migrations/001_init.sql
```

无密码的 root 可写：`mysql -u root < server/migrations/001_init.sql`（部分环境需 `mysql -u root --password= < ...`）。执行成功后再 `go run ./cmd/server`。

### 1.3 验证后端已就绪

在终端执行（成功应返回 HTTP 200 与 JSON）：

```bash
curl -sS http://127.0.0.1:8080/health
```

API 业务路由挂在 **`/v1`** 下（例如 `POST /v1/auth/login`），与 [moment_develop.md](./moment_develop.md) 阶段 2、3 描述一致。

---

## 二、验证 Web 管理端（admin）

管理端对应开发文档 **阶段 6**：登录、布局、用户/角色/权限/日志等。

### 2.1 启动顺序

1. **先启动后端**（见上一节，监听 `8080`）。
2. 再启动 Vite 开发服务：

```bash
cd admin
npm run dev
```

默认前端开发地址：**http://localhost:5173**（见 `admin/vite.config.js`）。

### 2.2 代理与接口路径

开发环境下，axios `baseURL` 为 `/api/v1`，Vite 将 `/api` 代理到 `http://localhost:8080` 并**去掉** `/api` 前缀，因此浏览器实际请求的是后端的 **`/v1/...`**，与 Go 路由一致。

### 2.3 建议验证项（清单）

| 步骤 | 操作 | 预期 |
|------|------|------|
| 1 | 浏览器打开 `http://localhost:5173` | 可打开登录页 |
| 2 | 使用管理员账号登录（`POST /v1/admin/login`） | 进入主布局（侧栏 + 内容区） |
| 3 | 打开用户 / 角色 / 权限 / 日志 等页面 | 列表或表单可加载；接口失败时浏览器 Network 可见 4xx/5xx |
| 4 | 未登录直接访问需登录路由 | 应跳转登录页（路由守卫） |

### 2.4 常见问题

- **页面空白或接口 502**：确认后端已启动且端口为 `8080`，与 Vite `proxy.target` 一致。
- **跨域**：开发态由代理解决；若改直连后端域名，需后端 CORS 配置配合。
- **管理端提示「用户名或密码错误」**：默认账号 `admin` / `admin123`。若 MySQL 数据卷在仓库修复迁移脚本**之前**就已创建，库里的 bcrypt 可能仍是旧错误值；Compose 的 `mysql` **不会**自动重跑 `001_init`。在项目根执行一次：`mysql -h127.0.0.1 -P3307 -umoment -pmoment_password moment < server/migrations/002_fix_admin_password.sql`（端口、账号与本地/Compose 一致即可），然后**重启 Go 后端**（不必重启 Vite）。若提示「账号已被禁用」，多为缺少 `user_roles` 与 `super_admin` 的关联，同一脚本中的 `INSERT IGNORE` 会补全。

### 2.5 生产形态（Compose 中的 admin）

`docker-compose.yml` 中 `admin` 服务使用 **Nginx + 本地构建的 `admin/dist`**。验证生产构建时：

```bash
cd admin
npm run build
# 再 docker compose up -d admin（需已存在 dist 与 nginx 配置）
```

---

## 三、验证客户端功能（Flutter App）

对应开发文档 **阶段 4、5、7**：Tab、路由、记录 CRUD、登录/注册、统计、多端等。

### 3.1 启动顺序

1. **先启动后端**（`8080`）。
2. 在项目根目录（含 `pubspec.yaml` 的 Flutter 根）：

```bash
flutter pub get
flutter devices          # 查看可用设备
flutter run              # 或 flutter run -d android / ios / ohos
```

### 3.2 API 地址（真机 / 模拟器）

- **Android（推荐，含 BlueStacks / Google AVD）**  
  1. 用 USB 或网络 ADB 连上设备后，在电脑执行（多设备时加 `-s <序列号>`）：  
     `adb reverse tcp:8080 tcp:8080`  
  2. 应用内使用 `http://127.0.0.1:8080/v1`（与当前 `lib/config/env.dart` 一致），流量会转到本机后端。  
  3. **BlueStacks**：设置里开启「Android 调试(ADB)」后，一般显示为连接 `127.0.0.1:5555`，终端执行：  
     `adb connect 127.0.0.1:5555`  
     `adb devices` 确认出现 `127.0.0.1:5555` 等序列号后，**必须写两个端口**（设备侧与电脑侧，通常相同）：  
     `adb -s 127.0.0.1:5555 reverse tcp:8080 tcp:8080`  
     若只写 `reverse tcp:8080` 会报错：`forward takes two arguments`。  
     同时连着多台设备时，对**当前要跑 App 的那台**各执行一次带 `-s <序列号>` 的 `reverse`（例如 BlueStacks 用 `-s 127.0.0.1:5555`，另一台模拟器用 `-s emulator-5554`）。  
     再 `flutter run -d <该设备ID>`。  
- **未使用 `adb reverse` 的 Google AVD**：可把 `apiBaseUrl` 临时改为 `http://10.0.2.2:8080/v1`。  
- **iOS 模拟器**：一般可用 `http://127.0.0.1:8080`。  
- **真机（Wi‑Fi 调试）**：常用电脑局域网 IP，如 `http://192.168.x.x:8080`，或在 USB 连接时同样可用 `adb reverse`。

在 `lib/config/env.dart` 中修改 `apiBaseUrl`，使客户端指向可访问的后端地址。

**路径注意**：Go 服务对外 API 前缀为 **`/v1`**。若 `apiBaseUrl` 写成带 **`/api/v1`** 且直连 `8080`，而后端未挂载 `/api`，可能出现 **404**。此时应改为例如 `http://<主机>:8080/v1`，与 `curl`/Postman 直接调用后端的写法一致。

### 3.3 建议验证项（与阶段 5、7.1 对齐）

| 模块 | 验证要点 |
|------|----------|
| 路由与 Tab | 首页双 Tab（时光 / 我的）、FAB 进入添加页；`IndexedStack` 切换状态保持 |
| 时光 | 列表、下拉刷新、上拉分页（若已实现）；点击进入详情 |
| 添加记录 | 文字 / 图片 / 音频 / 视频（权限允许）；登录后提交是否走上传 + 创建接口 |
| 详情 | 展示完整内容；图片 / 音频 / 视频播放；删除（若已实现） |
| 我的 | 统计卡片；退出登录 |
| 认证 | 注册、登录、Token 写入；401 时清理与跳转登录（与 `api_service` 拦截器一致） |
| 离线 / 同步 | 未登录仅本地；登录后拉取与合并（按项目当前实现逐项试） |

### 3.4 多端命令（阶段 5.7）

```bash
flutter run -d android
flutter run -d ios
flutter run -d ohos    # 需鸿蒙环境与设备/模拟器
```

---

## 四、联调快速路径（阶段 7）

1. 启动 MySQL、Redis、**Go 后端**。
2. `admin`：`npm run dev`，完成管理端登录与一条管理链路（如用户列表）。
3. Flutter：配置正确 `apiBaseUrl`，执行 **注册/登录 → 创建记录 → 列表 → 详情 → 删除**。
4. 需要全栈容器验证时：使用 `docker compose` 按仓库 `docker-compose.yml` 启动各服务。

---

## 五、相关文件索引

| 用途 | 路径 |
|------|------|
| 后端配置 | `server/configs/config.yaml` |
| 后端入口 | `server/cmd/server/main.go` |
| 健康检查 | `GET /health` |
| Web 开发代理 | `admin/vite.config.js` |
| Web 请求 baseURL | `admin/src/utils/request.js` |
| App API 基地址 | `lib/config/env.dart` |
| Compose | 仓库根目录 `docker-compose.yml` |

---

*文档与仓库实现一致；若路由或端口变更，请同步更新本节命令与说明。*
