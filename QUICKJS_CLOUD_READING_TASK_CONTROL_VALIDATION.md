# 第七批：云阅读私有会话与进度上传任务化验收

日期：2026-10-22。实施基线 `dev / 5265b54e`；第六批已提交为 `c97aad1f`。实施依据为 Claude 修订版 `QUICKJS_CLOUD_READING_TASK_CONTROL_PLAN.md`，并采用用户明确的“执行时才开始 30 秒预算”口径。

## 实现范围

- 云能力、进度读取、历史刷新和进度上报贯通可选 `taskOrigin`。历史、详情进度、打开阅读器前的云位置和阅读器能力检查持有独立取消身份；详情进度监听检查与单次加载分组分开。替换、退出和销毁先隔离旧结果，再取消；UI、动画、页码、上传节流及本地存储协议保持不变。
- `SourceCloudReadingSession` 固定主 handle、source 和账号身份，实际调用绑定私有 engine。私有初始化、历史分页分别使用独立共享生产者与逐消费者订阅；最后订阅离开才停止生产者。候选加载、注册、元数据和调用的脚本身份贯通，初始化候选迟到不能发布。
- `_ready()` 仅在真实会话键变化时退役；读取不再为旧账号凭据临时创建 `login_session`，避免并发读取轮换同代次身份。真实登录事务仍负责登录标记。主运行时回退只取消目标执行，不关闭共享主 engine 或 Dio。
- 切源立即撤销云读取；私有 source store 和秘密存储事务永不提交主账号。会话关闭封闭接纳、撤销交互、停止候选与已发布 engine，等待 worker、独占宿主工作和已开始提交；content 和 runtime assembly 暴露可等待的 `whenSettled`。
- `SourceReadingProgressUploads` 在首个异步间隙前检查登录、深冻结嵌套数据、捕获实际 handle/账号、取得 `SourceServiceRuntimeLease` 并登记任务。未登录直接跳过，服务归属上传与阅读页面的取消分组分开。
- 按原 source/账号维持 FIFO；排队和执行都持有租约，退出、换章、切源后继续使用原主运行时。统一 `_retainsSource` 覆盖阅读、下载和上传，保留原实际 handle 检查与 catalog 退役释放条件，不恢复已撤销的 UI 权限。
- 单笔执行预算集中定义为 30 秒，轮到执行才启用，覆盖能力检查、脚本、Promise；排队仍接受生命周期取消。其他调用原有 `SourceTaskOrigin.workTimeout` 语义不变。超时以 `SourceTaskTimedOut` / `timedOut` 结束，不重试；独占工作收尾后释放租约并推进队列。普通失败记录为 failed，保持上报容错；结构化停止向调用方传播。
- 账号和 catalog 监听检查非活动来源；旧项不能进入新账号或替代 handle。宿主命令及延迟提交前再次核验上传账号，覆盖账号已变化但通知未到的窗口。已开始的权威写入等待收尾，不承诺回滚服务器结果。

## 分阶段回归与修复

本批新增 **24 项**回归：私有会话/共享历史 10 项、上传任务 11 项、真实私有 loader 1 项、历史页生命周期 1 项、详情进度生命周期 1 项。原有生命周期异常断言改为更精确的结构化停止类型；没有删除测试或放宽导航断言。

