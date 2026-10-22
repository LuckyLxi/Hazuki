# QuickJS 后台执行与取消机制交接

更新时间：2026-10-22。项目：`D:\Project\Hazuki`，Windows / PowerShell。

## 新对话接手入口（第八批，优先）

第八批 **运行时健康判定与单次自动恢复** 已提交为 `5cd27539 feat(source): detect runtime failures and recover once`，实施前基线为 `dev / f7181f4b`。计划见 [第八批计划](QUICKJS_RUNTIME_HEALTH_RECOVERY_PLAN.md)，结果、场景映射、提交文件清单和第九批设备验收清单见 [第八批验收](QUICKJS_RUNTIME_HEALTH_RECOVERY_VALIDATION.md)。

`CLAUDE.md`、搜索栏、阅读器章节面板、作者列表及本交接文档的既有修改未纳入第八批提交；用户随后要求提交剩余改动，按内容分别提交。

提交前复验：格式 889 文件零变化、静态分析通过；第八批 72 项针对性回归通过，剩余 UI 改动及架构检查共 149 项通过。本次未重跑完整套件或平台构建，下方完整验收结果为第八批实施时记录。

最新验证：格式 889 文件零变化、静态分析通过、1279 项针对性回归通过；完整覆盖率 **2111 项通过、1 项基线失败**（`home_bottom_navigation_test.dart`，期望 10、实际 72.0）；Windows debug 138.2 秒、Android debug 21.3 秒构建通过。**完整应用验收尚未全绿**；未做真机交互，未改原生包。

第八批关键入口：

- `lib/services/source/models/source_task.dart`：`SourceRuntimeFailed` / `SourceRuntimeFailureKind`。
- `lib/services/source/runtime/source_script_engine.dart`、`source_script_worker.dart`：故障区分、`whenFailed`、`failed` 的 `kind`、中断后合并探针、release 中忽略的 `debugInjectFault`。
- `lib/services/source/runtime/source_runtime_handle.dart`、`source_runtime_health.dart`、`source_runtime_loader.dart`、`source_runtime_assembly.dart`：发布后监听、单次额度、锁存与恢复调度。
- `source_task_registry.dart`、`source_operation_runner.dart`、`interaction/source_ui_service.dart`：`runtimeFailed` 不映射为取消。

第八批不要改回的边界：

- 故障不是取消：`runtimeFailed` scope 原因不得转成 `requestStop`；故障先于插件请求重建、搜索自动重试、下载瞬态重试识别。`rethrowSourceOperationStop` 刻意未加入故障，以保留普通错误回退。
- 故障监听必须与实例处于同一错误 zone（不要改用 `Zone.root`），否则 `whenClosed` 的错误会成为未捕获错误。
- 恢复只在原 handle、经现有共享初始化进行；不调用 `recreateSourceRuntime`，不给 catalog/通用 `remove` 加全量停止；旧实例迟到故障按身份忽略。
- 锁存只由状态卡重试、本地重新加载、手动下载解除；网络恢复是自动入口，不能绕过。
- 探针不使用原生 task/work 总数比较（含主 isolate 预注册与内部 Promise work）。

下一步：第九批按验收清单做设备验收与总收尾。

## 第七批交接核对（历史）

第七批已经提交，当前 HEAD 为 **`dev / f7181f4b feat(source): control cloud reading sessions and progress uploads`**，实施前基线是 `5265b54e`。不能因代码不在工作区 diff 中就判断第七批尚未实现；完整改动可用 `git show --stat f7181f4b` 或 `git diff 5265b54e f7181f4b -- lib test` 查看。第七批为一个提交，包含 39 个文件，没有创建 PR 或推送。

本次交接重新核对了 git 状态、提交和验收记录，**只更新本交接文档，没有重新执行格式、静态分析、测试或构建**。下方测试数字均为第七批实现完成时的实际结果，不能算成本次复验。

交接时须保留的未提交改动：

```text
CLAUDE.md
lib/features/search/view/search_bar_shell.dart
test/features/search/search_bar_shell_test.dart
QUICKJS_HANDOFF.md                       # 本次交接更新
```

前三份是用户既有修改，未纳入第七批提交；不得覆盖、回退或顺带提交。本次文档更新也尚未另行提交。用户没有授权修改现有 UI 设计或动画，不得通过调整导航 UI 或放宽断言消除基线失败。

建议新对话按以下顺序接手：

1. 读 `AGENTS.md`、本节、第七批修订计划和验收记录，再核对 `git status --short`、`git log -3 --oneline`，识别用户是否有新的改动。
2. 对照 `QUICKJS_CLOUD_READING_TASK_CONTROL_PLAN.md` 与 `QUICKJS_CLOUD_READING_TASK_CONTROL_VALIDATION.md` 核对已实现范围；验收记录的“重点场景与具体测试”表列出每项对应测试，末尾明确列出本批 39 个文件。
3. 当前未完成范围是**运行时健康判定、自动恢复及最终设备验收**。下一批先结合 `QUICKJS_CANCELLATION_RECOVERY_PLAN.md` 核对代码，再形成可审阅计划；本次交接请求没有授权直接新增自动恢复或自动重放。
4. 验证按改动影响范围选择针对性测试；必要时再执行完整覆盖率和顺序平台构建。若修改 `third_party/pub_overrides/quickjs_engine`，须补齐独立包构建、格式、分析和测试；第七批没有改原生包，也没有重跑独立包检查或真机交互验收。

