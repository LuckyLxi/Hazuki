// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Hazuki';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsCacheTitle => '缓存';

  @override
  String get settingsCacheSubtitle => '缓存相关设置';

  @override
  String get settingsDisplayTitle => '显示';

  @override
  String get settingsDisplaySubtitle => '软件界面与语言设置';

  @override
  String get settingsReadingTitle => '阅读';

  @override
  String get settingsReadingSubtitle => '阅读器设置';

  @override
  String get settingsPrivacyTitle => '隐私';

  @override
  String get settingsPrivacySubtitle => '隐私相关功能';

  @override
  String get settingsCloudSyncTitle => '云同步';

  @override
  String get settingsCloudSyncSubtitle => '上传与恢复备份';

  @override
  String get settingsAdvancedTitle => '高级';

  @override
  String get settingsAdvancedSubtitle => '实验性功能';

  @override
  String get settingsAboutTitle => '关于';

  @override
  String get displayTitle => '显示';

  @override
  String get displayThemeTitle => '主题';

  @override
  String get displayThemeLight => '浅色';

  @override
  String get displayThemeDark => '深色';

  @override
  String get displayThemeSystem => '跟随系统';

  @override
  String get displayPresetMintGreen => '薄荷绿';

  @override
  String get displayPresetSeaSaltBlue => '海盐蓝';

  @override
  String get displayPresetTwilightPurple => '暮光紫';

  @override
  String get displayPresetCherryBlossomPink => '樱花粉';

  @override
  String get displayPresetCoralOrange => '珊瑚橙';

  @override
  String get displayPresetAmberYellow => '琥珀黄';

  @override
  String get displayPresetLimeGreen => '青柠绿';

  @override
  String get displayPresetGraphiteGray => '石墨灰';

  @override
  String get displayPresetBerryRed => '莓果红';

  @override
  String get displayLanguageTitle => '语言';

  @override
  String get displayLanguageSubtitle => '切换应用显示语言';

  @override
  String get displayLanguageSystem => '跟随系统';

  @override
  String get displayLanguageZhHans => '简体中文';

  @override
  String get displayLanguageEnglish => 'English';

  @override
  String get displayRefreshRateTitle => '屏幕帧率';

  @override
  String get displayRefreshRateAuto => '自动';

  @override
  String displayRefreshRateSpecified(Object id) {
    return '已指定模式（ID: $id）';
  }

  @override
  String get displayPureBlackTitle => '纯黑模式';

  @override
  String get displayPureBlackSubtitle => '深色模式下使用纯黑背景';

  @override
  String get displayDynamicColorTitle => '动态取色';

  @override
  String get displayDynamicColorSubtitle => '根据系统壁纸自动提取主题色（Android 12+）';

  @override
  String get displayComicDynamicColorTitle => '漫画详情页动态取色';

  @override
  String get displayComicDynamicColorSubtitle => '开启后根据漫画封面生成漫画详情页动态主题';

  @override
  String get displayColorSchemeTitle => '配色方案';

  @override
  String get homeGuestUser => '未登录';

  @override
  String get homeFirstUseLoading => '首次使用时间加载中...';

  @override
  String get homeFirstUseUnknown => '首次使用本应用';

  @override
  String homeFirstUseFormatted(Object date) {
    return '$date 首次使用';
  }

  @override
  String get homeLogoutTitle => '退出登录';

  @override
  String get homeLogoutContent => '确定要退出登录吗？';

  @override
  String get homeLoginTitle => '登录';

  @override
  String get homeLoginAccountLabel => '账号';

  @override
  String get homeLoginPasswordLabel => '密码';

  @override
  String get homeLoginHidePassword => '隐藏密码';

  @override
  String get homeLoginShowPassword => '显示密码';

  @override
  String get homeLoginEmptyError => '账号和密码不能为空';

  @override
  String get homeLoginSuccess => '登录成功';

  @override
  String get homeLoggedOut => '已退出登录';

  @override
  String get homeSaveAvatarTitle => '保存头像';

  @override
  String get homeSaveAvatarContent => '将当前头像保存到相册吗？';

  @override
  String homeAvatarSaved(Object path) {
    return '头像已保存到 $path';
  }

  @override
  String homeAvatarSaveFailed(Object error) {
    return '头像保存失败：$error';
  }

  @override
  String get homePressBackAgainToExit => '再按一次返回退出';

  @override
  String get homeSearchHint => '搜索漫画';

  @override
  String get homeSortTooltip => '排序';

  @override
  String get homeFavoriteSortByFavoriteTime => '收藏时间';

  @override
  String get homeFavoriteSortByUpdateTime => '更新时间';

  @override
  String get homeCreateFavoriteFolder => '新建收藏夹';

  @override
  String get homeMenuHistory => '历史记录';

  @override
  String get homeMenuCategories => '标签分类';

  @override
  String get homeMenuRanking => '排行榜';

  @override
  String get homeMenuDownloads => '下载';

  @override
  String get homeMenuLines => '线路';

  @override
  String get homeTabDiscover => '发现';

  @override
  String get homeTabFavorite => '收藏';

  @override
  String get dialogBarrierLabel => '对话框';

  @override
  String get aboutTitle => '关于';

  @override
  String get aboutVersion => '版本 1.0.0';

  @override
  String get aboutDescription => 'JMComic第三方';

  @override
  String get aboutProjectTitle => '项目地址';

  @override
  String get aboutProjectSubtitle => 'GitHub (https://github.com/LuckyLxi/Hazuki)';

  @override
  String get aboutFeedbackTitle => '反馈问题';

  @override
  String get aboutFeedbackSubtitle => '如果在阅读中遇到任何问题，欢迎反馈';

  @override
  String get aboutOpenLinkFailed => '无法打开链接';

  @override
  String get aboutOpenFeedbackFailed => '无法打开反馈链接';

  @override
  String get aboutLicenseTitle => '开源协议';

  @override
  String get aboutLicenseSubtitle => 'GPL-3.0 License';

  @override
  String get aboutLicenseSnackbar => '本项目采用 GPL-3.0 开源协议';

  @override
  String get aboutThanksTitle => '鸣谢';

  @override
  String get aboutThanksSubtitle => '启发本项目开发的优秀作品';

  @override
  String get aboutThanksDialogTitle => '致谢';

  @override
  String get aboutThanksDialogContent => '本项目的开发参考并感谢以下开源项目：\n\n• Venera: 登录逻辑实现参考\n• Animeko: 界面布局设计参考';

  @override
  String get commonConfirm => '确定';

  @override
  String get commonCancel => '取消';

  @override
  String get commonClose => '关闭';

  @override
  String get commonSave => '保存';

  @override
  String get commonLoading => '加载中...';

  @override
  String get commonRetry => '重试';

  @override
  String get searchTitle => '搜索';

  @override
  String get searchHint => '搜索漫画';

  @override
  String get searchHistoryTitle => '搜索历史';

  @override
  String get searchClearTooltip => '清空';

  @override
  String get searchSubmitTooltip => '搜索';

  @override
  String get searchClearHistoryTitle => '清空历史记录';

  @override
  String get searchClearHistoryContent => '你确定要清空所有搜索记录吗？';

  @override
  String get historyTitle => '历史记录';

  @override
  String get historyEmpty => '暂无历史记录';

  @override
  String get historySelectionCancelTooltip => '取消多选';

  @override
  String get historySelectionEnterTooltip => '多选';

  @override
  String get historyDeleteSelectedTooltip => '删除选中的历史';

  @override
  String get historyClearAllTooltip => '清空所有历史';

  @override
  String get historyDeleteSelectedTitle => '删除历史记录';

  @override
  String historyDeleteSelectedContent(Object count) {
    return '你确定要删除选中的$count部漫画历史记录吗？';
  }

  @override
  String get historyClearAllTitle => '清空历史记录';

  @override
  String get historyClearAllContent => '你确定要清空所有历史记录吗？此操作不可恢复。';

  @override
  String get historyCopiedComicId => '已复制漫画ID';

  @override
  String get historyLoginRequired => '请先登录';

  @override
  String get historyFavoriteProcessing => '正在处理收藏...';

  @override
  String get historyFavoriteFolderNotice => '多收藏夹请在漫画详情页内操作，正在执行默认操作...';

  @override
  String get historyFavoriteRemoved => '已取消收藏';

  @override
  String get historyFavoriteAdded => '已添加收藏';

  @override
  String historyFavoriteFailed(Object error) {
    return '收藏操作失败: $error';
  }

  @override
  String get historyMenuCopyComicId => '复制漫画ID';

  @override
  String get historyMenuToggleFavorite => '收藏/取消收藏';

  @override
  String get historyMenuDeleteItem => '删除此记录';

  @override
  String get discoverLoadTimeout => '发现页加载超时，请下拉重试';

  @override
  String discoverLoadFailed(Object error) {
    return '发现页加载失败：$error';
  }

  @override
  String get discoverEmpty => '当前漫画源暂无发现页内容';

  @override
  String get discoverMore => '查看更多';

  @override
  String get aboutThirdPartyLicensesTitle => '第三方库许可';

  @override
  String get aboutThirdPartyLicensesSubtitle => '查看本应用使用的开源库';

  @override
  String get searchOrderLatest => '最新';

  @override
  String get searchOrderTotalRanking => '总排行';

  @override
  String get searchOrderMonthlyRanking => '月排行';

  @override
  String get searchOrderWeeklyRanking => '周排行';

  @override
  String get searchOrderDailyRanking => '日排行';

  @override
  String get searchOrderMostImages => '最多图片';

  @override
  String get searchOrderMostLikes => '最多喜欢';

  @override
  String get searchTimeout => '搜索超时，请稍后重试';

  @override
  String searchFailed(Object error) {
    return '搜索失败：$error';
  }

  @override
  String get searchStartPrompt => '输入关键词开始搜索';

  @override
  String get searchLoading => '正在搜索...';

  @override
  String get searchEmpty => '什么也没搜到';

  @override
  String get searchSortTooltip => '排序';

  @override
  String get comicDetailFavoriteAdded => '已加入收藏';

  @override
  String get comicDetailFavoriteRemoved => '已取消收藏';

  @override
  String comicDetailFavoriteActionFailed(Object error) {
    return '收藏操作失败：$error';
  }

  @override
  String get comicDetailManageFavorites => '管理收藏';

  @override
  String get comicDetailCreateFavoriteFolder => '新增收藏夹';

  @override
  String get comicDetailFavoriteFolderNameHint => '请输入收藏夹名称';

  @override
  String get comicDetailFavoriteFolderNameRequired => '收藏夹名称不能为空';

  @override
  String comicDetailCreateFavoriteFolderFailed(Object error) {
    return '创建收藏夹失败：$error';
  }

  @override
  String get comicDetailDeleteFavoriteFolder => '删除收藏夹';

  @override
  String get comicDetailDeleteFavoriteFolderContent => '删除这个收藏夹吗？位于该收藏夹中的漫画将失去分组。';

  @override
  String get comicDetailDelete => '删除';

  @override
  String comicDetailDeleteFavoriteFolderFailed(Object error) {
    return '删除收藏夹失败：$error';
  }

  @override
  String comicDetailFavoriteFoldersLoadFailed(Object error) {
    return '加载收藏夹失败：$error';
  }

  @override
  String get comicDetailNoFavoriteFolders => '暂无收藏夹';

  @override
  String get comicDetailDeleteFavoriteFolderTooltip => '删除收藏夹';

  @override
  String get comicDetailCreateFavoriteFolderTooltip => '新建收藏夹';

  @override
  String get comicDetailSingleFolderHint => '当前漫画源仅支持将该漫画加入一个收藏夹';

  @override
  String get comicDetailMultipleFoldersHint => '可为该漫画选择多个收藏夹';

  @override
  String get comicDetailSelectAtLeastOneFolder => '请至少选择一个收藏夹';

  @override
  String get comicDetailFavoriteSettingsUpdated => '收藏设置已更新';

  @override
  String comicDetailFavoriteSettingsUpdateFailed(Object error) {
    return '更新收藏失败：$error';
  }

  @override
  String get comicDetailNoChapterInfo => '暂无章节信息';

  @override
  String get comicDetailNoChapters => '当前漫画暂无章节';

  @override
  String get comicDetailAuthor => '作者';

  @override
  String get comicDetailTags => '标签';

  @override
  String get comicDetailCopiedId => '已复制 ID';

  @override
  String comicDetailCopiedPrefix(Object value) {
    return '已复制：$value';
  }

  @override
  String comicDetailSavedToPath(Object path) {
    return '已保存到 $path';
  }

  @override
  String comicDetailSaveFailed(Object error) {
    return '保存失败：$error';
  }

  @override
  String get comicDetailLoading => '加载中...';

  @override
  String get comicDetailSummary => '简介';

  @override
  String get comicDetailNoRelatedComics => '暂无相关漫画';

  @override
  String get comicDetailCollapse => '收起';

  @override
  String get comicDetailExpand => '展开';

  @override
  String comicDetailUpdatedAt(Object time) {
    return '漫画更新时间：$time';
  }

  @override
  String get comicDetailTitle => '漫画详情';

  @override
  String get comicDetailTabInfo => '详情';

  @override
  String get comicDetailTabComments => '评论';

  @override
  String get comicDetailTabRelated => '相关';

  @override
  String get comicDetailChapters => '章节';

  @override
  String comicDetailChapterCount(Object count) {
    return '共 $count 话';
  }

  @override
  String comicDetailLikesCount(Object count) {
    return '$count点赞';
  }

  @override
  String comicDetailViewsCount(Object count) {
    return '$count浏览量';
  }

  @override
  String get comicDetailFavorite => '收藏';

  @override
  String get comicDetailUnfavorite => '取消收藏';

  @override
  String get comicDetailRead => '阅读';

  @override
  String comicDetailContinueReading(Object title) {
    return '继续阅读 $title';
  }

  @override
  String get comicDetailSaveImage => '保存图片';

  @override
  String get comicDetailRemindLaterToday => '今日不再提醒';

  @override
  String get sourceUpdateAvailableTitle => '漫画源有更新';

  @override
  String sourceUpdateLocalVersion(Object version) {
    return '本地漫画源版本号：$version';
  }

  @override
  String sourceUpdateRemoteVersion(Object version) {
    return '云端漫画源版本号：$version';
  }

  @override
  String get sourceUpdateDownloading => '下载中...';

  @override
  String sourceUpdateDownloadingProgress(Object progress) {
    return '下载中 $progress%';
  }

  @override
  String get sourceUpdateDownloadFailed => '下载失败，请稍后重试';

  @override
  String get sourceUpdateDownload => '下载';

  @override
  String get readingSettingsTitle => '阅读设置';

  @override
  String get readingModeTitle => '阅读模式';

  @override
  String get readingModeSubtitle => '选择阅读器中的页面排列方式';

  @override
  String get readingModeTopToBottom => '从上往下';

  @override
  String get readingModeRightToLeft => '从右到左';

  @override
  String get readingTapToTurnPageTitle => '点击翻页';

  @override
  String get readingTapToTurnPageSubtitle =>
      '仅在从右到左模式下生效，点击左侧回到上一页，点击右侧前往下一页';

  @override
  String get readingImmersiveModeTitle => '沉浸模式';

  @override
  String get readingImmersiveModeSubtitle => '开启后进入阅读器自动隐藏状态栏和底部导航栏';

  @override
  String get readingKeepScreenOnTitle => '屏幕常亮';

  @override
  String get readingKeepScreenOnSubtitle => '开启后阅读时保持屏幕常亮，不自动锁屏';

  @override
  String get readingCustomBrightnessTitle => '自定义亮度';

  @override
  String get readingCustomBrightnessSubtitle => '开启后可在阅读器内按此设置覆盖系统亮度';

  @override
  String readingBrightnessLabel(Object value) {
    return '亮度 $value';
  }

  @override
  String get readingPinchToZoomTitle => '双指缩放';

  @override
  String get readingPinchToZoomSubtitle => '启用后可双指捏合对漫画图片进行放大查看';

  @override
  String get readingLongPressSaveTitle => '长按保存图片';

  @override
  String get readingLongPressSaveSubtitle => '启用后长按漫画图片可保存该图片';

  @override
  String get downloadsTitle => '下载';

  @override
  String get downloadsTabOngoing => '正在下载';

  @override
  String get downloadsTabDownloaded => '已下载';

  @override
  String get downloadsEmptyOngoing => '暂无下载任务';

  @override
  String get downloadsEmptyDownloaded => '还没有已下载漫画';

  @override
  String downloadsSelectionTitle(Object count) {
    return '已选择 $count 项';
  }

  @override
  String get downloadsDeleteSelectedTitle => '删除已下载漫画';

  @override
  String downloadsDeleteSelectedContent(Object count) {
    return '确定删除选中的 $count 部已下载漫画吗？';
  }

  @override
  String get downloadsStatusQueued => '等待中';

  @override
  String get downloadsStatusDownloading => '下载中';

  @override
  String get downloadsStatusPaused => '已暂停';

  @override
  String downloadsStatusFailed(Object error) {
    return '失败：$error';
  }

  @override
  String downloadsChapterCount(Object count) {
    return '共 $count 话';
  }

  @override
  String downloadsCurrentProgress(Object current, Object total) {
    return '$current/$total 张图片';
  }

  @override
  String get downloadsActionSelect => '选择';

  @override
  String get downloadsActionPause => '暂停';

  @override
  String get downloadsActionResume => '继续';

  @override
  String downloadsQueued(Object count) {
    return '已加入 $count 话到下载队列';
  }

  @override
  String get downloadsDownloadChaptersTitle => '下载章节';

  @override
  String get downloadsDownloadChaptersSubtitle => '选择要下载的章节';

  @override
  String get downloadsDownloadAction => '下载';

  @override
  String get privacySettingsTitle => '隐私设置';

  @override
  String get privacyBlurTaskTitle => '模糊任务栏应用页面';

  @override
  String get privacyBlurTaskSubtitle => '切到近期任务时任务卡片显示为纯黑';

  @override
  String get privacyBiometricUnlockTitle => '生物认证解锁';

  @override
  String get privacyBiometricUnlockSubtitle => '每次进入软件需验证指纹';

  @override
  String get privacyAuthOnResumeTitle => '退出软件需重新验证';

  @override
  String get privacyAuthOnResumeSubtitle => '即使应用在后台，只要不在前台，再次打开便需要重新认证';

  @override
  String get lineSettingsTitle => '线路';

  @override
  String lineLoadFailed(Object error) {
    return '线路信息加载失败: $error';
  }

  @override
  String lineOptionLabel(Object value) {
    return '线路 $value';
  }

  @override
  String lineOptionWithHostLabel(Object value, Object host) {
    return '线路 $value（$host）';
  }

  @override
  String lineImageStreamLabel(Object value) {
    return '分流 $value';
  }

  @override
  String lineApiSwitched(Object value) {
    return 'API 域名分流已切到线路 $value';
  }

  @override
  String lineImageSwitched(Object value) {
    return '图片域名分流已切到分流 $value';
  }

  @override
  String lineSwitchFailed(Object error) {
    return '切换失败: $error';
  }

  @override
  String get lineRefreshOnStartUpdated => '已更新启动自动刷新设置';

  @override
  String lineSaveFailed(Object error) {
    return '保存失败: $error';
  }

  @override
  String get lineIntro => '你可以分别切换 API 与图片分流，切换后会自动应用到后续请求。';

  @override
  String get lineApiTitle => 'API 域名分流';

  @override
  String get lineApiSubtitle => '用于接口请求，建议网络异常时切换';

  @override
  String get lineSelectApiLabel => '选择 API 线路';

  @override
  String get lineImageTitle => '图片域名分流';

  @override
  String get lineImageHostUnavailable => '当前未获取到图片域名';

  @override
  String lineImageHostCurrent(Object host) {
    return '当前域名：$host';
  }

  @override
  String get lineSelectImageLabel => '选择图片分流';

  @override
  String get lineRefreshOnStartTitle => '启动时刷新域名列表';

  @override
  String get lineRefreshOnStartSubtitle => '每次打开应用时自动更新 API 域名池';

  @override
  String get lineRefreshStatusButton => '刷新线路状态';

  @override
  String get displayModeAndroidOnly => '仅 Android 支持屏幕帧率设置';

  @override
  String displayModeReadFailed(Object error) {
    return '读取屏幕模式失败：$error';
  }

  @override
  String get displayModeSystemRejected => '系统拒绝了该显示模式';

  @override
  String get displayModeApplied => '已应用屏幕帧率，若未生效请重启应用';

  @override
  String displayModeSetFailed(Object error) {
    return '设置失败：$error';
  }

  @override
  String get displayModeUnknown => '未知';

  @override
  String get displayModeUnknownMode => '未知模式';

  @override
  String displayModeCurrentLabel(Object mode) {
    return '当前系统模式：$mode';
  }

  @override
  String get displayModeCurrentSubtitle => '系统当前';

  @override
  String get displayModeSelectedSubtitle => '已选择';

  @override
  String get displayModeHint => '提示：部分机型会受系统省电或应用白名单策略影响。';

  @override
  String get cachePresetDefault => '默认 400MB';

  @override
  String get cachePresetLite => '轻量 600MB';

  @override
  String get cachePresetBalanced => '均衡 1024MB';

  @override
  String get cachePresetHeavy => '重度 2048MB';

  @override
  String get cacheMaxSizeTitle => '设置缓存最大容量';

  @override
  String get cacheMaxSizeHint => '最低 400MB，可选择预设或自定义输入';

  @override
  String get cacheCustomMbLabel => '自定义（MB）';

  @override
  String get cacheCustomMbHint => '例如 1024';

  @override
  String cacheLimitUpdated(Object value) {
    return '缓存上限已设为 ${value}MB';
  }

  @override
  String get cacheAutoCleanTitle => '缓存自动清理';

  @override
  String get cacheAutoCleanOverflowTitle => '超过上限自动清理';

  @override
  String get cacheAutoCleanOverflowSubtitle => '按最旧缓存优先删除，直到低于上限';

  @override
  String get cacheAutoCleanSevenDaysTitle => '每七天清理一次';

  @override
  String get cacheAutoCleanSevenDaysSubtitle => '删除 7 天前缓存文件';

  @override
  String get cacheAutoCleanSevenDaysApplied => '已设为每七天清理一次';

  @override
  String get cacheAutoCleanOverflowApplied => '已设为超过上限自动清理';

  @override
  String get cacheClearBarrierLabel => '关闭';

  @override
  String get cacheClearTitle => '清理缓存';

  @override
  String get cacheClearContent => '确定要清理所有图片缓存吗？此操作不可逆。';

  @override
  String get cacheClearConfirm => '确定清理';

  @override
  String get cacheCleared => '缓存清理成功';

  @override
  String cacheClearFailed(Object error) {
    return '清理失败：$error';
  }

  @override
  String get cacheSettingsTitle => '缓存设置';

  @override
  String get cacheSizeTitle => '缓存大小';

  @override
  String cacheSizeSummary(Object used, Object max) {
    return '当前 $used / 上限 $max';
  }

  @override
  String get cacheAutoCleanModeSummary => '每七天清理一次';

  @override
  String get cacheAutoCleanModeOverflowSummary => '超过上限自动清理';

  @override
  String get cacheClearNowTitle => '立即清理缓存';

  @override
  String get cacheClearNowSubtitle => '清空本地下载的所有图片缓存，释放存储空间';

  @override
  String get cloudSyncIncompleteConfig => '请填写完整 URL、Username、Password';

  @override
  String get cloudSyncInvalidUrl => 'URL 格式无效，请包含 http/https';

  @override
  String get cloudSyncStatusIncomplete => '配置不完整';

  @override
  String get cloudSyncStatusDisabled => '已关闭';

  @override
  String get cloudSyncConfigSaved => '云同步配置已保存';

  @override
  String cloudSyncSaveFailed(Object error) {
    return '保存失败: $error';
  }

  @override
  String get cloudSyncNeedCompleteConfig => '请先开启云同步并保存完整配置';

  @override
  String get cloudSyncUploadCompleted => '上传备份完成';

  @override
  String cloudSyncUploadFailed(Object error) {
    return '上传失败: $error';
  }

  @override
  String get cloudSyncRestoreTitle => '恢复备份';

  @override
  String get cloudSyncRestoreContent => '是否覆盖本地文件并恢复云端最新备份？';

  @override
  String get cloudSyncRestoreConfirm => '覆盖恢复';

  @override
  String get cloudSyncRestoreCompleted => '恢复备份完成，已覆盖本地数据';

  @override
  String cloudSyncRestoreFailed(Object error) {
    return '恢复失败: $error';
  }

  @override
  String get cloudSyncTitle => '云同步';

  @override
  String get cloudSyncStatusUnchecked => '未检测';

  @override
  String get cloudSyncStatusConnected => '已连接';

  @override
  String get cloudSyncStatusDisconnected => '未连接';

  @override
  String get cloudSyncEnabledTitle => '云同步';

  @override
  String get cloudSyncEnabledSubtitle => '开启后可上传与恢复云端备份';

  @override
  String get cloudSyncUrlHelper => '程序会自动拼接 /HazukiSync，无需手动填写';

  @override
  String get cloudSyncUsernameLabel => 'Username';

  @override
  String get cloudSyncPasswordLabel => 'Password';

  @override
  String get cloudSyncSave => '保存';

  @override
  String get cloudSyncUpload => '上传备份';

  @override
  String get cloudSyncRestore => '恢复备份';

  @override
  String get favoritesDebugCopied => '已复制网络日志';

  @override
  String get favoritesDebugFilterReason => '仅显示重要日志（错误日志、HTTP>=400、登录相关、含关键错误关键词）';

  @override
  String get favoritesDebugFilterImportantTooltip => '筛查重要日志';

  @override
  String get favoritesDebugCopyTooltip => '复制';

  @override
  String get favoritesDebugRefreshTooltip => '刷新网络日志';

  @override
  String favoritesDebugLoadFailed(Object error) {
    return '网络日志加载失败：$error';
  }

  @override
  String get favoritesDebugFullFetchButton => '手动执行完整网络抓取（慢）';

  @override
  String get logsNetworkTitle => '网络日志';

  @override
  String get logsApplicationTitle => '应用日志';

  @override
  String get logsApplicationCopied => '已复制应用日志';

  @override
  String get logsApplicationRefreshTooltip => '刷新应用日志';

  @override
  String logsApplicationLoadFailed(Object error) {
    return '应用日志加载失败：$error';
  }

  @override
  String get logsApplicationEmpty => '暂无应用日志';

  @override
  String get logsApplicationExportTooltip => '导出日志';

  @override
  String get logsApplicationExportSuccess => '日志文件已导出';

  @override
  String logsApplicationExportFailed(Object error) {
    return '导出日志文件失败：$error';
  }

  @override
  String get tagCategoryLoadTimeout => '标签分类加载超时，请稍后重试';

  @override
  String tagCategoryLoadFailed(Object error) {
    return '标签分类加载失败：$error';
  }

  @override
  String get tagCategoryTitle => '标签分类';

  @override
  String get tagCategoryEmpty => '当前漫画源暂无标签分类';

  @override
  String get rankingLoadOptionsTimeout => '排行榜分类加载超时，请稍后重试';

  @override
  String get rankingLoadTimeout => '排行榜加载超时，请稍后重试';

  @override
  String rankingLoadFailed(Object error) {
    return '排行榜加载失败：$error';
  }

  @override
  String get rankingTitle => '排行榜';

  @override
  String get rankingEmptyOptions => '当前漫画源暂无排行榜分类';

  @override
  String get rankingEmptyComics => '暂无排行榜内容';

  @override
  String get rankingReachedEnd => '已经到底了';

  @override
  String get favoriteAllFolder => '全部';

  @override
  String get favoriteLoadTimeout => '收藏加载超时，请下拉重试';

  @override
  String favoriteFoldersLoadFailed(Object error) {
    return '读取收藏夹失败：$error';
  }

  @override
  String favoriteCreated(Object name) {
    return '已成功创建收藏夹「$name」';
  }

  @override
  String favoriteCreateFailed(Object error) {
    return '新建收藏夹失败：$error';
  }

  @override
  String favoriteSortChangeFailed(Object error) {
    return '切换排序失败：$error';
  }

  @override
  String favoriteDeleteFailed(Object error) {
    return '删除收藏夹失败：$error';
  }

  @override
  String get favoriteFolderHeader => '收藏夹';

  @override
  String get favoriteDeleteCurrentFolderTooltip => '删除当前收藏夹';

  @override
  String get favoriteLoginRequired => '请登录';

  @override
  String get favoriteEmpty => '暂无收藏';

  @override
  String get favoriteCreateFolderTitle => '新建收藏夹';

  @override
  String get favoriteCreateFolderHint => '请输入收藏夹名称';

  @override
  String get favoriteCreateFolderNameRequired => '收藏夹名称不能为空';

  @override
  String get favoriteDeleteFolderTitle => '删除收藏夹';

  @override
  String favoriteDeleteFolderContent(Object name) {
    return '确定删除「$name」吗？';
  }

  @override
  String discoverSectionLoadFailed(Object error) {
    return '加载失败：$error';
  }

  @override
  String get discoverSectionEmpty => '暂无漫画';

  @override
  String get commentsTitle => '评论';

  @override
  String commentsLoadFailed(Object error) {
    return '加载评论失败：$error';
  }

  @override
  String get commentsLoginRequiredToSend => '请先登录后再评论';

  @override
  String get commentsSourceNotSupported => '当前漫画源不支持发送评论';

  @override
  String get commentsSendSuccess => '评论发送成功';

  @override
  String commentsSendFailed(Object error) {
    return '发送失败：$error';
  }

  @override
  String get commentsAnonymousUser => '匿名用户';

  @override
  String commentsReplyCount(Object count) {
    return '回复 $count';
  }

  @override
  String get commentsReplyTooltip => '回复';

  @override
  String commentsReplyToUser(Object name) {
    return '回复 @$name';
  }

  @override
  String get commentsCancelReplyTooltip => '取消回复';

  @override
  String get commentsComposerHint => '写下你的评论…';

  @override
  String commentsReplyComposerHint(Object name) {
    return '回复 $name…';
  }

  @override
  String get commentsSending => '发送中…';

  @override
  String get commentsSend => '发送';

  @override
  String get commentsEmpty => '暂无评论';

  @override
  String get readerSaveImageTitle => '保存图片';

  @override
  String get readerSaveImageContent => '是否将该漫画图片保存到本地？';

  @override
  String readerChapterLoadFailed(Object error) {
    return '加载章节失败：$error';
  }

  @override
  String get readerCurrentChapterNoImages => '当前章节无图片';

  @override
  String get readerResetZoom => '还原大小';

  @override
  String get advancedTitle => '高级';

  @override
  String get advancedDebugTitle => '日志';

  @override
  String get advancedDebugSubtitle => '网络日志与应用日志';

  @override
  String get advancedComicIdSearchTitle => '漫画 ID 搜索优化';

  @override
  String get advancedComicIdSearchSubtitle => '提交搜索时自动过滤非数字字符，仅保留阿拉伯数字作为关键词';

  @override
  String get advancedNoImageModeTitle => '无图模式';

  @override
  String get advancedNoImageModeSubtitle => '全局不显示图片（侧边栏登录头像除外）';

  @override
  String get settingsOtherTitle => '其它';

  @override
  String get settingsOtherSubtitle => '签到与附加功能';

  @override
  String get homeCheckInAction => '签到';

  @override
  String get homeCheckInDone => '今日已签到';

  @override
  String get homeCheckInInProgress => '签到中...';

  @override
  String get homeCheckInSuccess => '签到成功';

  @override
  String get homeCheckInAlreadyDone => '今天已经签到过了';

  @override
  String homeCheckInFailed(Object error) {
    return '签到失败：$error';
  }

  @override
  String get otherTitle => '其它';

  @override
  String get otherAutoCheckInTitle => '自动签到';

  @override
  String get otherAutoCheckInSubtitle => '开启后，每天打开软件时会自动触发一次签到';

  @override
  String get sourceBootstrapDownloading => '正在下载漫画源';

  @override
  String get sourceBootstrapPreparing => '正在准备源文件...';

  @override
  String sourceBootstrapProgress(Object progress) {
    return '已下载 $progress%';
  }
}
