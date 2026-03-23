# 拾光记 (Moment)

记录生活的点滴，留住美好的时光。

一款支持文字、图片、音频、视频等多种形式的生活记录 App，可部署至 Android、iOS、鸿蒙三端。

## 功能概览

- **时光**：展示所有记录列表，支持下拉刷新
- **我的**：记录统计、设置入口
- **添加记录**：支持文字、相册/拍照、视频/录像、录音
- **详情页**：查看完整内容，支持图片展示、音频播放、视频播放，可删除记录

## 技术架构

### 技术栈

| 类别 | 技术选型 |
|------|----------|
| 框架 | Flutter 3.22.1-ohos-1.0.1（兼容鸿蒙） |
| 状态管理 | Provider |
| 本地存储 | SQLite (sqflite) |
| 媒体 | image_picker、record、audioplayers、video_player |
| 工具 | path_provider、intl、uuid、permission_handler |

### 目录结构

```
lib/
├── main.dart                 # 应用入口，Provider 根节点
├── models/
│   └── moment_record.dart    # 记录数据模型
├── providers/
│   └── moment_provider.dart  # 记录状态管理
├── services/
│   └── database_service.dart # SQLite 数据库服务
└── screens/
    ├── home_screen.dart      # 首页（底部 Tab + FAB）
    ├── moments_tab.dart      # 时光 Tab
    ├── my_tab.dart           # 我的 Tab
    ├── add_moment_screen.dart    # 添加记录
    └── moment_detail_screen.dart # 记录详情
```

### 核心实现

#### 1. 导航结构

- 底部 `BottomNavigationBar` 两个 Tab：「时光」「我的」
- 使用 `IndexedStack` 保持 Tab 状态
- 右下角 `FloatingActionButton` 进入添加记录页

#### 2. 数据模型 (MomentRecord)

- **媒体类型**：`text` / `image` / `audio` / `video` / `mixed`
- **字段**：id、content、createdAt、mediaType、mediaPaths
- `mediaPaths` 以逗号分隔存储，支持多文件

#### 3. 数据库 (DatabaseService)

- 单例模式
- 表 `moments`：id、content、created_at、media_type、media_paths
- 提供：插入、删除、更新、查询、统计（按媒体类型）

#### 4. 状态管理 (MomentProvider)

- 封装数据库操作，对外提供 CRUD
- 删除记录时同步删除本地媒体文件
- 维护 `moments` 列表和 `statistics` 统计

#### 5. 媒体处理

- **图片**：相册/相机选择，压缩后保存到应用文档目录 `media/`
- **视频**：相册/录像，最长 10 分钟
- **音频**：`record` 录音，AAC 编码，保存到 `audio/`
- **混合类型**：根据文件扩展名自动识别

#### 6. 详情页媒体展示

- 图片：`Image.file` 展示
- 音频：`audioplayers` 播放，带进度条、播放/暂停
- 视频：`video_player` 播放，点击切换播放/暂停

## 运行要求

- Flutter 3.22.1-ohos-1.0.1（鸿蒙兼容版本）
- Dart SDK >= 3.4.0

## 后端 API（可选）

本地跑 `server/` 时，MySQL 账号与 `server/configs/config.yaml` 默认不一致：复制 `server/configs/config.local.example.yaml` 为 **`server/configs/config.local.yaml`** 并填写 `database`（该文件已加入 `.gitignore`）。**首次**若报库不存在，在项目根执行：`mysql -u root -p < server/migrations/001_init.sql`。详见 `doc/moment_debug.md`。

## 快速开始

```bash
# 安装依赖
flutter pub get

# 运行（按目标平台选择）
flutter run                    # 默认设备
flutter run -d android         # Android
flutter run -d ios              # iOS
flutter run -d ohos             # 鸿蒙
```

## 多端部署

项目已配置 Android、iOS、鸿蒙（ohos）三端：

- **Android**：`android/`
- **iOS**：`ios/`
- **鸿蒙**：`ohos/`（使用 hvigor 构建）

## 版本

当前版本：1.0.0
