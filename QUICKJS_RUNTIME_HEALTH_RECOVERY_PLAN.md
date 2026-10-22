# 第八批：运行时健康判定与单次自动恢复

## 实施状态

已按本计划在 `dev`（基线 `f7181f4b`）实施，结果与场景映射见 [第八批验收记录](QUICKJS_RUNTIME_HEALTH_RECOVERY_VALIDATION.md)。范围对应 [第三阶段方案](QUICKJS_CANCELLATION_RECOVERY_PLAN.md) 第 6 节；最终设备验收拆为第九批，本批只提供清单。

## 现状与范围

实施前代码核对发现三项缺陷：

1. **故障后永久不可用**：worker 遇到不可归属作业失败或 isolate 异常退出时，engine 自行关闭，但没有上层监听。`SourceRuntimeKernel.engine` 仍指向已死实例，`_isHandleInitialized` 只检查 `engine != null`，此后该来源所有调用都报 `source_script_engine_closed`，直到重启或切源；现有状态卡“重试”也只在同一 handle 上 `ensureInitialized`，无法恢复。
2. **故障伪装成取消**：`SourceScriptEngine._fail` 以 `runtimeDisposed` 撤销 scope，registry/runner 将其映射为 `runtimeClosed`/`user` 取消，页面按静默取消处理。
3. 没有 `SourceRuntimeFailed`、健康探针或故障/恢复诊断；故障路径没有测试。

用户确认的决策：仅在原生中断 JS 后做合并探针；活动来源故障后立即单次重建、非活动来源惰性重建；故障时已接纳上传以失败结束不转移、运行中下载暂停待手动恢复；设备验收拆到第九批。

## 接口与语义

- `SourceRuntimeFailed(runtimeId, kind, {taskId, cause})`，不继承取消类型；`kind` 为 `internalJob`、`workerError`、`exitedWithoutCleanup`、`probeFailed`、`bootstrap`。`toString` 为 `source_runtime_failed:<kind>`，不含脚本或凭据。
- `SourceScriptEngine.failure` / `whenFailed` 只在故障时出现；在途与之后的新调用都以带 taskId 的 `SourceRuntimeFailed` 结束。正常关闭语义不变，`whenClosed` 仍以故障原因结束。
- 故障通过 `SourceUiService.cancelRuntime(reason: 'runtimeFailed', error: failure)` 撤销交互；registry 与 runner 对 `runtimeFailed` 不发出停止请求，任务终态为 `failed`，页面 `run` 抛出 `scope.failure`。
- 运行时故障在详情/章节的插件请求重建、搜索自动重试和下载瞬态重试之前识别，不重放；`rethrowSourceOperationStop` 保持只识别停止，避免改变缓存降级等普通错误回退。

## 探针

- 第 0 步核对结论：原生 `taskCount` 包含主 isolate 已注册、worker 尚未收到的 token，`workCount` 还含内部 Promise work，**二者不能与 worker 表精确相等**，因此不采用。
- 原生中断正在执行的 JS（job step `stopped`，或进入 JS 后命令抛出停止）时置位；在 batch 完成且无待确认取消时合并执行一次。排队中取消、未进入 JS 的命令不触发。
- 探针只检查精确不变量：内部上下文求值 `0`，以及 worker 仍持有租约的 callback/delay/host work 在原生侧存在。失败与 batch 收尾自身异常都走 `failed(kind)` 加正常关闭，不使用 `Isolate.kill`。
- 测试用 `debugInjectFault` 注入真实故障路径，worker 在 `dart.vm.product` 构建中忽略该命令。

## 宿主恢复

- loader 原子发布 engine 后由 handle `watchEngine` 监听；回调与实例同一错误 zone，只解除继承的交互 scope。故障仅在 `identical(handle.runtime.engine, engine)` 且未请求销毁时生效，旧实例迟到故障忽略。
- 生效时清除 engine 引用（保留 `sourceMeta`），记录 `lastRuntimeFailure`，状态经现有 `setFailed` 置为 failed，并写 `Source runtime failure` 诊断（runtimeId、kind、recovery）。
- 单次额度：可用时消耗；活动来源立即经现有共享初始化在原 handle 重建（相位 `retrying`），非活动来源记为 `deferred`，下一次新调用惰性重建。恢复后实例首个业务操作成功时重置额度。
- 额度用尽再故障即锁存：`_ensureHandleInitialized` 直接抛出，网络恢复跳过；仅状态卡重试（`logRuntimeRetryRequested`）、本地重新加载、手动重新下载解除。插件更新/启用经 catalog 新建 handle。
- 原地重建保持阅读/下载/上传租约；不调用 `recreateSourceRuntime`，catalog 与通用 `remove` 路径不增加全量停止。

## 已接纳工作

- 上传在接纳时记录实例；轮到执行时若该实例已故障，该项以 `SourceRuntimeFailed` 结束并记录 failed，释放租约、推进 FIFO；新接纳项使用新实例。`report` 对外仍按普通失败容错。
- 下载运行遇到故障暂停（与插件更新一致），不计瞬态重试；图片写入不再把故障吞成缺页。
- 阅读会话与租约保留，用户经现有重试发起新调用。云阅读私有实例故障后丢弃，下一次读取新建私有实例，暂存仍永不提交。登录私有运行时只换错误类型。

## 不改动的边界

不改 UI 外观、动画、文案或 l10n（失败文本沿用 `source_init_failed:<error>`）；不改原生包、依赖、assets、CI；不新增运行时池或自动重放；第七批“不要改回的边界”全部保留。