1. 第一阶段先完成初始化、取消、重入和隔离测试，最终 72 项通过；日志 `hazuki-stage7-phase1.log`。初期可控宿主 fixture 没有响应停止信号，导致收尾等待；修复测试替身使其响应 `context.whenStopped`，未绕过生产 drain。
2. 第二阶段历史共享及页面接线，最终 275 项通过；日志 `hazuki-stage7-phase2-final.log`。初次漏改一处测试替身的可选参数导致编译失败，已补齐。
3. 第三阶段上传/租约回归最终 85 项通过；日志 `hazuki-stage7-phase3.log`。先复现“取消排队第二项后第三项越过第一项”，修复为后继同时等待前序屏障及当前项收尾。
4. 跨生命周期测试先复现页面 scope 超时包装在切源时终止已接纳上传，执行预算改用独立计时并保留任务级结构化停止。跨层 30 项通过，日志 `hazuki-stage7-cross-lifecycle-fixed.log`；追加宿主账号写入守卫后 31 项通过，日志 `hazuki-stage7-authority.log`。
5. 复核发现详情监听能力检查与加载共用分组会被首次加载提前取消，已分开；新增回归覆盖监听存活、旧结果隔离和销毁。新测试初次误用取消信号 getter，修正为检查结构化原因后通过；日志 `hazuki-stage7-progress-lifetime.log`。

以上阶段数字是中间验证，不与最终扩大回归相加冒充独立测试总数。

## 重点场景与具体测试

以下路径均相对于 `test/`；跨层场景同时列出业务与共用宿主回归，不将共用基础测试描述为新增云接口端到端测试。

| 场景 | 对应测试文件及断言 |
|---|---|
| 历史两个消费者取消一个、分页继续；最后订阅停止；旧清理不删除新请求 | `services/source/source_cloud_reading_task_control_test.dart`：共享分页、最后订阅和同 key 新请求；`services/source/source_script_cancellation_test.dart`、`services/network_client_test.dart`：共享 HTTP 原子停止、重试等待取消 |
| `_ready()` 并发重入不撤销同代次；账号变化撤销旧订阅 | `services/source/source_cloud_reading_task_control_test.dart`：旧凭据身份稳定、并发读取、账号关闭；`services/source/source_cloud_reading_test.dart`：迟到账号结果拒绝 |
| 私有初始化和同步脚本可停止，主回退不关闭共享 engine；完整私有收尾 | `services/source/source_cloud_reading_task_control_test.dart`：单/最后初始化订阅、迟到候选、同步死循环、主回退、私有 worker 关闭；`services/source/source_runtime_loader_test.dart`：真实受控私有 loader 的 HTTP 候选取消及既有 Promise 候选关闭 |
| Promise、HTTP、交互等待、Cookie 和已开始提交收尾只结算一次 | `services/source/source_cloud_reading_task_control_test.dart`：受控 Promise；`services/source/source_cloud_reading_test.dart`：账号撤销中止私有 HTTP、丢弃暂存；`services/source/source_script_cancellation_test.dart`：HTTP/Cookie 提交 drain、迟到浏览器结果、共享宿主资源；`services/source/source_service_task_cancellation_test.dart`：交互与 Dart 提交；`services/source/source_login_storage_transaction_test.dart`：事务隔离 |
| 切源/注销/换账号/更新后旧结果隔离，存储不污染主账号 | `services/source/source_cloud_reading_test.dart`、`services/source/source_cloud_reading_task_control_test.dart`、`services/source/source_runtime_loader_test.dart`；`features/history/history_page_controller_test.dart`、`features/comic_detail/comic_detail_progress_task_lifetime_test.dart`：页面替换/销毁；`features/comic_detail/comic_detail_cloud_progress_test.dart`：不写本地进度库 |
| 云读取取消不影响上传或阅读；搜索、图片、下载兼容 | `services/source/source_cloud_reading_task_control_test.dart`：切源后云读取停止、同主 handle 上传/阅读继续；`services/source/source_search_cancellation_test.dart`、`services/source/source_image_task_cancellation_test.dart`、`services/manga_download_task_lifetime_test.dart`：独立任务/共享资源隔离 |
| 退出/切源后队列按原序执行；账号撤销停止非活动旧队列；更新新实例隔离 | `services/source/source_reading_progress_task_control_test.dart`：原 handle FIFO、取消中间项不越序、非活动账号撤销、catalog 新旧 handle 隔离、通知前写入守卫 |
| 阅读器退出立即切源，最终进度已同步接纳 | `services/source/source_reading_progress_task_control_test.dart`：接纳立即登记，阅读租约释放后仍使用原 handle；`features/reader/reader_progress_reporter_test.dart`、`features/reader/reader_progress_integration_test.dart`、`features/comic_detail/comic_detail_page_smoke_test.dart`：最终 flush 与回到详情的迟到保存 |
| 前项挂起超时，后项有完整预算；全部结束释放非活动 handle | `services/source/source_reading_progress_task_control_test.dart`：注入 250 ms 执行预算，前项永久 Promise 超时、日志 timedOut、后项独立预算、常量默认 30 秒、最终 handle 释放 |
| 三类租约共用保留判断及既有释放条件 | `services/source/source_image_task_cancellation_test.dart`：阅读/下载独立租约与 catalog；`services/source/source_reading_progress_task_control_test.dart`：上传保留、账号撤销仍保留阅读、最终释放；`services/source/source_cloud_reading_task_control_test.dart`：读取与上传/阅读不同寿命 |
| 普通失败后继续、嵌套数据冻结、未登录跳过、节流不变 | `services/source/source_reading_progress_task_control_test.dart`：failed 日志、后继执行、Map/List/null 冻结、未登录无租约任务；`services/source/source_plugins_test.dart`、`features/reader/reader_progress_reporter_test.dart`：既有插件行为及节流 |
| 冷启动/本地/仅上传声明/未登录不初始化、原始页码与缓存降级 | `services/source/source_cloud_reading_test.dart`、`features/reader/reader_cloud_restoration_test.dart`、`features/reader/reader_progress_integration_test.dart`、`features/history/history_page_controller_test.dart`、`features/comic_detail/comic_detail_cloud_progress_test.dart` |
| 创建/取消/销毁，无迟到通知和遗留运行工作 | `services/source/source_cloud_reading_task_control_test.dart`、`services/source/source_reading_progress_task_control_test.dart`：dispose/whenSettled；`features/history/history_page_controller_test.dart`、`features/comic_detail/comic_detail_progress_task_lifetime_test.dart`：信号撤销、迟到结果无通知 |

