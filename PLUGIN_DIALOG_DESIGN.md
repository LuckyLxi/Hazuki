# 插件通用交互弹窗设计

状态：第一版已实现，以下为接口与实现约束。日期：2026-10-20。

## 1. 目标与第一版范围

插件可以在一次前台操作中打开原生弹窗，组合内容，等待用户操作，原地更新并关闭。用途包括公告、确认、访问密码、线路选择、多步表单、看图输入和按顺序点图验证码。网络请求、业务校验、重试与持久化由插件负责。

第一版采用按声明顺序垂直排列的原生组件，支持多个输入和选择控件。窗口外壳、按钮、主题、键盘适配、滚动和动画沿用应用现有规范。标题附近始终显示宿主提供的插件名称，插件不能覆盖该来源标识。

第一版不包含 HTML/WebView、自定义绘制、任意样式和拖动拼图。现有浏览器授权继续走原接口；之后可以给组件类型增加滑块能力，无需另设一套弹窗生命周期。

本设计不修改既有页面、登录弹窗的外观或动画，不迁移旧登录接口。正式实现若需要改变现有视觉行为，按 AGENTS.md 单独确认。

## 2. 插件接口

新增可选 SDK 命名空间 `Hazuki.ui`，保留 API v1。旧插件不受影响；新插件用 `typeof Hazuki.ui?.openDialog === 'function'` 判断宿主是否支持。

```ts
interface PluginUi {
  isAvailable(): Promise<boolean>;
  openDialog(options: DialogOptions): Promise<PluginDialog>;
  readonly PluginDialogCancelledError: new (reason: DialogCloseReason) => Error;
}

interface DialogOptions {
  title: SourceText;
  content: DialogComponent[];
  buttons: DialogButton[];
}

interface PluginDialog {
  nextEvent(): Promise<DialogEvent>;
  update(patch: DialogPatch): Promise<void>;
  close(): Promise<void>;
}

interface DialogPatch {
  title?: SourceText;
  content?: DialogComponent[];
  buttons?: DialogButton[];
  values?: Record<string, DialogValue>;
  busy?: boolean;
}

interface DialogButton {
  id: string;
  text: SourceText;
  role?: 'primary' | 'secondary'; // 默认 secondary，至多一个 primary
  enabled?: boolean;             // 默认 true
  validate?: boolean;            // 默认 false，提交按钮可设为 true
}

type DialogValue = string | string[] | boolean | {x: number; y: number}[];

type DialogCloseReason = 'user' | 'plugin' | 'ownerGone' | 'superseded' |
  'sourceChanged' | 'background' | 'timeout' | 'runtimeDisposed' |
  'operationFinished';

type DialogEvent =
  | {type: 'action'; id: string; values: Record<string, DialogValue>}
  | {type: 'change'; id: string; values: Record<string, DialogValue>}
  | {type: 'closed'; reason: DialogCloseReason};
```

- `openDialog` 等到窗口实际展示后返回句柄；排队期间保持异步等待，排队取消时抛出 `plugin_ui_cancelled` 并附带原因。
- `nextEvent` 等待下一次按钮操作或主动启用的选择变化。字段编辑和点图结果保存在窗口本地，事件携带当前全部交互字段的值快照。隐藏或移除的字段不返回。
- 同一窗口至多允许一个未完成的 `nextEvent`；重复等待报 `plugin_ui_wait_in_progress`。
- 按钮操作或需要通知插件的选择变化被接收后，宿主立即进入 busy，冻结可编辑组件和业务按钮，阻止连点。系统关闭操作始终可用。
- `update` 对整个补丁先校验，再原子应用；成功后默认解除 busy，也可以显式传 `busy: true` 继续显示处理中。校验失败保留原内容和状态，插件可修正后再更新。
- 省略的顶层字段保持不变；提供 `content` 或 `buttons` 时替换对应数组。相同 ID、相同类型的交互组件保留当前值、焦点和选择；新组件采用默认值。通过 `values` 显式覆盖或清空值。移除组件时释放本地状态。
- 替换点图组件的图片时清空旧坐标；普通文本或按钮更新不清空坐标。
- `close` 可重复调用；窗口关闭后，当前及后续 `nextEvent` 都立即返回同一个 `closed` 结果，不遗留等待。关闭后的 `update` 报 `plugin_ui_closed`。
- 输入只在内存中存在，关闭时释放，不自动保存。业务取消应退出当前流程；SDK 提供可识别的 `PluginDialogCancelledError`，业务入口识别后停止自动重试并按普通取消结束，不显示通用网络错误。

