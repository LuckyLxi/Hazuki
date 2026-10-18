# 第三方授权验证记录

## 公开脚本与未登录入口

再漫画公开脚本声明微信、QQ、微博的 web/auth_url，将返回地址交给浏览器。脚本读取 URL 查询参数 token 并写 Cookie，再查询账号资料。公开脚本位于独立 Sources 仓库 scratch/zaimanhua/，不纳入提交；支付不列为已确认阻碍。

2026-10-18 检查真实入口：微信返回 open.weixin.qq.com/connect/qrconnect，QQ 返回 graph.qq.com/oauth2.0/authorize，微博返回 api.weibo.com/oauth2/authorize。各入口指定网站自身 account-api.zaimanhua.com/v1/{provider}/web/auth_back，带有 state。state 的生成和验证规则未逆向确认。

微信入口接受 https://i.zaimanhua.com/login、https://manhua.zaimanhua.com/。本次传入自定义协议、本机 HTTP/HTTPS 回调及 example.com HTTPS 回调，均返回 errno=1、“参数错误”；这不是完整域名白名单的证明。

## 用户参与的真实微信授权

2026-10-18 用户在独立桌面 Edge 测试窗口完成微信授权。观察到 https://i.zaimanhua.com/login 带 token 查询字段，随后回到网站。使用该站点主机专属的 token Cookie 请求 https://account-api.zaimanhua.com/v1/userInfo/get，HTTP 200、errno=0，存在账号资料。验证仅保留地址结构、字段名、状态及 Cookie 属性，不保存凭据或完整回调。

观察到 token Cookie 同时存在主机范围与父域范围记录，其生命周期不同；未将它们视为宿主插件 Cookie，也未导入宿主。开始时用户先完成过账号密码登录，该次操作不作为第三方成功证据。

## 宿主实现与待验收项目

宿主提供通用 context.requestBrowserAuthorization：Windows 隔离 WebView2 环境、Android 独立 WebView Profile；精确 HTTPS 回调、完成/取消/超时、无密码会话标记和现有登录事务。不含再漫画专用逻辑，生产插件未修改。

2026-10-18 用户再次在宿主真实内嵌 WebView2 授权窗口完成微信扫码。临时测试程序确认精确回调已截获，使用回调中的令牌查询账号资料成功。只保存 callbackCompleted=true、accountVerified=true，不保存回调或账号数据。该结果验证 Windows 内嵌流程；没有修改生产再漫画插件。

Windows 原生自动测试使用合成数据验证 Cookie、localStorage、IndexedDB、Cache API 在不同授权会话之间隔离，以及顶层回调截获。测试入口是 test/platform/source_authorization_browser_smoke.dart，需要联网访问 example.com，不使用真实账号。

目录清理测试发现 flutter_inappwebview_windows 0.6.0 的环境通道绑定及释放时序问题。局部覆盖保留上游许可证，修复环境 ID，关闭隐藏控制器，并等待 BrowserProcessExited 后完成释放。原生重测已确认会话目录被删除，另有依赖包回归测试验证不同环境各自释放。

以下仍须独立验证，不宣称已打通：

- Android 真机上的真实微信成功流程，以及 Profile 支持/不支持两条原生路径。
- QQ、微博真实账号授权，包括拒绝、失效和取消路径。
- 网站允许的完整 backUrl 范围、state 规则及 Cookie 有效期。
- 各网站需要跳转第三方 App 的真实授权流程；宿主现有通用拉起与回传能力，不代表微信、QQ 原生 SDK 兼容。

Windows WebView2 的成功不能代替 Android 验证。Android 无 MULTI_PROFILE 时仅提供更新组件提示，不退回共享 Cookie 环境。

## 三项能力扩展（2026-10-18）

网站阅读进度通过插件声明 loadReadingProgress / loadReadingHistory 启用，没有再漫画 ID 或域名识别。声明读取后在线进度以网站为准；旧本地位置和 WebDAV 数据不作为恢复备选，离线继续使用本地位置。网站读取在独立运行时中执行，私有数据、Secrets 和 Cookie 写入仅存在本次账号读取会话，不提交正常插件状态；换号、退出、切源、停用或宿主销毁时关闭该运行时的 HTTP 客户端并丢弃迟到结果。插件读取接口应只读取数据，不依赖其写入正常运行时全局变量或私有存储。

