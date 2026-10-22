# 第三阶段实施方案：任务取消、精确中断与运行时恢复

状态：原生取消、代理/宿主资源、搜索及第四批其他服务接线已实现；第五批已提交并接入图片共享订阅、阅读生命周期、封面及封面预取。生产 worker 显式启用控制，独立包默认仍关闭。第六批已提交为 `c97aad1f`，接入下载取消、运行租约、暂停/恢复、删除与文件收尾；第七批接入云阅读私有会话、共享历史、页面取消与上传服务租约/FIFO。健康判定和自动恢复仍未实施。最新结果及测试场景映射见 [第七批云阅读验收](QUICKJS_CLOUD_READING_TASK_CONTROL_VALIDATION.md)；第六批结果见 [第六批下载验收](QUICKJS_DOWNLOAD_TASK_CONTROL_VALIDATION.md)；第五批结果见 [第五批图片与阅读验收](QUICKJS_IMAGE_READER_TASK_CONTROL_VALIDATION.md)；历史结果见 [第四批服务接线](QUICKJS_SERVICE_TASK_CONTROL_VALIDATION.md)、[搜索接线](QUICKJS_SEARCH_TASK_CANCELLATION_VALIDATION.md)、[第一批](QUICKJS_TASK_CONTROL_VALIDATION.md) 和 [第二批](QUICKJS_HOST_TASK_CONTROL_VALIDATION.md)。

第三批历史验证（2026-10-21）：627 项针对性测试、1986 项完整覆盖率测试、格式检查及静态分析全部通过，随后完成 Windows 和 Android debug 构建。

第四批历史验证（2026-10-22）：1066 项针对性回归、875 文件格式检查、静态分析及 Windows/Android debug 构建通过；完整覆盖率为 **2008 项通过、1 项失败**，失败为基线 `4ba4a7aa` 导航玻璃厚度断言不一致。详细结果见对应验收记录，不能用历史完整通过结果掩盖当前失败。未做真机交互、其他平台或独立包重新检查。

第五批验证（2026-10-22）：878 文件格式检查、静态分析及 **1327 项针对性回归通过**；最终完整覆盖率为 **2041 项通过、1 项基线失败**；Windows/Android debug 构建通过。详细结果见第五批验收记录。导航基线断言按用户选择保留，不修改 UI 或断言制造全绿，完整应用验收尚未全部通过。

第六批验证（2026-10-22）：880 文件格式检查、静态分析及 **1250 项针对性回归通过**；完整覆盖率为 **2064 项通过、1 项既有导航基线失败**；Windows debug（21.1 秒）与 Android debug（35.9 秒）构建通过。第六批已提交为 `c97aad1f`。完整应用验收尚未全绿，详细记录见第六批验收文档。

第七批验证（2026-10-22）：886 文件格式检查、静态分析及 **1205 项针对性回归通过**；完整覆盖率 **2090 项通过、1 项既有导航基线失败**；Windows debug（30.8 秒）与 Android debug（25.9 秒）顺序构建通过。按修订计划整批作为一个 Conventional Commit，排除用户既有搜索栏及 `CLAUDE.md` 修改。**完整应用验收尚未全绿**；场景映射、命令和日志见第七批验收记录。

## 1. 目标、约束与现状

目标是让取消贯穿服务操作、worker 排队、HTTP、重试、插件延时、JS 运算和结果回传，保留同源共享状态与异步并发。普通取消只影响目标调用及无人继续使用的工作；独立的搜索、阅读和下载可以继续。

继续使用一个运行时对应一个 worker 和一个 QuickJS 实例。保留 UI、动画、JavaScript API、现有默认超时及登录事务，不增加运行时池、持久化任务表或任务管理页面。后台运行时关闭仍须正常清理，不使用 `Isolate.kill` 代替释放。

当前可复用的基础（其余章节保留整体目标，不能视为所有业务均已实施）：