第七批关键代码入口：

- `lib/services/source/content/source_cloud_reading.dart`：会话键、读取任务、共享历史、后台刷新及展示缓存降级。
- `lib/services/source/content/source_cloud_reading_session.dart`：共享私有初始化、候选发布、实际私有 engine、暂存事务丢弃及可等待关闭。
- `lib/services/source/content/source_reading_progress_uploads.dart`：同步接纳、深冻结、原 handle FIFO、执行预算、账号核验和租约释放。
- `lib/services/source/runtime/source_runtime_host.dart`、`source_task_registry.dart`、`source_operation_context.dart`：三类租约、实际资源绑定、结构化停止与执行阶段超时。
- `lib/services/source/runtime/source_runtime_load_control.dart`、`source_runtime_loader.dart`、`source_host_call_context.dart`、`source_js_bridge_cookie_capability.dart`：候选脚本身份、宿主写入前账号核验及资源收尾。
- `lib/features/history/state/history_page_controller.dart`、`lib/features/comic_detail/support/comic_detail_session_controller.dart`、`comic_detail_actions_controller.dart`、`lib/features/reader/view/reader_page.dart`：页面读取寿命；最终进度 flush 仍由服务持有。

不要改回的边界：

- 上传必须在首个异步间隙前完成登录检查、冻结、实际 handle 捕获、租约和任务登记；**默认 30 秒仅从轮到执行开始计时**，排队仍可取消。不能把预算重新挂到已撤销的页面交互 scope，否则切源会误停已接纳上传。
- FIFO 后继要等待前序屏障及当前项收尾；取消中间排队项不能让后项越过仍执行的前项。超时和普通失败都不重放，结构化停止不得吞掉。
- `_ready()` 不为旧账号凭据临时生成登录标记，不因同键并发读取退役；真实登录事务保留其登录标记职责。
- 云读取切源立即停止；阅读、下载及已接纳上传各有独立租约。正常取消不重建主 runtime，不直接关闭其他消费者仍使用的 engine/Dio；通用 `remove` / `recreateSourceRuntime` 不新增全量停止。
- 详情进度监听的能力检查与单次进度加载使用不同取消分组；替换和销毁先隔离旧结果再取消。
- 账号变更检查涵盖非活动来源及宿主提交前的通知空窗；旧 owner 不得影响替代实例。私有暂存永不提交主账号，已开始的权威写入等待收尾，不承诺回滚服务器结果。

最新验证结论：格式 886 文件零变化、静态分析通过、1205 项针对性回归通过；完整覆盖率 **2090 项通过、1 项基线失败**。Windows debug 30.8 秒、Android debug 25.9 秒构建通过。唯一失败仍为 `test/features/home/home_bottom_navigation_test.dart:237`，厚度期望 10、实际 72.0，**完整应用验收尚未全绿**。完整命令、日志名称、产物和未验证边界见第七批验收记录。

## 第七批最新状态（优先）

第七批 **云阅读私有会话与进度上传任务化** 按 Claude 修订版计划实施，已提交为 `f7181f4b`，基线为 `dev / 5265b54e`。第六批已提交为 `c97aad1f`，此前“尚未提交”的描述已更正。第七批最终结果和重点场景测试映射见 [第七批验收记录](QUICKJS_CLOUD_READING_TASK_CONTROL_VALIDATION.md)，范围依据见 [修订计划](QUICKJS_CLOUD_READING_TASK_CONTROL_PLAN.md)。

- 私有初始化和云历史按独立生产者/逐消费者共享，单个读取取消不关闭主 engine 或共享 Dio；私有实例关闭可等待。`_ready()` 只在 source、账号或实际主 handle 变化时退役；普通错误保留同会话历史缓存降级，结构化停止优先。
- 历史页、详情进度、打开阅读器前的云位置和阅读器能力检查接入生命周期。详情监听与单次读取使用不同分组。切源立即停止云读取，私有暂存存储始终丢弃；云位置不写本地进度库或 WebDAV。
- 上传在首个异步间隙前检查登录、深冻结数据、捕获实际 handle/账号、取得服务租约并登记任务。退出、换章和切源后，已接纳项继续原主运行时 FIFO，不恢复旧交互权限。统一 `_retainsSource` 管理阅读/下载/上传，原释放条件保持不变。
- **30 秒预算从该笔轮到执行时开始，排队时间不计入**；排队仍可被账号/catalog 等生命周期撤销。超时保持 `SourceTaskTimedOut` / `timedOut`，收尾后释放租约并推进后项。普通失败容错但记录 failed，结构化停止向外传播。
- 非活动账号与旧实例同样受撤销；执行及宿主提交前核验身份。content / assembly 提供 `whenSettled`，销毁后停止接纳并等待专属工作和已开始提交；服务器已接收的写入不承诺回滚。
- 本批新增 24 项回归；私有会话、共享历史、上传预算/FIFO/数据冻结、真实 loader 和页面生命周期重点场景已映射到验收文档。最终格式检查 886 文件、0 变化，静态分析无问题，**1205 项针对性回归通过**；完整覆盖率 **2090 项通过、1 项既有导航厚度断言失败**（期望 10、实际 72.0）。Windows debug（30.8 秒）、Android debug（25.9 秒）顺序构建通过；没有修改导航 UI 或断言，**完整应用验收尚未全绿**。