取消异常携带稳定的 `code: 'plugin_ui_cancelled'` 与 `reason`。SDK 负责保留跨桥接的取消分类，宿主业务层按 code 识别，不依赖 JS instanceof 或错误文案。`isAvailable` 只表示当前调用有交互资格，不保证之后排队或展示一定成功。

### 2.1 第一版组件

所有组件都使用窗口内唯一的 `id`。文案使用已有 `SourceText` 翻译规则。布局由宿主适配移动端和桌面端，插件通过组件顺序和内容控制流程。

| type | 主要字段 | 行为与返回值 |
| --- | --- | --- |
| `text` | `text`, `tone?: normal / error / secondary` | 展示说明或错误，不返回值 |
| `image` | `image`, `description?` | 按比例展示图片，不返回值 |
| `input` | `label`, `initialValue?`, `placeholder?`, `obscure?`, `keyboardType?: text / number`, `required?`, `maxLength?` | 返回字符串；数字键盘仅提示输入方式，业务格式由插件验证 |
| `select` | `label`, `options: {value, label}[]`, `multiple?`, `initialValue?`, `required?`, `notifyChange?` | 单选返回字符串，多选返回字符串数组；默认单选且不通知变化 |
| `toggle` | `label`, `initialValue?`, `notifyChange?` | 返回 boolean，默认 false；默认不通知变化 |
| `clickImage` | `image`, `hintImage?`, `description?`, `pointCount?` | 按顺序返回原图像素坐标，支持撤销与清空；默认至多 32 点，可指定 1–32 的精确点数 |
| `progress` | `text?`, `value?` | value 为 0–1 的进度；省略时显示不定进度，不返回值 |
| `divider` | 无其他字段 | 内容分隔，不返回值 |

组件默认值：input 为空字符串；单选为空字符串；多选与点图为空数组；toggle 为 false。`select.options` 的 value 必须唯一且非空，因此空字符串代表未选择。`notifyChange` 仅用于 select 和 toggle；启用后用户完成一次选择就发出 change 事件，插件更新依赖选项后解除 busy。第一版输入不逐字回调。

`validate: true` 的按钮检查 required、maxLength 及点数；点图有 pointCount 时要求精确匹配，否则要求至少一点。检查失败在字段旁提示，不发送 action，也不进入 busy。刷新、上一步等按钮默认不触发校验。网络与网站业务校验不进入宿主验证规则。

图片由插件用现有 HTTP 接口获取，再传字节数组或 base64 image Data URL；组件不自行请求 URL，因此继续使用插件原有 Cookie 与网络能力。解码前后检查大小，损坏图片显示可读错误，其他按钮与关闭仍可使用。点选坐标排除留白，并按实际图片尺寸换算，复用现有登录点图算法。

为了适配现有 64 MiB 脚本内存限制，第一版约束每个窗口最多 64 个组件、4 个业务按钮、每个 select 最多 100 项；单图压缩数据最多 4 MiB，整个窗口图片合计最多 8 MiB，单图解码像素最多 400 万。普通文案单项最多 32 KiB、合计最多 256 KiB；输入 maxLength 默认 4096，允许 1–32768。未知类型、重复 ID、非法选项和超限数据返回 `plugin_ui_invalid_options`，不创建或部分修改窗口。

## 3. 典型流程

以下为拟定接口的使用示意，fetchCaptcha 与 verifyCaptcha 是插件自身方法。