- `SourceTaskRegistry` 已由宿主持有；搜索、第四批服务及第五批阅读/图片具有取消/超时终态、实际 handle/engine 绑定及资源收尾回执。页面读取、阅读租约与服务写入分开归属，Dart 已开始的提交计入收尾；下载完整生命周期已在第六批提交；第七批云阅读与上传同样进入统一任务表。
- `SourceScriptEngine` 的命令有调用 ID、运行时 ID 和执行身份；原生 Promise reaction、job 和远程回调已保留注册上下文。
- 插件 HTTP 已贯通 `CancelToken`，网络重试及搜索 450 ms 等待可取消；搜索替换/退出已实测停止目标 HTTP 和 Timer。
- worker 的 Timer、宿主 Future、远程句柄按 work/task 清理，普通作业故障按实际 token 隔离，正常取消不关闭整个同源运行时。
- 图片缓存按实际 handle 内的 source/URL 合并共享生产者，逐消费者订阅，最后消费者退出停止调度/脚本/GET。阅读与封面已接入释放；无 origin 的调用仍保留独立订阅；第六批下载使用逐运行订阅、可取消源任务和文件提交屏障。

## 2. 对外语义与接口

### 任务与归属

将唯一的任务管理器放在 `SourceRuntimeHost`，管理当前及仍有租约的旧运行时；搜索服务不再另建独立注册表。每次服务操作创建一个业务 task，内部能力检查和脚本命令复用该 taskId，各命令仍有独立 callId/nativeToken。子服务调用显式接收父执行上下文，不通过共享“当前任务”变量推断。

在搜索、分类、收藏、账号、阅读、图片、插件动作和诊断的异步 Dart 网关、服务及适配器上增加可选 `SourceTaskOrigin? taskOrigin`；已有搜索参数保持兼容。未提供时创建独立服务归属。`resultDisposition` 和取消监听器只留在主 isolate，wire DTO 只传普通字段。

扩展 origin/execution/snapshot，记录 ownerId、groupId、operationKind、parentTaskId（可空）、deadlineAt（可空）和取消原因。保留现有插件 ID、版本、方法、运行时、请求序号及时间字段。

新增可注入的 `SourceTaskControlGateway`：

```dart
Future<SourceTaskCancelReceipt> cancelTask(String taskId, SourceTaskStopReason reason);
Future<SourceTaskCancelReceipt> cancelGroup({
  required String ownerId,
  required String groupId,
  String? pluginId,
  required SourceTaskStopReason reason,
});
Future<SourceTaskCancelReceipt> cancelOwner(String ownerId, SourceTaskStopReason reason);
```

receipt 区分已请求、已结束和不存在，携带 `whenSettled`；请求方法不等待其他调用仍使用的共享工作。`whenSettled` 在目标调用终止、订阅解除及其非共享资源清理后完成。共享资源转由剩余消费者持有，另记保留数量，不能冒充“全部底层工作已停止”。重复取消幂等，终态只写一次。

### 第七批云阅读与上传口径

读取会话固定主 handle/账号、私有 engine 和代次；初始化与历史刷新独立共享，切源立即停止读取，私有暂存永不提交主账号。已接纳上传同步冻结数据、登记任务并持有 `SourceServiceRuntimeLease`，退出/换章/切源后继续原主运行时 FIFO；账号/catalog 撤销旧队列。阅读、下载、上传共同保留非活动 handle，不恢复撤销的交互权限。上传的默认 30 秒执行预算从轮到该笔时开始，排队时间不计入；其他调用现有 `SourceTaskOrigin.workTimeout` 计时语义保持不变。超时结构化停止，收尾释放租约后继续下一项，不重试或重放。详见第七批计划与验收。

### 状态、异常与截止时间

- 状态为 created、running、cancelRequested、succeeded、failed、cancelled、timedOut。排队、执行、等待宿主及等待 Promise 另作命令阶段，避免一个业务任务多条命令间反复改变业务状态。
- 原因使用枚举：user、superseded、ownerDisposed、downloadPaused、pluginDisabled、pluginUpdated、deadlineExceeded、executionTimeout、runtimeClosed、downloadPaused、accountChanged。运行时故障使用单独错误类型，不伪装成取消。
- 新增 `SourceTaskCancelled`、`SourceTaskTimedOut`、`SourceRuntimeFailed` 类型，携带 taskId/runtimeId 和结构化原因；扩展值编码保留这些类型。取消不能被 HTTP 错误包装、重新登录或自动重试吞掉。
- 主 isolate 串行裁决取消、截止时间和已解析结果的先后；接受取消后，迟到成功结果只能丢弃。结果已完成后取消返回“已结束”。请求序号检查继续保留。
- 普通搜索及聚合搜索每次服务调用沿用当前 25 秒期限；自动重试的新调用重新计时，分组不设新的总期限。除第七批单笔上传新增的 30 秒执行预算外，其他操作不增加总超时，保留现有网络、初始化等待和单次 JS 五秒配置。UTC 时间用于日志，进程内 Stopwatch/剩余预算用于计时。

