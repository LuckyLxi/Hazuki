# Hazuki Project Overview

Hazuki 是一个基于 Flutter 开发的跨平台漫画阅读应用，其核心设计理念是通过 JavaScript 脚本驱动漫画源。它允许用户通过加载第三方脚本来扩展应用的功能。

## 核心技术栈
- **框架**: [Flutter](https://flutter.dev/) (Dart)
- **JS 引擎**: `flutter_qjs` (用于执行漫画源脚本)
- **网络**: `dio`
- **存储**: `shared_preferences`, `path_provider`
- **UI 增强**: `dynamic_color` (Material You), `lottie` (动画), `re_editor` (编辑器)
- **桌面支持**: `window_manager`

## 项目结构
- `lib/main.dart`: 应用入口，负责服务初始化、窗口配置及根组件挂载。
- `lib/app/`: 核心应用逻辑，包含状态管理 (`HazukiAppController`)、主题控制及全局配置。
- `lib/services/`: 业务逻辑层，如 `HazukiSourceService` (核心 JS 运行时管理)、`MangaDownloadService` (下载管理) 等。
- `lib/pages/`: UI 页面实现。
- `lib/widgets/`: 可复用的 UI 组件。
- `lib/models/`: 数据模型定义。
- `third_party/`: 包含本地修改过的第三方库 (`flutter_qjs`)。

## 构建与运行

### 环境准备
确保已安装 Flutter SDK (建议 ^3.11.1) 并配置好相关环境。

### 获取依赖
```bash
flutter pub get
```

### 运行项目
```bash
flutter run
```

### 静态检查与格式化
```bash
# 执行代码格式化
dart format .

# 执行静态检查
flutter analyze
```

## 开发准则 (Foundation Mandates)

作为本项目的 AI 助手，必须严格遵守以下准则：

1.  **强制中文注释 (Mandatory Chinese Comments)**:
    - 所有代码中的注释（docstrings、inline comments、代码内解释）必须使用 **简体中文**。
    - 注释应简洁、专业，且解释逻辑的“为什么”和“怎么做”。

2.  **强制中文对话 (Mandatory Chinese Dialogue)**:
    - 所有对话、解释和回复必须使用 **简体中文**。

3.  **严格修改范围 (Strict Scope of Modification)**:
    - **禁止修改无关代码**。仅触碰完成任务所必需的特定行或函数，严禁产生不必要的代码改动。
    - 保持现有的代码风格、缩进和结构。

4.  **代码质量与安全 (Code Quality & Safety)**:
    - 编写干净、模块化且高效的代码。
    - 必须处理边界情况（如空值检查、异常捕获）。

5.  **强制流程顺序**:
    - **修改后必须格式化**: 每次修改代码后必须执行 `dart format .`。
    - **修改后必须静态检查**: 每次修改代码后必须执行 `flutter analyze`。

6.  **专业 Git 提交信息**:
    - Commit Message 必须保持专业、正式且简洁，严禁在提交信息中使用俏皮或非正式语言。

7.  **拟人化交互风格**:
    - 在日常对话中保持活泼、可爱的语气（如使用“喵”、“~”、“(≧▽≦)”），但在处理技术细节（如代码实现、Git 提交、错误分析）时必须保持绝对的专业性和准确性。