本批按用户要求作为一个 Conventional Commit：`feat(source): control cloud reading sessions and progress uploads`；`CLAUDE.md`、`lib/features/search/view/search_bar_shell.dart`、`test/features/search/search_bar_shell_test.dart` 是接手时的既有修改，保留并排除在本批提交之外。没有修改原生包、依赖、assets、UI 或动画，没有新增自动重放。健康判定、自动恢复及最终设备验收留后续。

接手先读 `AGENTS.md`、本节、修订计划及验收记录，再核对 `git status --short` 与 `git log -3 --oneline`。测试场景映射在第七批验收记录的“重点场景与具体测试”表；以下章节均为历史快照。

## 第六批已提交基线（历史）

第三阶段第六批 **下载任务取消与文件收尾** 已提交为 `c97aad1f feat(download): implement cancellable download tasks and file finalization`。以下验证描述第六批实施时点；当时基线为 `f6d11c9e`，工作区干净。最新验证见 `QUICKJS_DOWNLOAD_TASK_CONTROL_VALIDATION.md`，第五批及以下章节为历史基线。

- 下载服务显式注入任务控制，每个 storageKey 的每次执行使用新 group、取消信号和下载会话；章节、封面、图片准备及原始图片子订阅贯通 origin。阅读与下载租约独立，切源保留有效下载，停用/更新暂停旧运行并等待用户手动恢复。
- 暂停/恢复、删除、覆盖重下经过逐 key 收尾屏障；保存目录切换经过全局屏障。删除已下载漫画保留暂停任务并清除对应完成标记；删除任务保留完整章节，失败恢复暂停任务并返回错误。
- 图片、封面和元数据使用同目录临时文件发布；暂停后不接纳后续提交。已开始的 IO 与源任务清理均等待收尾；元数据和状态持久化串行。临时文件和非连续断点不冒充已完成页。
- 服务销毁停止在途运行，`whenDisposed` 可等待清理，不再发布迟到通知。现有 UI、动画、平台后台策略、并发、超时和瞬态重试上限保持原样。
- 最终格式检查 880 文件、0 变化；静态分析无问题；**1250 项针对性回归通过**；完整覆盖率 **2064 项通过、1 项既有导航基线失败**。Windows debug（21.1 秒）、Android debug（35.9 秒）构建通过。未修改导航 UI 或断言，**完整应用验收尚未全绿**。

接手先读 `AGENTS.md`、本节和第六批验收记录，再核对 `git status --short` 与 `git log -3 --oneline`。本批新增 `manga_download_run.dart` 与 `manga_download_task_lifetime_test.dart`，既有图片任务取消回归增加下载会话场景，均须保留。

云阅读私有会话任务化已在第七批实现；健康判定/自动恢复及最终设备验收继续后续实施。本批没有授权自动重放。

## 第五批已提交基线


当前已按用户确认的计划实现 **第三阶段第五批：图片共享订阅与阅读生命周期**，已提交为 `f6d11c9e feat(source): connect image subscriptions and reader lifetime task control`；以下验证描述第五批提交时点。开始时六份 Markdown 文档及其既有修改均保留。最新验收见 `QUICKJS_IMAGE_READER_TASK_CONTROL_VALIDATION.md`。

最终格式检查为 878 文件、0 变化；静态分析无问题；**1327 项针对性回归全部通过**。最终完整覆盖率为 **2041 项通过、1 项基线失败**，失败仍为导航厚度期望 10、实际 72.0。Windows debug（29.8 秒）和 Android debug（48.8 秒）构建通过。没有改 UI 或断言；**完整应用验收尚未全绿**，详细命令与日志见第五批验收记录。

- 图片生产者、逐消费者订阅、可取消调度、图片 GET、图片脚本/转换、缓存意愿和提交收尾已接线；未提供 origin 的下载调用保留独立消费者。
- 阅读会话固定 sourceKey，持有跨空闲期租约，A→B 后仍可读取 A；停用/更新按实际旧 handle 停止。catalog 退役标记同时拒绝取消回调重入时新建旧资源任务或阅读租约。
- 阅读器的章节、图片、预取、详情、无图模式、换章和退出接入任务归属；代次保护覆盖 provider、尺寸缓存、解码许可及预取 drain。换章保留原退场动画和已显示图片。
- 封面/头像组件及封面预取接入订阅释放，首帧、占位及动画参数保持原样。未修改导航厚度断言，完整验收仍须明确记录基线失败。
- 下载暂停/删除、云阅读私有会话任务化、健康判定/自动恢复及最终设备验收留后续；没有修改原生包、依赖、assets 或 CI。

