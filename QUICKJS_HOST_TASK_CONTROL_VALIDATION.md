# 第三阶段第二批：运行时与宿主桥接接线记录

本文保留第二批实现及三项旧失败收尾的历史范围与结果。后续宿主任务集中管理、搜索/直接 ID 取消及详情共享订阅接线见 [第三批搜索验收](QUICKJS_SEARCH_TASK_CANCELLATION_VALIDATION.md)，不能将本文“尚未接入搜索”等历史描述作为当前状态。

第四批其他图源服务任务迁移及当前完整验收状态见 [服务接线验收](QUICKJS_SERVICE_TASK_CONTROL_VALIDATION.md)。本文的通过数量仍为历史结果。

验证日期：2026-10-21。实现已接线；首次完整套件的三项失败已收尾，本轮完整应用套件 **1955 项通过、0 失败**，详细结果见文末。应用 worker 显式使用 `taskControlEnabled: true`，独立包默认仍为 `false`。没有增加页面、搜索控制器或下载服务的取消入口，没有自动恢复、运行时池或业务任务管理器迁移。

## 调用与资源语义

- worker ready 返回不透明 controlId；主代理提交命令前注册 token，每条命令仍有独立 callId，多个命令可携带同一个 taskId。命令结果与快照检查点完成后才解除 native 调用方根引用，原生及宿主引用尚未释放时保留身份。
- 带显式身份但仍在等待 worker ready 的调用也计入代理索引；这时取消返回 accepted，ready 后确认没有执行用户代码，whenSettled 等待调用结束。尚未发往 worker 的调用没有 native token（停止错误中的 token 为 0），不伪造已注册的 token。
- `SourceScriptEngine.cancelExecution(taskId, reason)` 返回请求状态与 `whenSettled`。重复请求幂等，停止标记保留到运行时关闭；同 taskId 后续业务命令拒绝，释放命令始终允许。返回 notFound 表示当前代理没有索引到该身份的在途调用或资源，不是业务任务管理器的终态判断。
- 调用方可先收到 `SourceScriptStopped`，其中保留执行身份、runtimeId、native token、原因、超时标志及可用堆栈。`whenSettled` 等待目标调用及其独占资源收尾，共享保留资源另行计数。迟到成功只释放返回资源，不覆盖取消；晚订阅已停止的生产者得到 dependencyStopped，而自身 taskId 仍可用于新调用。
- 最后一个消费者退出时，取消回执同时追踪这次停止认领的资源；即使该资源登记在已经取消的原生产者名下，也等待实际收尾，不能仅按资源的 taskId 判断已经清理。
- worker 使用 `executePendingJobStep()` 按实际 token 定位异常；普通异常、取消与超时不会遍历结束其他任务。无法归属的内部作业失败使运行时不可用并关闭，不重建、不重放。
- 同 taskId 多条命令仍按各自 token 隔离作业异常；远程回调额外索引注册 token，不用 taskId 批量结算其他命令。取消入口则有意停止该 taskId 的全部调用及遗留工作。
- 取消确认和句柄释放属于控制流，可在有限批次之间完成，不等待另一任务无界微任务链结束。普通结果及宿主完成事件仍遵守微任务检查点顺序。读取 job 结果前延后释放最后一份身份引用，避免关闭时误判任务不可归属。
- 原生新增 worker 本地 work 租约、跨线程状态查询、已完成调用遗留资源停止及原子停止认领。查询不能授权 abort；只有已停止且没有有效消费者的工作才能认领，认领后不可被迟到订阅复活。
- 每个异步宿主请求及 Timer 拥有独立生产 work，返回的 JS Promise 绑定该 work；共享其中一个资源不会连带保留未使用的兄弟资源。认领同时封闭生产者自己的派生 Promise，晚订阅即使没有宿主完成事件也明确失败。
- 邮箱创建时绑定控制及 work，独占工作停止或关闭会唤醒等待者，区分取消、超时与关闭；同步结果与停止响应只结算一次。跨线程不持有或调用 JS 指针，注册表锁不覆盖阻塞等待或脚本执行。
- 同步握手耗尽现有剩余预算时，按原生等待状态转换为私有标记的超时，禁止用户 catch 吞掉终止；不通过错误文本识别。独立包的无绑定邮箱超时仍符合 StateError 兼容契约。
- `SourceHostCallContext` 携带执行身份、token/work/resource ID、有效性检查与停止通知。HTTP 的 CancelToken 只由资源停止认领触发，贯通重定向及重试 Timer；取消不转换为普通 HTTP 响应，也不继续重试。worker Timer 和远程句柄同样按 work 清理，共享生产者继续使用原注册身份。
- 权威存储仍在主 isolate。生产桥接在启动存储、设置、秘密存储及 Cookie 写入前设置 requiresDrain；关闭先拒绝调用、停止/解绑资源、由 worker 销毁原生对象，再等待已开始的权威写入收尾。普通宿主订阅关闭时可解绑，任意 Dart Future 不承诺可强制中断。登录事务提交/回滚、UI 作用域和检查白名单保持原规则。
- HTTP 响应保存 Cookie 的提交单独计数；即使 Dio 取消先结束外层请求，whenSettled 和关闭仍等待已经开始的 Cookie 写入。停止后尚未开始的提交被拒绝，不承诺回滚已提交的修改。
- 浏览器交互不会因代理取消被自动关闭；迟到授权结果在 Cookie/浏览器 User-Agent 提交前重新检查工作有效性，已经开始的提交加入收尾租约。现有登录事务及 UI 作用域检查继续执行。
- 复用现有日志捕获开关、脱敏与导出，记录真实排队时间、包含等待的操作耗时、阶段、停止原因、可用脚本位置及共享保留数。HTTP 日志关联 token/work/resource ID。诊断不记录脚本、参数、搜索关键词或异常正文；日志观察器失败不能改变结果。包含等待的操作耗时不称为 JS CPU 执行耗时。

