# 第三阶段第四批：其他图源服务任务接线验收

日期：2026-10-21 至 2026-10-22。基线：`bb881f0a`。本批未创建提交或 PR，保留开始时五份工作区文档及其修改。没有修改 UI 外观、布局、动画、QuickJS 原生包、控制协议或默认五秒配置。

## 已接入范围

- 发现、插件推荐、分类、排行、收藏读取与变更、评论读取/发送/点赞、头像、签到、普通/交互登录、退出登录、插件动作，以及设置脚本回调和线路操作。
- 相关网关、服务、适配器增加可选 `taskOrigin`；页面和控制器从 composition root 显式接收任务控制入口，测试注入假实现。每次业务调用创建任务，内部辅助方法显式传递 `SourceOperationContext`，不使用全局当前任务。
- `SourceTaskRegistry` 按实际 handle 归属停止任务，实际 engine 绑定后用于取消。停用/版本替换先记录结构化原因，再撤销交互权限；未迁移的阅读、图片和下载操作不纳入这次任务筛选。
- 页面读取使用独立 owner/group，替换取消旧分组，分页保留分组并增加调用序号。保留原请求版本检查；销毁释放 owner，临时遮挡和切换标签不增加取消。
- 收藏变更、评论写入、签到、退出登录、插件动作及设置回调由服务持有，页面离开后继续完成已经接纳的非交互工作。权限仍归原发起页面，等待中的交互关闭或之后请求输入会结束对应操作，不能借此在后台重新弹窗。
- `retainAdmittedWork` 仅是 Dart 代理的显式命令选项，默认关闭；服务上下文允许后续非交互命令继续，仍携带旧 UI scope，不能恢复已撤销权限。业务完成时撤销服务 scope，遗留原生回调不获得新的交互权限。
- Dart 权威写入和共享资源解除后的 drain 纳入任务收尾；业务终态与资源归零分开，成功任务可以清理遗留 Timer 而不改变成功状态。已开始的普通写入等待完成，不承诺回滚。

## 共享、账号与兼容性

- 初始化继续使用独立共享生命周期。调用方停止立即结束其业务等待，完成初始化后不得再提交该任务脚本；没有通过关闭整个同源运行时取消读取。
- 头像在途合并改为独立生产者和逐调用方订阅；取消一个保留另一个，最后消费者退出停止生产者，迟到结果不写缓存。保留原有 15 秒预算及头像超时返回缓存的 API 行为，底层任务仍记录超时和停止。
- 自动重登录使用服务任务，不继承读取的取消信号。读取取消不等待维护任务结束，维护完成后也不重试已停止读取。取消绕过认证重试、普通错误包装和可选数据降级；被停止的依赖仍按失败处理。
- 普通登录和交互登录都具有任务身份。登录框关闭会取消其任务，并保留 `SourceLoginCancelled` 兼容识别；交互登录继续使用私有运行时和原事务。内部失败后的清理取消单独标记，不能将普通 `login_method_unavailable` 等错误改报成用户取消。
- 保留普通错误返回、无来源时的空/跳过结果、现有缓存优先级和预算。页面已有超时继续驱动任务停止，等待输入暂停计时，没有统一新增 25 秒期限。
- 任务日志复用开关和脱敏，登录凭据、评论内容、收藏名称和设置字符串作为敏感值处理。生命周期清理不依赖日志开关。

## 验证状态

新增服务/worker 回归 16 项、发现控制器生命周期回归 4 项，并补充登录取消兼容回归 1 项。新回归组合连同一项原登录测试共 **22 项通过**；最终代码的扩大回归、检查与构建状态如下。

| 检查 | 本批实际结果 |
|---|---|
| `dart format --output=none --set-exit-if-changed lib test` | 875 文件，0 文件变化，通过 |
| `flutter analyze --no-pub` | 无问题，通过 |
| 图源、网络、推荐、搜索、发现、收藏、评论、账号、详情及架构回归 | **1066 项全部通过**，48 秒 |
| 完整覆盖率测试 | **2008 项通过、1 项失败**，4 分 40 秒；生成 `coverage/lcov.info` |
| Windows debug 构建 | 通过，22.2 秒 |
| Android debug 构建 | 通过，37.2 秒 |

新增回归验证初始化前停止、多命令身份、真实 HTTP abort、Timer 清理、同步运算中断、同源写入继续、退出后下一条非交互命令、交互权限撤销、已开始写入收尾、成功任务遗留资源、来源切换、版本替换/停用原因、共享头像及独立重登录等待。正常取消保持原 runtimeId，旧 owner 不能停止新实例。

扩大核验曾发现并修复头像超时缓存兼容、评论回复取消异常外泄、普通登录失败被清理取消覆盖、插件动作同步抛错、遗漏的参数转发及 mock 匹配等问题。失败日志保留，最终状态仅以本表最后实际执行结果为准。

## 已复现的基线失败

`test/features/home/home_bottom_navigation_test.dart` 中 `uses liquid glass surface and preserves destination taps` 在第 237 行期望 `settings.thickness == 10`，当前实际为 `72.0`。相关 UI/样式来自基线历史 `4ba4a7aa`，本批对该测试、`home_bottom_navigation.dart` 和 `liquid_glass_support.dart` 的 `git diff HEAD` 均为空；单独运行该文件也复现同一失败。

本批没有改 UI 参数、放宽或删除该断言。本轮完整套件已执行并记录这一失败；不得据历史第三批 1986 项通过追认当前基线或本批完整验收通过。

最终完整覆盖率运行仅剩上述一项失败，没有其他失败。因此服务任务接线和针对性验收已完成，**完整应用验收尚未全部通过**。

## 命令与日志

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub test/services/source test/services/network_client_test.dart test/services/discover_daily_recommendation_service_test.dart test/services/discover_recommendation_components_test.dart test/services/discover_recommendation_cache_store_test.dart test/features/search test/features/discover test/features/favorite test/features/comments test/features/home/home_profile_controller_test.dart test/features/home/home_profile_avatar_test.dart test/features/home/home_coordinator_test.dart test/features/home/home_source_account_login_test.dart test/features/comic_detail test/features/settings/source_plugin_action_placement_test.dart test/features/settings/source_plugins_page_test.dart test/pages/discover test/architecture/dependency_boundaries_test.dart --concurrency 4 --reporter expanded
flutter test --coverage --reporter expanded --concurrency 4
$env:Path = 'D:\Visual Studio 2026\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin;' + $env:Path
flutter build windows --debug --no-pub
flutter build apk --debug --no-pub
```

日志位于 `%TEMP%/hazuki-stage4-*.log`。最终记录使用 `format-final`、`analyze-final`、`targeted-final-verified`、`full`、`windows-build`、`android-build` 后缀；中间失败日志不能代替最终结果。完整测试和平台构建顺序执行。

本轮构建产物为 `build/windows/x64/runner/Debug/hazuki.exe`（配套 `data/flutter_assets` 含本批 Dart 实现）和 `build/app/outputs/flutter-apk/app-debug.apk`。构建通过不等同于完整测试通过；本轮 `git diff --check` 通过，原生包、依赖清单、assets 和 CI 没有修改。

阅读/预取、图片订阅取消、下载、运行时健康判定与自动恢复尚未实施。真机/模拟器交互、原生 Sanitizer、其他平台构建和独立包重新检查未执行；本批使用已有原生测试 DLL。
