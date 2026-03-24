import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Hazuki'**
  String get appTitle;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsCacheTitle.
  ///
  /// In en, this message translates to:
  /// **'Cache'**
  String get settingsCacheTitle;

  /// No description provided for @settingsCacheSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Cache-related settings'**
  String get settingsCacheSubtitle;

  /// No description provided for @settingsDisplayTitle.
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get settingsDisplayTitle;

  /// No description provided for @settingsDisplaySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Interface and language settings'**
  String get settingsDisplaySubtitle;

  /// No description provided for @settingsReadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get settingsReadingTitle;

  /// No description provided for @settingsReadingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reader settings'**
  String get settingsReadingSubtitle;

  /// No description provided for @settingsPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get settingsPrivacyTitle;

  /// No description provided for @settingsPrivacySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy-related features'**
  String get settingsPrivacySubtitle;

  /// No description provided for @settingsCloudSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'Cloud Sync'**
  String get settingsCloudSyncTitle;

  /// No description provided for @settingsCloudSyncSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Upload and restore backups'**
  String get settingsCloudSyncSubtitle;

  /// No description provided for @settingsAdvancedTitle.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get settingsAdvancedTitle;

  /// No description provided for @settingsAdvancedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Experimental features'**
  String get settingsAdvancedSubtitle;

  /// No description provided for @settingsAboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAboutTitle;

  /// No description provided for @displayTitle.
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get displayTitle;

  /// No description provided for @displayThemeTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get displayThemeTitle;

  /// No description provided for @displayThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get displayThemeLight;

  /// No description provided for @displayThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get displayThemeDark;

  /// No description provided for @displayThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get displayThemeSystem;

  /// No description provided for @displayPresetMintGreen.
  ///
  /// In en, this message translates to:
  /// **'Mint Green'**
  String get displayPresetMintGreen;

  /// No description provided for @displayPresetSeaSaltBlue.
  ///
  /// In en, this message translates to:
  /// **'Sea Salt Blue'**
  String get displayPresetSeaSaltBlue;

  /// No description provided for @displayPresetTwilightPurple.
  ///
  /// In en, this message translates to:
  /// **'Twilight Purple'**
  String get displayPresetTwilightPurple;

  /// No description provided for @displayPresetCherryBlossomPink.
  ///
  /// In en, this message translates to:
  /// **'Cherry Blossom Pink'**
  String get displayPresetCherryBlossomPink;

  /// No description provided for @displayPresetCoralOrange.
  ///
  /// In en, this message translates to:
  /// **'Coral Orange'**
  String get displayPresetCoralOrange;

  /// No description provided for @displayPresetAmberYellow.
  ///
  /// In en, this message translates to:
  /// **'Amber Yellow'**
  String get displayPresetAmberYellow;

  /// No description provided for @displayPresetLimeGreen.
  ///
  /// In en, this message translates to:
  /// **'Lime Green'**
  String get displayPresetLimeGreen;

  /// No description provided for @displayPresetGraphiteGray.
  ///
  /// In en, this message translates to:
  /// **'Graphite Gray'**
  String get displayPresetGraphiteGray;

  /// No description provided for @displayPresetBerryRed.
  ///
  /// In en, this message translates to:
  /// **'Berry Red'**
  String get displayPresetBerryRed;

  /// No description provided for @displayLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get displayLanguageTitle;

  /// No description provided for @displayLanguageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Switch the app display language'**
  String get displayLanguageSubtitle;

  /// No description provided for @displayLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get displayLanguageSystem;

  /// No description provided for @displayLanguageZhHans.
  ///
  /// In en, this message translates to:
  /// **'简体中文'**
  String get displayLanguageZhHans;

  /// No description provided for @displayLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get displayLanguageEnglish;

  /// No description provided for @displayRefreshRateTitle.
  ///
  /// In en, this message translates to:
  /// **'Refresh rate'**
  String get displayRefreshRateTitle;

  /// No description provided for @displayRefreshRateAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get displayRefreshRateAuto;

  /// No description provided for @displayRefreshRateSpecified.
  ///
  /// In en, this message translates to:
  /// **'Specified mode (ID: {id})'**
  String displayRefreshRateSpecified(Object id);

  /// No description provided for @displayPureBlackTitle.
  ///
  /// In en, this message translates to:
  /// **'Pure black mode'**
  String get displayPureBlackTitle;

  /// No description provided for @displayPureBlackSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use a pure black background in dark mode'**
  String get displayPureBlackSubtitle;

  /// No description provided for @displayDynamicColorTitle.
  ///
  /// In en, this message translates to:
  /// **'Dynamic color'**
  String get displayDynamicColorTitle;

  /// No description provided for @displayDynamicColorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Extract theme colors from the system wallpaper automatically (Android 12+)'**
  String get displayDynamicColorSubtitle;

  /// No description provided for @displayComicDynamicColorTitle.
  ///
  /// In en, this message translates to:
  /// **'Comic detail dynamic color'**
  String get displayComicDynamicColorTitle;

  /// No description provided for @displayComicDynamicColorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Generate a dynamic theme for the comic detail page from the cover image'**
  String get displayComicDynamicColorSubtitle;

  /// No description provided for @displayColorSchemeTitle.
  ///
  /// In en, this message translates to:
  /// **'Color scheme'**
  String get displayColorSchemeTitle;

  /// No description provided for @homeGuestUser.
  ///
  /// In en, this message translates to:
  /// **'Not signed in'**
  String get homeGuestUser;

  /// No description provided for @homeFirstUseLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading first-use time...'**
  String get homeFirstUseLoading;

  /// No description provided for @homeFirstUseUnknown.
  ///
  /// In en, this message translates to:
  /// **'First time using this app'**
  String get homeFirstUseUnknown;

  /// No description provided for @homeFirstUseFormatted.
  ///
  /// In en, this message translates to:
  /// **'First used on {date}'**
  String homeFirstUseFormatted(Object date);

  /// No description provided for @homeLogoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get homeLogoutTitle;

  /// No description provided for @homeLogoutContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out?'**
  String get homeLogoutContent;

  /// No description provided for @homeLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get homeLoginTitle;

  /// No description provided for @homeLoginAccountLabel.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get homeLoginAccountLabel;

  /// No description provided for @homeLoginPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get homeLoginPasswordLabel;

  /// No description provided for @homeLoginHidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get homeLoginHidePassword;

  /// No description provided for @homeLoginShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get homeLoginShowPassword;

  /// No description provided for @homeLoginEmptyError.
  ///
  /// In en, this message translates to:
  /// **'Account and password cannot be empty'**
  String get homeLoginEmptyError;

  /// No description provided for @homeLoginSuccess.
  ///
  /// In en, this message translates to:
  /// **'Signed in successfully'**
  String get homeLoginSuccess;

  /// No description provided for @homeLoggedOut.
  ///
  /// In en, this message translates to:
  /// **'Signed out'**
  String get homeLoggedOut;

  /// No description provided for @homeSaveAvatarTitle.
  ///
  /// In en, this message translates to:
  /// **'Save avatar'**
  String get homeSaveAvatarTitle;

  /// No description provided for @homeSaveAvatarContent.
  ///
  /// In en, this message translates to:
  /// **'Save the current avatar to your gallery?'**
  String get homeSaveAvatarContent;

  /// No description provided for @homeAvatarSaved.
  ///
  /// In en, this message translates to:
  /// **'Avatar saved to {path}'**
  String homeAvatarSaved(Object path);

  /// No description provided for @homeAvatarSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save avatar: {error}'**
  String homeAvatarSaveFailed(Object error);

  /// No description provided for @homePressBackAgainToExit.
  ///
  /// In en, this message translates to:
  /// **'Press back again to exit'**
  String get homePressBackAgainToExit;

  /// No description provided for @homeSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search comics'**
  String get homeSearchHint;

  /// No description provided for @homeSortTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get homeSortTooltip;

  /// No description provided for @homeFavoriteSortByFavoriteTime.
  ///
  /// In en, this message translates to:
  /// **'Favorite time'**
  String get homeFavoriteSortByFavoriteTime;

  /// No description provided for @homeFavoriteSortByUpdateTime.
  ///
  /// In en, this message translates to:
  /// **'Update time'**
  String get homeFavoriteSortByUpdateTime;

  /// No description provided for @homeCreateFavoriteFolder.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get homeCreateFavoriteFolder;

  /// No description provided for @homeMenuHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get homeMenuHistory;

  /// No description provided for @homeMenuCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get homeMenuCategories;

  /// No description provided for @homeMenuRanking.
  ///
  /// In en, this message translates to:
  /// **'Ranking'**
  String get homeMenuRanking;

  /// No description provided for @homeMenuDownloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get homeMenuDownloads;

  /// No description provided for @homeMenuLines.
  ///
  /// In en, this message translates to:
  /// **'Lines'**
  String get homeMenuLines;

  /// No description provided for @homeTabDiscover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get homeTabDiscover;

  /// No description provided for @homeTabFavorite.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get homeTabFavorite;

  /// No description provided for @dialogBarrierLabel.
  ///
  /// In en, this message translates to:
  /// **'Dialog'**
  String get dialogBarrierLabel;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// No description provided for @aboutVersion.
  ///
  /// In en, this message translates to:
  /// **'Version 1.0.0'**
  String get aboutVersion;

  /// No description provided for @aboutDescription.
  ///
  /// In en, this message translates to:
  /// **'A third-party JMComic client'**
  String get aboutDescription;

  /// No description provided for @aboutProjectTitle.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get aboutProjectTitle;

  /// No description provided for @aboutProjectSubtitle.
  ///
  /// In en, this message translates to:
  /// **'GitHub (https://github.com/LuckyLxi/Hazuki)'**
  String get aboutProjectSubtitle;

  /// No description provided for @aboutFeedbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get aboutFeedbackTitle;

  /// No description provided for @aboutFeedbackSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Report any issues you encounter while reading'**
  String get aboutFeedbackSubtitle;

  /// No description provided for @aboutOpenLinkFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to open the link'**
  String get aboutOpenLinkFailed;

  /// No description provided for @aboutOpenFeedbackFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to open the feedback link'**
  String get aboutOpenFeedbackFailed;

  /// No description provided for @aboutLicenseTitle.
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get aboutLicenseTitle;

  /// No description provided for @aboutLicenseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'GPL-3.0 License'**
  String get aboutLicenseSubtitle;

  /// No description provided for @aboutLicenseSnackbar.
  ///
  /// In en, this message translates to:
  /// **'This project is licensed under GPL-3.0'**
  String get aboutLicenseSnackbar;

  /// No description provided for @aboutThanksTitle.
  ///
  /// In en, this message translates to:
  /// **'Acknowledgements'**
  String get aboutThanksTitle;

  /// No description provided for @aboutThanksSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Outstanding projects that inspired this app'**
  String get aboutThanksSubtitle;

  /// No description provided for @aboutThanksDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Acknowledgements'**
  String get aboutThanksDialogTitle;

  /// No description provided for @aboutThanksDialogContent.
  ///
  /// In en, this message translates to:
  /// **'This project was developed with reference to and thanks to the following open-source projects:\n\n• Venera: reference for login flow implementation\n• Animeko: reference for interface layout design'**
  String get aboutThanksDialogContent;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonConfirm;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get commonLoading;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @searchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchTitle;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search comics'**
  String get searchHint;

  /// No description provided for @searchHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Search history'**
  String get searchHistoryTitle;

  /// No description provided for @searchClearTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get searchClearTooltip;

  /// No description provided for @searchSubmitTooltip.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchSubmitTooltip;

  /// No description provided for @searchClearHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear history'**
  String get searchClearHistoryTitle;

  /// No description provided for @searchClearHistoryContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to clear all search history?'**
  String get searchClearHistoryContent;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyTitle;

  /// No description provided for @historyEmpty.
  ///
  /// In en, this message translates to:
  /// **'No history yet'**
  String get historyEmpty;

  /// No description provided for @historySelectionCancelTooltip.
  ///
  /// In en, this message translates to:
  /// **'Exit multi-select'**
  String get historySelectionCancelTooltip;

  /// No description provided for @historySelectionEnterTooltip.
  ///
  /// In en, this message translates to:
  /// **'Multi-select'**
  String get historySelectionEnterTooltip;

  /// No description provided for @historyDeleteSelectedTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete selected history'**
  String get historyDeleteSelectedTooltip;

  /// No description provided for @historyClearAllTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear all history'**
  String get historyClearAllTooltip;

  /// No description provided for @historyDeleteSelectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete history'**
  String get historyDeleteSelectedTitle;

  /// No description provided for @historyDeleteSelectedContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete the history of {count} selected comics?'**
  String historyDeleteSelectedContent(Object count);

  /// No description provided for @historyClearAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear history'**
  String get historyClearAllTitle;

  /// No description provided for @historyClearAllContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to clear all history? This action cannot be undone.'**
  String get historyClearAllContent;

  /// No description provided for @historyCopiedComicId.
  ///
  /// In en, this message translates to:
  /// **'Comic ID copied'**
  String get historyCopiedComicId;

  /// No description provided for @historyLoginRequired.
  ///
  /// In en, this message translates to:
  /// **'Please sign in first'**
  String get historyLoginRequired;

  /// No description provided for @historyFavoriteProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing favorite...'**
  String get historyFavoriteProcessing;

  /// No description provided for @historyFavoriteFolderNotice.
  ///
  /// In en, this message translates to:
  /// **'For multiple favorite folders, please use the comic detail page. Performing the default action...'**
  String get historyFavoriteFolderNotice;

  /// No description provided for @historyFavoriteRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed from favorites'**
  String get historyFavoriteRemoved;

  /// No description provided for @historyFavoriteAdded.
  ///
  /// In en, this message translates to:
  /// **'Added to favorites'**
  String get historyFavoriteAdded;

  /// No description provided for @historyFavoriteFailed.
  ///
  /// In en, this message translates to:
  /// **'Favorite action failed: {error}'**
  String historyFavoriteFailed(Object error);

  /// No description provided for @historyMenuCopyComicId.
  ///
  /// In en, this message translates to:
  /// **'Copy comic ID'**
  String get historyMenuCopyComicId;

  /// No description provided for @historyMenuToggleFavorite.
  ///
  /// In en, this message translates to:
  /// **'Favorite / Unfavorite'**
  String get historyMenuToggleFavorite;

  /// No description provided for @historyMenuDeleteItem.
  ///
  /// In en, this message translates to:
  /// **'Delete this record'**
  String get historyMenuDeleteItem;

  /// No description provided for @discoverLoadTimeout.
  ///
  /// In en, this message translates to:
  /// **'Discover page loading timed out. Pull down to retry.'**
  String get discoverLoadTimeout;

  /// No description provided for @discoverLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load discover page: {error}'**
  String discoverLoadFailed(Object error);

  /// No description provided for @discoverEmpty.
  ///
  /// In en, this message translates to:
  /// **'No discover content is available for the current source'**
  String get discoverEmpty;

  /// No description provided for @discoverMore.
  ///
  /// In en, this message translates to:
  /// **'See more'**
  String get discoverMore;

  /// No description provided for @aboutThirdPartyLicensesTitle.
  ///
  /// In en, this message translates to:
  /// **'Third-party licenses'**
  String get aboutThirdPartyLicensesTitle;

  /// No description provided for @aboutThirdPartyLicensesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View the open-source libraries used by this app'**
  String get aboutThirdPartyLicensesSubtitle;

  /// No description provided for @searchOrderLatest.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get searchOrderLatest;

  /// No description provided for @searchOrderTotalRanking.
  ///
  /// In en, this message translates to:
  /// **'Top overall'**
  String get searchOrderTotalRanking;

  /// No description provided for @searchOrderMonthlyRanking.
  ///
  /// In en, this message translates to:
  /// **'Top monthly'**
  String get searchOrderMonthlyRanking;

  /// No description provided for @searchOrderWeeklyRanking.
  ///
  /// In en, this message translates to:
  /// **'Top weekly'**
  String get searchOrderWeeklyRanking;

  /// No description provided for @searchOrderDailyRanking.
  ///
  /// In en, this message translates to:
  /// **'Top daily'**
  String get searchOrderDailyRanking;

  /// No description provided for @searchOrderMostImages.
  ///
  /// In en, this message translates to:
  /// **'Most images'**
  String get searchOrderMostImages;

  /// No description provided for @searchOrderMostLikes.
  ///
  /// In en, this message translates to:
  /// **'Most likes'**
  String get searchOrderMostLikes;

  /// No description provided for @searchTimeout.
  ///
  /// In en, this message translates to:
  /// **'Search timed out. Please try again later.'**
  String get searchTimeout;

  /// No description provided for @searchFailed.
  ///
  /// In en, this message translates to:
  /// **'Search failed: {error}'**
  String searchFailed(Object error);

  /// No description provided for @searchStartPrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter keywords to start searching'**
  String get searchStartPrompt;

  /// No description provided for @searchLoading.
  ///
  /// In en, this message translates to:
  /// **'Searching...'**
  String get searchLoading;

  /// No description provided for @searchEmpty.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get searchEmpty;

  /// No description provided for @searchSortTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get searchSortTooltip;

  /// No description provided for @comicDetailFavoriteAdded.
  ///
  /// In en, this message translates to:
  /// **'Added to favorites'**
  String get comicDetailFavoriteAdded;

  /// No description provided for @comicDetailFavoriteRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed from favorites'**
  String get comicDetailFavoriteRemoved;

  /// No description provided for @comicDetailFavoriteActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Favorite action failed: {error}'**
  String comicDetailFavoriteActionFailed(Object error);

  /// No description provided for @comicDetailManageFavorites.
  ///
  /// In en, this message translates to:
  /// **'Manage favorites'**
  String get comicDetailManageFavorites;

  /// No description provided for @comicDetailCreateFavoriteFolder.
  ///
  /// In en, this message translates to:
  /// **'New favorite folder'**
  String get comicDetailCreateFavoriteFolder;

  /// No description provided for @comicDetailFavoriteFolderNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a folder name'**
  String get comicDetailFavoriteFolderNameHint;

  /// No description provided for @comicDetailFavoriteFolderNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Folder name cannot be empty'**
  String get comicDetailFavoriteFolderNameRequired;

  /// No description provided for @comicDetailCreateFavoriteFolderFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create favorite folder: {error}'**
  String comicDetailCreateFavoriteFolderFailed(Object error);

  /// No description provided for @comicDetailDeleteFavoriteFolder.
  ///
  /// In en, this message translates to:
  /// **'Delete favorite folder'**
  String get comicDetailDeleteFavoriteFolder;

  /// No description provided for @comicDetailDeleteFavoriteFolderContent.
  ///
  /// In en, this message translates to:
  /// **'Delete this folder? Comics in this folder will lose their grouping.'**
  String get comicDetailDeleteFavoriteFolderContent;

  /// No description provided for @comicDetailDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get comicDetailDelete;

  /// No description provided for @comicDetailDeleteFavoriteFolderFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete favorite folder: {error}'**
  String comicDetailDeleteFavoriteFolderFailed(Object error);

  /// No description provided for @comicDetailFavoriteFoldersLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load favorite folders: {error}'**
  String comicDetailFavoriteFoldersLoadFailed(Object error);

  /// No description provided for @comicDetailNoFavoriteFolders.
  ///
  /// In en, this message translates to:
  /// **'No favorite folders yet'**
  String get comicDetailNoFavoriteFolders;

  /// No description provided for @comicDetailDeleteFavoriteFolderTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete folder'**
  String get comicDetailDeleteFavoriteFolderTooltip;

  /// No description provided for @comicDetailCreateFavoriteFolderTooltip.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get comicDetailCreateFavoriteFolderTooltip;

  /// No description provided for @comicDetailSingleFolderHint.
  ///
  /// In en, this message translates to:
  /// **'The current source only supports adding this comic to one favorite folder'**
  String get comicDetailSingleFolderHint;

  /// No description provided for @comicDetailMultipleFoldersHint.
  ///
  /// In en, this message translates to:
  /// **'You can select multiple favorite folders for this comic'**
  String get comicDetailMultipleFoldersHint;

  /// No description provided for @comicDetailSelectAtLeastOneFolder.
  ///
  /// In en, this message translates to:
  /// **'Please select at least one favorite folder'**
  String get comicDetailSelectAtLeastOneFolder;

  /// No description provided for @comicDetailFavoriteSettingsUpdated.
  ///
  /// In en, this message translates to:
  /// **'Favorite settings updated'**
  String get comicDetailFavoriteSettingsUpdated;

  /// No description provided for @comicDetailFavoriteSettingsUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update favorite settings: {error}'**
  String comicDetailFavoriteSettingsUpdateFailed(Object error);

  /// No description provided for @comicDetailNoChapterInfo.
  ///
  /// In en, this message translates to:
  /// **'No chapter information available'**
  String get comicDetailNoChapterInfo;

  /// No description provided for @comicDetailNoChapters.
  ///
  /// In en, this message translates to:
  /// **'This comic has no chapters yet'**
  String get comicDetailNoChapters;

  /// No description provided for @comicDetailAuthor.
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get comicDetailAuthor;

  /// No description provided for @comicDetailTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get comicDetailTags;

  /// No description provided for @comicDetailCopiedId.
  ///
  /// In en, this message translates to:
  /// **'Copied ID'**
  String get comicDetailCopiedId;

  /// No description provided for @comicDetailCopiedPrefix.
  ///
  /// In en, this message translates to:
  /// **'Copied: {value}'**
  String comicDetailCopiedPrefix(Object value);

  /// No description provided for @comicDetailSavedToPath.
  ///
  /// In en, this message translates to:
  /// **'Saved to {path}'**
  String comicDetailSavedToPath(Object path);

  /// No description provided for @comicDetailSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save: {error}'**
  String comicDetailSaveFailed(Object error);

  /// No description provided for @comicDetailLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get comicDetailLoading;

  /// No description provided for @comicDetailSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get comicDetailSummary;

  /// No description provided for @comicDetailNoRelatedComics.
  ///
  /// In en, this message translates to:
  /// **'No related comics yet'**
  String get comicDetailNoRelatedComics;

  /// No description provided for @comicDetailCollapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get comicDetailCollapse;

  /// No description provided for @comicDetailExpand.
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get comicDetailExpand;

  /// No description provided for @comicDetailUpdatedAt.
  ///
  /// In en, this message translates to:
  /// **'Updated at: {time}'**
  String comicDetailUpdatedAt(Object time);

  /// No description provided for @comicDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Comic details'**
  String get comicDetailTitle;

  /// No description provided for @comicDetailTabInfo.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get comicDetailTabInfo;

  /// No description provided for @comicDetailTabComments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get comicDetailTabComments;

  /// No description provided for @comicDetailTabRelated.
  ///
  /// In en, this message translates to:
  /// **'Related'**
  String get comicDetailTabRelated;

  /// No description provided for @comicDetailChapters.
  ///
  /// In en, this message translates to:
  /// **'Chapters'**
  String get comicDetailChapters;

  /// No description provided for @comicDetailChapterCount.
  ///
  /// In en, this message translates to:
  /// **'{count} chapters'**
  String comicDetailChapterCount(Object count);

  /// No description provided for @comicDetailLikesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} likes'**
  String comicDetailLikesCount(Object count);

  /// No description provided for @comicDetailViewsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} views'**
  String comicDetailViewsCount(Object count);

  /// No description provided for @comicDetailFavorite.
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get comicDetailFavorite;

  /// No description provided for @comicDetailUnfavorite.
  ///
  /// In en, this message translates to:
  /// **'Unfavorite'**
  String get comicDetailUnfavorite;

  /// No description provided for @comicDetailRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get comicDetailRead;

  /// No description provided for @comicDetailContinueReading.
  ///
  /// In en, this message translates to:
  /// **'Continue reading {title}'**
  String comicDetailContinueReading(Object title);

  /// No description provided for @comicDetailSaveImage.
  ///
  /// In en, this message translates to:
  /// **'Save image'**
  String get comicDetailSaveImage;

  /// No description provided for @comicDetailRemindLaterToday.
  ///
  /// In en, this message translates to:
  /// **'Don\'t remind again today'**
  String get comicDetailRemindLaterToday;

  /// No description provided for @sourceUpdateAvailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Source update available'**
  String get sourceUpdateAvailableTitle;

  /// No description provided for @sourceUpdateLocalVersion.
  ///
  /// In en, this message translates to:
  /// **'Local source version: {version}'**
  String sourceUpdateLocalVersion(Object version);

  /// No description provided for @sourceUpdateRemoteVersion.
  ///
  /// In en, this message translates to:
  /// **'Cloud source version: {version}'**
  String sourceUpdateRemoteVersion(Object version);

  /// No description provided for @sourceUpdateDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading...'**
  String get sourceUpdateDownloading;

  /// No description provided for @sourceUpdateDownloadingProgress.
  ///
  /// In en, this message translates to:
  /// **'Downloading {progress}%'**
  String sourceUpdateDownloadingProgress(Object progress);

  /// No description provided for @sourceUpdateDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed. Please try again later.'**
  String get sourceUpdateDownloadFailed;

  /// No description provided for @sourceUpdateDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get sourceUpdateDownload;

  /// No description provided for @readingSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reading settings'**
  String get readingSettingsTitle;

  /// No description provided for @readingModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Reading mode'**
  String get readingModeTitle;

  /// No description provided for @readingModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose how pages are arranged in the reader'**
  String get readingModeSubtitle;

  /// No description provided for @readingModeTopToBottom.
  ///
  /// In en, this message translates to:
  /// **'Top to bottom'**
  String get readingModeTopToBottom;

  /// No description provided for @readingModeRightToLeft.
  ///
  /// In en, this message translates to:
  /// **'Right to left'**
  String get readingModeRightToLeft;

  /// No description provided for @readingTapToTurnPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Tap to turn page'**
  String get readingTapToTurnPageTitle;

  /// No description provided for @readingTapToTurnPageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Only works in right-to-left mode. Tap the left side for the previous page and the right side for the next page'**
  String get readingTapToTurnPageSubtitle;

  /// No description provided for @readingImmersiveModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Immersive mode'**
  String get readingImmersiveModeTitle;

  /// No description provided for @readingImmersiveModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hide the status bar and bottom navigation bar automatically when entering the reader'**
  String get readingImmersiveModeSubtitle;

  /// No description provided for @readingKeepScreenOnTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep screen on'**
  String get readingKeepScreenOnTitle;

  /// No description provided for @readingKeepScreenOnSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep the screen awake while reading to prevent auto lock'**
  String get readingKeepScreenOnSubtitle;

  /// No description provided for @readingCustomBrightnessTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom brightness'**
  String get readingCustomBrightnessTitle;

  /// No description provided for @readingCustomBrightnessSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Override the system brightness inside the reader when enabled'**
  String get readingCustomBrightnessSubtitle;

  /// No description provided for @readingBrightnessLabel.
  ///
  /// In en, this message translates to:
  /// **'Brightness {value}'**
  String readingBrightnessLabel(Object value);
 
  /// No description provided for @readingPageIndicatorTitle.
  ///
  /// In en, this message translates to:
  /// **'Page indicator'**
  String get readingPageIndicatorTitle;
 
  /// No description provided for @readingPageIndicatorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show the chapter number and current page/total pages in the lower-left corner of the reader'**
  String get readingPageIndicatorSubtitle;
 
  /// No description provided for @readingPinchToZoomTitle.
  ///
  /// In en, this message translates to:
  /// **'Pinch to zoom'**
  String get readingPinchToZoomTitle;

  /// No description provided for @readingPinchToZoomSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Allow two-finger pinch gestures to zoom comic images'**
  String get readingPinchToZoomSubtitle;

  /// No description provided for @readingLongPressSaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Long press to save images'**
  String get readingLongPressSaveTitle;

  /// No description provided for @readingLongPressSaveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Allow saving the current comic image by long pressing it'**
  String get readingLongPressSaveSubtitle;

  /// No description provided for @downloadsTitle.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloadsTitle;

  /// No description provided for @downloadsTabOngoing.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get downloadsTabOngoing;

  /// No description provided for @downloadsTabDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get downloadsTabDownloaded;

  /// No description provided for @downloadsEmptyOngoing.
  ///
  /// In en, this message translates to:
  /// **'No active downloads'**
  String get downloadsEmptyOngoing;

  /// No description provided for @downloadsEmptyDownloaded.
  ///
  /// In en, this message translates to:
  /// **'No downloaded comics yet'**
  String get downloadsEmptyDownloaded;

  /// No description provided for @downloadsSelectionTitle.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String downloadsSelectionTitle(Object count);

  /// No description provided for @downloadsDeleteSelectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete downloaded comics'**
  String get downloadsDeleteSelectedTitle;

  /// No description provided for @downloadsDeleteSelectedContent.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} selected downloaded comics?'**
  String downloadsDeleteSelectedContent(Object count);

  /// No description provided for @downloadsStatusQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get downloadsStatusQueued;

  /// No description provided for @downloadsStatusDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get downloadsStatusDownloading;

  /// No description provided for @downloadsStatusPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get downloadsStatusPaused;

  /// No description provided for @downloadsStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed: {error}'**
  String downloadsStatusFailed(Object error);

  /// No description provided for @downloadsChapterCount.
  ///
  /// In en, this message translates to:
  /// **'{count} chapters'**
  String downloadsChapterCount(Object count);

  /// No description provided for @downloadsCurrentProgress.
  ///
  /// In en, this message translates to:
  /// **'{current}/{total} images'**
  String downloadsCurrentProgress(Object current, Object total);

  /// No description provided for @downloadsActionSelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get downloadsActionSelect;

  /// No description provided for @downloadsActionPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get downloadsActionPause;

  /// No description provided for @downloadsActionResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get downloadsActionResume;

  /// No description provided for @downloadsQueued.
  ///
  /// In en, this message translates to:
  /// **'{count} chapters added to downloads'**
  String downloadsQueued(Object count);

  /// No description provided for @downloadsDownloadChaptersTitle.
  ///
  /// In en, this message translates to:
  /// **'Download chapters'**
  String get downloadsDownloadChaptersTitle;

  /// No description provided for @downloadsDownloadChaptersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select the chapters you want to download'**
  String get downloadsDownloadChaptersSubtitle;

  /// No description provided for @downloadsDownloadAction.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get downloadsDownloadAction;

  /// No description provided for @privacySettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy settings'**
  String get privacySettingsTitle;

  /// No description provided for @privacyBlurTaskTitle.
  ///
  /// In en, this message translates to:
  /// **'Blur app in recent tasks'**
  String get privacyBlurTaskTitle;

  /// No description provided for @privacyBlurTaskSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show a pure black task card when switching to recent apps'**
  String get privacyBlurTaskSubtitle;

  /// No description provided for @privacyBiometricUnlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Biometric unlock'**
  String get privacyBiometricUnlockTitle;

  /// No description provided for @privacyBiometricUnlockSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Require fingerprint verification each time the app is opened'**
  String get privacyBiometricUnlockSubtitle;

  /// No description provided for @privacyAuthOnResumeTitle.
  ///
  /// In en, this message translates to:
  /// **'Require verification after leaving app'**
  String get privacyAuthOnResumeTitle;

  /// No description provided for @privacyAuthOnResumeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Require authentication again whenever the app returns to foreground'**
  String get privacyAuthOnResumeSubtitle;

  /// No description provided for @lineSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Lines'**
  String get lineSettingsTitle;

  /// No description provided for @lineLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load line information: {error}'**
  String lineLoadFailed(Object error);

  /// No description provided for @lineOptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Line {value}'**
  String lineOptionLabel(Object value);

  /// No description provided for @lineOptionWithHostLabel.
  ///
  /// In en, this message translates to:
  /// **'Line {value} ({host})'**
  String lineOptionWithHostLabel(Object value, Object host);

  /// No description provided for @lineImageStreamLabel.
  ///
  /// In en, this message translates to:
  /// **'Stream {value}'**
  String lineImageStreamLabel(Object value);

  /// No description provided for @lineApiSwitched.
  ///
  /// In en, this message translates to:
  /// **'API domain stream switched to line {value}'**
  String lineApiSwitched(Object value);

  /// No description provided for @lineImageSwitched.
  ///
  /// In en, this message translates to:
  /// **'Image domain stream switched to stream {value}'**
  String lineImageSwitched(Object value);

  /// No description provided for @lineSwitchFailed.
  ///
  /// In en, this message translates to:
  /// **'Switch failed: {error}'**
  String lineSwitchFailed(Object error);

  /// No description provided for @lineRefreshOnStartUpdated.
  ///
  /// In en, this message translates to:
  /// **'Startup auto-refresh setting updated'**
  String get lineRefreshOnStartUpdated;

  /// No description provided for @lineSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String lineSaveFailed(Object error);

  /// No description provided for @lineIntro.
  ///
  /// In en, this message translates to:
  /// **'You can switch API and image streams separately, and changes will apply automatically to subsequent requests.'**
  String get lineIntro;

  /// No description provided for @lineApiTitle.
  ///
  /// In en, this message translates to:
  /// **'API domain stream'**
  String get lineApiTitle;

  /// No description provided for @lineApiSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Used for API requests. Switch it if the network is unstable.'**
  String get lineApiSubtitle;

  /// No description provided for @lineSelectApiLabel.
  ///
  /// In en, this message translates to:
  /// **'Select API line'**
  String get lineSelectApiLabel;

  /// No description provided for @lineImageTitle.
  ///
  /// In en, this message translates to:
  /// **'Image domain stream'**
  String get lineImageTitle;

  /// No description provided for @lineImageHostUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Current image domain is unavailable'**
  String get lineImageHostUnavailable;

  /// No description provided for @lineImageHostCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current domain: {host}'**
  String lineImageHostCurrent(Object host);

  /// No description provided for @lineSelectImageLabel.
  ///
  /// In en, this message translates to:
  /// **'Select image stream'**
  String get lineSelectImageLabel;

  /// No description provided for @lineRefreshOnStartTitle.
  ///
  /// In en, this message translates to:
  /// **'Refresh domain list on startup'**
  String get lineRefreshOnStartTitle;

  /// No description provided for @lineRefreshOnStartSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Automatically update the API domain pool each time the app opens'**
  String get lineRefreshOnStartSubtitle;

  /// No description provided for @lineRefreshStatusButton.
  ///
  /// In en, this message translates to:
  /// **'Refresh line status'**
  String get lineRefreshStatusButton;

  /// No description provided for @displayModeAndroidOnly.
  ///
  /// In en, this message translates to:
  /// **'Only Android supports refresh rate settings'**
  String get displayModeAndroidOnly;

  /// No description provided for @displayModeReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to read display modes: {error}'**
  String displayModeReadFailed(Object error);

  /// No description provided for @displayModeSystemRejected.
  ///
  /// In en, this message translates to:
  /// **'The system rejected this display mode'**
  String get displayModeSystemRejected;

  /// No description provided for @displayModeApplied.
  ///
  /// In en, this message translates to:
  /// **'Refresh rate applied. Restart the app if it does not take effect.'**
  String get displayModeApplied;

  /// No description provided for @displayModeSetFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to apply setting: {error}'**
  String displayModeSetFailed(Object error);

  /// No description provided for @displayModeUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get displayModeUnknown;

  /// No description provided for @displayModeUnknownMode.
  ///
  /// In en, this message translates to:
  /// **'Unknown mode'**
  String get displayModeUnknownMode;

  /// No description provided for @displayModeCurrentLabel.
  ///
  /// In en, this message translates to:
  /// **'Current system mode: {mode}'**
  String displayModeCurrentLabel(Object mode);

  /// No description provided for @displayModeCurrentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Current system mode'**
  String get displayModeCurrentSubtitle;

  /// No description provided for @displayModeSelectedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get displayModeSelectedSubtitle;

  /// No description provided for @displayModeHint.
  ///
  /// In en, this message translates to:
  /// **'Note: some devices may be affected by system power saving or app whitelist policies.'**
  String get displayModeHint;

  /// No description provided for @cachePresetDefault.
  ///
  /// In en, this message translates to:
  /// **'Default 400MB'**
  String get cachePresetDefault;

  /// No description provided for @cachePresetLite.
  ///
  /// In en, this message translates to:
  /// **'Light 600MB'**
  String get cachePresetLite;

  /// No description provided for @cachePresetBalanced.
  ///
  /// In en, this message translates to:
  /// **'Balanced 1024MB'**
  String get cachePresetBalanced;

  /// No description provided for @cachePresetHeavy.
  ///
  /// In en, this message translates to:
  /// **'Heavy 2048MB'**
  String get cachePresetHeavy;

  /// No description provided for @cacheMaxSizeTitle.
  ///
  /// In en, this message translates to:
  /// **'Set maximum cache size'**
  String get cacheMaxSizeTitle;

  /// No description provided for @cacheMaxSizeHint.
  ///
  /// In en, this message translates to:
  /// **'Minimum 400MB. Choose a preset or enter a custom value.'**
  String get cacheMaxSizeHint;

  /// No description provided for @cacheCustomMbLabel.
  ///
  /// In en, this message translates to:
  /// **'Custom (MB)'**
  String get cacheCustomMbLabel;

  /// No description provided for @cacheCustomMbHint.
  ///
  /// In en, this message translates to:
  /// **'For example, 1024'**
  String get cacheCustomMbHint;

  /// No description provided for @cacheLimitUpdated.
  ///
  /// In en, this message translates to:
  /// **'Cache limit set to {value}MB'**
  String cacheLimitUpdated(Object value);

  /// No description provided for @cacheAutoCleanTitle.
  ///
  /// In en, this message translates to:
  /// **'Cache auto-clean'**
  String get cacheAutoCleanTitle;

  /// No description provided for @cacheAutoCleanOverflowTitle.
  ///
  /// In en, this message translates to:
  /// **'Clean automatically when limit is exceeded'**
  String get cacheAutoCleanOverflowTitle;

  /// No description provided for @cacheAutoCleanOverflowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Delete the oldest cache first until usage drops below the limit'**
  String get cacheAutoCleanOverflowSubtitle;

  /// No description provided for @cacheAutoCleanSevenDaysTitle.
  ///
  /// In en, this message translates to:
  /// **'Clean every seven days'**
  String get cacheAutoCleanSevenDaysTitle;

  /// No description provided for @cacheAutoCleanSevenDaysSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Delete cache files older than 7 days'**
  String get cacheAutoCleanSevenDaysSubtitle;

  /// No description provided for @cacheAutoCleanSevenDaysApplied.
  ///
  /// In en, this message translates to:
  /// **'Set to clean every seven days'**
  String get cacheAutoCleanSevenDaysApplied;

  /// No description provided for @cacheAutoCleanOverflowApplied.
  ///
  /// In en, this message translates to:
  /// **'Set to clean automatically when limit is exceeded'**
  String get cacheAutoCleanOverflowApplied;

  /// No description provided for @cacheClearBarrierLabel.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get cacheClearBarrierLabel;

  /// No description provided for @cacheClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear cache'**
  String get cacheClearTitle;

  /// No description provided for @cacheClearContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to clear all image cache? This action cannot be undone.'**
  String get cacheClearContent;

  /// No description provided for @cacheClearConfirm.
  ///
  /// In en, this message translates to:
  /// **'Clear now'**
  String get cacheClearConfirm;

  /// No description provided for @cacheCleared.
  ///
  /// In en, this message translates to:
  /// **'Cache cleared successfully'**
  String get cacheCleared;

  /// No description provided for @cacheClearFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to clear cache: {error}'**
  String cacheClearFailed(Object error);

  /// No description provided for @cacheSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Cache settings'**
  String get cacheSettingsTitle;

  /// No description provided for @cacheSizeTitle.
  ///
  /// In en, this message translates to:
  /// **'Cache size'**
  String get cacheSizeTitle;

  /// No description provided for @cacheSizeSummary.
  ///
  /// In en, this message translates to:
  /// **'Current {used} / Limit {max}'**
  String cacheSizeSummary(Object used, Object max);

  /// No description provided for @cacheAutoCleanModeSummary.
  ///
  /// In en, this message translates to:
  /// **'Clean every seven days'**
  String get cacheAutoCleanModeSummary;

  /// No description provided for @cacheAutoCleanModeOverflowSummary.
  ///
  /// In en, this message translates to:
  /// **'Clean automatically when limit is exceeded'**
  String get cacheAutoCleanModeOverflowSummary;

  /// No description provided for @cacheClearNowTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear cache now'**
  String get cacheClearNowTitle;

  /// No description provided for @cacheClearNowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Remove all locally downloaded image cache to free up storage space'**
  String get cacheClearNowSubtitle;

  /// No description provided for @cloudSyncIncompleteConfig.
  ///
  /// In en, this message translates to:
  /// **'Please fill in the complete URL, Username, and Password'**
  String get cloudSyncIncompleteConfig;

  /// No description provided for @cloudSyncInvalidUrl.
  ///
  /// In en, this message translates to:
  /// **'Invalid URL format. Please include http/https'**
  String get cloudSyncInvalidUrl;

  /// No description provided for @cloudSyncStatusIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Configuration incomplete'**
  String get cloudSyncStatusIncomplete;

  /// No description provided for @cloudSyncStatusDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get cloudSyncStatusDisabled;

  /// No description provided for @cloudSyncConfigSaved.
  ///
  /// In en, this message translates to:
  /// **'Cloud sync configuration saved'**
  String get cloudSyncConfigSaved;

  /// No description provided for @cloudSyncSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String cloudSyncSaveFailed(Object error);

  /// No description provided for @cloudSyncNeedCompleteConfig.
  ///
  /// In en, this message translates to:
  /// **'Please enable cloud sync and save a complete configuration first'**
  String get cloudSyncNeedCompleteConfig;

  /// No description provided for @cloudSyncUploadCompleted.
  ///
  /// In en, this message translates to:
  /// **'Backup upload completed'**
  String get cloudSyncUploadCompleted;

  /// No description provided for @cloudSyncUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed: {error}'**
  String cloudSyncUploadFailed(Object error);

  /// No description provided for @cloudSyncRestoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore backup'**
  String get cloudSyncRestoreTitle;

  /// No description provided for @cloudSyncRestoreContent.
  ///
  /// In en, this message translates to:
  /// **'Overwrite local files and restore the latest cloud backup?'**
  String get cloudSyncRestoreContent;

  /// No description provided for @cloudSyncRestoreConfirm.
  ///
  /// In en, this message translates to:
  /// **'Overwrite and restore'**
  String get cloudSyncRestoreConfirm;

  /// No description provided for @cloudSyncRestoreCompleted.
  ///
  /// In en, this message translates to:
  /// **'Backup restored and local data overwritten'**
  String get cloudSyncRestoreCompleted;

  /// No description provided for @cloudSyncRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Restore failed: {error}'**
  String cloudSyncRestoreFailed(Object error);

  /// No description provided for @cloudSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'Cloud sync'**
  String get cloudSyncTitle;

  /// No description provided for @cloudSyncStatusUnchecked.
  ///
  /// In en, this message translates to:
  /// **'Unchecked'**
  String get cloudSyncStatusUnchecked;

  /// No description provided for @cloudSyncStatusConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get cloudSyncStatusConnected;

  /// No description provided for @cloudSyncStatusDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get cloudSyncStatusDisconnected;

  /// No description provided for @cloudSyncEnabledTitle.
  ///
  /// In en, this message translates to:
  /// **'Cloud sync'**
  String get cloudSyncEnabledTitle;

  /// No description provided for @cloudSyncEnabledSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enable uploading and restoring cloud backups'**
  String get cloudSyncEnabledSubtitle;

  /// No description provided for @cloudSyncUrlHelper.
  ///
  /// In en, this message translates to:
  /// **'The app will append /HazukiSync automatically, so you do not need to enter it manually'**
  String get cloudSyncUrlHelper;

  /// No description provided for @cloudSyncUsernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get cloudSyncUsernameLabel;

  /// No description provided for @cloudSyncPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get cloudSyncPasswordLabel;

  /// No description provided for @cloudSyncSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get cloudSyncSave;

  /// No description provided for @cloudSyncUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload backup'**
  String get cloudSyncUpload;

  /// No description provided for @cloudSyncRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore backup'**
  String get cloudSyncRestore;

  /// No description provided for @favoritesDebugCopied.
  ///
  /// In en, this message translates to:
  /// **'Network logs copied'**
  String get favoritesDebugCopied;

  /// No description provided for @favoritesDebugFilterReason.
  ///
  /// In en, this message translates to:
  /// **'Show only important logs (error logs, HTTP>=400, login-related entries, and entries containing critical error keywords)'**
  String get favoritesDebugFilterReason;

  /// No description provided for @favoritesDebugFilterImportantTooltip.
  ///
  /// In en, this message translates to:
  /// **'Filter important logs'**
  String get favoritesDebugFilterImportantTooltip;

  /// No description provided for @favoritesDebugCopyTooltip.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get favoritesDebugCopyTooltip;

  /// No description provided for @favoritesDebugRefreshTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh network logs'**
  String get favoritesDebugRefreshTooltip;

  /// No description provided for @favoritesDebugLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load network logs: {error}'**
  String favoritesDebugLoadFailed(Object error);

  /// No description provided for @favoritesDebugFullFetchButton.
  ///
  /// In en, this message translates to:
  /// **'Run full network fetch manually (slow)'**
  String get favoritesDebugFullFetchButton;

  /// No description provided for @logsNetworkTitle.
  ///
  /// In en, this message translates to:
  /// **'Network logs'**
  String get logsNetworkTitle;

  /// No description provided for @logsApplicationTitle.
  ///
  /// In en, this message translates to:
  /// **'Application logs'**
  String get logsApplicationTitle;

  /// No description provided for @logsApplicationCopied.
  ///
  /// In en, this message translates to:
  /// **'Application logs copied'**
  String get logsApplicationCopied;

  /// No description provided for @logsApplicationRefreshTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh application logs'**
  String get logsApplicationRefreshTooltip;

  /// No description provided for @logsApplicationLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load application logs: {error}'**
  String logsApplicationLoadFailed(Object error);

  /// No description provided for @logsApplicationEmpty.
  ///
  /// In en, this message translates to:
  /// **'No application logs yet'**
  String get logsApplicationEmpty;

  /// No description provided for @logsApplicationExportTooltip.
  ///
  /// In en, this message translates to:
  /// **'Export logs'**
  String get logsApplicationExportTooltip;

  /// No description provided for @logsApplicationExportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Log file exported'**
  String get logsApplicationExportSuccess;

  /// No description provided for @logsApplicationExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to export log file: {error}'**
  String logsApplicationExportFailed(Object error);

  /// No description provided for @tagCategoryLoadTimeout.
  ///
  /// In en, this message translates to:
  /// **'Tag categories timed out while loading. Please try again later.'**
  String get tagCategoryLoadTimeout;

  /// No description provided for @tagCategoryLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load tag categories: {error}'**
  String tagCategoryLoadFailed(Object error);

  /// No description provided for @tagCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Tag categories'**
  String get tagCategoryTitle;

  /// No description provided for @tagCategoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No tag categories are available for the current source'**
  String get tagCategoryEmpty;

  /// No description provided for @rankingLoadOptionsTimeout.
  ///
  /// In en, this message translates to:
  /// **'Ranking categories timed out while loading. Please try again later.'**
  String get rankingLoadOptionsTimeout;

  /// No description provided for @rankingLoadTimeout.
  ///
  /// In en, this message translates to:
  /// **'Rankings timed out while loading. Please try again later.'**
  String get rankingLoadTimeout;

  /// No description provided for @rankingLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load rankings: {error}'**
  String rankingLoadFailed(Object error);

  /// No description provided for @rankingTitle.
  ///
  /// In en, this message translates to:
  /// **'Rankings'**
  String get rankingTitle;

  /// No description provided for @rankingEmptyOptions.
  ///
  /// In en, this message translates to:
  /// **'No ranking categories are available for the current source'**
  String get rankingEmptyOptions;

  /// No description provided for @rankingEmptyComics.
  ///
  /// In en, this message translates to:
  /// **'No ranking content available'**
  String get rankingEmptyComics;

  /// No description provided for @rankingReachedEnd.
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached the end'**
  String get rankingReachedEnd;

  /// No description provided for @favoriteAllFolder.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get favoriteAllFolder;

  /// No description provided for @favoriteLoadTimeout.
  ///
  /// In en, this message translates to:
  /// **'Favorites timed out while loading. Pull down to retry.'**
  String get favoriteLoadTimeout;

  /// No description provided for @favoriteFoldersLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load favorite folders: {error}'**
  String favoriteFoldersLoadFailed(Object error);

  /// No description provided for @favoriteCreated.
  ///
  /// In en, this message translates to:
  /// **'Favorite folder \"{name}\" created successfully'**
  String favoriteCreated(Object name);

  /// No description provided for @favoriteCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create favorite folder: {error}'**
  String favoriteCreateFailed(Object error);

  /// No description provided for @favoriteSortChangeFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to change sort order: {error}'**
  String favoriteSortChangeFailed(Object error);

  /// No description provided for @favoriteDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete favorite folder: {error}'**
  String favoriteDeleteFailed(Object error);

  /// No description provided for @favoriteFolderHeader.
  ///
  /// In en, this message translates to:
  /// **'Favorite folders'**
  String get favoriteFolderHeader;

  /// No description provided for @favoriteDeleteCurrentFolderTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete current favorite folder'**
  String get favoriteDeleteCurrentFolderTooltip;

  /// No description provided for @favoriteLoginRequired.
  ///
  /// In en, this message translates to:
  /// **'Please sign in'**
  String get favoriteLoginRequired;

  /// No description provided for @favoriteEmpty.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet'**
  String get favoriteEmpty;

  /// No description provided for @favoriteCreateFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'New favorite folder'**
  String get favoriteCreateFolderTitle;

  /// No description provided for @favoriteCreateFolderHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a folder name'**
  String get favoriteCreateFolderHint;

  /// No description provided for @favoriteCreateFolderNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Folder name cannot be empty'**
  String get favoriteCreateFolderNameRequired;

  /// No description provided for @favoriteDeleteFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete favorite folder'**
  String get favoriteDeleteFolderTitle;

  /// No description provided for @favoriteDeleteFolderContent.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String favoriteDeleteFolderContent(Object name);

  /// No description provided for @discoverSectionLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Load failed: {error}'**
  String discoverSectionLoadFailed(Object error);

  /// No description provided for @discoverSectionEmpty.
  ///
  /// In en, this message translates to:
  /// **'No comics available'**
  String get discoverSectionEmpty;

  /// No description provided for @commentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get commentsTitle;

  /// No description provided for @commentsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load comments: {error}'**
  String commentsLoadFailed(Object error);

  /// No description provided for @commentsLoginRequiredToSend.
  ///
  /// In en, this message translates to:
  /// **'Please sign in before commenting'**
  String get commentsLoginRequiredToSend;

  /// No description provided for @commentsSourceNotSupported.
  ///
  /// In en, this message translates to:
  /// **'The current source does not support sending comments'**
  String get commentsSourceNotSupported;

  /// No description provided for @commentsSendSuccess.
  ///
  /// In en, this message translates to:
  /// **'Comment sent successfully'**
  String get commentsSendSuccess;

  /// No description provided for @commentsSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send: {error}'**
  String commentsSendFailed(Object error);

  /// No description provided for @commentsAnonymousUser.
  ///
  /// In en, this message translates to:
  /// **'Anonymous user'**
  String get commentsAnonymousUser;

  /// No description provided for @commentsReplyCount.
  ///
  /// In en, this message translates to:
  /// **'Replies {count}'**
  String commentsReplyCount(Object count);

  /// No description provided for @commentsReplyTooltip.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get commentsReplyTooltip;

  /// No description provided for @commentsReplyToUser.
  ///
  /// In en, this message translates to:
  /// **'Reply to @{name}'**
  String commentsReplyToUser(Object name);

  /// No description provided for @commentsCancelReplyTooltip.
  ///
  /// In en, this message translates to:
  /// **'Cancel reply'**
  String get commentsCancelReplyTooltip;

  /// No description provided for @commentsComposerHint.
  ///
  /// In en, this message translates to:
  /// **'Write your comment…'**
  String get commentsComposerHint;

  /// No description provided for @commentsReplyComposerHint.
  ///
  /// In en, this message translates to:
  /// **'Reply to {name}…'**
  String commentsReplyComposerHint(Object name);

  /// No description provided for @commentsSending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get commentsSending;

  /// No description provided for @commentsSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get commentsSend;

  /// No description provided for @commentsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No comments yet'**
  String get commentsEmpty;

  /// No description provided for @readerSaveImageTitle.
  ///
  /// In en, this message translates to:
  /// **'Save image'**
  String get readerSaveImageTitle;

  /// No description provided for @readerSaveImageContent.
  ///
  /// In en, this message translates to:
  /// **'Save this comic image locally?'**
  String get readerSaveImageContent;

  /// No description provided for @readerChapterLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load chapter: {error}'**
  String readerChapterLoadFailed(Object error);

  /// No description provided for @readerCurrentChapterNoImages.
  ///
  /// In en, this message translates to:
  /// **'No images in the current chapter'**
  String get readerCurrentChapterNoImages;
 
  /// No description provided for @readerPageIndicator.
  ///
  /// In en, this message translates to:
  /// **'Chapter {chapter} {current}/{total}'**
  String readerPageIndicator(Object chapter, Object current, Object total);
 
  /// No description provided for @readerResetZoom.
  ///
  /// In en, this message translates to:
  /// **'Reset zoom'**
  String get readerResetZoom;

  /// No description provided for @advancedTitle.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advancedTitle;

  /// No description provided for @advancedDebugTitle.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get advancedDebugTitle;

  /// No description provided for @advancedDebugSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Network logs and application logs'**
  String get advancedDebugSubtitle;

  /// No description provided for @advancedComicIdSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Comic ID search optimization'**
  String get advancedComicIdSearchTitle;

  /// No description provided for @advancedComicIdSearchSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Automatically remove non-digit characters on search submission and keep only Arabic numerals as the keyword'**
  String get advancedComicIdSearchSubtitle;

  /// No description provided for @advancedNoImageModeTitle.
  ///
  /// In en, this message translates to:
  /// **'No-image mode'**
  String get advancedNoImageModeTitle;

  /// No description provided for @advancedNoImageModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hide images globally (except the login avatar in the sidebar)'**
  String get advancedNoImageModeSubtitle;

  /// No description provided for @settingsOtherTitle.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get settingsOtherTitle;

  /// No description provided for @settingsOtherSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Check-in and extra actions'**
  String get settingsOtherSubtitle;

  /// No description provided for @homeCheckInAction.
  ///
  /// In en, this message translates to:
  /// **'Check in'**
  String get homeCheckInAction;

  /// No description provided for @homeCheckInDone.
  ///
  /// In en, this message translates to:
  /// **'Checked in today'**
  String get homeCheckInDone;

  /// No description provided for @homeCheckInInProgress.
  ///
  /// In en, this message translates to:
  /// **'Checking in...'**
  String get homeCheckInInProgress;

  /// No description provided for @homeCheckInSuccess.
  ///
  /// In en, this message translates to:
  /// **'Check-in successful'**
  String get homeCheckInSuccess;

  /// No description provided for @homeCheckInAlreadyDone.
  ///
  /// In en, this message translates to:
  /// **'Already checked in today'**
  String get homeCheckInAlreadyDone;

  /// No description provided for @homeCheckInFailed.
  ///
  /// In en, this message translates to:
  /// **'Check-in failed: {error}'**
  String homeCheckInFailed(Object error);

  /// No description provided for @otherTitle.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get otherTitle;

  /// No description provided for @otherAutoCheckInTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto daily check-in'**
  String get otherAutoCheckInTitle;

  /// No description provided for @otherAutoCheckInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Automatically check in once when the app is opened each day'**
  String get otherAutoCheckInSubtitle;

  /// No description provided for @sourceBootstrapDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading comic source'**
  String get sourceBootstrapDownloading;

  /// No description provided for @sourceBootstrapPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing source files...'**
  String get sourceBootstrapPreparing;

  /// No description provided for @sourceBootstrapProgress.
  ///
  /// In en, this message translates to:
  /// **'Downloaded {progress}%'**
  String sourceBootstrapProgress(Object progress);
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'zh': return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