```js
const captcha = await fetchCaptcha();
const dialog = await Hazuki.ui.openDialog({
  title: '验证后继续',
  content: [
    {id: 'picture', type: 'image', image: captcha.image},
    {id: 'code', type: 'input', label: '验证码', required: true},
    {id: 'error', type: 'text', tone: 'error', text: ''},
  ],
  buttons: [
    {id: 'refresh', text: '换一张'},
    {id: 'submit', text: '提交', role: 'primary', validate: true},
  ],
});

try {
  while (true) {
    const event = await dialog.nextEvent();
    if (event.type === 'closed') {
      throw new Hazuki.ui.PluginDialogCancelledError(event.reason);
    }
    if (event.type !== 'action') continue;

    if (event.id === 'refresh') {
      // 获取新图后，通过 update 替换 content 并用 values 清空 code。
      // update 成功前业务按钮保持 busy，系统关闭仍可用。
      await refreshCaptchaInDialog(dialog);
      continue;
    }

    const result = await verifyCaptcha(event.values.code);
    if (result.ok) break;
    // 更新错误文案并解除 busy，保留窗口和已有输入。
    await showCaptchaErrorInDialog(dialog, result.message);
  }
} finally {
  await dialog.close();
}
```

简单公告只需一个 text 和一个“知道了”按钮；线路选择使用 select；确认操作使用 text 和两个不同 ID 的按钮。按钮 ID 决定业务含义，点击按钮本身不自动关闭窗口。关闭由插件显式调用，或由宿主生命周期处理。

## 4. 前台归属、并发与取消

### 4.1 允许交互的操作

宿主为用户当前操作创建可撤销的前台交互作用域，再调用插件。第一版接入普通与聚合搜索、探索/分类前台加载、漫画详情、用户正在打开的章节、手动账号操作、插件操作按钮和用户主动修改插件设置。操作需要的初始化继承同一作用域。

自动预热、启动检查、静默刷新、预加载、后台下载、云同步、阅读进度上报、自动重登、安装校验和元数据检查不获得此作用域。应用在前台不代表任务可以交互。现有隔离登录获得登录作用域，通用组件在当前登录容器内展示，继续遵守原登录事务与取消规则；旧 requestText/requestClickCaptcha 不改动。

`isAvailable` 查询当前调用作用域是否仍有效。未授权调用 openDialog 报 `plugin_ui_unavailable`；作用域过期后不能通过重试恢复权限。后台初始化若有交互需求，应先查询可用性，将交互推迟到前台业务方法，不使后台预热依赖弹窗完成。

初始化可能被多个调用共享：初始化作用域在创建时确定，后台 init 不因后来出现前台等待者而升级为可交互；前台 init 的所有者离开后撤销其交互，其他等待者不能接管旧窗口。初始化失败按现有恢复机制重建，不新增跨任务转移弹窗的规则。

### 4.2 排队与关闭

- 全局同时展示一个插件交互窗口。同一操作至多持有一个打开或排队的窗口，重复打开报 `plugin_ui_already_open`；多步流程通过 update 完成。
- 不同操作按请求顺序排队。已有宿主模态窗口时等待其结束；隔离登录的所属交互使用登录容器，不额外叠加一个模态窗口。
- 排队、展示和每次更新都核对作用域、插件、引擎实例及请求是否仍有效。关闭窗口时按确切路由或容器句柄移除，不能直接 pop 当前页面。
- 点击遮罩、返回键、桌面关闭操作都能取消，插件不能创建无法关闭的窗口。busy 不屏蔽这些操作。
- 离开或遮住所属页面、搜索条件变化、当前内容请求被替换、插件停用/卸载、引擎销毁、相关源切换和操作结束时，撤销对应窗口及队列项。插件操作即使来自非当前源，也按发起它的操作绑定，不因 activeSourceKey 与插件 ID 不同而误取消。
- 插件自己的弹窗路由和同作用域登录容器不算遮住所属页面；由其他业务打开的页面或模态路由则会撤销当前窗口，避免在旧页面上继续交互。需逐个 Navigator 观察确切路由归属，不能将一次路由 push 一律当作失效。
- 应用真正进入后台（paused/hidden）时取消交互，不在恢复前台后重新弹出；inactive 或桌面单纯失焦不视为取消。
- 生命周期撤销立即结算 openDialog/nextEvent，清理输入、图片、队列和监听器。迟到的更新与回包不能修改其他窗口。
- 用户关闭后，插件可主动决定退出业务或采用无需交互的替代流程。宿主取消标记覆盖该操作余下的自动重试，防止同一次搜索取消后再次弹窗。新的用户操作可以重新请求。
- 只撤销对应作用域的 UI 能力，不关闭共享引擎、不影响同插件其他正在执行的任务，也不承诺回滚已经发送到网站的业务请求。

