# Hazuki

<p align="center">
  <img src="screenshots/discover.jpg" width="220" alt="发现页">
  <img src="screenshots/detail.jpg" width="220" alt="详情页">
  <img src="screenshots/favorite.jpg" width="220" alt="收藏页">
</p>

<p align="center">
  基于 Flutter 构建的 JMComic 第三方阅读器，专注于移动端阅读体验、现代化界面与可持续维护的工程结构。
</p>

---

## 项目概览

Hazuki 是一个以 **漫画阅读体验** 为核心的 Flutter 应用，当前主要面向 **Android** 使用场景。项目提供发现、搜索、详情、阅读、收藏、历史、下载、设置等完整流程，并通过本地缓存、图片处理、动态主题与源脚本热更新机制来优化实际使用体验。

项目同时保留了 Flutter 多平台工程骨架，但 `pubspec.yaml` 中已经明确说明 **当前主要目标平台为 Android**，README 中的运行与打包说明也以 Android 为主。 

## 当前能力

### 阅读与浏览
- 发现页、分区浏览、排行浏览与标签分类浏览。
- 搜索页与搜索历史记录。
- 漫画详情页、章节列表、评论查看与封面/元信息展示。
- 面向长图场景的阅读页，并对图片加载与解扰流程做了适配。

### 账号与收藏
- 登录态保持与账号会话能力。
- 收藏列表、收藏夹管理、详情页收藏操作。
- 历史记录查看、批量删除、从历史页快捷操作收藏。
- 每日签到与可选的启动自动签到。

### 本地能力
- 图片缓存与内存缓存。
- 漫画章节离线下载、暂停/继续、已下载内容管理。
- 阅读历史与搜索历史持久化。
- 缓存清理、隐私设置、显示模式与阅读设置。

### 个性化与界面
- Material 3 风格界面。
- 深色模式、OLED 纯黑、配色预设。
- 支持动态取色与漫画详情页动态配色。
- 毛玻璃风格顶部栏、偏移动端的沉浸式视觉设计。
- 中英文本地化。

### 数据与同步
- 支持云同步配置、连通性检测、上传备份与恢复最近一次备份。
- 云同步基于 HTTP/WebDAV 风格接口与 Basic Auth 配置，适合自建同步端点。

## 技术实现亮点

- **Flutter + Material 3**：主体界面与交互构建在 Flutter 上。
- **动态漫画源加载**：应用会在初始化阶段下载/加载 `jm.js` 源脚本，并支持检查云端版本与更新。
- **QuickJS 集成**：通过内置 `flutter_qjs` 在应用内执行源脚本逻辑。
- **本地缓存体系**：包括图片缓存、漫画详情缓存、发现页缓存与下载内容管理。
- **SharedPreferences 持久化**：用于保存语言、外观、历史、搜索记录和同步配置等数据。
- **Dio 网络层**：用于漫画源脚本、图片与同步相关请求。

## 项目结构

```text
lib/
├── main.dart                    # 应用入口、主题、初始化与导航骨架
├── models/                      # 数据模型
├── pages/                       # 页面与交互逻辑
│   ├── discover/                # 发现页与分区页
│   ├── comic_detail/            # 详情页组件拆分
│   ├── search/                  # 搜索页与结果页
│   └── settings/                # 外观、缓存、隐私、云同步等设置页
├── services/                    # 漫画源、云同步、下载等核心服务
├── widgets/                     # 通用 UI 组件
└── l10n/                        # 国际化资源

assets/
├── init.js                      # 源初始化脚本资源
├── avatars/                     # 头像等资源
└── stickers/loading/            # 加载动画素材

third_party/flutter_qjs/         # QuickJS Flutter 集成依赖
```

## 运行环境

### 必需条件
- Flutter SDK（需满足 `sdk: ^3.11.1` 所对应的 Dart/Flutter 版本要求）
- Android Studio 或可用的 Android SDK / adb 环境
- JDK 17（Android Gradle 配置使用 Java 17）