新对话先读 `AGENTS.md`、本节及第五批验收记录，再执行 `git status --short` 和 `git log -3 --oneline`。第五批和第六批均已提交，保留所有新增测试与文档。优先入口为图片缓存/调度/下载器、`SourceSharedRequest`、`SourceReaderSession`、runtime host 和阅读图片流水线；新回归为 `source_image_task_cancellation_test.dart`、`reader_task_lifetime_test.dart` 与 `comic_cover_task_lifetime_test.dart`。

第五批历史交接建议先规划下载暂停/删除与文件收尾，该项已在第六批提交；后续范围以上方最新状态为准。

**以下是第四批历史交接快照。其“当前状态”“未实施”“下一步”只描述第四批交接时点，第五批状态和验证以上方及新验收记录为准。**

## 第四批交接结论（历史快照）

目前做到 **第三阶段第四批：其他图源服务接入统一任务管理**。原生与代理基础为 `320e3a41`，旧验收失败收尾为 `dc727c96`，搜索接线为 `bb881f0a`；交接时第四批代码已进入当前 `dev` 分支的 `728057dc feat(source): integrate unified task control across source services`。生产 worker 显式启用任务控制，独立 QuickJS 包默认仍关闭。

本批覆盖发现、推荐、分类、排行、收藏、评论、账号、登录、插件动作及设置脚本回调。页面读取可以停止；服务写入在页面退出后继续非交互收尾，UI 权限仍会撤销；头像按订阅共享。**1066 项针对性回归、格式、静态分析及 Windows/Android debug 构建已通过**；完整覆盖率为 **2008 项通过、1 项基线失败**，详见下表和 `QUICKJS_SERVICE_TASK_CONTROL_VALIDATION.md`。阅读、图片、下载及自动恢复仍未实施。

实现期间代理未创建提交或 PR；交接时重新读取 git，已观察到上述第四批提交。当前仅六份 Markdown 文档存在工作区改动，验证状态以下表为准。本次交接整理只修改文档，没有重跑代码测试或构建。

## 第四批接手说明（历史）

1. 阅读 `AGENTS.md`、本文件和 `QUICKJS_SERVICE_TASK_CONTROL_VALIDATION.md`，再执行 `git status --short` 与 `git log -3 --oneline`，确认用户是否又有新修改。第四批实现已在 HEAD，不能只看未提交 diff 判断迁移范围；需要时比较 `git diff bb881f0a 728057dc -- lib test`。
2. 当前工作区需保留：已修改的 `QUICKJS_CANCELLATION_RECOVERY_PLAN.md`、`QUICKJS_TASK_CONTROL_VALIDATION.md`，以及未跟踪的 `QUICKJS_HANDOFF.md`、`QUICKJS_HOST_TASK_CONTROL_VALIDATION.md`、`QUICKJS_SEARCH_TASK_CANCELLATION_VALIDATION.md`、`QUICKJS_SERVICE_TASK_CONTROL_VALIDATION.md`。未跟踪不表示可删除。
3. 第四批代码已实现，完整验收仍有下述一项既有导航断言失败；不要将其记成全绿，也不要未经用户同意修改 UI 或放宽断言。测试数字是第四批实际执行记录，本次文档整理不另算一次执行；代码或环境变化后按影响范围复验。
4. 下一批建议先规划图片共享订阅与阅读生命周期；下载、健康判定与恢复、最终设备验收分别留到后续。此交接没有授权现在开始这些新实现。

接手实现时优先看 `lib/services/source/runtime/source_operation_context.dart`、`source_operation_runner.dart` 和 `lib/shared/source_task_owner.dart`，再参考 `test/services/source/source_service_task_cancellation_test.dart` 与 `test/features/discover/discover_task_lifetime_test.dart`。

容易破坏的约束：服务任务寿命与原页面交互权限分开；`retainAdmittedWork` 只能允许已接纳的非交互工作继续，不能恢复 UI scope。取消按原实际 handle/engine 绑定执行。停用、卸载、版本替换的 catalog 路径负责停止已迁移任务；不要直接在通用 `remove` 或 `recreateSourceRuntime` 增加全量停止，否则会破坏既有运行时租约和详情恢复语义。取消必须先于降级、认证重试和普通错误包装识别。

## 第四批历史验证

| 检查 | 结果 |
|---|---|
| Dart 格式 | 875 文件，0 文件变化，通过 |
| 静态分析 | 无问题，通过 |
| 针对性回归 | **1066 项全部通过**，48 秒 |
| 完整覆盖率测试 | **2008 项通过、1 项失败**，4 分 40 秒；已生成覆盖率文件 |
| Windows debug 构建 | 通过，22.2 秒 |
| Android debug 构建 | 通过，37.2 秒 |

