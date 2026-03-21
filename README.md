# Hazuki

一个基于 Flutter 开发的高颜值、高性能漫画阅读器，专为 JMComic 资源提供极致的阅读体验。

## ✨ 特性

- **极致设计**：界面设计参考 [Animeko](https://github.com/open-ani/animeko)，兼顾现代感与实用性。
- **动态取色 (Material You)**：漫画详情页支持根据封面图自动转换系统主题色，带来沉浸式的视觉体验。
- **智能进度记录**：自动记录每一部漫画的阅读进度，支持从详情页“继续阅读”，多话漫画无缝衔接。
- **完善的历史管理**：本地持久化保存阅读历史，支持多选删除、一键清理。
- **高性能阅读器**：支持全方位双指缩放、平移，针对大图加载进行了优化，告别闪烁感。
- **引擎驱动**：通过 JavaScript 脚本实现数据加载与解析，逻辑上参考了 [Venera](https://github.com/venera-app/venera) 的相关实现。
- **隐私与安全**：内置隐私模式（防截屏、后台模糊），保护你的阅读私密空间。

## 🛠️ 技术栈

- **Core**: Flutter (Dart)
- **Engine**: JavaScript 解释器 (由 `flutter_qjs` 驱动)
- **Storage**: `shared_preferences` & 文件系统缓存
- **UI Components**: Material 3 Design

## 🤝 致谢

本项目的开发离不开以下优秀开源项目的启发与帮助：

- **[Venera](https://github.com/venera-app/venera)**：参考了其登录逻辑的实现。
- **[Animeko](https://github.com/open-ani/animeko)**：参考了其出色的界面布局设计。

## 📜 开源协议

本项目采用 [GPL-3.0 License](LICENSE) 协议开源。

---

> 如果你喜欢这个项目，欢迎点一个 Star 🌟。