## 3. 原生控制通道与 worker 协议

先完成原生隔离测试，再连接生产取消入口。

1. 在独立 QuickJS 包中增加运行时控制表，以不透明递增 uint64 controlId 访问 `shared_ptr<ControlState>`。worker 创建并绑定该对象，ready 消息返回 controlId；主 isolate 只能操作线程安全的控制状态和通信缓冲区，不能访问 JSRuntime/JSContext 指针。
2. 主代理在发送命令前分配并注册 nativeToken，worker 使用传入 token，替换当前私有递增 token。控制槽保存业务身份、停止请求、原因和资源引用；只有命令结束且 native job/reaction/Timer/句柄引用归零后才注销。保留 finished task 的资源索引，允许页面退出时清理已经返回结果后遗留的回调。
3. 取消同时写入原生控制标志并发送绕过普通队列的 worker 控制消息。原生中断处理器在所属线程查询当前执行 token，仅中断符合条件的目标执行；等待其他任务网络时取消 A，不能中断正在运行的 B。超时与取消分别记录首个生效原因。
4. worker 从队列删除尚未启动的目标命令，清理其计时器和回调，拒绝对应 Future。取消同步桥接等待时唤醒对应 mailbox，并传递结构化停止原因；正常结果和取消/关闭竞态只完成一次，迟到响应安全忽略。
5. 新增 `executePendingJobStep()`，返回 job token、执行结果、错误和中断原因；保留现有包 API 作为兼容包装。原生在恢复外层上下文前保存失败 job 身份，worker 据此只结束所属操作。运行时内部作业失败另走运行时故障处理。
6. 已取消 reaction 不执行用户 handler；由原生 Promise/async continuation 路径结束该分支的派生 Promise 并释放引用，不能单纯丢弃 job 导致 await 永久悬挂。被取消上下文不得再发起宿主副作用或新的独占延时。
7. 正常取消后 worker 完成受控清理及检查点，继续有限批次调度其他任务。不能复用目前“遍历 calls 全部报错”的分支处理任务级取消或普通单任务 JS 错误。

注册、取消、注销和运行时关闭使用相同生命周期锁规则；关闭从控制表移除 ID 并唤醒等待者，持有共享引用的在途原生调用退出后才销毁控制对象。不得通过裸地址查找已释放内存。

## 4. 共享 Promise、HTTP 和图片资源

**默认规则：取消调用方不等于销毁其他调用仍依赖的生产者。** 实际依赖与普通同源并发分开记录，沿用原注册上下文记日志。