## 5. 等待与超时

现有普通搜索超时为 25 秒，初始化为 90 秒。直接沿用外围 Future.timeout 会让正在输入的用户遇到请求先超时，因此前台入口需要统一使用可感知交互状态的等待预算。

- 保留当前业务执行预算；只有窗口排队或等待用户操作期间暂停该预算。插件收到 action/change 后处理业务和联网时恢复计时，进入下一次 nextEvent 后再次暂停。
- 同一前台操作内，所有窗口累计交互等待最多 5 分钟；更新、刷新和重新打开不重置这份预算。单次排队最多 60 秒，先触及的限制生效。
- 非交互网络请求仍保留 Dio 自身超时，插件同步 JS 执行仍使用现有 5 秒限制。等待输入不修改或延长原生 CPU 执行限制。
- 初始化与外层请求共用作用域时，两层等待预算都感知相同交互等待状态，避免只暂停一层计时。业务失败、页面失效或总交互超时，立即撤销该作用域的窗口。
- 等待预算耗尽返回 closed(timeout) 或排队取消错误，取消不进入自动重试。用户处理当前交互后，业务预算用剩余时间继续，而非重新给完整 25/90 秒。

## 6. 宿主实现边界

### SDK 与桥接

在 assets/hazuki_plugin_sdk.js 增加 ui 及本地 JS 句柄封装。桥接只传结构化组件、值和事件，通过 ui_open、ui_next_event、ui_update、ui_close、ui_available 处理；回调函数留在插件端，不传入组件描述。

沿用 SourceScriptEngine 的异步 host reply 和 SourceScriptExecution。服务端管理实际权限：将调用执行标识映射到宿主维护的交互作用域，核对 pluginId、runtimeId 与窗口所有权。不能信任插件请求里的 taskId、sourceKey 或窗口 ID 来授予权限，也不能给共享 SourceRuntimeHandle 设置一个全局“允许弹窗”开关。

为当前执行上下文补充可传递的宿主交互作用域引用；页面对象、BuildContext 和取消回调仍留在主 isolate。作用域从最外层前台调用开始覆盖初始化、子调用和业务 JS，脚本自行启动且已脱离该操作生命周期的任务不得继续使用它。候选初始化引擎也使用本次加载实际 runtimeId，不依赖其已发布为主引擎。

### 交互服务与 Flutter 展示

新增独立的插件交互服务，负责数据校验、作用域、队列、窗口状态、事件与清理；由现有桥接分派给它，避免继续将 UI 实现塞进 Cookie 能力类。

应用层注入 presenter，负责通过已有 Navigator 展示窗口及观察页面/模态路由生命周期。共享组件渲染器按 ID 保存本地字段状态，复用现有弹窗外壳与点图坐标算法；登录作用域使用现有登录控制器承载组件。组件或窗口尺寸更新使用现有布局与动画规范。

搜索已有的 SourceTaskOrigin/resultDisposition 用来关联请求，但其结束时检查不足以驱动即时关闭：增加可监听的作用域撤销信号，由页面销毁、替换请求与超时主动触发。其他前台入口采用相同机制，不能只把开放权限绑定到搜索。

不修改 QuickJS 原生执行控制；仓库当前已有的 QuickJS 与工作流变更属于其他进行中的工作，保持原样。

### 文档与兼容

实现时更新 HazukiSources/docs/API.md、hazuki-source.d.ts 并新增通用表单/验证码示例。新增文案写入 ARB 后运行 flutter gen-l10n，不手改生成文件。正式文档以已完成并验证的能力为准，设计稿中的接口在实现前不宣称可用。

## 7. 验收与检查

