# 第三阶段第三批：搜索业务取消接线

本文保留第三批范围和历史结果。发现、分类、收藏、评论、账号及插件动作等后续迁移见 [第四批服务验收](QUICKJS_SERVICE_TASK_CONTROL_VALIDATION.md)，本文“其他业务尚未迁移”等表述以第三批时间点为准。

日期：2026-10-21。基于 `dc727c96` 继续接线。保留开始时两份方案/验证文档的修改，以及未跟踪的交接和第二批验收记录。没有修改 UI 外观、布局或动画，没有修改独立 QuickJS 包、原生控制协议或默认五秒脚本执行配置。没有创建提交或 PR。

## 实现范围

- `SourceRuntimeHost.tasks` 统一持有任务注册表；搜索服务不再单独创建注册表。当前业务接入范围为关键词搜索与搜索框直接 ID 查询，不表示分类、收藏、账号、阅读或下载已完成迁移。
- `SourceTaskControlGateway` 提供按 task、owner/group/plugin 和 owner 取消；通过 composition root、DI、搜索页面构造参数传给控制器。测试显式注入假控制入口，生产没有空实现回退。
- 每次搜索服务调用拥有独立 taskId，能力检查和实际搜索命令共用该身份。任务保存实际使用的 engine/runtimeId，正常取消不查找或替换当前同源实例，旧实例上的停止请求不能命中新实例。
- 任务状态增加 cancelRequested、cancelled、timedOut，停止原因使用枚举；`SourceTaskCancelled` 与 `SourceTaskTimedOut` 保留任务、运行时和原因。原生单次执行超时归为 timedOut；被停止的依赖属于失败，不伪装成用户取消；普通运行时故障仍按失败处理，不新增恢复。
- 取消先同步标记，再下发原生及订阅停止，重复取消保留首个原因。成功、失败与停止只确定一次；成功任务后续清理遗留资源不改写成功终态。
- 回执区分 accepted、alreadyRequested、alreadyFinished、notFound，并携带 `whenSettled` 与动态共享保留数量。业务结果、活动业务表和资源收尾拥有不同生命周期；业务结束后仍有工作时保留必要归属，以便页面退出清理 Timer、回调或宿主工作。
- engine 增加独立于诊断开关的执行生命周期通知和工作查询。资源归零后解除绑定；不通过日志事件维持任务存活。完成回执仅保留最近 256 条普通快照，不持有页面回调或 engine；历史淘汰后查不到的任务返回 notFound。

## 搜索与交互规则

- 普通搜索的新查询、刷新、来源变更及直接 ID 查询准备会使旧请求失效并停止旧 owner 的任务；分页与自动重试沿用查询 groupId，但每次服务调用仍新建 taskId。
- 保留首次搜索普通失败或空结果最多五次、每次间隔 450 ms 的规则。等待使用可取消 Timer；退出、替换和工作预算到期不提交后续尝试，原生单次 JS 超时仍遵守原失败重试规则。
- 聚合新查询停止所有旧分组；排序、单源重试、插件替换或移除只清理对应来源分支，保留其他来源的结果。销毁控制器按 owner 清理所有遗留分组。
- 提交协调器先使普通及聚合控制器上一轮请求失效，再执行新查询或 ID 查询。ID 普通失败及 25 秒工作超时保留关键词回退；主动任务取消及关闭交互不回退、不导航，也不继续记录本轮历史。
- 保留 token、generation 和 `resultDisposition`。结果用途诊断不自动授权取消；外部单纯使用 `Future.timeout` 仍不等同于请求底层停止。
- 输入编辑、仅清空输入框、关闭键盘和临时遮挡页面不增加取消行为；真实页面销毁才释放控制器 owner。搜索页面的视觉代码仅增加依赖参数传递。
- 25 秒工作预算复用现有 `SourceUiScope.timeout`，覆盖初始化等待及执行，等待用户输入时暂停。显式取消信号让宿主任务下发底层停止；没有增加一个持续消耗预算的墙钟计时器。

## 共享初始化与详情