### Android 权限与依赖
项目当前在 Android 端声明并使用了以下关键能力：
- `INTERNET`：访问漫画源、图片与同步服务。
- `USE_BIOMETRIC`：用于隐私相关能力。
- `androidx.biometric`、`appcompat`、`core-splashscreen` 等 Android 依赖已在 Gradle 中配置。

## 快速开始

### 1. 拉取依赖
```bash
flutter pub get
```

### 2. 运行项目
```bash
flutter run -d android
```

如果你本地只有一个 Android 设备或模拟器，也可以直接执行：

```bash
flutter run
```

### 3. 构建 APK
```bash
flutter build apk
```

如果项目根目录存在 `android/key.properties`，release 构建会自动使用配置的签名；否则会回退到 debug 签名，方便本地验证。

## 首次启动说明

应用首次启动时会初始化漫画源环境：
- 尝试下载并缓存远端 `jm.js` 源脚本。
- 加载 `assets/init.js` 与源元数据。
- 如果网络不可用，会尽量使用本地缓存继续初始化。

这意味着：
- **首次启动建议保持网络可用**。
- 如果漫画源脚本更新，应用也具备检查新版本并重新下载的能力。

## 主要页面

- **首页 / 发现**：浏览推荐内容、分区、排行与分类。
- **搜索**：支持关键字检索与搜索历史。
- **详情页**：查看封面、元信息、章节、评论与收藏操作。
- **阅读页**：针对漫画图片阅读做了图片处理与缓存优化。
- **收藏**：查看收藏内容并进行排序/管理。
- **历史记录**：支持批量删除、复制漫画 ID、快捷收藏操作。
- **下载**：支持下载任务列表、暂停/继续、已下载漫画管理。
- **设置**：包含外观、显示模式、缓存、隐私、阅读、高级、线路与云同步配置。

## 云同步说明

项目内置云同步页面与服务逻辑，支持：
- 保存同步地址、用户名、密码。
- 检测连接是否可用。
- 上传当前本地备份。
- 恢复最近一次备份。

当前实现会在远端根路径下使用 `HazukiSync` 目录，并轮换维护最多 3 份备份。若你要启用该能力，建议准备一个支持 Basic Auth 的 WebDAV / HTTP 文件服务端点。

## 本地数据与缓存

项目目前会在本地保存或管理以下数据：
- 外观与语言设置。
- 阅读历史与搜索历史。
- 漫画图片缓存。
- 漫画详情缓存与发现页缓存。
- 下载任务与已下载漫画元数据。
- 云同步配置。

如果你准备二次开发，建议优先阅读：
- `lib/main.dart`
- `lib/services/hazuki_source_service.dart`
- `lib/services/manga_download_service.dart`
- `lib/services/cloud_sync_service.dart`

## 开发建议

### 常用命令
```bash
flutter analyze
flutter test
```

### 推荐阅读顺序
1. `lib/main.dart`：理解应用初始化、主题、导航与全局状态。
2. `lib/services/hazuki_source_service.dart`：理解漫画源加载、缓存、网络与脚本执行。
3. `lib/pages/`：按业务页面阅读 UI 与交互。
4. `lib/services/manga_download_service.dart` / `cloud_sync_service.dart`：理解下载与同步能力。

## Roadmap 建议

如果后续继续完善，README 之外的工程方向可以优先考虑：
- 补充更完整的自动化测试。
- 增加 CI/CD 与构建说明。
- 细化下载、同步与漫画源的错误处理可观测性。
- 为 Android 之外的平台补齐适配策略或明确裁剪。
- 为贡献者补充开发约定与提交规范。

## 致谢

本项目在设计与实现过程中参考或使用了以下项目的相关思路与资源：

- [Venera](https://github.com/venera-app/venera)
- [venera-configs](https://github.com/venera-app/venera-configs)
- [Animeko](https://github.com/open-ani/animeko)
- [flutter_qjs](https://github.com/cfug/flutter_qjs)

感谢这些优秀的开源项目提供的灵感与基础能力。

## 免责声明

本项目仅供技术研究与学习交流使用，请勿将其用于任何违法违规用途。使用者应自行承担因使用本项目而产生的一切后果。

## 许可证

本项目基于 [GPL-3.0](LICENSE) 开源，详见 [`LICENSE`](LICENSE)。