## 最终验证

| 检查 | 最终结果 |
|---|---|
| Dart 格式 | 886 文件、0 变化，通过 |
| 静态分析 | `flutter analyze --no-pub` 无问题 |
| 扩大针对性回归 | **1205 项全部通过**，55 秒 |
| 完整覆盖率 | **2090 项通过、1 项既有导航基线失败**，4 分 46 秒；生成 `coverage/lcov.info` |
| Windows debug | 通过，Flutter 报告 30.8 秒 |
| Android debug | 通过，Gradle 报告 25.9 秒 |
| `git diff --check` | 通过 |

唯一失败为 `test/features/home/home_bottom_navigation_test.dart:237` 的 `uses liquid glass surface and preserves destination taps`，厚度期望 10、实际 72.0。该测试和导航 UI 没有本批改动，没有放宽断言；**完整应用验收尚未全绿**。本批新增问题已修复，新增 24 项回归全部通过。完整套件包含保留的用户搜索栏修改，其检查通过不代表将其纳入本批提交。

按格式、分析、针对性回归、完整覆盖率、Windows、Android 的顺序执行；最后一次代码变更后的扩大回归日志为 `hazuki-stage7-targeted-final.log`，中间阶段次数不能替代最终验收。

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub test/services/source test/services/network_client_test.dart test/services/manga_download_task_lifetime_test.dart test/services/manga_download_queue_test.dart test/services/manga_download_conflict_test.dart test/services/manga_download_lifecycle_coordinator_test.dart test/features/reader test/pages/reader test/features/history test/features/comic_detail test/shared test/widgets test/features/downloads test/pages/downloads test/architecture/dependency_boundaries_test.dart --reporter expanded --concurrency 4
flutter test --no-pub --coverage --reporter expanded --concurrency 4
flutter build windows --debug --no-pub
flutter build apk --debug --no-pub
```

最终日志位于 `$env:TEMP`：`hazuki-stage7-format-final.log`、`hazuki-stage7-analyze-final.log`、`hazuki-stage7-targeted-final.log`、`hazuki-stage7-full-final.log`、`hazuki-stage7-windows-build.log`、`hazuki-stage7-android-build.log`。Windows 构建将 `D:\Visual Studio 2026\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin` 加入该进程 PATH。

两平台产物已核验；Windows Dart kernel 时间为 17:23:41，覆盖率文件时间为 17:23:11。产物为 `build/windows/x64/runner/Debug/hazuki.exe`（含配套 Dart assets）和 `build/app/outputs/flutter-apk/app-debug.apk`；Windows 同时核对 `data/flutter_assets/kernel_blob.bin`，不能只凭可能未变动的原生 EXE 时间戳判断 Dart 产物是否更新。

## 提交范围与边界

本批代码、测试、计划及交接/验收文档作为一个 Conventional Commit：`feat(source): control cloud reading sessions and progress uploads`。既有 `CLAUDE.md`、`lib/features/search/view/search_bar_shell.dart`、`test/features/search/search_bar_shell_test.dart` 保留在工作区，不纳入本批提交。没有修改现有 UI 设计、动画、原生包、依赖、assets 或 CI。

健康判定、自动恢复及最终设备验收留后续；没有新增自动重放。未修改独立 QuickJS 包，因此没有重建测试 DLL 或另跑独立包检查。Windows/Android debug 构建不替代真机交互验收。

本批提交明确限定以下 39 个文件（仓库相对路径）：

```text
QUICKJS_CANCELLATION_RECOVERY_PLAN.md
QUICKJS_CLOUD_READING_TASK_CONTROL_PLAN.md
QUICKJS_CLOUD_READING_TASK_CONTROL_VALIDATION.md
QUICKJS_HANDOFF.md
lib/app/home/home_feature_entrypoints.dart
lib/features/comic_detail/repository/comic_detail_repository.dart
lib/features/comic_detail/support/comic_detail_actions_controller.dart
lib/features/comic_detail/support/comic_detail_session_controller.dart
lib/features/comic_detail/view/comic_detail_page.dart
lib/features/history/state/history_page_controller.dart
lib/features/history/view/history_page.dart
lib/features/reader/view/reader_page.dart
lib/services/source/adapters/hazuki_source_content_adapters.dart
lib/services/source/content/source_cloud_reading.dart
lib/services/source/content/source_cloud_reading_session.dart
lib/services/source/content/source_content_operations.dart
lib/services/source/content/source_reading_progress_uploads.dart
lib/services/source/gateways/source_content_gateways.dart
lib/services/source/models/source_task.dart
lib/services/source/plugins/source_plugin_script_inspector.dart
lib/services/source/runtime/source_host_call_context.dart
lib/services/source/runtime/source_js_bridge_cookie_capability.dart
lib/services/source/runtime/source_operation_context.dart
lib/services/source/runtime/source_runtime_assembly.dart
lib/services/source/runtime/source_runtime_handle.dart
lib/services/source/runtime/source_runtime_host.dart
lib/services/source/runtime/source_runtime_load_control.dart
lib/services/source/runtime/source_runtime_loader.dart
lib/services/source/runtime/source_task_registry.dart
test/features/comic_detail/comic_detail_cloud_progress_test.dart
test/features/comic_detail/comic_detail_page_smoke_test.dart
test/features/comic_detail/comic_detail_progress_task_lifetime_test.dart
test/features/history/history_page_controller_test.dart
test/features/reader/reader_cloud_restoration_test.dart
test/features/reader/reader_progress_integration_test.dart
test/services/source/source_cloud_reading_task_control_test.dart
test/services/source/source_cloud_reading_test.dart
test/services/source/source_reading_progress_task_control_test.dart
test/services/source/source_runtime_loader_test.dart
```