- 原生为 Promise 创建、adoption、reaction、await continuation、组合 Promise 和解析器记录 workId、生产关系及消费者边；边在订阅、结算、取消或释放时更新。控制状态只保存 ID 和依赖数据，不保存可供其他线程调用的 JS 对象。
- 共享存活判定使用从未取消操作/有效运行时后台订阅出发的图可达性，并处理环；不能仅以边引用计数判断，否则无活跃消费者的 Promise 环会永久保留资源。引用计数只管理实际对象内存。图遍历和原生取消判定在 worker 执行，主 isolate 只更新停止标志；遍历不持有阻塞主侧控制请求的生命周期锁。
- 取消一个共享 Promise 的消费分支时，拒绝该分支的派生结果，保留原 Promise 及其他 reaction。某个生产者仍被未取消任务依赖时，保留所需生产工作，标记 `retainedForConsumers`，暂不向该工作下发中断或 HTTP abort。消费者全都离开后再停止。
- 依赖关系决定资源是否还能取消，不改变 callback 的注册 taskId。脱离调用方的保留工作进入运行时资源表，不能留在活动业务任务表中伪装成运行中搜索。
- 只保护已经建立的依赖；后来订阅已经终止的生产者得到明确依赖失败，不能永久等待。任意共享 JS 全局变量无法自动回滚，不能声称恢复了插件取消前的业务状态；登录仍按已有暂存事务回滚。
- 图片 `imageDownloadInFlight` 从裸 Future 改为共享请求对象，管理各调用方订阅、优先级、缓存意愿及独立资源任务。取消一个订阅不取消其他订阅；最后一个订阅退出才取消调度队列/HTTP/转换。缓存与结果提交均检查运行时版本和仍有效的消费者。
- 在 `SourceHttpGateway.request/getBytes/sendJsHttpRequest` 及图片下载器中显式传递资源对应的 CancelToken。同步发送前、重试前后检查停止状态；网络重试等待使用可取消 Timer。取消返回结构化错误，不作为普通 HTTP body/error 文本处理，不继续重试或重登录。
- worker 的 Timer、宿主调用、远程句柄按 workId 和执行上下文建立索引。取消后拒绝迟到宿主调用、响应和回调；已经提交到权威存储的普通写入不承诺撤销，未提交的登录 Cookie/秘密存储继续遵守现有事务。
- 远程函数句柄在 wire 中携带所属 runtimeId、注册 taskId 和 workId；主代理调用和释放时保留该归属，worker 校验句柄记录。不能把回调命令自动生成的内部身份用于取消或覆盖原注册身份。

共享依赖的原生验证是正式接线的前置门槛。若边或 continuation 清理不完整，修复并补测后再推进，不能以关闭同源引擎、串行所有调用或改为每任务运行时规避隔离要求。

## 5. 页面与后台任务接入

| 入口 | owner／分组及取消规则 |
|---|---|
| 普通搜索、直接 ID 查询 | 控制器独立 owner；新查询取消旧分组；分页和自动重试沿用分组，每次服务调用新 taskId；450 ms 重试等待可取消，取消不进入重试分支。 |
| 聚合搜索 | 同次查询共享 groupId；以 pluginId 过滤单源取消；新查询或释放控制器取消全部旧分组；排序/单源重试只替换该源分支，保留其他分支。 |
| 阅读与预取 | 阅读会话独立 owner，章节/预取各自分组；换章和退出只取消所属工作。共享图片订阅解除，不误伤下载。 |
| 下载、封面与图片处理 | 下载服务 owner，每个持久化下载 storageKey 对应一次运行分组；暂停/删除取消该分组，暂停全部逐组取消；恢复生成新分组，保留已完成文件和既有断点规则。取消不作为瞬态网络错误重新排队。 |
| 登录与云阅读私有会话 | 保留独立 runtime 和现有取消信号，映射到任务控制；关闭交互、释放临时运行时、回滚事务。主运行时的其他操作保持有效。 |
| 插件动作及维护 | 未指定页面归属时使用独立服务任务；运行时维护任务明确归属于 runtime，不归入最近一次搜索。 |

将 coordinator 的退役原因区分为切源、版本替换、停用和故障。切源仅取消已失去页面用途的分组，保留有效阅读/下载租约；停用或版本替换取消对应旧插件/运行时工作并使旧句柄失效。所有条件以 runtimeId 和实际 handle 身份判断，不能只靠插件 ID 误伤新实例。

下载文件写入前后都检查运行分组及现有下载状态，取消后不提交完成进度。已经开始的普通文件 IO 等待收尾，再解除该写入租约；删除任务/文件前等待目标 `whenSettled`，防止删除后又被迟到写入重新创建。暂停保留已有完整文件，不把不可中断的文件写入描述为已被立即中断。

## 6. 健康判定与恢复