完整套件仅剩一项基线外观断言失败：`home_bottom_navigation_test.dart:237` 期望玻璃厚度 10，基线实际 72.0。相关 UI、样式和测试在本批没有差异，最后变更来自 `4ba4a7aa`。没有为通过验收改 UI 或放宽断言；**本批完整应用验收尚未全部通过**。

本轮产物：`build/windows/x64/runner/Debug/hazuki.exe`（含配套 Dart assets）和 `build/app/outputs/flutter-apk/app-debug.apk`。`git diff --check` 通过；未修改原生包、依赖清单、assets 或 CI，未做真机操作验证。

## 工作区保护要求

- 先读项目 `AGENTS.md`。未经用户明确同意，不得改变 UI 外观或动画。
- 保留所有工作区修改，不要 reset、checkout 覆盖或清理未跟踪文件。
- 第四批开始时保留两份方案/原生验证文档的修改，以及未跟踪的本交接、第二批记录和 `QUICKJS_SEARCH_TASK_CANCELLATION_VALIDATION.md`。这些既有五份文档均保留；本批新增服务接线验收记录。
- 旧交接提到的菜单 UI、QuickJS、菜单拆分、验证码工具和搜索接线均已进入 HEAD，旧 numstat 不再适用。本轮调整服务/控制器任务归属、依赖传递及收尾，没有改变现有布局或动画。
- 第三批控制网关、共享请求和搜索回归均已在基线。本批新增 `SourceOperationContext`、`runSourceOperation`、`SourceTaskOwner`、服务取消集成和发现生命周期测试；既有测试没有删除。
- 独立包位置：`third_party/pub_overrides/quickjs_engine`。修改它后要在该目录单独做格式、分析和测试。

## 已经实现的内容

### 前两阶段已有基础

- 搜索任务身份和诊断基础已存在：`SourceTaskRegistry`、`SourceTaskOrigin`、`SourceScriptExecution`。
- 生产脚本通过主 isolate 代理进入 worker，QuickJS 在 worker 创建、调用、调度和释放。
- 同一运行时共享 JS 状态，等待 Promise / 网络时保留异步并发。
- 同步宿主握手、异步 Future、值图编码、字节、远程回调、快照、候选运行时发布和运行时租约已有实现。
- 旧阶段的完整验收状态以对应记录为准，不凭本交接文件追认全部通过。

### 第三阶段第一批已有原生基础

- 默认关闭的 `taskControlEnabled`、不透明 controlId、唯一 native token、task/work 上下文。
- 原生私有停止标记，区分取消与执行超时；JS 终止不可捕获。
- `executePendingJobStep()` 返回实际作业 token、状态和停止原因。
- Promise 生产者 / 消费者依赖及共享隔离；Dart 结果观察器可以结算，但不是保护生产者的业务消费者。
- 停止清理不重新执行用户 `catch/finally`；宿主 Future 迟到完成先检查运行时 epoch。

### 第二批已有的代理与宿主接线

- worker ready 返回 controlId，主代理提交命令前注册 native token；每个命令保留独立 callId/token。
- `SourceScriptEngine.cancelExecution(taskId, reason)` 返回状态与 `whenSettled`，另有动态共享保留数量。
- taskId 停止标记保留到运行时关闭；该身份后续业务调用拒绝，释放命令仍允许。ready 前等待中的显式任务调用也纳入索引。
- `whenSettled` 等待目标调用和独占资源收尾，不等待仍有其他消费者的共享资源，也不等同于所有底层工作已经停止。
- 原生增加已完成调用的遗留工作停止、worker 本地上下文租约、工作状态查询、原子停止认领、关闭通道。
- 同步邮箱原子绑定 work；停止 / 关闭可唤醒等待，迟到响应与重复结算安全。
- `SourceHostCallContext` 携带执行身份、runtimeId、token、workId、resourceId、有效性检查和停止通知。
- 每个宿主 Future 和 Timer 有独立生产 work；共享一个资源不会连带保留无用的兄弟资源。
- HTTP 贯通可选 CancelToken，重定向及网络重试等待都能停止；**只有原子停止认领成功才 abort**，状态查询本身不能授权 abort。
- worker 按实际 job token 处理异常、取消与超时，不再结束所有 pending calls。同 taskId 多条独立命令的普通作业异常也隔离；远程回调继续按注册身份执行。
- 无法归属的内部作业故障使运行时不可用并正常关闭；没有自动重建或重放。
- 关闭拒绝新调用、停止原生工作、唤醒邮箱、清理 Timer / 回调 / Future，再由 worker 释放 QuickJS 并确认退出，不使用 Isolate.kill。
- 取消后的迟到成功结果释放并丢弃；结果只完成一次；正常结果仍遵守快照和微任务检查点顺序。
- 复用现有日志开关、脱敏和导出，记录调用阶段、真实排队时间、操作耗时、停止原因和共享保留数量，HTTP 关联任务字段。
- `.github/workflows/check.yml` 图源回归步骤加入网络客户端测试；新测试由现有应用 / 独立包测试步骤发现，未跳过既有失败。

### 第三批搜索业务接线