没有用共享“当前任务”变量推断并发归属，没有主线程 QuickJS 调用、生产旧路径回退或 Isolate.kill。`SourceUiScope` 未自动映射到新取消入口，共享工作不会获得额外 UI 权限。

## 针对性回归

新增代理测试覆盖主动中断与主 isolate 心跳、排队任务无副作用、同运行时继续使用、deadline 类型/身份及重复取消、共享宿主/HTTP/Timer、最后消费者退出、已返回回调取消、迟到依赖订阅、不可中断写入收尾、关闭确认及诊断不记录异常正文。

另外覆盖资源兄弟分支的独立清理、无界微任务下的取消确认/释放，以及自定义 Promise species 的拒绝解析器死循环。停止清理只对引擎自己的解析器暂时抑制中断，不在该状态下调用用户自定义解析器；相应派生等待由停止结算路径结束。

最后复核新增六条先失败后修复的回归：HTTP 取消/关闭必须等待已开始的 Cookie 提交；自定义 Promise resolver 失败不能结束同 taskId 的另一独立命令；最后消费者等待资源收尾；迟到浏览器结果不能为已停止工作提交 Cookie；worker ready 前的排队调用也正确报告 accepted 并等待结算；同步握手预算耗尽得到结构化超时且用户 catch 不执行。代理测试共 21 项，全部包含在最终图源回归中；交互与登录测试也包含在内。

独立包新增已完成调用的 work 保留/停止认领，以及取消/超时唤醒绑定邮箱测试。现有 Promise 共享、组合与循环、关闭竞态、字节切片、HTML、插件检查、快照、登录/存储事务和图片回归继续执行。网络客户端新增取消 30 秒重试等待后两秒内返回且不发下一次请求的断言。

扩大回归曾发现关闭中的 job 在返回前释放末引用，造成身份过早清理；已用现有“queued WebView/native dialog teardown”测试复现并修复，相关交互与代理测试共 34 项通过。该问题不列入下方保留的既有失败。

CI 的 Windows source-runtime 检查继续重建原生库，运行全部独立包及 source 测试，并加入网络客户端测试。应用完整套件步骤保留，未跳过或放宽既有失败测试。

## 首次接线批次的命令与结果（历史）

日志位于系统临时目录 `hazuki-stage3b-*.log`。

应用根目录执行：

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

独立包目录执行：

```powershell
$env:PUB_CACHE = 'D:\Pub\Cache'
flutter pub get
dart format --output=none --set-exit-if-changed lib/quickjs/ffi.dart lib/quickjs/object.dart lib/quickjs/quickjs_runtime2.dart lib/quickjs/wrapper.dart lib/quickjs/task_control.dart test/task_control_test.dart test/worker_support_test.dart test/runtime_lifecycle_test.dart
flutter analyze --no-pub
$env:LIBQUICKJSC_TEST_PATH = 'D:\Project\Hazuki\packages\quickjs_engine\native\build\quickjs_c_bridge_plugin.dll'
flutter test --reporter expanded
```

首次接线批次结束时的代码核验（不代表下方收尾后的最新结果）：

