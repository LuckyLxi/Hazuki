# 第八批验收：运行时健康判定与单次自动恢复

更新时间：2026-10-22。基线 `dev / f7181f4b`。范围依据 [第八批计划](QUICKJS_RUNTIME_HEALTH_RECOVERY_PLAN.md)。本批已提交为 `5cd27539`。

## 实现结论

- 运行时故障有独立类型 `SourceRuntimeFailed`（`internalJob`、`workerError`、`exitedWithoutCleanup`、`probeFailed`、`bootstrap`），在途与之后的新调用都带 taskId 结束；正常关闭不产生故障。
- 故障以 `runtimeFailed` 撤销交互并携带故障对象；任务终态为 `failed`，不再被映射为 `runtimeClosed`/`user` 静默取消。
- worker 在原生中断 JS 后合并执行只读探针（内部求值 `0`、worker 持有租约的 work 在原生侧存在）；探针失败及 batch 收尾异常都转为故障并正常关闭。
- handle 监听已发布实例的故障，清除已死引用；活动来源立即在原 handle 单次重建，非活动来源惰性重建；崩溃循环锁存，仅显式手动入口解除；网络恢复不绕过锁存。
- 已接纳上传、运行中下载、搜索自动重试、插件请求的详情/章节重建都不把故障工作重放到新实例；云阅读私有实例故障后丢弃并按需新建。

## 第 0 步前提核对

原生 `taskCount` 含主 isolate 已注册但 worker 尚未收到的 token，`workCount` 含内部 Promise work，与 worker 表**不能精确比较**，因此不用于探针。探针只使用可精确判定的不变量，不设近似阈值。没有修改独立 QuickJS 包。

## 重点场景与具体测试

| 场景 | 测试 |
|---|---|
| 不可归属作业失败：在途/新调用得到带 taskId 的故障，`whenFailed`/`failure` 一致，scope 原因为 `runtimeFailed`，原生实例释放 | `services/source/source_script_worker_failure_test.dart`：internal job failure |
| 正常关闭不报告故障 | 同上：normal close never reports a runtime failure |
| 中断后单次健康探针，运行时 ID 不变且可用；排队取消不探针；探针失败转故障 | 同上：interrupted computation、cancelled while queued、failed probe |
| isolate 未捕获错误、未清理退出 | 同上：workerError、exit without cleanup |
| 活动来源故障：原 handle 单次重建、新 runtimeId、被中断操作不重放 | `services/source/source_runtime_health_test.dart`：rebuilt once on the same handle |
| 页面 scope 收到故障；任务日志终态 failed、无停止原因 | 同上：page scope receives the runtime failure |
| 并发新调用共享一次重建 | 同上：concurrent new calls share one rebuild |
| 非活动来源惰性重建（日志 `deferred`） | 同上：non-active retained source is rebuilt lazily |
| 已退役实例迟到故障被忽略 | 同上：late failure from a retired engine is ignored |
| 崩溃循环锁存、网络恢复跳过、手动重试解除 | 同上：crash loop latches until an explicit manual retry |
| 成功业务操作重置单次额度 | 同上：successful business operation restores the allowance |
| 正常取消不重建 | 同上：normal cancellation never rebuilds the runtime |
| 故障前接纳的上传不转移到新实例，新接纳项使用新实例 | `services/source/source_reading_progress_task_control_test.dart`：runtime failure ends admitted uploads |
| 图片准备/章节加载故障暂停下载，不计瞬态重试 | `services/manga_download_task_lifetime_test.dart`：两项 runtime failure |
| 搜索故障显示错误且不自动重试，普通错误仍重试 | `features/search/search_results_controller_test.dart`：runtime failure is shown without automatic retry |
| 故障绕过插件请求的详情重建 | `services/source/source_comic_details_cancellation_test.dart`：runtime failure bypasses plugin-requested recreation |
| 云阅读私有实例故障后丢弃并新建，主运行时不受影响 | `services/source/source_cloud_reading_task_control_test.dart`：failed private instance is discarded |

本批新增 21 项回归。测试与实现同批编写（故障注入入口为本批新增，无法在旧代码上原样运行）；为确认测试能捕获原缺陷，逐项做了变异核对：去掉 loader 的 `watchEngine`、registry 的 `runtimeFailed` 跳过、上传接纳实例检查、搜索故障跳过、详情故障跳过，或把下载两文件、云阅读会话恢复为 `f7181f4b` 版本后，对应测试均失败；恢复后通过。HEAD 版云阅读会话在私有实例故障后触发空值断言崩溃，属本批修复的既有缺陷。

## 最终验证

| 检查 | 结果 |
|---|---|
| Dart 格式 | 889 文件、0 变化，通过 |
| 静态分析 | `flutter analyze --no-pub` 无问题 |
| 扩大针对性回归（第七批集合加 `test/features/search`） | **1279 项全部通过**，1 分 14 秒 |
| 完整覆盖率 | **2111 项通过、1 项既有导航基线失败**，4 分 24 秒；生成 `coverage/lcov.info` |
| Windows debug | 通过，Flutter 报告 138.2 秒 |
| Android debug | 通过，Gradle 报告 21.3 秒 |
| `git diff --check` | 通过 |