- `SourceRuntimeHost.tasks` 统一持有注册表，`SourceTaskControlGateway` 经 DI 和页面构造参数传入控制器；实际 engine/runtimeId 随任务绑定。
- 普通/聚合搜索和直接 ID 查询以 owner/group 归属，替换与退出先使旧请求失效再停止；450 ms 重试等待可以取消，25 秒预算等待输入时暂停。
- 详情共享改为独立生产者及逐调用方订阅；无 taskOrigin 的详情调用同样保护生产者，最后消费者退出才停止底层工作。
- 业务终态与遗留资源收尾分开；成功搜索不继续占活动表，仍可按 owner 清理 Timer、回调和宿主工作。生命周期通知独立于日志开关。
- 取消错误绕过详情重建；保留普通插件恢复，恢复尝试使用新交互 scope，不能复用已退役 scope。

### 第四批服务接线

- 网关、服务及适配器接收可选 taskOrigin，辅助方法显式传递上下文，同一业务的检查和命令共用 taskId。
- 读取由页面 owner/group 控制，写操作由服务持有；切源保留已接纳写入租约，停用/更新按实际旧 handle 停止本批任务。
- 服务 UI scope 与业务寿命分开；代理仅允许已接纳的非交互命令继续，原 scope 的撤销仍阻止输入，业务完成后也不恢复 UI 权限。
- 头像生产者与订阅分开，重登录维护不继承首个读取取消；登录框关闭取消尝试，普通失败后的清理不伪装成用户取消。
- Dart 提交和共享解除后的 drain 计入 whenSettled；成功终态不因清理遗留资源而改变。日志开关不参与资源生命周期。

## 第二批修复过的关键边界，后续不要改回去

这些问题都通过先失败后修复的回归确认：

1. 自定义 Promise species 的 reject resolver 可以包含任意用户代码，停止清理不能在关闭中断的状态下进入它。
2. 原生 job 返回前可能释放最后一份身份引用，worker 必须延迟元数据删除到读完作业结果，避免误判为内部故障。
3. 取消确认和句柄释放能在有限微任务批次之间完成，不能被另一个任务的无界微任务链一直挡住；普通结果 / 宿主完成仍遵守检查点顺序。
4. 同 taskId 不代表同一 native 执行，不能用 taskId 批量结算普通作业异常。回调调用另有注册 token 索引。
5. HTTP 取消可能先结束 Dio 外层 Future，响应拦截器仍在写 Cookie。`runCommit` 单独计数，`whenSettled` 和关闭要等已经开始的提交完成。
6. 最后消费者退出时，还要等待本次停止认领的生产者资源，即使资源登记在此前已取消的另一个 taskId 名下。
7. 代理取消不自动关闭浏览器 UI，但迟到浏览器结果在 Cookie / User-Agent 提交前必须重查工作有效性。已经开始的权威写入计入收尾，不承诺回滚已提交内容。
8. ready 前的调用取消要返回 accepted，并等调用结束后再结算，不能简单报告 notFound。
9. 同步握手预算耗尽要按原生等待状态转为结构化超时，不能靠异常文本识别。独立包的 `QuickJsMailboxTimeout` 是 StateError 子类型，兼容原无绑定邮箱错误契约；worker 转成私有停止标记，用户 catch 不执行。

## 主要文件入口

| 范围 | 文件 |
|---|---|
| 主代理 / 取消 API / 宿主资源 / 关闭 | `lib/services/source/runtime/source_script_engine.dart` |
| worker / 调度 / Timer / 邮箱 / 回调 | `lib/services/source/runtime/source_script_worker.dart` |
| 停止错误、回执、宿主上下文及提交收尾 | `lib/services/source/runtime/source_host_call_context.dart` |
| 值和结构化停止错误编码 | `lib/services/source/runtime/source_script_codec.dart` |
| 生产接线和诊断 | `lib/services/source/runtime/source_runtime_loader.dart` |
| 主 isolate 权威桥接、浏览器结果提交检查 | `lib/services/source/runtime/source_js_bridge_cookie_capability.dart` |
| HTTP abort / Cookie 提交 / 关联日志 | `lib/services/source/http/source_http_gateway.dart` |
| 可取消的网络重试等待 | `lib/services/network/hazuki_network_client.dart` |
| Dart 原生接口 / 租约 / Future 和 JS 函数转换 | 独立包 `lib/quickjs/{ffi,task_control,quickjs_runtime2,object,wrapper}.dart` |
| 原生控制图与同步邮箱 | 独立包 `native/cxx/task_control.h`、`libfastdev_quickjs_runtime.cpp` |
| Promise 停止清理 | 独立包 `native/cxx/quickjs/quickjs.c`、`quickjs.h` |
| 新代理回归（21 项） | `test/services/source/source_script_cancellation_test.dart` |
| 原生控制回归 | 独立包 `test/task_control_test.dart` |
| 重试等待回归 | `test/services/network_client_test.dart` |

## 历史验收失败收尾

