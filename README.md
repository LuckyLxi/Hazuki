# Hazuki

<p align="center">
  <img src="screenshots/discover.jpg" width="220" alt="发现页">
  <img src="screenshots/detail.jpg" width="220" alt="详情页">
  <img src="screenshots/favorite.jpg" width="220" alt="收藏页">
</p>

<p align="center">
  一个基于 Flutter 的 JMComic 第三方阅读器，强调阅读性能、现代化界面
</p>

---

## 项目简介

Hazuki 是一个使用 Flutter 构建的漫画阅读应用，围绕“高性能阅读体验、贴近移动端习惯的界面设计”展开。

## 功能特性

### 1. 阅读体验优化

- 面向漫画阅读场景设计的页面结构
- 图片缓存与内存缓存结合，减少重复加载
- 支持长图阅读场景下的流畅浏览
- 针对源站图片处理逻辑做了适配

### 2. 现代化 UI

- 基于 Material 3 构建
- 支持动态取色与主题切换
- 提供毛玻璃风格顶部栏与更偏移动端的沉浸式视觉体验
- 首页、发现、搜索、详情、收藏、历史等核心页面已完成

### 3. 设置与个性化能力

- 主题模式切换
- 显示模式设置
- 阅读设置
- 缓存管理
- 隐私设置
- 高级设置
- 云同步相关页面

### 4. 账号与社区相关能力

- 登录态保持
- 收藏相关能力
- 评论浏览
- 排行与分类浏览
- 历史记录管理

## 致谢

本项目在设计与实现过程中参考或使用了以下项目的相关思路与资源：

- [Venera](https://github.com/venera-app/venera)
- [venera-configs](https://github.com/venera-app/venera-configs)
- [Animeko](https://github.com/open-ani/animeko)
- [flutter_qjs](https://github.com/cfug/flutter_qjs)

感谢这些优秀的开源项目提供的灵感与基础能力。

## 免责声明

本软件仅供学习、交流与个人体验使用，不提供漫画资源，也不直接存储、上传或分发漫画内容。

软件在首次启动或更新漫画源时，可能会自动从第三方 GitHub 仓库下载漫画源脚本；相关脚本及其解析出的内容均来自第三方，版权归原作者或权利人所有。

请在遵守当地法律法规及版权要求的前提下使用本软件；因下载、使用第三方漫画源或访问相关内容产生的任何纠纷、损失或法律责任，均由使用者自行承担。


## 许可证

本项目基于 [GPL-3.0](LICENSE) 开源，详见 [`LICENSE`](LICENSE)。
