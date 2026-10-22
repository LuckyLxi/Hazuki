# 第三阶段第五批：图片共享订阅与阅读生命周期验收

日期：2026-10-22。代码基线：`dev / 728057dc`；本批实现保留在工作区，未创建提交或 PR。开始时六份 Markdown 文档及其既有修改均保留。本批没有修改 UI 外观、布局、动画、原生 QuickJS 包、依赖、JS SDK 或默认超时。

## 已接入范围

- 图片下载、图片预取、章节读取、图片准备及阅读器详情接口贯通可选 `taskOrigin`，同步更新网关、服务、适配器与测试替身。未提供 origin 的下载/保存等调用作为独立消费者保护共享生产者，没有接入下载暂停/删除。
- 图片在途映射改为 `SourceSharedRequest<Uint8List>`；生产者独立持有执行身份、调度取消信号和 GET CancelToken。取消一个消费者只解除其订阅，最后消费者退出才停止排队、脚本和网络；旧请求清理按对象身份检查，不能删除同 key 的新请求。
- 保持按实际 handle 内的 source/URL 合并、下载并发 4、阅读图片准备并发 5、现有预取窗口和优先级规则。调度等待支持排队取消与获准时取消，名额只释放一次。
- 磁盘/内存缓存意愿按仍有效消费者合并；提交前检查 handle 和登录身份。磁盘读取涉及的 touch、已接纳缓存写入及图片 HTTP Cookie 提交计入收尾；取消后不开始新提交，不回滚已经开始的写入。
- `onImageLoad`、图片配置、`transformImageBytes` 和 Promise 解析携带任务身份。取消优先于普通 hook 降级、缓存重试和章节恢复。原生 JS 宿主 HTTP 的停止认领规则没有改变。
- 图片 GET 日志关联生产者执行身份，业务日志复用现有开关和脱敏。生命周期、缓存意愿和资源清理均不依赖日志开关。

## 阅读与封面生命周期

- `SourceReaderSession` 是主 isolate 内的阅读租约；会话固定 sourceKey，章节/图片/预取按 owner/group 管理。租约、`retainOnSourceChange` 与 `serviceOwned`、UI 权限分别处理，不进入 worker wire 协议。
- A→B 切源时保留有效 A 阅读租约和当前 handle，包括空闲后发起的新请求；最后一个非活动阅读租约释放后退役该 handle。已接纳的独立共享下载仍按原运行时操作租约收尾。
- 停用、卸载或版本替换在注册表内按旧 handle 写入弱引用退役标记，拒绝取消回调重入时的新任务/租约，再关闭旧会话并退役实际旧 handle。旧会话后续调用在获取替代实例之前拒绝；旧 owner 不会停止新实例。通用 remove/recreate 没有增加全量停止。
- 章节重新加载、换章、退出、无图模式和预取窗口移动释放各自需求。无图模式保留章节读取；换章在旧路由退场动画前退役工作，同时保留已显示图片。正常取消保持静默，普通错误沿用原呈现。
- provider Future、尺寸缓存、解码许可和预取 drain 加入代次/身份保护，避免迟到结果及旧许可释放污染新章节。阅读会话的图片尺寸解析在任务内执行，不能中断的 Flutter 解码等待完成并释放 codec/image 后收尾。
- 插件原有单次章节恢复保留，每次尝试使用独立新 scope 和任务身份；外层阅读 scope 不被旧运行时退役连带取消。用户取消不触发恢复，不增加故障自动重建或操作重放。
- `WidgetImageLoadSession` 在替换、无图模式和销毁时取消旧订阅；封面预取在窗口变化、无图模式和销毁时释放自己的订阅。保留原首帧、占位、加载动画和路由效果。
- 本地离线图片不创建图源任务；云阅读私有会话、进度上传与下载服务的暂停/删除/文件收尾没有迁移。

## 实际验证

