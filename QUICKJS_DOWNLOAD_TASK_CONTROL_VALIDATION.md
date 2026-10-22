# 第六批：下载任务取消与文件收尾验收

日期：2026-10-22。基线 `dev / f6d11c9e`，接手时工作区干净；本批代码和文档未提交。第五批已在基线，交接文档中“尚未提交”的旧描述已更正。

## 实现范围

- `MangaDownloadService` 生产 DI 显式注入任务控制，构造参数保持可选兼容，并提供文件/目录访问依赖用于可控 IO 回归。每次实际执行创建独立 group、取消信号和 `MangaDownloadRun`，收尾后才释放同 key 运行权限。
- 新增可选 `SourceDownloadSessionGateway` 与 host-only `SourceDownloadSession`，origin、章节读取、封面、图片准备及子订阅贯通下载会话。下载与阅读共同保留非活动 source handle；绑定实际 handle，catalog 先标记退役再撤销租约，旧 owner 不影响新实例。会话及取消信号不进入 worker wire，原生包未修改。
- 切源保留有效下载及其共享生产者；最后消费者退出才停止底层 GET。现有插件请求的单次章节恢复使用新任务身份和交互 scope，由 host 显式转接租约；主动取消优先，不触发恢复或瞬态重试。
- 逐 key 屏障处理暂停/恢复、同 key 重入队、删除和覆盖重下；多 key 屏障兼容历史 JM 别名且不停止其他来源。全局目录屏障先收尾旧运行，再保存路径和扫描；失败保留暂停状态，保存/扫描阶段失败回退旧路径。现有外部目录变更通知同样暂停和收尾。
- 暂停先使运行失效；公开 Future 等待源资源、共享订阅解除和已开始的 IO。再次暂停在排队的恢复之后仍生效；普通交互取消留下暂停任务。源停用/更新保留完整文件并暂停，手动恢复使用新身份。
- 图片/封面使用同目录 `.hazuki-<id>.part` 写入并发布；停止前未发布的临时文件清理，已经发布的完整图片保留供断点复用。断点只识别连续前缀，忽略 `.part` / `.tmp`。元数据按目录串行原子发布，SharedPreferences 状态串行保存；存储返回失败时抛错，不伪报成功。
- 删除任务等待运行收尾，保留已完成章节；删除失败恢复暂停任务并返回错误。删除已下载漫画先暂停相关下载，删除文件和索引后清除完成标记，任务保留供手动恢复。路径使用规范化绝对路径检查，保留来源隔离及历史 JM 目录兼容。
- `dispose` 拒绝新运行、发出取消并释放租约，`whenDisposed` 等待初始化、已开始的持久化、源资源与文件 IO，不发布迟到通知。现有 UI、动画、目录命名、图片调度/下载并发、超时、五次瞬态重试及平台后台策略保持原样。

## 回归与修复记录

本批新增 23 项回归：下载生命周期 18 项，真实图源/HTTP/运行时下载租约 5 项；另加强现有 catalog 重入回归，确认旧下载租约也无法重入接纳。

- 删除失败回归先复现任务从内存丢失（`Bad state: No element`），修复为恢复暂停任务并保留可重试状态；针对性回归通过。
- 快速“暂停→恢复→再次暂停”先复现最终状态为 downloading，修复为在串行屏障内重申暂停，保留最后命令的效力；针对性回归通过。
- 保留既有“覆盖重下期间旧任务删除、新入队仍成立”、同来源追加章节、历史目录删除、平台挂起和五次瞬态重试测试。
- 首轮扩大回归命令误包含不存在的 `test/pages/settings`，产生一项加载错误；修正目录列表后重跑。初轮分析发现格式规则提示，已修复。上述问题不与导航基线失败合并。

## 最终验证

| 检查 | 最终结果 |
|---|---|
| Dart 格式 | 880 文件、0 变化，通过 |
| 静态分析 | `flutter analyze --no-pub` 无问题 |
| 扩大针对性回归 | **1250 项全部通过**，72 秒 |
| 完整覆盖率测试 | **2064 项通过、1 项既有基线失败**，4 分 16 秒；已生成 `coverage/lcov.info` |
| Windows debug 构建 | 通过，Flutter 报告 21.1 秒 |
| Android debug 构建 | 通过，Gradle 报告 35.9 秒 |
| `git diff --check` | 通过 |

唯一完整套件失败仍为 `test/features/home/home_bottom_navigation_test.dart:237` 的 `uses liquid glass surface and preserves destination taps`：厚度期望 10、实际 72.0。相关 UI 和断言无差异，未放宽断言；**完整应用验收尚未全绿**。本批新增问题均已修复，最终针对性回归、静态分析和构建均通过。

执行顺序为最终格式/分析及针对性回归，随后完整覆盖率，再顺序执行 Windows、Android 构建。扩大回归最终日志为 `hazuki-stage6-targeted-complete.log`；此前 `targeted-final` / `targeted-verified` 的通过次数对应中间代码，不能冒充最终验收。

最终命令：

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub test/services/source test/services/network_client_test.dart test/services/manga_download_task_lifetime_test.dart test/services/manga_download_queue_test.dart test/services/manga_download_conflict_test.dart test/services/manga_download_lifecycle_coordinator_test.dart test/services/manga_download_models_test.dart test/features/reader test/pages/reader test/shared test/widgets test/features/downloads test/pages/downloads test/features/settings test/features/comic_detail test/architecture/dependency_boundaries_test.dart --reporter expanded --concurrency 4
flutter test --no-pub --coverage --reporter expanded --concurrency 4
flutter build windows --debug --no-pub
flutter build apk --debug --no-pub
```

日志位于 `$env:TEMP`：`hazuki-stage6-format-final.log`、`hazuki-stage6-analyze-final.log`、`hazuki-stage6-targeted-complete.log`、`hazuki-stage6-full-final.log`、`hazuki-stage6-windows-build.log`、`hazuki-stage6-android-build.log`。中间扩大回归另存于 `hazuki-stage6-targeted.log`、`hazuki-stage6-targeted-final.log` 和 `hazuki-stage6-targeted-verified.log`，不能替代最终结果。

默认构建产物为 `build/windows/x64/runner/Debug/hazuki.exe`（含配套 Dart assets）与 `build/app/outputs/flutter-apk/app-debug.apk`。两项产物均已重新生成；Windows 核验同时包含 `data/flutter_assets/kernel_blob.bin`，不能仅凭未变动的原生 EXE 时间戳判定 Dart 构建是否更新。

## 边界

云阅读私有会话、健康判定/自动恢复及最终设备验收未实施。未修改独立 QuickJS 包、依赖、assets 或 CI，未重建测试 DLL 或另跑独立包检查。没有真机/模拟器交互验证、其他平台构建或 Sanitizer 验证；不能用宿主测试替代设备验收。既有导航玻璃厚度断言保持原样，本轮完整应用验收仍未全绿。
