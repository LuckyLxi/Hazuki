# QuickJS 后台执行迁移记录

## 实现范围

生产图源入口统一使用 `SourceScriptEngine` 异步代理，包括插件检查、初始化、搜索、分类、收藏、登录、阅读、图片脚本和诊断。每个实例拥有一个 worker isolate 和一个 QuickJS 实例；同源调用共享 JS 状态，并可在其他调用等待 Promise 或网络时继续进入。插件检查、交互登录及既有云阅读私有会话继续使用独立运行时。

主 isolate 不访问 QuickJS 引用或执行脚本。`ready` 表示 worker 可接受调用，`whenClosed` 表示 worker 已退出；`close()` 可重复等待。worker 启动或异常退出会结束相关调用，当前实现不会自动重放操作。

## 桥接与顺序

- HTML、转换与加密、随机数、UUID、平台查询及插件延时由 worker 执行。检查模式保留原宿主调用白名单。
- HTTP、Cookie、存储、设置、秘密存储、语言、日志及登录交互继续访问主 isolate 的权威服务。原生同步响应通道只传递字节；同步返回值和异常保持同步，Future 立即握手为 Promise，完成后通过消息返回。
- 通道使用不透明递增 ID、互斥锁及共享生命周期管理。关闭和超时可以唤醒等待者，迟到响应无法访问已释放内存。等待使用当前脚本剩余执行预算。
- 值编码保留集合共享引用、循环结构、字节切片、非有限数值及异常。异步字节使用 `TransferableTypedData`，不会转移或修改调用方原缓冲区。远程函数句柄只对所属运行时有效，释放幂等。
- 原生 Promise reaction 捕获注册时任务，job 入队和执行保存、恢复上下文；thenable、await、组合 Promise、延时及远程回调均保留归属。维护调用使用运行时内部任务。HTTP 日志携带任务、插件、版本、方法和运行时身份。
- 微任务按最多 64 个作业或 8 ms 分批推进。普通命令及宿主完成事件等待当前微任务检查点，关闭控制消息可以在批次间处理。

## 快照与生命周期

能力标志、翻译及元数据在同步执行和微任务检查点后发布，并先于对应操作结果到达主 isolate。代理只接受本实例的递增快照，kernel 忽略已替换实例的更新。首次绑定候选快照不会额外通知并触发重复加载。

候选引擎完成加载和初始化后整体发布；失败保留原引擎及元数据。业务租约覆盖能力检查、脚本等待和解析。已接纳操作可跨 await 继续，切源拒绝新操作；同一 handle 的旧引擎等租约结束后释放。旧结果不会写入新实例的运行时缓存。交互登录仍按既有事务规则提交或回滚，取消后关闭私有 worker，迟到宿主响应被忽略。

worker 关闭时结束桥接 Future、取消 Timer、释放远程引用、HTML 句柄和原生运行时，再确认退出。没有使用 `Isolate.kill` 代替正常关闭。

## 第二阶段收尾

- 公共弹窗转场、背景色函数及玻璃转场进度作用域已原样移动到 `source_account_dialog_support.dart`。账号、登录交互、浏览器授权和外部授权使用单向公共依赖；原账号弹窗入口继续导出原有公共函数。未改变布局、颜色、转场时长、曲线或玻璃层。
- 补充真实 loader 的并发回归，复现并修复候选初始化失败时恢复旧快照、覆盖旧实例最新元数据的问题。候选尚未发布时只释放候选，不重新写入捕获的旧状态。
- 修复候选失败与 handle 释放竞态导致已关闭引擎被重新写入的问题；最终发布前再次检查 handle 状态。成功替换时，已接纳操作继续使用旧引擎，租约结束后旧引擎正常退出。
- 生产代码中 QuickJS 创建、调用、函数引用释放和销毁仍仅在 worker；关闭、迟到响应、重复释放和快照隔离由现有后台回归继续验证。本轮未增加任务取消、中断或恢复实现。

## 验证记录

本机：Windows，2026-10-19。执行原生相关测试前已使用项目工具重建 QuickJS 测试 DLL。

| 检查 | 实际执行及结果 |
|---|---|
| 应用格式 | `dart format --output=none --set-exit-if-changed lib test`：831 个文件，0 个需调整。 |
| 应用分析 | `flutter analyze --no-pub`：No issues found。 |
| 架构与弹窗 | 架构、账号弹窗、头像、登录交互及弹窗形态切换五个测试文件：64 项通过，包含全部依赖环检查。 |
| 生命周期针对性回归 | loader、HTML 和后台执行三个文件：23 项通过；新增三个真实候选加载/租约场景，其中两个先复现失败再修复。 |
| 图源与搜索 | `flutter test test/services/source test/features/search --reporter expanded`：444 项通过。 |
| 完整套件及覆盖率 | `flutter test --coverage --reporter expanded`：1768 项全部通过，输出 `coverage/lcov.info`。 |
| 原生测试库 | `dart run tool/build_quickjs_test_library.dart`：成功构建当前 QuickJS 测试 DLL。 |
| 独立 QuickJS 包 | 在独立包目录执行 `flutter pub get`、修改文件格式检查、`flutter analyze --no-pub`、`flutter test --no-pub --reporter expanded`：检查通过，全部 7 项测试通过。新增原生通信与任务传播测试已进入现有 Windows CI。 |
| Windows | `flutter build windows --debug`：成功，产物 `build/windows/x64/runner/Debug/hazuki.exe`。 |
| Android | `flutter build apk --debug`：成功，产物 `build/app/outputs/flutter-apk/app-debug.apk`。 |

第二阶段原有的弹窗循环导入已消除，最终完整套件无剩余失败。尚未进行真机/设备运行验证，也未验证其他平台构建。构建通过不代表已经完成这些设备验证。

回归覆盖同步宿主读写和异常、长字符串、循环结构、字节切片、共享 Promise 交错、HTTP 日志归属、嵌套远程回调、快照替换、切源租约、重复关闭、Timer 清理、初始化及图片脚本运算超时、主 isolate 心跳与 Flutter 帧推进，并复用现有插件、HTML、存储、登录和图片测试。

独立包检查需在 `third_party/pub_overrides/quickjs_engine` 下执行。Windows 包测试设置 `LIBQUICKJSC_TEST_PATH` 指向项目工具生成的 DLL。本机 pub 缓存位于 `D:\Pub\Cache`，独立包安装依赖时显式设置了 `PUB_CACHE`，避免默认临时目录的跨盘重命名失败。

## 阶段边界

本阶段保留既有脚本超时策略、UI、动画、插件接口及登录事务规则。代码、静态检查、宿主测试及 Windows/Android debug 构建验收通过，设备验证仍未完成。尚未实现任务级主动取消、精确 JS 中断或运行时自动恢复；后续按 [第三阶段独立实施方案](QUICKJS_CANCELLATION_RECOVERY_PLAN.md) 推进，本文不把该方案中的能力描述为已实现。