| 检查 | 本批结果 |
|---|---|
| Dart 格式 | 878 文件，0 文件变化，通过 |
| 静态分析 | `flutter analyze --no-pub`，无问题，通过 |
| 扩大针对性回归 | **1327 项全部通过**，74 秒（Flutter 测试内计时 68 秒） |
| 完整覆盖率测试 | **2041 项通过、1 项基线失败**，266 秒（Flutter 测试内计时 258 秒），生成 `coverage/lcov.info` |
| Windows debug 构建 | 通过，Flutter 构建计时 29.8 秒，命令总计 32.3 秒 |
| Android debug 构建 | 通过，Gradle 构建计时 48.8 秒，命令总计 52.9 秒 |

新增 **33 项回归**，覆盖共享订阅保留/最后订阅停止、排队与获准竞态、初始化取消、同步图片 hook/转换中断、缓存意愿、迟到完成、Cookie 提交 drain、准备任务与子订阅、阅读租约及停用/版本替换、独立下载继续、章节恢复与取消优先级、阅读代次/解码许可、预取窗口/runner、单图重试、封面与头像组件销毁及 catalog 重入接纳。

首轮扩大回归为 1017 通过、2 失败，发现重新加载时过早清空已显示 provider 缓存；已改为先失效待完成工作，收到当前章节结果后再替换显示缓存，保留原断言。中间编译失败和静态提示均已修复，最终状态以本节最后检查为准。

收尾审查补充了 catalog 取消回调重入回归，先复现新阅读租约未被拒绝，再以旧资源弱引用退役标记修复接纳窗口；相关图片、服务取消、注册表及 runtime host 组合 **49 项通过**。这项修复之后重新执行最终静态检查、扩大回归、完整覆盖率和平台构建，不能用修复前的完整套件结果追认最终代码。

导航基线断言仍按计划保留：`home_bottom_navigation_test.dart:237` 期望厚度 10，现有值 72.0。规划阶段选取的六份测试实际复验为 50 通过、1 基线失败。本批没有修改该测试及对应 UI 参数；不得据针对性测试通过宣称完整应用验收全绿。

最终完整覆盖率仅剩上述一项基线失败；修复前的完整运行是 2040 通过、同一项基线失败，另有一次先失败的 catalog 重入回归。最终代码的针对性验收通过，**完整应用验收尚未全绿**。

## 命令与日志

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub test/services/source test/services/network_client_test.dart test/features/reader test/pages/reader test/widgets test/shared test/services/manga_download_queue_test.dart test/services/manga_download_lifecycle_coordinator_test.dart test/features/comic_detail test/features/search test/features/discover test/features/favorite test/features/comments test/architecture/dependency_boundaries_test.dart --concurrency 4 --reporter expanded
flutter test --no-pub --coverage --reporter expanded --concurrency 4
$env:Path = 'D:\Visual Studio 2026\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin;' + $env:Path
flutter build windows --debug --no-pub
flutter build apk --debug --no-pub
```

最终日志使用 `%TEMP%/hazuki-stage5-*.log` 的 `format-final`、`analyze-final`、`targeted-verified`、`full-final`、`windows-build` 和 `android-build` 后缀。`targeted-first`、`targeted-final`、`new-regressions`、`retirement-regression` 和 `full` 保留中间核验记录；其中旧完整运行不能代替修复后的 `full-final`。完整测试与平台构建顺序执行。

本轮产物为 `build/windows/x64/runner/Debug/hazuki.exe`（包含配套 `data/flutter_assets`）和 `build/app/outputs/flutter-apk/app-debug.apk`；覆盖率文件为 `coverage/lcov.info`。`git diff --check` 通过；构建通过不等同于完整应用测试全绿。

独立包与原生库没有改动，未重建测试 DLL 或另跑独立包测试。本批没有执行真机/模拟器操作、其他平台构建或 Sanitizer。下载完整取消、云阅读私有会话任务化、健康判定/自动恢复与最终设备验收继续留后续。
