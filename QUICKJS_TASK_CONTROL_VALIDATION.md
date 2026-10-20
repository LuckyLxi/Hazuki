# 第三阶段第一批：原生取消基础与隔离验证

本批只修改独立 QuickJS 包、针对性测试、CI 和迁移记录。`taskControlEnabled` 默认 `false`，生产 `SourceScriptEngine` 未启用新能力。应用任务模型、页面、HTTP、下载取消、超时配置、登录事务和自动恢复均未修改。UI 和动画未改动，保留工作区已有的 `assets/data/authors.txt` 修改。

## 实现与使用约定

- `QuickJsTaskControl` 通过不透明 `controlId` 注册不复用的任务 token，区分停止请求已接受、重复、调用方已完成及无效身份。停止请求不表示共享工作已经结束。`complete` 解除调用方根引用；Promise、job、回调和宿主 Future 的捕获仍保留资源记录。
- 控制表由进程内递增 ID、短注册表锁和共享生命周期管理；每个控制对象拥有独立图锁及原子停止标志。跨 isolate API 不持有 JS 指针。遍历依赖图及执行 JS 时不持有注册表锁，关闭先注销 ID，迟到请求不会访问原生运行时。
- worker 使用 `withTaskContext(token, ...)` 进入脚本，Promise、reaction、await、adoption、函数引用和宿主 Future 保存并恢复 task/work。JS 依赖图从未停止的调用方及内部订阅计算可达工作，引用计数仅管理记录生命周期。
- eval、直接函数调用和 Promise job 检查目标工作；死循环通过原有中断检查点停止。取消和超时使用原生私有错误标记及 `QuickJsTaskStoppedError`，无法由异常文本或 JS 可写字段冒充。
- `executePendingJobStep()` 返回实际 job token、状态、错误和停止原因。启用控制时，原有 dispatch 包装也使用相同结算路径；关闭新能力时保留旧执行路径。
- 中断保持不可捕获，内部结算拒绝派生 Promise、终止 async continuation 并释放引用，不执行被停止分支的用户 `catch/finally`。仍被其他消费者依赖的生产工作继续；取消前的共享状态修改不回滚。
- Dart 结果观察回调不是业务消费者，但会保留待结算 Promise。调用方取消时，即使生产者因共享依赖继续执行，对应 Dart Future 也独立拒绝。后续订阅已终止的生产者明确失败。
- Future 迟到完成先核对运行时 epoch，再进行任何原生访问，避免旧指针复用。完成解析器仍发送微任务唤醒消息，保持原有异步顺序。

所有注册任务应在调用方结束时执行 `complete(token)`；运行时关闭前不要求其 JS 引用已全部释放。控制诊断字段分别表示任务记录数、工作记录数和已停止任务中因共享依赖保留的工作数，不是持久化任务表。

## 验收矩阵

| 场景 | 对应测试与结果 |
|---|---|
| 预先取消 | eval 和直接函数调用不产生副作用；结构化取消错误 |
| 五秒预算下持续计算 | 主 isolate 心跳继续；请求取消后两秒内返回；随后调用正常 |
| A 等待、B 计算；A 计算、B 等待 | 中断/取消 A 后 B 正常，含 await continuation |
| 取消和超时 | 同步、直接调用、初始 async、Promise job、await job 分别验证；普通异常不能冒充 |
| 共享生产者 | 取消原调用方的 Future 独立结算，其他消费者继续；最后消费者退出后停止正在运算的生产者 |
| Promise 组合 | all/race/any/allSettled、thenable、adoption、finally、循环依赖及迟到订阅 |
| 内部结果观察 | 取消分支的 catch/finally 不执行；观察回调仍结算；不调用插件覆盖的 then |
| 宿主 Future | 两种模式均唤醒微任务；共享宿主结果和字节切片正确；关闭后的迟到完成安全忽略 |
| 生命周期与竞态 | ID 唯一、重复停止、完成与停止、关闭与注册、失效控制 ID；正常完成后 task/work 归零；反复关闭后控制表和 Dart 运行时/回调计数恢复基线 |
| 默认关闭 | 既有独立包测试及应用图源、搜索回归通过 |

新增原生场景通过 Flutter 测试 worker 调用实际重建的原生库；主测试 isolate 只通过控制 ID 发出请求，不创建、调用或释放 QuickJS。

## 实际验证命令

验证日期：2026-10-20，Windows 本机。命令日志保存于系统临时目录 `hazuki-stage3-*.log`。

应用根目录：

```powershell
$env:Path = 'D:\Visual Studio 2026\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin;' + $env:Path
dart run tool/build_quickjs_test_library.dart
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test test/services/source test/features/search --reporter expanded
flutter build windows --debug --no-pub
flutter build apk --debug --no-pub
```

独立包目录 `third_party/pub_overrides/quickjs_engine`：

```powershell
$env:PUB_CACHE = 'D:\Pub\Cache'
flutter pub get
dart format --output=none --set-exit-if-changed lib/quickjs/ffi.dart lib/quickjs/object.dart lib/quickjs/quickjs_runtime2.dart lib/quickjs/wrapper.dart lib/quickjs/task_control.dart test/runtime_lifecycle_test.dart test/worker_support_test.dart test/task_control_test.dart
flutter analyze --no-pub
$env:LIBQUICKJSC_TEST_PATH = 'D:\Project\Hazuki\packages\quickjs_engine\native\build\quickjs_c_bridge_plugin.dll'
flutter test --reporter expanded
```

最终结果：原生测试库重建成功；应用格式检查（836 个文件、零改动）和应用/独立包静态分析通过；独立包修改文件格式检查通过，全部 35 项测试通过（新增 28 项）；应用图源及搜索 448 项回归通过。Windows debug 构建生成 `build/windows/x64/runner/Debug/hazuki.exe`，Android debug 构建生成 `build/app/outputs/flutter-apk/app-debug.apk`。CI 已扩展独立包格式检查清单；原有重建原生库和全部独立包测试步骤自动包含新增测试。

实施中回归记录：新增等待取消测试发现 Dart 结果 Promise 需要显式保留，已修复并验证正常完成后任务及工作计数归零。首次应用图源回归中阅读进度测试超时，定位到 Future 新结算入口漏发微任务唤醒；补齐默认关闭/开启两种模式的回归后修复，应用回归重跑全部通过。

## 未接入与未验证

本批不接入应用取消入口，不替换生产 worker 当前微任务错误结束所有调用的处理，不唤醒因任务取消而等待的同步宿主邮箱，也不取消 HTTP、重试、Timer、下载或恢复运行时。这些都属于后续生产接线。

未运行真机、模拟器交互或 Flutter 帧采样；验证的是测试主 isolate 心跳及 debug 构建。iOS、macOS、Linux 构建及原生地址/线程 Sanitizer 未验证。应用完整 Flutter 套件本批未运行，按计划使用图源与搜索回归；CI 原有完整应用测试仍保留。后续接线仍须重新验证真实插件、共享资源订阅清理及应用任务终态，不将本批验收描述为第三阶段整体完成。