- QuickJS 测试库重建成功；独立包全部 39 项测试通过，格式检查与分析通过。
- 应用 861 个 Dart 文件格式检查无变化，静态分析通过；图源与网络针对性回归 494 项通过。
- 最后一次应用完整测试（含覆盖率）：1949 项通过、3 项失败，耗时约 1 分 50 秒。失败清单如下；本次增加的用例及图源生命周期回归均通过。
- Windows debug 最终构建通过（`flutter build windows --debug --no-pub`，19.8 秒）；Android debug 最终构建通过（`flutter build apk --debug --no-pub`，29.4 秒）。产物分别为 `build/windows/x64/runner/Debug/hazuki.exe` 和 `build/app/outputs/flutter-apk/app-debug.apk`。

## 收尾前的既有失败与验证限制（历史）

多轮完整测试均保留相同 3 项失败（首轮 1939 项通过，最终新增回归后 1949 项通过）：

1. 架构依赖环：hazuki_frosted_menu → source_plugin_menu → hazuki_frosted_menu。HEAD 已包含两向依赖，本批未改动这些 import/export。
2. `search_task_identity_test` 的 aggregate caller timeout：使用模拟网关，不执行 QuickJS，SourceUiService.run 在超时路径抛异常。单独运行同样失败；相关控制器及 UI scope 本批未修改。
3. `other_settings_page_test` 的 conversion menu 位置断言：期望 142、实际 90。本批未修改该菜单或该测试。

工作区原有 `hazuki_frosted_menu.dart` 和对应测试的修改保留，不为本批调整 UI、页面取消语义或断言。不能将完整套件标记为通过，也不能据此声称整批正式验收完成。

Windows 首次构建的 Flutter assemble 步骤退出，单独重跑 verbose 构建成功；最终构建结果以上方核验为准。未执行真机、模拟器操作、其他桌面/Apple 平台构建或原生 Sanitizer。页面/下载取消、统一业务任务终态、图片共享订阅及自动恢复仍属于后续批次。

## 三项验收失败收尾（2026-10-21）

本轮从提交 `320e3a41` 开始，原有工作区修改为两份方案/验证文档，以及未跟踪的本记录与交接文档。此前的菜单 UI 与 QuickJS 实现已进入 HEAD，不能再按旧交接中的工作区 numstat 判断。

修复与依据：

1. 菜单模型、基础展示和原渲染实现迁至 `lib/widgets/hazuki_frosted_menu_core.dart`；旧入口保留插件分流、原函数签名和类型导出。插件菜单仅依赖基础实现，移除菜单双向依赖。
2. 原架构测试只报告首个环。菜单环解除后，发现登录弹窗与插件弹窗通过 `captchaImagePoint` 形成另一个既有环。将该坐标换算函数原样提取为共享工具，原登录入口继续导出，两个弹窗改为直接引用工具；没有改变验证码交互。
3. 聚合搜索原先只在 UI scope 内捕获错误；`SourceUiService.run` 会在 scope 超时后再次抛出保存的异常。控制器现在在外层同样捕获，按进入前保存的请求 token 检查有效性，再设置错误和清除加载状态。保持取消静默、过期结果隔离和现有 UI scope 语义。
4. 用户已确认保持现有菜单定位设计。设置页测试将旧的“按钮下方 +8”断言改为顶部对齐（仍精确到 0.1）并增加重叠检查，与现有菜单组件专用测试一致；右侧对齐、圆角、模糊及开闭动画断言保留。这是同步过时的设计预期，没有放宽断言或回退 UI。

回归补充：加强原聚合超时测试的错误及加载状态断言，新增三项测试，覆盖其他来源成功结果保留、超时后重试、分页超时保留已加载漫画，以及旧搜索迟到错误不能覆盖新搜索。修复前，新增的首次搜索和分页超时测试均复现了外层异常外泄。

本轮已执行：

- 三个失败文件、菜单/插件菜单、聚合搜索、UI 服务，以及登录交互、插件弹窗和登录变形弹窗回归：**114 项全部通过**。
- `dart format --output=none --set-exit-if-changed lib test`：**863 个文件，0 文件变化**。
- `flutter analyze --no-pub`：**无问题**。
- `flutter test --coverage --reporter expanded`：**1955 项通过、0 失败**，约 2 分 1 秒；生成 `coverage/lcov.info`。原有三项失败与新增三项回归均通过，未跳过测试。

迁移后对照 HEAD 核验：菜单选项模型、完整路由/布局/渲染/动画实现及验证码坐标换算函数均逐字一致。本轮未修改原生库或独立 QuickJS 包，未重新构建原生测试库、执行独立包检查或重跑平台构建；上节对应结果保留为历史验证，不能视为对当前代码重新执行。没有创建提交或 PR。

本轮日志：`%TEMP%/hazuki-stage3b-closeout-targeted.log`、`hazuki-stage3b-closeout-analyze.log`、`hazuki-stage3b-closeout-full.log`。业务取消接线、统一任务管理、图片共享订阅及自动恢复仍未实施。