- 菜单选项模型、基础展示及原渲染实现迁入 `hazuki_frosted_menu_core.dart`，旧入口保留插件分流和兼容导出，插件菜单直接依赖基础实现。
- 原架构测试只报告首个依赖环；菜单环解除后，进一步提取共享验证码坐标换算函数，解决登录弹窗与插件弹窗的另一个既有环。旧登录入口继续导出该函数。
- 聚合搜索在 `SourceUiOwner.run` 外层捕获超时与普通错误，按进入前保存的 token 保护当前分区状态，清除加载标记；取消保持静默，不改变 UI scope 或业务取消链路。
- 用户确认按当前“菜单覆盖按钮、顶部对齐”的设计修正设置页旧断言，保留 0.1 精度及全部原动画检查，并增加矩形重叠检查。
- 新增三项搜索回归，覆盖分区成功结果保留、超时后重试、分页超时保留已加载漫画和旧搜索迟到错误隔离；加强原超时测试的状态断言。
- 菜单模型、完整路由/布局/渲染/动画实现和验证码坐标换算函数与 HEAD 逐字核对一致。

## 第三批历史验证结果

| 检查 | 结果 |
|---|---|
| 第三批应用 Dart 格式（870 文件） | 通过，0 文件变化 |
| 第三批应用静态分析 | 通过，无问题 |
| 第三批图源、网络、搜索、页面及架构针对性回归 | **627 项全部通过** |
| 第三批应用完整 Flutter 测试（含覆盖率） | **1986 项全部通过**，4 分 23 秒 |
| 第三批 Windows debug 构建 | 通过，20.7 秒 |
| 第三批 Android debug 构建 | 通过，39.0 秒 |
| 历史三项验收失败收尾 | 完整套件 **1955 项通过、0 失败**；针对性回归 114 项通过 |
| 历史 QuickJS 原生测试库重建 | 通过；第三批未重建 |
| 历史图源及网络针对性回归 | **494 项通过**，其中代理取消测试 21 项 |
| 历史独立包格式、静态分析及全部测试 | 通过，**39 项测试通过**；第三批未单独复跑 |
| 历史 Windows debug 构建 | 通过，19.8 秒；第三批结果另列 |
| 历史 Android debug 构建 | 通过，29.4 秒；第三批结果另列 |
| 真机 / 模拟器交互、其他平台、Sanitizer | 未执行 |

第三批曾在相同默认路径生成产物，现已由第四批构建覆盖；当前产物以上方第四批记录为准。

第三批首次完整运行有一份搜索套件在加载阶段停滞，核对进程后停止该子进程；随后扩大核验还发现普通详情恢复误用旧交互 scope。已保留失败记录、补测修复，最终 1986 项全部通过，详见第三批验收记录。

历史首次完整套件曾为 **1949 通过、3 失败**。三项失败已在上一轮收尾中修复：

1. `test/architecture/dependency_boundaries_test.dart`：菜单环及随后暴露的弹窗环均通过提取共享实现解除，未跳过检测。
2. `test/features/search/search_task_identity_test.dart`：聚合超时异常外泄已修复，不将调用方超时等同于底层任务取消。
3. `test/features/settings/other_settings_page_test.dart`：旧断言期望 142、实际 90；按用户确认的现有设计改为验证按钮顶部位置 90，而非移动菜单或放宽误差。

不要删除测试、放宽断言或回退用户 UI 修改来制造通过。此前的 UI teardown 身份过早释放问题已在首次接线批次修复，与第三批三项收尾问题不同。

## 第四批未完成范围（历史）

1. **验证边界**：第四批结果见顶部表格和服务验收记录；历史独立包测试不算本轮重跑，基线导航断言也不能略去。
2. **阅读/预取、图片与下载尚未迁移**：搜索和第四批列出的其他服务已经接线，不表示阅读会话、图片队列、下载暂停/删除已经停止底层工作。
3. **共享详情的普通调用方仅参与订阅保护**：保留完成缓存和现有恢复规则，不将未提供 taskOrigin 的所有调用自动解释为页面业务任务。
4. **原生图片下载及共享图片缓存订阅取消未接线**，仍属后续批次。既有图片兼容性测试通过不表示图片下载取消已完成。
5. **无自动恢复 / 重建 / 重放**：内部不可归属故障会明确失败并关闭运行时，不自动重建，更不重放可能有副作用的操作。
6. 停用/更新会按实际旧 handle 停止本批已迁移任务；尚未迁移后台业务的完整停用、切源和删除竞态须在对应批次验收。
7. 未做真机或模拟器操作验证，未做原生 Sanitizer、Apple / Linux 桌面构建。

仍保持的边界：不新增任务管理页、持久化任务表或运行时池，不串行化所有同源任务，不每任务创建运行时，不通过关掉整个同源引擎实现精确取消。页面读取、服务写入和登录使用各自明确的寿命，不将所有 SourceUiScope 自动映射为业务取消。

## 第四批当时建议（历史）

先核对本批完整测试和基线断言，再规划第五批图片共享订阅与阅读接线；后续下载、健康判定/恢复及整体验收仍需分别实施。

