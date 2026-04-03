// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Hazuki';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsCacheTitle => 'Cache';

  @override
  String get settingsCacheSubtitle => 'Cache-related settings';

  @override
  String get settingsDisplayTitle => 'Display';

  @override
  String get settingsDisplaySubtitle => 'Interface and language settings';

  @override
  String get settingsReadingTitle => 'Reading';

  @override
  String get settingsReadingSubtitle => 'Reader settings';

  @override
  String get settingsPrivacyTitle => 'Privacy';

  @override
  String get settingsPrivacySubtitle => 'Privacy-related features';

  @override
  String get settingsCloudSyncTitle => 'Cloud Sync';

  @override
  String get settingsCloudSyncSubtitle => 'Upload and restore backups';

  @override
  String get settingsOtherTitle => 'Other';

  @override
  String get settingsOtherSubtitle => 'Check-in and extra actions';

  @override
  String get settingsAdvancedTitle => 'Advanced';

  @override
  String get settingsAdvancedSubtitle => 'Experimental features';

  @override
  String get settingsAboutTitle => 'About';

  @override
  String get displayTitle => 'Display';

  @override
  String get displayThemeTitle => 'Theme';

  @override
  String get displayThemeLight => 'Light';

  @override
  String get displayThemeDark => 'Dark';

  @override
  String get displayThemeSystem => 'Follow system';

  @override
  String get displayPresetMintGreen => 'Mint Green';

  @override
  String get displayPresetSeaSaltBlue => 'Sea Salt Blue';

  @override
  String get displayPresetTwilightPurple => 'Twilight Purple';

  @override
  String get displayPresetCherryBlossomPink => 'Cherry Blossom Pink';

  @override
  String get displayPresetCoralOrange => 'Coral Orange';

  @override
  String get displayPresetAmberYellow => 'Amber Yellow';

  @override
  String get displayPresetLimeGreen => 'Lime Green';

  @override
  String get displayPresetGraphiteGray => 'Graphite Gray';

  @override
  String get displayPresetBerryRed => 'Berry Red';

  @override
  String get displayLanguageTitle => 'Language';

  @override
  String get displayLanguageSubtitle => 'Switch the app display language';

  @override
  String get displayLanguageSystem => 'Follow system';

  @override
  String get displayLanguageZhHans => '简体中文';

  @override
  String get displayLanguageEnglish => 'English';

  @override
  String get displayRefreshRateTitle => 'Refresh rate';

  @override
  String get displayRefreshRateAuto => 'Auto';

  @override
  String displayRefreshRateSpecified(Object id) {
    return 'Specified mode (ID: $id)';
  }

  @override
  String get displayPureBlackTitle => 'Pure black mode';

  @override
  String get displayPureBlackSubtitle => 'Use a pure black background in dark mode';

  @override
  String get displayDynamicColorTitle => 'Dynamic color';

  @override
  String get displayDynamicColorSubtitle => 'Extract theme colors from the system wallpaper automatically (Android 12+)';

  @override
  String get displayComicDynamicColorTitle => 'Comic detail dynamic color';

  @override
  String get displayComicDynamicColorSubtitle => 'Generate a dynamic theme for the comic detail page from the cover image';

  @override
  String get displayColorSchemeTitle => 'Color scheme';

  @override
  String get homeGuestUser => 'Not signed in';

  @override
  String get homeFirstUseLoading => 'Loading first-use time...';

  @override
  String get homeFirstUseUnknown => 'First time using this app';

  @override
  String homeFirstUseFormatted(Object date) {
    return 'First used on $date';
  }

  @override
  String get homeLogoutTitle => 'Sign out';

  @override
  String get homeLogoutContent => 'Are you sure you want to sign out?';

  @override
  String get homeLoginTitle => 'Sign in';

  @override
  String get homeLoginAccountLabel => 'Account';

  @override
  String get homeLoginPasswordLabel => 'Password';

  @override
  String get homeLoginHidePassword => 'Hide password';

  @override
  String get homeLoginShowPassword => 'Show password';

  @override
  String get homeLoginEmptyError => 'Account and password cannot be empty';

  @override
  String get homeLoginSuccess => 'Signed in successfully';

  @override
  String get homeLoggedOut => 'Signed out';

  @override
  String get homeSaveAvatarTitle => 'Save avatar';

  @override
  String get homeSaveAvatarContent => 'Save the current avatar to your gallery?';

  @override
  String get homeAvatarSaved => 'Avatar saved';

  @override
  String homeAvatarSaveFailed(Object error) {
    return 'Failed to save avatar: $error';
  }

  @override
  String get homePressBackAgainToExit => 'Press back again to exit';

  @override
  String get homeSearchHint => 'Search comics';

  @override
  String get homeSortTooltip => 'Sort';

  @override
  String get homeFavoriteSortByFavoriteTime => 'Favorite time';

  @override
  String get homeFavoriteSortByUpdateTime => 'Update time';

  @override
  String get homeCreateFavoriteFolder => 'New folder';

  @override
  String get homeMenuHistory => 'History';

  @override
  String get homeMenuCategories => 'Categories';

  @override
  String get homeMenuRanking => 'Ranking';

  @override
  String get homeMenuDownloads => 'Downloads';

  @override
  String get homeMenuLines => 'Lines';

  @override
  String get homeCheckInAction => 'Check in';

  @override
  String get homeCheckInDone => 'Checked in today';

  @override
  String get homeCheckInInProgress => 'Checking in...';

  @override
  String get homeCheckInSuccess => 'Check-in successful';

  @override
  String get homeCheckInAlreadyDone => 'Already checked in today';

  @override
  String homeCheckInFailed(Object error) {
    return 'Check-in failed: $error';
  }

  @override
  String get homeTabDiscover => 'Discover';

  @override
  String get homeTabFavorite => 'Favorites';

  @override
  String get otherTitle => 'Other';

  @override
  String get otherAutoCheckInTitle => 'Auto daily check-in';

  @override
  String get otherAutoCheckInSubtitle => 'Automatically check in once when the app is opened each day';

  @override
  String get sourceBootstrapDownloading => 'Downloading comic source';

  @override
  String get sourceBootstrapPreparing => 'Preparing source files...';

  @override
  String sourceBootstrapProgress(Object progress) {
    return 'Downloaded $progress%';
  }

  @override
  String get dialogBarrierLabel => 'Dialog';

  @override
  String get aboutTitle => 'About';

  @override
  String get aboutVersion => 'Version 1.0.0';

  @override
  String get aboutDescription => 'A third-party JMComic client';

  @override
  String get aboutProjectTitle => 'Project';

  @override
  String get aboutProjectSubtitle => 'GitHub (https://github.com/LuckyLxi/Hazuki)';

  @override
  String get aboutFeedbackTitle => 'Feedback';

  @override
  String get aboutFeedbackSubtitle => 'Report any issues you encounter while reading';

  @override
  String get aboutOpenLinkFailed => 'Unable to open the link';

  @override
  String get aboutOpenFeedbackFailed => 'Unable to open the feedback link';

  @override
  String get aboutDisclaimerTitle => 'Disclaimer';

  @override
  String get aboutDisclaimerSubtitle => 'Please read before use';

  @override
  String get aboutDisclaimerContent => 'This app is provided only for learning, interface research, and personal technical exchange. It does not provide any comic resources, nor does it directly store, upload, or distribute comic content.\n\nOn first launch or when updating the comic source, the app automatically downloads a comic-source script from a third-party GitHub repository. Both that script and any content parsed through it originate from third parties, and the related copyrights and liabilities belong to the original authors or rights holders.\n\nPlease use this app in compliance with local laws, regulations, and copyright requirements. Any disputes, losses, or legal liabilities arising from downloading, using third-party comic sources, or accessing related content shall be borne solely by the user.';

  @override
  String get commonConfirm => 'OK';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonClose => 'Close';

  @override
  String get commonSave => 'Save';

  @override
  String get commonLoading => 'Loading...';

  @override
  String get commonRetry => 'Retry';

  @override
  String get searchTitle => 'Search';

  @override
  String get searchHint => 'Search comics';

  @override
  String get searchHistoryTitle => 'Search history';

  @override
  String get searchClearTooltip => 'Clear';

  @override
  String get searchSubmitTooltip => 'Search';

  @override
  String get searchClearHistoryTitle => 'Clear history';

  @override
  String get searchClearHistoryContent => 'Are you sure you want to clear all search history?';

  @override
  String get historyTitle => 'History';

  @override
  String get historyEmpty => 'No history yet';

  @override
  String get historySelectionCancelTooltip => 'Exit multi-select';

  @override
  String get historySelectionEnterTooltip => 'Multi-select';

  @override
  String get historyDeleteSelectedTooltip => 'Delete selected history';

  @override
  String get historyClearAllTooltip => 'Clear all history';

  @override
  String get historyDeleteSelectedTitle => 'Delete history';

  @override
  String historyDeleteSelectedContent(Object count) {
    return 'Are you sure you want to delete the history of $count selected comics?';
  }

  @override
  String get historyClearAllTitle => 'Clear history';

  @override
  String get historyClearAllContent => 'Are you sure you want to clear all history? This action cannot be undone.';

  @override
  String get historyCopiedComicId => 'Comic ID copied';

  @override
  String get historyLoginRequired => 'Please sign in first';

  @override
  String get historyFavoriteProcessing => 'Processing favorite...';

  @override
  String get historyFavoriteFolderNotice => 'For multiple favorite folders, please use the comic detail page. Performing the default action...';

  @override
  String get historyFavoriteRemoved => 'Removed from favorites';

  @override
  String get historyFavoriteAdded => 'Added to favorites';

  @override
  String historyFavoriteFailed(Object error) {
    return 'Favorite action failed: $error';
  }

  @override
  String get historyMenuCopyComicId => 'Copy comic ID';

  @override
  String get historyMenuToggleFavorite => 'Favorite / Unfavorite';

  @override
  String get historyMenuDeleteItem => 'Delete this record';

  @override
  String get discoverLoadTimeout => 'Discover page loading timed out. Pull down to retry.';

  @override
  String discoverLoadFailed(Object error) {
    return 'Failed to load discover page: $error';
  }

  @override
  String get discoverEmpty => 'No discover content is available for the current source';

  @override
  String get discoverMore => 'See more';

  @override
  String get aboutThirdPartyLicensesTitle => 'Third-party licenses';

  @override
  String get aboutThirdPartyLicensesSubtitle => 'View the open-source libraries used by this app';

  @override
  String get searchOrderLatest => 'Latest';

  @override
  String get searchOrderTotalRanking => 'Top overall';

  @override
  String get searchOrderMonthlyRanking => 'Top monthly';

  @override
  String get searchOrderWeeklyRanking => 'Top weekly';

  @override
  String get searchOrderDailyRanking => 'Top daily';

  @override
  String get searchOrderMostImages => 'Most images';

  @override
  String get searchOrderMostLikes => 'Most likes';

  @override
  String get searchTimeout => 'Search timed out. Please try again later.';

  @override
  String searchFailed(Object error) {
    return 'Search failed: $error';
  }

  @override
  String get searchStartPrompt => 'Enter keywords to start searching';

  @override
  String get searchLoading => 'Searching...';

  @override
  String get searchEmpty => 'No results found';

  @override
  String get searchSortTooltip => 'Sort';

  @override
  String get comicDetailFavoriteAdded => 'Added to favorites';

  @override
  String get comicDetailFavoriteRemoved => 'Removed from favorites';

  @override
  String comicDetailFavoriteActionFailed(Object error) {
    return 'Favorite action failed: $error';
  }

  @override
  String get comicDetailManageFavorites => 'Manage favorites';

  @override
  String get comicDetailCreateFavoriteFolder => 'New favorite folder';

  @override
  String get comicDetailFavoriteFolderNameHint => 'Enter a folder name';

  @override
  String get comicDetailFavoriteFolderNameRequired => 'Folder name cannot be empty';

  @override
  String comicDetailCreateFavoriteFolderFailed(Object error) {
    return 'Failed to create favorite folder: $error';
  }

  @override
  String get comicDetailDeleteFavoriteFolder => 'Delete favorite folder';

  @override
  String get comicDetailDeleteFavoriteFolderContent => 'Delete this folder? Comics in this folder will lose their grouping.';

  @override
  String get comicDetailDelete => 'Delete';

  @override
  String comicDetailDeleteFavoriteFolderFailed(Object error) {
    return 'Failed to delete favorite folder: $error';
  }

  @override
  String comicDetailFavoriteFoldersLoadFailed(Object error) {
    return 'Failed to load favorite folders: $error';
  }

  @override
  String get comicDetailNoFavoriteFolders => 'No favorite folders yet';

  @override
  String get comicDetailDeleteFavoriteFolderTooltip => 'Delete folder';

  @override
  String get comicDetailCreateFavoriteFolderTooltip => 'New folder';

  @override
  String get comicDetailSingleFolderHint => 'The current source only supports adding this comic to one favorite folder';

  @override
  String get comicDetailMultipleFoldersHint => 'You can select multiple favorite folders for this comic';

  @override
  String get comicDetailSelectAtLeastOneFolder => 'Please select at least one favorite folder';

  @override
  String get comicDetailFavoriteSettingsUpdated => 'Favorite settings updated';

  @override
  String comicDetailFavoriteSettingsUpdateFailed(Object error) {
    return 'Failed to update favorite settings: $error';
  }

  @override
  String get comicDetailNoChapterInfo => 'No chapter information available';

  @override
  String get comicDetailNoChapters => 'This comic has no chapters yet';

  @override
  String get comicDetailAuthor => 'Author';

  @override
  String get comicDetailTags => 'Tags';

  @override
  String get comicDetailCopiedId => 'Copied ID';

  @override
  String comicDetailCopiedPrefix(Object value) {
    return 'Copied: $value';
  }

  @override
  String get comicDetailSavedToPath => 'Saved';

  @override
  String comicDetailSaveFailed(Object error) {
    return 'Failed to save: $error';
  }

  @override
  String get comicDetailLoading => 'Loading...';

  @override
  String get comicDetailSummary => 'Summary';

  @override
  String get comicDetailNoRelatedComics => 'No related comics yet';

  @override
  String get comicDetailCollapse => 'Collapse';

  @override
  String get comicDetailExpand => 'Expand';

  @override
  String comicDetailUpdatedAt(Object time) {
    return 'Updated at: $time';
  }

  @override
  String get comicDetailTitle => 'Comic details';

  @override
  String get comicDetailTabInfo => 'Details';

  @override
  String get comicDetailTabComments => 'Comments';

  @override
  String get comicDetailTabRelated => 'Related';

  @override
  String get comicDetailChapters => 'Chapters';

  @override
  String get comicDetailDefaultChapterTitle => 'Chapter 1';

  @override
  String comicDetailChapterCount(Object count) {
    return '$count chapters';
  }

  @override
  String comicDetailLikesCount(Object count) {
    return '$count likes';
  }

  @override
  String comicDetailViewsCount(Object count) {
    return '$count views';
  }

  @override
  String get comicDetailFavorite => 'Favorite';

  @override
  String get comicDetailUnfavorite => 'Unfavorite';

  @override
  String get comicDetailRead => 'Read';

  @override
  String comicDetailContinueReading(Object title) {
    return 'Continue reading $title';
  }

  @override
  String get comicDetailSaveImage => 'Save image';

  @override
  String get comicDetailRemindLaterToday => 'Don\'t remind again today';

  @override
  String get sourceUpdateAvailableTitle => 'Source update available';

  @override
  String sourceUpdateLocalVersion(Object version) {
    return 'Local source version: $version';
  }

  @override
  String sourceUpdateRemoteVersion(Object version) {
    return 'Cloud source version: $version';
  }

  @override
  String get sourceUpdateDownloading => 'Downloading...';

  @override
  String sourceUpdateDownloadingProgress(Object progress) {
    return 'Downloading $progress%';
  }

  @override
  String get sourceUpdateDownloadFailed => 'Download failed. Please try again later.';

  @override
  String get sourceUpdateDownload => 'Download';

  @override
  String get readingSettingsTitle => 'Reading settings';

  @override
  String get readingModeTitle => 'Reading mode';

  @override
  String get readingModeSubtitle => 'Choose how pages are arranged in the reader';

  @override
  String get readingModeTopToBottom => 'Top to bottom';

  @override
  String get readingModeRightToLeft => 'Right to left';

  @override
  String get readingTapToTurnPageTitle => 'Tap to turn page';

  @override
  String get readingTapToTurnPageSubtitle => 'Only works in right-to-left mode. Tap the left side for the previous page and the right side for the next page';

  @override
  String get readingImmersiveModeTitle => 'Immersive mode';

  @override
  String get readingImmersiveModeSubtitle => 'Hide the status bar and bottom navigation bar automatically when entering the reader';

  @override
  String get readingKeepScreenOnTitle => 'Keep screen on';

  @override
  String get readingKeepScreenOnSubtitle => 'Keep the screen awake while reading to prevent auto lock';

  @override
  String get readingCustomBrightnessTitle => 'Custom brightness';

  @override
  String get readingCustomBrightnessSubtitle => 'Override the system brightness inside the reader when enabled';

  @override
  String readingBrightnessLabel(Object value) {
    return 'Brightness $value';
  }

  @override
  String get readingPageIndicatorTitle => 'Page indicator';

  @override
  String get readingPageIndicatorSubtitle => 'Show the chapter number and current page/total pages in the lower-left corner of the reader';

  @override
  String get readingPinchToZoomTitle => 'Pinch to zoom';

  @override
  String get readingPinchToZoomSubtitle => 'Allow two-finger pinch gestures to zoom comic images';

  @override
  String get readingLongPressSaveTitle => 'Long press to save images';

  @override
  String get readingLongPressSaveSubtitle => 'Allow saving the current comic image by long pressing it';

  @override
  String get downloadsTitle => 'Downloads';

  @override
  String get downloadsTabOngoing => 'Downloading';

  @override
  String get downloadsTabDownloaded => 'Downloaded';

  @override
  String get downloadsEmptyOngoing => 'No active downloads';

  @override
  String get downloadsEmptyDownloaded => 'No downloaded comics yet';

  @override
  String downloadsSelectionTitle(Object count) {
    return '$count selected';
  }

  @override
  String get downloadsDeleteSelectedTitle => 'Delete downloaded comics';

  @override
  String downloadsDeleteSelectedContent(Object count) {
    return 'Delete $count selected downloaded comics?';
  }

  @override
  String get downloadsStatusQueued => 'Queued';

  @override
  String get downloadsStatusDownloading => 'Downloading';

  @override
  String get downloadsStatusPaused => 'Paused';

  @override
  String downloadsStatusFailed(Object error) {
    return 'Failed: $error';
  }

  @override
  String downloadsChapterCount(Object count) {
    return '$count chapters';
  }

  @override
  String downloadsCurrentProgress(Object current, Object total) {
    return '$current/$total images';
  }

  @override
  String get downloadsActionSelect => 'Select';

  @override
  String get downloadsActionPause => 'Pause';

  @override
  String get downloadsActionResume => 'Resume';

  @override
  String downloadsQueued(Object count) {
    return '$count chapters added to downloads';
  }

  @override
  String get downloadsDownloadChaptersTitle => 'Download chapters';

  @override
  String get downloadsDownloadChaptersSubtitle => 'Select the chapters you want to download';

  @override
  String get downloadsDownloadAction => 'Download';

  @override
  String get privacySettingsTitle => 'Privacy settings';

  @override
  String get privacyBlurTaskTitle => 'Blur app in recent tasks';

  @override
  String get privacyBlurTaskSubtitle => 'Show a pure black task card when switching to recent apps';

  @override
  String get privacyBiometricUnlockTitle => 'Biometric unlock';

  @override
  String get privacyBiometricUnlockSubtitle => 'Require fingerprint verification each time the app is opened';

  @override
  String get privacyAuthOnResumeTitle => 'Require verification after leaving app';

  @override
  String get privacyAuthOnResumeSubtitle => 'Require authentication again whenever the app returns to foreground';

  @override
  String get lineSettingsTitle => 'Lines';

  @override
  String lineLoadFailed(Object error) {
    return 'Failed to load line information: $error';
  }

  @override
  String lineOptionLabel(Object value) {
    return 'Line $value';
  }

  @override
  String lineOptionWithHostLabel(Object value, Object host) {
    return 'Line $value ($host)';
  }

  @override
  String lineImageStreamLabel(Object value) {
    return 'Stream $value';
  }

  @override
  String lineApiSwitched(Object value) {
    return 'API domain stream switched to line $value';
  }

  @override
  String lineImageSwitched(Object value) {
    return 'Image domain stream switched to stream $value';
  }

  @override
  String lineSwitchFailed(Object error) {
    return 'Switch failed: $error';
  }

  @override
  String get lineRefreshOnStartUpdated => 'Startup auto-refresh setting updated';

  @override
  String lineSaveFailed(Object error) {
    return 'Save failed: $error';
  }

  @override
  String get lineIntro => 'You can switch API and image streams separately, and changes will apply automatically to subsequent requests.';

  @override
  String get lineApiTitle => 'API domain stream';

  @override
  String get lineApiSubtitle => 'Used for API requests. Switch it if the network is unstable.';

  @override
  String get lineSelectApiLabel => 'Select API line';

  @override
  String get lineImageTitle => 'Image domain stream';

  @override
  String get lineImageHostUnavailable => 'Current image domain is unavailable';

  @override
  String lineImageHostCurrent(Object host) {
    return 'Current domain: $host';
  }

  @override
  String get lineSelectImageLabel => 'Select image stream';

  @override
  String get lineRefreshOnStartTitle => 'Refresh domain list on startup';

  @override
  String get lineRefreshOnStartSubtitle => 'Automatically update the API domain pool each time the app opens';

  @override
  String get lineRefreshStatusButton => 'Refresh line status';

  @override
  String get displayModeAndroidOnly => 'Only Android supports refresh rate settings';

  @override
  String displayModeReadFailed(Object error) {
    return 'Failed to read display modes: $error';
  }

  @override
  String get displayModeSystemRejected => 'The system rejected this display mode';

  @override
  String get displayModeApplied => 'Refresh rate applied. Restart the app if it does not take effect.';

  @override
  String displayModeSetFailed(Object error) {
    return 'Failed to apply setting: $error';
  }

  @override
  String get displayModeUnknown => 'Unknown';

  @override
  String get displayModeUnknownMode => 'Unknown mode';

  @override
  String displayModeCurrentLabel(Object mode) {
    return 'Current system mode: $mode';
  }

  @override
  String get displayModeCurrentSubtitle => 'Current system mode';

  @override
  String get displayModeSelectedSubtitle => 'Selected';

  @override
  String get displayModeHint => 'Note: some devices may be affected by system power saving or app whitelist policies.';

  @override
  String get cachePresetDefault => 'Default 400MB';

  @override
  String get cachePresetLite => 'Light 600MB';

  @override
  String get cachePresetBalanced => 'Balanced 1024MB';

  @override
  String get cachePresetHeavy => 'Heavy 2048MB';

  @override
  String get cacheMaxSizeTitle => 'Set maximum cache size';

  @override
  String get cacheMaxSizeHint => 'Minimum 400MB. Choose a preset or enter a custom value.';

  @override
  String get cacheCustomMbLabel => 'Custom (MB)';

  @override
  String get cacheCustomMbHint => 'For example, 1024';

  @override
  String cacheLimitUpdated(Object value) {
    return 'Cache limit set to ${value}MB';
  }

  @override
  String get cacheAutoCleanTitle => 'Cache auto-clean';

  @override
  String get cacheAutoCleanOverflowTitle => 'Clean automatically when limit is exceeded';

  @override
  String get cacheAutoCleanOverflowSubtitle => 'Delete the oldest cache first until usage drops below the limit';

  @override
  String get cacheAutoCleanSevenDaysTitle => 'Clean every seven days';

  @override
  String get cacheAutoCleanSevenDaysSubtitle => 'Delete cache files older than 7 days';

  @override
  String get cacheAutoCleanSevenDaysApplied => 'Set to clean every seven days';

  @override
  String get cacheAutoCleanOverflowApplied => 'Set to clean automatically when limit is exceeded';

  @override
  String get cacheClearBarrierLabel => 'Close';

  @override
  String get cacheClearTitle => 'Clear cache';

  @override
  String get cacheClearContent => 'Are you sure you want to clear all image cache? This action cannot be undone.';

  @override
  String get cacheClearConfirm => 'Clear now';

  @override
  String get cacheCleared => 'Cache cleared successfully';

  @override
  String cacheClearFailed(Object error) {
    return 'Failed to clear cache: $error';
  }

  @override
  String get cacheSettingsTitle => 'Cache settings';

  @override
  String get cacheSizeTitle => 'Cache size';

  @override
  String cacheSizeSummary(Object used, Object max) {
    return 'Current $used / Limit $max';
  }

  @override
  String get cacheAutoCleanModeSummary => 'Clean every seven days';

  @override
  String get cacheAutoCleanModeOverflowSummary => 'Clean automatically when limit is exceeded';

  @override
  String get cacheClearNowTitle => 'Clear cache now';

  @override
  String get cacheClearNowSubtitle => 'Remove all locally downloaded image cache to free up storage space';

  @override
  String get cloudSyncIncompleteConfig => 'Please fill in the complete URL, Username, and Password';

  @override
  String get cloudSyncInvalidUrl => 'Invalid URL format. Please include http/https';

  @override
  String get cloudSyncStatusIncomplete => 'Configuration incomplete';

  @override
  String get cloudSyncStatusDisabled => 'Disabled';

  @override
  String get cloudSyncConfigSaved => 'Cloud sync configuration saved';

  @override
  String cloudSyncSaveFailed(Object error) {
    return 'Save failed: $error';
  }

  @override
  String get cloudSyncNeedCompleteConfig => 'Please enable cloud sync and save a complete configuration first';

  @override
  String get cloudSyncUploadCompleted => 'Backup upload completed';

  @override
  String cloudSyncUploadFailed(Object error) {
    return 'Upload failed: $error';
  }

  @override
  String get cloudSyncRestoreTitle => 'Restore backup';

  @override
  String get cloudSyncRestoreContent => 'Overwrite local files and restore the latest cloud backup?';

  @override
  String get cloudSyncRestoreConfirm => 'Overwrite and restore';

  @override
  String get cloudSyncRestoreCompleted => 'Backup restored and local data overwritten';

  @override
  String cloudSyncRestoreFailed(Object error) {
    return 'Restore failed: $error';
  }

  @override
  String get cloudSyncTitle => 'Cloud sync';

  @override
  String get cloudSyncStatusUnchecked => 'Unchecked';

  @override
  String get cloudSyncStatusConnected => 'Connected';

  @override
  String get cloudSyncStatusDisconnected => 'Disconnected';

  @override
  String get cloudSyncEnabledTitle => 'Cloud sync';

  @override
  String get cloudSyncEnabledSubtitle => 'Enable uploading and restoring cloud backups';

  @override
  String get cloudSyncUrlHelper => 'The app will append /HazukiSync automatically, so you do not need to enter it manually';

  @override
  String get cloudSyncUsernameLabel => 'Username';

  @override
  String get cloudSyncPasswordLabel => 'Password';

  @override
  String get cloudSyncSave => 'Save';

  @override
  String get cloudSyncUpload => 'Upload backup';

  @override
  String get cloudSyncRestore => 'Restore backup';

  @override
  String get favoritesDebugCopied => 'Network logs copied';

  @override
  String get favoritesDebugFilterReason => 'Show only important logs (error logs, HTTP>=400, login-related entries, and entries containing critical error keywords)';

  @override
  String get favoritesDebugFilterImportantTooltip => 'Filter important logs';

  @override
  String get favoritesDebugCopyTooltip => 'Copy';

  @override
  String get favoritesDebugRefreshTooltip => 'Refresh network logs';

  @override
  String favoritesDebugLoadFailed(Object error) {
    return 'Failed to load network logs: $error';
  }

  @override
  String get favoritesDebugFullFetchButton => 'Run full network fetch manually (slow)';

  @override
  String get logsNetworkTitle => 'Network logs';

  @override
  String get logsApplicationTitle => 'Application logs';

  @override
  String get logsApplicationCopied => 'Application logs copied';

  @override
  String get logsApplicationRefreshTooltip => 'Refresh application logs';

  @override
  String logsApplicationLoadFailed(Object error) {
    return 'Failed to load application logs: $error';
  }

  @override
  String get logsApplicationEmpty => 'No application logs yet';

  @override
  String get logsApplicationExportTooltip => 'Export logs';

  @override
  String get logsApplicationExportSuccess => 'Log file exported';

  @override
  String logsApplicationExportFailed(Object error) {
    return 'Failed to export log file: $error';
  }

  @override
  String get logsReaderTitle => 'Reader logs';

  @override
  String get logsReaderCopied => 'Reader logs copied';

  @override
  String get logsReaderRefreshTooltip => 'Refresh reader logs';

  @override
  String logsReaderLoadFailed(Object error) {
    return 'Failed to load reader logs: $error';
  }

  @override
  String get logsReaderEmpty => 'No reader logs yet';

  @override
  String get tagCategoryLoadTimeout => 'Tag categories timed out while loading. Please try again later.';

  @override
  String tagCategoryLoadFailed(Object error) {
    return 'Failed to load tag categories: $error';
  }

  @override
  String get tagCategoryTitle => 'Tag categories';

  @override
  String get tagCategoryEmpty => 'No tag categories are available for the current source';

  @override
  String get rankingLoadOptionsTimeout => 'Ranking categories timed out while loading. Please try again later.';

  @override
  String get rankingLoadTimeout => 'Rankings timed out while loading. Please try again later.';

  @override
  String rankingLoadFailed(Object error) {
    return 'Failed to load rankings: $error';
  }

  @override
  String get rankingTitle => 'Rankings';

  @override
  String get rankingEmptyOptions => 'No ranking categories are available for the current source';

  @override
  String get rankingEmptyComics => 'No ranking content available';

  @override
  String get rankingReachedEnd => 'You\'ve reached the end';

  @override
  String get favoriteAllFolder => 'All';

  @override
  String get favoriteLoadTimeout => 'Favorites timed out while loading. Pull down to retry.';

  @override
  String favoriteFoldersLoadFailed(Object error) {
    return 'Failed to load favorite folders: $error';
  }

  @override
  String favoriteCreated(Object name) {
    return 'Favorite folder \"$name\" created successfully';
  }

  @override
  String favoriteCreateFailed(Object error) {
    return 'Failed to create favorite folder: $error';
  }

  @override
  String favoriteSortChangeFailed(Object error) {
    return 'Failed to change sort order: $error';
  }

  @override
  String favoriteDeleteFailed(Object error) {
    return 'Failed to delete favorite folder: $error';
  }

  @override
  String get favoriteFolderHeader => 'Favorite folders';

  @override
  String get favoriteDeleteCurrentFolderTooltip => 'Delete current favorite folder';

  @override
  String get favoriteLoginRequired => 'Please sign in';

  @override
  String get favoriteEmpty => 'No favorites yet';

  @override
  String get favoriteCreateFolderTitle => 'New favorite folder';

  @override
  String get favoriteCreateFolderHint => 'Enter a folder name';

  @override
  String get favoriteCreateFolderNameRequired => 'Folder name cannot be empty';

  @override
  String get favoriteDeleteFolderTitle => 'Delete favorite folder';

  @override
  String favoriteDeleteFolderContent(Object name) {
    return 'Delete \"$name\"?';
  }

  @override
  String discoverSectionLoadFailed(Object error) {
    return 'Load failed: $error';
  }

  @override
  String get discoverSectionEmpty => 'No comics available';

  @override
  String get commentsTitle => 'Comments';

  @override
  String commentsLoadFailed(Object error) {
    return 'Failed to load comments: $error';
  }

  @override
  String get commentsLoginRequiredToSend => 'Please sign in before commenting';

  @override
  String get commentsSourceNotSupported => 'The current source does not support sending comments';

  @override
  String get commentsSendSuccess => 'Comment sent successfully';

  @override
  String commentsSendFailed(Object error) {
    return 'Failed to send: $error';
  }

  @override
  String get commentsAnonymousUser => 'Anonymous user';

  @override
  String commentsReplyCount(Object count) {
    return 'Replies $count';
  }

  @override
  String get commentsReplyTooltip => 'Reply';

  @override
  String commentsReplyToUser(Object name) {
    return 'Reply to @$name';
  }

  @override
  String get commentsCancelReplyTooltip => 'Cancel reply';

  @override
  String get commentsComposerHint => 'Write your comment…';

  @override
  String commentsReplyComposerHint(Object name) {
    return 'Reply to $name…';
  }

  @override
  String get commentsSending => 'Sending…';

  @override
  String get commentsSend => 'Send';

  @override
  String get commentsEmpty => 'No comments yet';

  @override
  String get readerSaveImageTitle => 'Save image';

  @override
  String get readerSaveImageContent => 'Save this comic image locally?';

  @override
  String readerChapterLoadFailed(Object error) {
    return 'Failed to load chapter: $error';
  }

  @override
  String get readerCurrentChapterNoImages => 'No images in the current chapter';

  @override
  String readerPageIndicator(Object chapter, Object current, Object total) {
    return 'Chapter $chapter $current/$total';
  }

  @override
  String get readerResetZoom => 'Reset zoom';

  @override
  String get advancedTitle => 'Advanced';

  @override
  String get advancedDebugTitle => 'Logs';

  @override
  String get advancedDebugSubtitle => 'Network, application, and reader logs';

  @override
  String get advancedSoftwareLogCaptureTitle => 'Record software logs';

  @override
  String get advancedSoftwareLogCaptureSubtitle => 'When turned off, network, application, and reader logs will no longer be captured';

  @override
  String get advancedComicIdSearchTitle => 'Comic ID search optimization';

  @override
  String get advancedComicIdSearchSubtitle => 'Automatically remove non-digit characters on search submission and keep only Arabic numerals as the keyword';

  @override
  String get advancedNoImageModeTitle => 'No-image mode';

  @override
  String get advancedNoImageModeSubtitle => 'Hide images globally (except the login avatar in the sidebar)';

  @override
  String get advancedEditSourceTitle => 'Edit comic source';

  @override
  String get advancedEditSourceSubtitle => 'Open a lightweight editor to edit and save jm.js';

  @override
  String get advancedRestoreSourceLabel => 'Restore comic source';

  @override
  String get advancedRestoreSourceSuccess => 'Comic source restored';

  @override
  String get sourceEditorLoading => 'Loading comic source…';

  @override
  String get sourceEditorHint => 'Restart the app after saving to apply the updated source.';

  @override
  String get sourceEditorSaved => 'Comic source saved';

  @override
  String sourceEditorLoadFailed(Object error) {
    return 'Load failed: $error';
  }

  @override
  String sourceEditorSaveFailed(Object error) {
    return 'Save failed: $error';
  }

  @override
  String sourceEditorLineCount(Object count) {
    return '$count lines';
  }

  @override
  String get sourceEditorRestoreConfirmContent => 'Restore the official comic source? Your saved edits will be overwritten.';

  @override
  String get sourceEditorRestoreFailed => 'Restore failed. Please try again later.';

  @override
  String sourceEditorRestoreDownloadingProgress(Object progress) {
    return 'Downloading $progress%';
  }

  @override
  String get sourceEditorRestoringTitle => 'Restoring comic source';

  @override
  String get downloadsScanPermissionDenied => 'File access permission was not granted. Unable to scan local comics.';

  @override
  String downloadsScanCompleted(Object scannedDirectories, Object recoveredComics) {
    return 'Scan complete. Scanned $scannedDirectories folders and recovered $recoveredComics comics.';
  }

  @override
  String get downloadsScanNoRecoverable => 'Scan complete. No recoverable downloaded comics were found.';

  @override
  String downloadsScanFailed(Object error) {
    return 'Scan failed: $error';
  }

  @override
  String get downloadsScanTooltip => 'Scan local comics';

  @override
  String get sourceUpdateRestartTitle => 'Please restart the app';

  @override
  String get sourceUpdateRestartMessage => 'The source update has finished downloading. Please restart the app to apply the update.';

  @override
  String get sourceUpdateLocalLabel => 'Local';

  @override
  String get sourceUpdateCloudLabel => 'Cloud';

  @override
  String get sourceUpdateAvailableMessage => 'A new source version is available. Download it now and restart the app to apply it.';

  @override
  String get sourceUpdateDownloadingMessage => 'Downloading and replacing the source package. Please keep the network connected.';

  @override
  String get sourceUpdateRestartHint => 'Close and reopen the app to finish applying the update.';
}