唯一失败仍为 `test/features/home/home_bottom_navigation_test.dart` 的 `uses liquid glass surface and preserves destination taps`，期望 10、实际 72.0；本批未改导航 UI 或断言，**完整应用验收尚未全绿**。2111 = 第七批 2090 + 本批 21。完整套件包含保留的用户搜索栏修改，不代表将其纳入本批。

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub test/services/source test/services/network_client_test.dart test/services/manga_download_task_lifetime_test.dart test/services/manga_download_queue_test.dart test/services/manga_download_conflict_test.dart test/services/manga_download_lifecycle_coordinator_test.dart test/features/reader test/pages/reader test/features/history test/features/comic_detail test/features/search test/shared test/widgets test/features/downloads test/pages/downloads test/architecture/dependency_boundaries_test.dart --reporter expanded --concurrency 4
flutter test --no-pub --coverage --reporter expanded --concurrency 4
flutter build windows --debug --no-pub
flutter build apk --debug --no-pub
```

日志位于 `$env:TEMP`：`hazuki-stage8-format-final.log`、`hazuki-stage8-analyze-final.log`、`hazuki-stage8-targeted-final.log`、`hazuki-stage8-full-final.log`、`hazuki-stage8-windows-build.log`、`hazuki-stage8-android-build.log`。Windows 构建将 `D:\Visual Studio 2026\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin` 加入进程 PATH。产物 `build/windows/x64/runner/Debug/hazuki.exe`（`data/flutter_assets/kernel_blob.bin` 时间 18:19:46）与 `build/app/outputs/flutter-apk/app-debug.apk`（18:22:22）。

## 未验证边界

- 未做真机/模拟器交互；故障通过测试注入命令触发，未在真实插件中复现原生内部故障。
- 失败状态文本沿用 `source_init_failed:source_runtime_failed:<kind>`，未新增文案；其在各页面的实际展示需在第九批设备验收中确认。
- 失败的自动重建若在候选初始化阶段再次崩溃，按既有初始化失败语义由后续调用按需重试（锁存只覆盖“已发布实例”的连续故障）。
- 未修改原生包，因此未重建测试 DLL、未跑独立包检查；未做 Sanitizer 或其他平台构建。

## 第九批设备验收清单

1. 正常阅读、搜索、详情、下载、云阅读与进度上传各走一遍，确认无回归。
2. 搜索/阅读中途退出页面（取消），确认运行时不重建（日志无 `Source runtime failure`）。
3. 对活动来源注入 `internalJob` 故障（应用内没有注入入口，需在 debug 构建临时调用 `SourceScriptEngine.debugInjectFault`，该方式须先经用户同意）：确认状态卡短暂失败后回到就绪、正在进行的页面显示错误而非空白、点重试可继续。
4. 连续两次注入（中间无成功操作）：确认锁存后状态卡重试可解除，网络断开再恢复不会自动重建。
5. 故障时有下载在跑：确认任务变为暂停且可手动恢复；有进度上传排队：确认不在新实例补发。
6. 切到其他来源阅读后令旧来源故障：确认下一次使用旧来源时才重建。
7. 记录 Android 与 Windows 各一次完整结果，以及导航基线断言的处理决定。

## 提交范围

已作为一个 Conventional Commit 提交：`5cd27539 feat(source): detect runtime failures and recover once`，共 30 个文件；排除用户既有的 `CLAUDE.md`、`lib/features/search/view/search_bar_shell.dart`、`test/features/search/search_bar_shell_test.dart` 及 `QUICKJS_HANDOFF.md`。下列为本批实施文件清单，其中交接文档按用户后续要求另行提交：

```text
QUICKJS_RUNTIME_HEALTH_RECOVERY_PLAN.md
QUICKJS_RUNTIME_HEALTH_RECOVERY_VALIDATION.md
QUICKJS_HANDOFF.md
QUICKJS_CANCELLATION_RECOVERY_PLAN.md
lib/features/search/state/search_results_controller.dart
lib/services/manga_download/manga_download_files.dart
lib/services/manga_download/manga_download_queue_support.dart
lib/services/source/comic/comic_details_capability.dart
lib/services/source/content/source_cloud_reading_session.dart
lib/services/source/content/source_reading_progress_uploads.dart
lib/services/source/interaction/source_ui_service.dart
lib/services/source/models/source_task.dart
lib/services/source/runtime/source_operation_runner.dart
lib/services/source/runtime/source_runtime_assembly.dart
lib/services/source/runtime/source_runtime_diagnostics_operations.dart
lib/services/source/runtime/source_runtime_handle.dart
lib/services/source/runtime/source_runtime_health.dart
lib/services/source/runtime/source_runtime_host.dart
lib/services/source/runtime/source_runtime_initialization_operations.dart
lib/services/source/runtime/source_runtime_loader.dart
lib/services/source/runtime/source_runtime_recovery_operations.dart
lib/services/source/runtime/source_script_engine.dart
lib/services/source/runtime/source_script_worker.dart
lib/services/source/runtime/source_task_registry.dart
test/features/search/search_results_controller_test.dart
test/services/manga_download_task_lifetime_test.dart
test/services/source/source_cloud_reading_task_control_test.dart
test/services/source/source_comic_details_cancellation_test.dart
test/services/source/source_reading_progress_task_control_test.dart
test/services/source/source_runtime_health_test.dart
test/services/source/source_script_worker_failure_test.dart
```

`QUICKJS_HANDOFF.md` 在本批开始前已有未提交的交接更新，未纳入 `5cd27539`；用户随后要求提交剩余改动，交接文档另行提交。