自动测试已覆盖：网站接口优先级、无记录及失败不回退、数字章节 ID、缺省 maxPage 的全量分页、账号缓存隔离、迟到 HTTP 和 Cookie、历史去重及换号清屏、原始图片页码恢复和越界修正、单双页与条漫、在线不写本地位置以及现有离线与 WebDAV 行为。切章、章节面板扩展与返回动画的现有回归测试保留。

Windows 原生模拟授权 App 位于 test/platform/fixtures/external_authorization/，不含真实凭据或网站 SDK；由系统 URI 关联拉起，再通过注册协议启动回调进程，转交当前用户命名管道。test/platform/source_external_authorization_smoke.dart 已验证两个并行会话、真实跨进程回传、错误路径、重复和无待处理回调、取消后的迟到回调，以及未安装协议的脱敏错误。测试只写布尔值；临时 mock 协议在测试结束时按所属命令清理。协议查询采用 Windows AssocQueryStringW，未关联协议不会打开系统应用选择器。

Windows Cookie 原生测试使用合成 HttpOnly、Secure、SameSite 和持久 Cookie，并验证主机范围、到期时间、指定名称过滤、隔离和目录释放。授权视图保持 InPrivate 且使用独立环境目录；Cookie 读取固定调用本次视图浏览器上下文的原生 Network.getCookies，不经网页 JavaScript，也不使用默认或系统浏览器 Cookie。Windows 依赖覆盖同时修正 Cookie 到期时间的秒/毫秒转换。

Android 使用本次 Profile 的 CookieManagerCompat.getCookieInfo，要求 GET_COOKIE_INFO 与 MULTI_PROFILE；无支持时提示更新。Chromium 的导出格式会为主机 Cookie 显式写出 domain=host，因此浏览器快照解析与 HTTP Set-Cookie 解析分开处理主机范围，不把主机 Cookie 扩大为域 Cookie。参考：[AndroidX 接口](https://developer.android.com/reference/androidx/webkit/CookieManagerCompat)、[Chromium 导出实现](https://chromium.googlesource.com/chromium/src/+/badf72dc6e24b0e7abb016aa49bedc9d361c06cd/android_webview/browser/cookie_manager.cc)。

仍未验收：Android 真机上的外部应用回传、Profile 支持和不支持分支的系统集成、Cookie 属性读取与进程重启清理；本轮没有连接 Android 设备。也没有使用真实网站账号验证新增的网站历史导入、Cookie-only 登录或外部原生 App 授权。先前 Windows 内嵌微信成功仅证明令牌回调登录，不作为这三项真实网站成功的证据。QQ、微博及需要特定 AppID、签名或原生 SDK 的流程继续待验证。

通用示例及类型契约同步在 Sources 的 docs/examples/cloud-and-authorization.js、docs/API.md 和 docs/hazuki-source.d.ts；没有修改再漫画生产插件，也没有提交网站脚本、浏览器数据或凭据。另一位 AI 对生产插件和其测试的已有修改予以保留。

### 本轮交付检查

- `dart format --output=none --set-exit-if-changed lib test`：802 个文件，无格式差异。
- `flutter analyze --no-pub`：无问题。
- 源运行时、阅读器、历史、详情、WebDAV 与路由动画的针对性回归：658 项通过。
- 封面动画文件单独复跑：4 项通过，`routed background fades in and reuses the cover on reentry` 仍失败。此前在干净 HEAD 60bdb136 上已复现相同失败；本轮不改动既有动画来绕过它。
- Windows 原生模拟 App：跨进程回传、会话隔离、错误路径、重复/取消/无会话及未安装协议均通过。
- 浏览器网页夹具为 `test/platform/fixtures/browser_authorization/login.html`。原生测试通过 CDP Fetch 返回本地 HTML 与合成 Set-Cookie，在 HTTPS 上下文验证 HttpOnly 等属性；不忽略证书错误，初始 example.com 页面仍需联网。Cookie、localStorage、IndexedDB、缓存隔离及最终目录删除均通过。
- Windows 依赖覆盖的环境释放测试通过，相关依赖 Dart 格式与静态分析通过。
- `flutter build windows --debug --no-pub`、`flutter build apk --debug --no-pub`：均成功，最终产物使用 `lib/main.dart`。
- Sources：类型检查、通用示例独立类型检查、Prettier 检查通过；116 项 Node 测试通过。
- Android 无连接设备；Windows 安装器/卸载器的注册项所有权逻辑尚未执行实际安装卸载验收。此前列出的真实网站与 Android 系统集成边界仍然有效。