1. 先阅读本文件和本批验收记录，检查当前 git diff，保护用户已有修改。
2. 核对上文最新完整套件结果与工作区差异，继续保持 UI / 动画与现有交互语义。
3. 第五批先规划图片共享订阅与阅读接线，明确 owner/group、共享消费者、取消原因、缓存提交和收尾语义；不要直接扩展到下载或自动恢复。
4. 后续分别处理下载暂停/删除及文件收尾、运行时健康判定 / 恢复、整体验收。默认不重放已接纳操作，新实例只接收恢复后的新调用。
5. 每批先补针对性回归，再修复 / 接线；修改原生库后先重建测试库。只把实际执行通过的检查写为通过。

## 复跑命令与环境

本批命令与结果优先见 `QUICKJS_SERVICE_TASK_CONTROL_VALIDATION.md`；搜索历史结果见第三批记录。覆盖率文件为 `coverage/lcov.info`。

以下保留包含原生包的历史复跑参考；第四批实际命令以本批记录为准，本轮没有执行原生库重建或独立包检查。

应用根目录（PowerShell）：

```powershell
$env:Path = 'D:\Visual Studio 2026\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin;' + $env:Path
dart run tool/build_quickjs_test_library.dart
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test test/services/source test/services/network_client_test.dart --reporter expanded
flutter test --coverage --reporter expanded
flutter build windows --debug --no-pub
flutter build apk --debug --no-pub
```

独立包目录：`D:\Project\Hazuki\third_party\pub_overrides\quickjs_engine`：

```powershell
$env:PUB_CACHE = 'D:\Pub\Cache'
flutter pub get
dart format --output=none --set-exit-if-changed lib/quickjs/ffi.dart lib/quickjs/object.dart lib/quickjs/quickjs_runtime2.dart lib/quickjs/wrapper.dart lib/quickjs/task_control.dart test/task_control_test.dart test/worker_support_test.dart test/runtime_lifecycle_test.dart
flutter analyze --no-pub
$env:LIBQUICKJSC_TEST_PATH = 'D:\Project\Hazuki\packages\quickjs_engine\native\build\quickjs_c_bridge_plugin.dll'
flutter test --reporter expanded
```

注意：测试 DLL 在根目录 `packages/quickjs_engine/native/build`，不是独立包自己的 build 目录。使用项目构建工具，不要随意替换本地依赖覆盖。Windows 构建曾在与完整测试并行期间 assemble 失败，单独重跑成功，最后一次也成功；建议完整测试与烟雾构建按顺序跑。

首次接线批次日志在 `C:\Users\MeiQO\AppData\Local\Temp\hazuki-stage3b-*.log`：重点为 `full-final`、`source-final`、`package-tests`、`app-analyze`、`package-analyze`、`native-build`、`windows-build`、`android-build`。历史收尾日志为 `hazuki-stage3b-closeout-targeted.log`、`hazuki-stage3b-closeout-analyze.log`、`hazuki-stage3b-closeout-full.log`。

第三批搜索取消日志使用 `%TEMP%/hazuki-search-cancel-*.log`，最终通过记录为 `hazuki-search-cancel-full-verified.log`。第四批使用 `%TEMP%/hazuki-stage4-*.log`，最终检查为 `format-final`、`analyze-final`、`targeted-final-verified`、`full`、`windows-build` 和 `android-build`。各批中间失败日志不能替代最终结果；临时日志可能被系统清理，长期结论以仓库记录为准。

## 相关记录

- `QUICKJS_SERVICE_TASK_CONTROL_VALIDATION.md`：第四批服务任务接线、最新验收及当前基线失败，优先阅读。
- `QUICKJS_SEARCH_TASK_CANCELLATION_VALIDATION.md`：第三批搜索业务取消实现与历史验收。
- `QUICKJS_HOST_TASK_CONTROL_VALIDATION.md`：上一批运行时/宿主接线及旧验收失败收尾。
- `QUICKJS_TASK_CONTROL_VALIDATION.md`：第一批原生隔离验证。
- `QUICKJS_BACKGROUND_EXECUTION.md`：第二阶段后台迁移记录。
- `QUICKJS_CANCELLATION_RECOVERY_PLAN.md`：第三阶段整体方案，包含尚未实施部分，不能当作全部已完成。
- `third_party/pub_overrides/quickjs_engine/HAZUKI_NOTES.md`：独立包接口与实现约束。

可在新对话直接发送：

> 请先阅读 `D:\Project\Hazuki\QUICKJS_HANDOFF.md`、`D:\Project\Hazuki\QUICKJS_SERVICE_TASK_CONTROL_VALIDATION.md` 和 `D:\Project\Hazuki\AGENTS.md`，保留所有工作区修改。交接时 dev 的 HEAD 为 `728057dc`，第四批服务接线已提交，完整验收仍有一项基线导航断言失败。先核对现状，再写第五批图片共享订阅与阅读迁移计划；不要直接实现，不改变 UI 或动画，不创建提交或 PR，也不要将下载、图片订阅取消或自动恢复视为已完成。