- 普通脚本异常与可定位的取消/超时首先按任务结束，保持运行时可用。worker 清理停止任务关联的 job/continuation、宿主和句柄后，以内部上下文执行只读 `0` 探针，检查原生状态、待完成调用及引用一致性；不运行插件方法作为探针，不改现有脚本超时配置。
- 只有 worker 异常退出、原生损坏/清理不完整、探针失败或无法定位的内部调度错误才判为不可用。不能仅因一个业务任务被取消就重建运行时。
- 不可用时拒绝该旧实例的新命令，以 `SourceRuntimeFailed` 结束仍归属旧实例的排队及在途调用，保留结构化故障原因。此处属于运行时故障，不得宣称其他任务“正常完成取消”。
- host 对每个失败 runtimeId 只启动一次候选重建，使用现有 loader、当前插件版本和权威会话数据；通过 handle/版本检查后整体发布。并发新调用等待同一个恢复 Future；重建失败保留明确失败状态，使用现有手动重试入口，不无限重建。
- 不自动重放任何已经接纳的搜索、登录、收藏、存储写入或插件动作，也不把旧队列转移到新实例。重建只服务新操作；旧回调、快照、响应和取消请求均按旧 epoch 拒绝。
- 原生资源仍由 worker 正常释放；故障退出时清理主侧控制表、mailbox 和 Future。无法正常释放必须报告，不能默认为成功。

## 7. 实施顺序与诊断

按以下顺序提交可评审的小批次，尚未通过隔离门槛前不开放生产取消入口：

1. 原生控制表、精准 job 结果、共享依赖及 continuation 清理；独立包测试验证无串扰及无引用泄漏。
2. 统一服务任务管理和停止错误编码，贯通 proxy/worker/宿主资源索引；用假宿主验证排队、等待、关闭与取消竞态。
3. HTTP/重试/插件 Timer 与图片订阅取消，随后接入搜索、阅读、下载和登录 owner；保留旧请求序号作为结果保护。
4. 健康判定与单次恢复、旧 epoch 隔离；完整回归后正式启用所有入口，更新迁移记录。

复用日志开关、脱敏和导出，增加 parentTaskId、operationKind、deadlineAt、cancelRequestedAt、executionStoppedAt、settledAt、stopReason、共享保留原因、运行时恢复结果。排队和执行耗时来自真实 command 阶段事件，不用服务总耗时冒充排队时间，不记录关键词、凭据或完整脚本。

## 8. 验收与验证命令

| 场景 | 验收断言 |
|---|---|
| 持续计算／初始化／图片脚本 | 原五秒配置保留；主动取消在等待现有超时之前生效，主 isolate 心跳与 Flutter 帧推进；取消、截止时间和脚本超时原因可区分。 |
| 原生取消精准性 | 通过进入脚本的同步握手设立屏障，在五秒预算下请求取消；专用测试要求两秒内结束目标调用，并证明正在执行的非目标 token 未中断。 |
| 连续搜索、分页、自动重试 | 旧独占 HTTP 和重试 Timer 真正结束，不再继续提交调用；当前结果正常；取消不是成功，不被重试吞掉。 |
| 同源搜索／阅读／下载 | 分别取消任一项，其余独立操作结果和日志正常；运行时 ID 不因正常取消改变。 |
| 共享 Promise／await／thenable／all/race/any/allSettled | 消费者取消不破坏其他 reaction；被保留的生产者正确结算；无消费者后可停止；取消派生链不悬挂，任务和 native 引用可释放。 |
| 共享图片请求 | 两个订阅取消一个不 abort；全部取消才 abort；取消排队不占并发名额；取消调用方不提交缓存或下载进度。 |
| 登录取消／存储提交 | 交互与宿主等待结束，Cookie/秘密存储按事务回滚；普通已提交写入不被假装撤销；迟到响应不写入新会话。 |
| 停用／更新／切源 | 停用与更新结束旧 epoch，旧回调失效；切源保留有用途的后台租约，新操作使用当前实例。 |
| 故障恢复 | 正常取消不重建；内部故障只重建一次；重建失败可由既有入口重试；旧副作用操作不重放，旧快照不覆盖新缓存。 |
| 竞态与资源 | 结果/取消/超时/关闭同时到达只终结一次；重复取消安全；反复重建后活动控制槽、mailbox、Timer、远程句柄和原生注册回到基线。 |

每批先运行针对性测试。应用执行 `dart format --output=none --set-exit-if-changed lib test`、`flutter analyze`；原生测试前运行 `dart run tool/build_quickjs_test_library.dart`。独立包在其目录执行依赖安装、修改文件格式检查、分析和全部测试，新增测试纳入当前 CI。正式切换后运行一次 `flutter test --coverage --reporter expanded`、`flutter build windows --debug` 和 `flutter build apk --debug`。真机、其他平台及无法验证的行为单独记录，不能用宿主单元测试代替设备验证。