- 初始化使用宿主共享生产者和原有 initFuture，不继承首个搜索的取消标记。取消搜索只退出等待，并在初始化结束后阻止该搜索继续提交脚本；初始化继续遵守原有运行时生命周期和初始化预算。
- 详情在途缓存改为共享生产者对象，每个调用方各有订阅，包括没有传入 taskOrigin 的现有详情调用方。生产者具有独立资源执行身份；取消首个搜索不停止其他详情订阅。
- 最后一个订阅退出才认领并停止底层生产者。停止时立即撤下可订阅入口，随后查询创建新生产者，不能复活已停止的请求；旧回执动态共享数量随剩余消费者变化。
- 详情及初始化生产者拥有独立交互 scope；共享只传播“正在等待输入”的计时贡献，不转移消费者的 owner 或 UI 授权。贡献按生产者独立计数，一个生产者结束不会恢复另一生产者仍需暂停的工作预算。
- 运行时退役仍撤销旧交互权限，但共享详情保留已接纳操作的租约并等待结果；缓存提交继续检查实际 engine、handle、有效消费者和最新刷新 token。取消/旧 runtime 的迟到结果不得写入新缓存，强制刷新保持优先。
- 取消错误在详情恢复循环之前被重新抛出，不触发插件请求的运行时重建或重放。普通未取消操作的既有恢复规则保留。
- `whenSettled` 不等待被其他消费者保留的共享生产者；独占资源及已开始的提交仍按现有桥接语义收尾。任意 Dart Future 不能强制中断，不宣称取消时所有底层工作已经同步停止。

## 回归与验证

新增回归包括：任务初始化前取消、结果/取消竞态、observer 重入、owner/group/plugin 隔离、同步计算中断、成功任务遗留写入收尾、原生共享消费者保护、预算暂停及多个共享输入等待的独立计数。

详情回归覆盖搜索和普通详情页共享、最后消费者退出、新请求替换已停止生产者、强制刷新竞争、初始化后禁止提交、迟到缓存丢弃、旧 runtime 缓存隔离、取消绕过重建及首个 UI scope 解除。补核发现普通插件恢复会误用已退役的交互 scope；新增回归先失败后修复，现在恢复尝试使用新 scope，原 scope 不再为新 engine 授权。真实共享输入关闭也验证仅停止搜索订阅，其他普通消费者保留。

真实服务/worker 集成覆盖新查询实际 abort 独占 HTTP、销毁一个页面保留同源另一请求、停止长 Timer 后不执行 continuation，以及普通/聚合查询切换。控制器和协调器补充重试间隔取消、聚合单源清理、ID 超时回退和关闭交互不回退。原注册表的八项测试保留，新增取消用例位于独立文件。

本轮最终验证状态：

| 检查 | 结果 |
|---|---|
| Dart 格式 | 870 个文件，0 文件变化 |
| 应用静态分析 | 无问题 |
| 图源、网络、搜索、搜索页面与架构回归 | **627 项全部通过** |
| 完整应用测试及覆盖率 | **1986 项全部通过**，4 分 23 秒；已生成 `coverage/lcov.info` |
| Windows debug 构建 | 通过，20.7 秒 |
| Android debug 构建 | 通过，39.0 秒 |

首次完整覆盖率运行曾停在 `source_search_tasks_test.dart` 的套件加载阶段，未开始该文件用例；核对进程身份后结束该测试进程，该轮为 1973 项通过、1 项加载失败，随后以并发 4 重跑。另次扩大核验为 1984 项通过、1 项失败，发现上文普通详情恢复问题，已经补测并修复。最终运行使用修复后的代码，1986 项全部通过，包含此前未加载的搜索服务文件；最新完整结果以表格为准，不忽略历史失败。

命令：

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub test/services/source test/services/network_client_test.dart test/features/search test/pages/search test/architecture/dependency_boundaries_test.dart --reporter expanded
flutter test --coverage --reporter expanded --concurrency 4
flutter build windows --debug --no-pub
flutter build apk --debug --no-pub
```

本轮日志位于 `%TEMP%/hazuki-search-cancel-*.log`，最终完整通过日志为 `hazuki-search-cancel-full-verified.log`，平台日志为 `hazuki-search-cancel-windows-build.log` 和 `hazuki-search-cancel-android-build.log`。完整测试、Windows 构建和 Android 构建已顺序执行通过。产物为 `build/windows/x64/runner/Debug/hazuki.exe` 和 `build/app/outputs/flutter-apk/app-debug.apk`。没有修改原生实现，复用既有测试 DLL，独立包检查不冒充本轮重新执行。

## 未实施范围

其他业务服务的统一任务迁移、下载暂停/删除取消、图片缓存共享订阅取消、运行时健康检查及自动恢复均未实施。没有新增任务页、持久化任务表或运行时池。真机/模拟器操作、原生 Sanitizer 和其他平台构建尚未执行；主机测试不能替代这些验证。