- 桥接集成：真实 QuickJS 调用打开、等待、更新、关闭；事件返回正确；异步 continuation 保持作用域；raw sendMessage 无法越权操作其他插件、任务或引擎的窗口。
- 渲染与状态：公告、确认、多字段表单、选择联动、进度、多步内容更新；稳定 ID 保留输入，显式 values 能清空；非法更新原子失败；组件删除释放状态。
- 验证码：刷新不关闭窗口；错误后重试；图片更换清点；缩放与留白坐标正确；损坏图、超大图、精确点数与撤销操作可用。
- 事件与竞态：双击只接收一次；busy 时仍可取消；重复 nextEvent 报错；关闭后等待立即结算；关闭与网络回包、更新、引擎销毁同时发生不残留 UI 或等待。
- 生命周期：离页、遮住所属页面、新搜索、停用/卸载、切源、后台与前台恢复；迟到请求不重新弹窗；非当前源插件操作不会被误拒绝；同引擎后台任务没有 UI 权限。
- 并发与等待：跨任务 FIFO、已有模态窗口等待、排队撤销及 60 秒上限；输入超过 25 秒仍能继续搜索；业务处理仍超时；初始化内交互暂停内外层预算；累计交互超过 5 分钟取消。
- 兼容回归：旧插件和旧登录行为保持；登录暂存与回滚不因通用组件改变；普通与聚合搜索的用户取消不会触发自动重试；同插件其他并发任务不受影响。
- 代码实现后运行修改文件格式检查及 flutter analyze，按范围运行 SDK/桥接、交互服务、widget、搜索控制器与登录针对性测试。跨仓库修改后运行 Sources 的类型检查及新增示例测试。Android 与 Windows 各做一次键盘、返回/关闭、图片与多步流程实机或构建环境冒烟；无法完成的验证明确记录。

第一版实现包含 SDK、宿主作用域与排队管理、原生组件渲染、前台业务接入，以及 HazukiSources 的类型声明、API 文档和可运行示例。沿用现有窗口与动画规范，保留旧登录接口和进行中的其他代码修改。

第一版已完成 Flutter 静态检查、格式检查及相关模块针对性回归；新增测试覆盖真实 QuickJS、初始化/内容调用/隔离登录、后台权限、候选引擎销毁、表单与点图渲染、原地更新、排队、取消和超时。Sources 的类型检查、格式检查、示例类型检查与三个 Node 示例测试通过。Android APK 和 Windows 调试构建均已跑通，最终构建结果以对应 build/plugin_dialog_*_build.log 为准。尚未进行 Android/Windows 实机人工操作验收；浏览器授权的既有平台实测记录继续以 Sources 的授权验证文档为准。

## 8. 第二版：快捷调用、字段错误与连续登录

- SDK 新增 alert/confirm/prompt，复用 openDialog 和现有宿主权限、等待与清理。明确的取消按钮返回 false/null；关闭及生命周期取消沿用取消错误。输入选项和校验与 input 相同。
- update 新增 fieldErrors，以交互组件 ID 映射 SourceText 或 null。提供时替换错误集合，省略时清空，保持第一版行为；编辑字段清除对应错误。非法 ID、文案和大小在提交更新前整体验证，关闭动画结束后释放错误文字。宿主基础校验错误与插件文案分别解释。
- 再漫画 1.6.0 检测新增 prompt 接口及当前交互资格，使用同一窗口完成点图、刷新、失败重试和短信输入；旧宿主保留原登录流程，第三方授权保持原状。短信格式可原地纠正；网站错误沿用原失败规则，不自动重发。提交期间窗口关闭后，迟到的成功响应不能继续验证及保存凭据。
- 选择联动复用第一版 change/update，不新增逐字输入通知、滑块或网页组件。窗口外观和动画沿用已有实现。
- 自动化覆盖快捷调用真实 QuickJS、返回值与取消、字段错误与原子更新、焦点和输入保留，以及再漫画新旧流程与迟到响应。插件网络测试使用合成响应；真实账号登录及 Android/Windows 人工操作验收尚未完成。

第二版当前已通过 45 项 Flutter 针对性回归、70 项 Sources 插件与示例测试，以及 Sources 类型、格式、示例类型检查。构建及静态检查结果以 build/plugin_dialog_v2_* 日志为准。
