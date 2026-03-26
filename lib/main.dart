import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:io';
import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models/hazuki_models.dart';
import 'services/cloud_sync_service.dart';
import 'services/hazuki_source_service.dart';
import 'services/manga_download_service.dart';

part 'pages/home_page.dart';
part 'pages/discover/discover_page.dart';
part 'pages/discover/discover_section_page.dart';
part 'pages/favorite_page.dart';
part 'pages/settings/settings_page.dart';
part 'pages/settings/appearance_settings_page.dart';
part 'pages/settings/display_mode_settings_page.dart';
part 'pages/settings/cache_settings_page.dart';
part 'pages/settings/privacy_settings_page.dart';
part 'pages/settings/reading_settings_page.dart';
part 'pages/settings/favorites_debug_page.dart';
part 'pages/settings/other_settings_page.dart';
part 'pages/settings/advanced_settings_page.dart';
part 'pages/settings/source_editor_page.dart';
part 'pages/settings/line_settings_page.dart';
part 'pages/settings/cloud_sync_page.dart';
part 'pages/comic_detail_page.dart';
part 'pages/comic_detail/comic_detail_panels.dart';
part 'pages/comic_detail/comic_detail_cover.dart';
part 'pages/comic_detail/comic_detail_meta.dart';
part 'pages/comic_detail/comic_detail_sections.dart';
part 'pages/comic_detail/comic_detail_header.dart';
part 'pages/comic_detail/comic_detail_scaffold.dart';
part 'pages/reader_page.dart';
part 'pages/comments_page.dart';
part 'pages/search/search_page.dart';
part 'pages/search/search_results_page.dart';
part 'pages/history_page.dart';
part 'pages/tag_category_page.dart';
part 'pages/ranking_page.dart';
part 'pages/downloads_page.dart';
part 'pages/about_page.dart';
part 'widgets/cached_image_widgets.dart';
part 'widgets/hazuki_prompt.dart';
part 'widgets/sticker_loading_indicator.dart';

const MethodChannel _displayModeChannel = MethodChannel(
  'hazuki.comics/display_mode',
);
const MethodChannel _readerDisplayChannel = MethodChannel(
  'hazuki.comics/reader_display',
);
const _discoverSearchHeroTag = 'discover_search_to_search_page';
const _noImageModeKey = 'advanced_no_image_mode';
const _autoCheckInEnabledKey = 'other_auto_check_in_enabled';
const _defaultAppearancePresetIndex = 0;
const _defaultDynamicColorEnabled = false;
final ValueNotifier<bool> hazukiNoImageModeNotifier = ValueNotifier<bool>(
  false,
);

Future<void> _loadGlobalUiFlags() async {
  final prefs = await SharedPreferences.getInstance();
  hazukiNoImageModeNotifier.value = prefs.getBool(_noImageModeKey) ?? false;
}

Future<void> _ensureAndroidNoMediaMarker() async {
  if (!Platform.isAndroid) {
    return;
  }

  await _ensureNoMediaFile('/storage/emulated/0/Download/Hazuki_Manga');
}

Future<void> _ensureNoMediaFile(String dirPath) async {
  if (dirPath.trim().isEmpty) {
    return;
  }
  try {
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final noMediaFile = File('${dir.path}/.nomedia');
    if (!await noMediaFile.exists()) {
      await noMediaFile.writeAsString('', flush: true);
    }
  } catch (_) {}
}

Future<void> setHazukiNoImageMode(bool enabled) async {
  hazukiNoImageModeNotifier.value = enabled;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_noImageModeKey, enabled);
}

AppLocalizations l10n(BuildContext context) => AppLocalizations.of(context)!;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _loadGlobalUiFlags();
  await HazukiSourceService.instance.loadSoftwareLogCaptureEnabled();
  await _ensureAndroidNoMediaMarker();
  await MangaDownloadService.instance.ensureInitialized();
  runApp(const HazukiApp());
}

class AppearanceSettingsData {
  const AppearanceSettingsData({
    required this.themeMode,
    required this.oledPureBlack,
    required this.dynamicColor,
    required this.presetIndex,
    required this.displayModeRaw,
    required this.comicDetailDynamicColor,
  });

  final ThemeMode themeMode;
  final bool oledPureBlack;
  final bool dynamicColor;
  final int presetIndex;
  final String displayModeRaw;
  final bool comicDetailDynamicColor;

  AppearanceSettingsData copyWith({
    ThemeMode? themeMode,
    bool? oledPureBlack,
    bool? dynamicColor,
    int? presetIndex,
    String? displayModeRaw,
    bool? comicDetailDynamicColor,
  }) {
    return AppearanceSettingsData(
      themeMode: themeMode ?? this.themeMode,
      oledPureBlack: oledPureBlack ?? this.oledPureBlack,
      dynamicColor: dynamicColor ?? this.dynamicColor,
      presetIndex: presetIndex ?? this.presetIndex,
      displayModeRaw: displayModeRaw ?? this.displayModeRaw,
      comicDetailDynamicColor:
          comicDetailDynamicColor ?? this.comicDetailDynamicColor,
    );
  }
}

class HazukiColorPreset {
  const HazukiColorPreset({
    required this.labelBuilder,
    required this.seedColor,
  });

  final String Function(AppLocalizations strings) labelBuilder;
  final Color seedColor;
}

const List<HazukiColorPreset> kHazukiColorPresets = [
  HazukiColorPreset(
    labelBuilder: _displayPresetMintGreen,
    seedColor: Color(0xFF009688),
  ),
  HazukiColorPreset(
    labelBuilder: _displayPresetSeaSaltBlue,
    seedColor: Color(0xFF0288D1),
  ),
  HazukiColorPreset(
    labelBuilder: _displayPresetTwilightPurple,
    seedColor: Color(0xFF7E57C2),
  ),
  HazukiColorPreset(
    labelBuilder: _displayPresetCherryBlossomPink,
    seedColor: Color(0xFFEC407A),
  ),
  HazukiColorPreset(
    labelBuilder: _displayPresetCoralOrange,
    seedColor: Color(0xFFFF7043),
  ),
  HazukiColorPreset(
    labelBuilder: _displayPresetAmberYellow,
    seedColor: Color(0xFFFFB300),
  ),
  HazukiColorPreset(
    labelBuilder: _displayPresetLimeGreen,
    seedColor: Color(0xFF7CB342),
  ),
  HazukiColorPreset(
    labelBuilder: _displayPresetGraphiteGray,
    seedColor: Color(0xFF546E7A),
  ),
  HazukiColorPreset(
    labelBuilder: _displayPresetBerryRed,
    seedColor: Color(0xFFC62828),
  ),
];

String _displayPresetMintGreen(AppLocalizations strings) =>
    strings.displayPresetMintGreen;
String _displayPresetSeaSaltBlue(AppLocalizations strings) =>
    strings.displayPresetSeaSaltBlue;
String _displayPresetTwilightPurple(AppLocalizations strings) =>
    strings.displayPresetTwilightPurple;
String _displayPresetCherryBlossomPink(AppLocalizations strings) =>
    strings.displayPresetCherryBlossomPink;
String _displayPresetCoralOrange(AppLocalizations strings) =>
    strings.displayPresetCoralOrange;
String _displayPresetAmberYellow(AppLocalizations strings) =>
    strings.displayPresetAmberYellow;
String _displayPresetLimeGreen(AppLocalizations strings) =>
    strings.displayPresetLimeGreen;
String _displayPresetGraphiteGray(AppLocalizations strings) =>
    strings.displayPresetGraphiteGray;
String _displayPresetBerryRed(AppLocalizations strings) =>
    strings.displayPresetBerryRed;

class HazukiApp extends StatefulWidget {
  const HazukiApp({super.key});

  @override
  State<HazukiApp> createState() => _HazukiAppState();
}

PreferredSizeWidget hazukiFrostedAppBar({
  required BuildContext context,
  Widget? title,
  List<Widget>? actions,
  Widget? leading,
  bool automaticallyImplyLeading = true,
  double? toolbarHeight,
  PreferredSizeWidget? bottom,
  double elevation = 0,
  bool centerTitle = false,
  double backgroundAlpha = 0.72,
  double? titleSpacing,
}) {
  final surface = Theme.of(context).colorScheme.surface;
  return AppBar(
    title: title,
    actions: actions,
    leading: leading,
    automaticallyImplyLeading: automaticallyImplyLeading,
    toolbarHeight: toolbarHeight,
    titleSpacing: titleSpacing,
    bottom: bottom,
    elevation: elevation,
    centerTitle: centerTitle,
    backgroundColor: surface.withValues(alpha: backgroundAlpha),
    surfaceTintColor: Colors.transparent,
    scrolledUnderElevation: 0,
    clipBehavior: Clip.antiAlias,
    flexibleSpace: ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: const SizedBox.expand(),
      ),
    ),
  );
}

class _HazukiAppState extends State<HazukiApp>
    with WidgetsBindingObserver {
  static const _themeModeKey = 'appearance_theme_mode';
  static const _oledPureBlackKey = 'appearance_oled_pure_black';
  static const _dynamicColorKey = 'appearance_dynamic_color';
  static const _presetIndexKey = 'appearance_preset_index';
  static const _displayModeKey = 'appearance_display_mode';
  static const _comicDetailDynamicColorKey =
      'appearance_comic_detail_dynamic_color';
  static const _sourceUpdateSkipDateKey = 'source_update_skip_date';
  static const _localeKey = 'app_locale';

  final Connectivity _connectivity = Connectivity();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _hasConnectivity = true;
  bool _isCheckingSourceUpdate = false;
  bool _isShowingSourceUpdateDialog = false;
  bool _showInitialSourceBootstrapOverlay = false;
  bool _showInitialSourceBootstrapIntro = false;
  bool _sourceBootstrapIndeterminate = true;
  double _sourceBootstrapProgress = 0;
  String? _sourceBootstrapErrorText;
  int _homeRefreshTick = 0;
  bool _allowDiscoverInitialLoad = false;

  AppearanceSettingsData _appearance = const AppearanceSettingsData(
    themeMode: ThemeMode.system,
    oledPureBlack: false,
    dynamicColor: _defaultDynamicColorEnabled,
    presetIndex: _defaultAppearancePresetIndex,
    displayModeRaw: 'native:auto',
    comicDetailDynamicColor: false,
  );
  Locale? _locale;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadAppearance());
    unawaited(_loadLocalePreference());
    unawaited(_initConnectivityWatcher());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_bootstrapSourceRuntime());
    });
    unawaited(CloudSyncService.instance.autoSyncOnce());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _scheduleSourceUpdateDialogCheck();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadAppearance() async {
    final prefs = await SharedPreferences.getInstance();
    final modeRaw = prefs.getString(_themeModeKey) ?? 'system';
    final mode = switch (modeRaw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    var presetIndex =
        prefs.getInt(_presetIndexKey) ?? _defaultAppearancePresetIndex;
    if (presetIndex < 0 || presetIndex >= kHazukiColorPresets.length) {
      presetIndex = _defaultAppearancePresetIndex;
    }
    final displayModeRaw = prefs.getString(_displayModeKey) ?? 'native:auto';
    if (Platform.isAndroid) {
      try {
        final applied = await _displayModeChannel.invokeMethod<bool>(
          'applyDisplayModeRaw',
          {'raw': displayModeRaw},
        );
        if (applied != true) {
          await _displayModeChannel.invokeMethod<void>('applyAutoDisplayMode');
        }
      } catch (e) {
        debugPrint('Failed to apply preferred display mode: $e');
      }
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _appearance = AppearanceSettingsData(
        themeMode: mode,
        oledPureBlack: prefs.getBool(_oledPureBlackKey) ?? false,
        dynamicColor:
            prefs.getBool(_dynamicColorKey) ?? _defaultDynamicColorEnabled,
        presetIndex: presetIndex,
        displayModeRaw: displayModeRaw,
        comicDetailDynamicColor:
            prefs.getBool(_comicDetailDynamicColorKey) ?? false,
      );
    });
  }

  Future<void> _updateAppearance(AppearanceSettingsData next) async {
    final prefs = await SharedPreferences.getInstance();
    final modeRaw = switch (next.themeMode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      _ => 'system',
    };
    await prefs.setString(_themeModeKey, modeRaw);
    await prefs.setBool(_oledPureBlackKey, next.oledPureBlack);
    await prefs.setBool(_dynamicColorKey, next.dynamicColor);
    await prefs.setInt(_presetIndexKey, next.presetIndex);
    await prefs.setString(_displayModeKey, next.displayModeRaw);
    await prefs.setBool(
      _comicDetailDynamicColorKey,
      next.comicDetailDynamicColor,
    );

    if (!mounted) {
      return;
    }
    setState(() {
      _appearance = next;
    });
  }

  Future<void> _loadLocalePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final localeTag = prefs.getString(_localeKey);
    if (!mounted) {
      return;
    }
    setState(() {
      _locale = switch (localeTag) {
        'zh' => const Locale('zh'),
        'en' => const Locale('en'),
        _ => null,
      };
    });
  }

  Future<void> _updateLocalePreference(Locale? locale) async {
    final prefs = await SharedPreferences.getInstance();
    final localeTag = switch (locale?.languageCode) {
      'zh' => 'zh',
      'en' => 'en',
      _ => 'system',
    };
    await prefs.setString(_localeKey, localeTag);
    if (!mounted) {
      return;
    }
    setState(() {
      _locale = localeTag == 'system' ? null : locale;
    });
  }

  Future<void> _bootstrapSourceRuntime() async {
    final hasLocalSource =
        await HazukiSourceService.instance.hasLocalJmSourceFile();
    if (!mounted) {
      return;
    }

    if (!hasLocalSource) {
      var bootstrapSucceeded = false;
      setState(() {
        _allowDiscoverInitialLoad = false;
        _showInitialSourceBootstrapIntro = true;
        _showInitialSourceBootstrapOverlay = false;
        _sourceBootstrapIndeterminate = true;
        _sourceBootstrapProgress = 0;
        _sourceBootstrapErrorText = null;
      });
      unawaited(() async {
        await Future<void>.delayed(const Duration(milliseconds: 900));
        if (!mounted || !_showInitialSourceBootstrapIntro) {
          return;
        }
        setState(() {
          _showInitialSourceBootstrapIntro = false;
          _showInitialSourceBootstrapOverlay = true;
        });
      }());
      try {
        await HazukiSourceService.instance.init(
          onSourceDownloadProgress: (received, total) {
            if (!mounted) {
              return;
            }
            setState(() {
              if (total > 0) {
                _sourceBootstrapIndeterminate = false;
                _sourceBootstrapProgress = (received / total).clamp(0.0, 1.0);
              } else {
                _sourceBootstrapIndeterminate = true;
              }
            });
          },
        );
        await HazukiSourceService.instance.ensureInitialized();
        bootstrapSucceeded = true;
      } catch (e) {
        if (!mounted) {
          return;
        }
        setState(() {
          _sourceBootstrapIndeterminate = false;
          _sourceBootstrapProgress = 1;
          _sourceBootstrapErrorText = '$e';
        });
        await Future<void>.delayed(const Duration(seconds: 2));
      }
      if (!mounted || !bootstrapSucceeded) {
        return;
      }
      setState(() {
        _showInitialSourceBootstrapIntro = false;
        _showInitialSourceBootstrapOverlay = false;
      });
      await Future<void>.delayed(const Duration(milliseconds: 280));
      if (!mounted) {
        return;
      }
      setState(() {
        _allowDiscoverInitialLoad = true;
        _homeRefreshTick++;
      });
      return;
    }

    await HazukiSourceService.instance.ensureInitialized();
    if (!mounted) {
      return;
    }
    setState(() {
      _allowDiscoverInitialLoad = true;
      _homeRefreshTick++;
    });
    _scheduleSourceUpdateDialogCheck();
  }

  Future<void> _initConnectivityWatcher() async {
    try {
      final initial = await _connectivity.checkConnectivity();
      _hasConnectivity = initial.any(
        (result) => result != ConnectivityResult.none,
      );
    } catch (_) {
      _hasConnectivity = true;
    }

    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      results,
    ) {
      final hasNetwork = results.any(
        (result) => result != ConnectivityResult.none,
      );
      if (_hasConnectivity == hasNetwork) {
        return;
      }
      _hasConnectivity = hasNetwork;
      if (_hasConnectivity) {
        _scheduleSourceRecovery();
      }
    });
  }

  void _scheduleSourceRecovery() {
    unawaited(_runSourceRecovery());
  }

  void _scheduleSourceUpdateDialogCheck() {
    if (_isCheckingSourceUpdate || _isShowingSourceUpdateDialog) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isCheckingSourceUpdate || _isShowingSourceUpdateDialog) {
        return;
      }
      unawaited(_runSourceUpdateDialogCheck());
    });
  }

  Future<void> _runSourceUpdateDialogCheck() async {
    if (_isCheckingSourceUpdate || _isShowingSourceUpdateDialog) {
      return;
    }

    _isCheckingSourceUpdate = true;
    try {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!mounted) {
        return;
      }
      final result = await _showSourceUpdateDialogIfNeeded();
      if (!mounted) {
        return;
      }
      if (result == _SourceUpdateDialogAction.downloaded) {
        setState(() {
          _homeRefreshTick++;
        });
      }
    } finally {
      _isCheckingSourceUpdate = false;
    }
  }

  Future<void> _runSourceRecovery() async {
    final refreshed = await HazukiSourceService.instance
        .refreshSourceOnNetworkRecovery();
    if (!mounted || !refreshed) {
      return;
    }
    _scheduleSourceUpdateDialogCheck();
  }

  String _formatTodayKey() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<T?> _showAnimatedDialog<T>({
    required Widget child,
    bool barrierDismissible = true,
    ValueNotifier<bool>? dismissibleListenable,
  }) {
    final dialogContext =
        _navigatorKey.currentState?.overlay?.context ??
        _navigatorKey.currentContext;
    if (dialogContext == null) {
      return Future<T?>.value(null);
    }
    return showGeneralDialog<T>(
      context: dialogContext,
      barrierDismissible: false,
      barrierLabel: l10n(dialogContext).dialogBarrierLabel,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (buildContext, animation, secondaryAnimation) {
        Widget buildPage(bool canDismiss) {
          return PopScope(
            canPop: canDismiss,
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: canDismiss
                        ? () => Navigator.of(buildContext).maybePop()
                        : null,
                    child: AnimatedBuilder(
                      animation: animation,
                      builder: (context, child) {
                        final colorScheme = Theme.of(context).colorScheme;
                        final transitionProgress = Curves.easeOutCubic
                            .transform(animation.value);
                        final blurProgress = const Interval(
                          0.0,
                          0.82,
                          curve: Curves.easeOutCubic,
                        ).transform(animation.value);
                        final sigma = 4 + (14 * blurProgress);
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            ColoredBox(
                              color: Colors.black.withValues(
                                alpha: 0.20 * transitionProgress,
                              ),
                            ),
                            ClipRect(
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: sigma,
                                  sigmaY: sigma,
                                ),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        colorScheme.surface.withValues(
                                          alpha: 0.06 * transitionProgress,
                                        ),
                                        colorScheme.surface.withValues(
                                          alpha: 0.12 * transitionProgress,
                                        ),
                                        colorScheme.surfaceContainerHighest
                                            .withValues(
                                              alpha:
                                                  0.18 * transitionProgress,
                                            ),
                                      ],
                                    ),
                                  ),
                                  child: child,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                SafeArea(
                  minimum: const EdgeInsets.all(16),
                  child: Center(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {},
                      child: Material(
                        type: MaterialType.transparency,
                        child: child,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        if (dismissibleListenable == null) {
          return buildPage(barrierDismissible);
        }

        return ValueListenableBuilder<bool>(
          valueListenable: dismissibleListenable,
          builder: (context, canDismiss, _) {
            return buildPage(canDismiss);
          },
        );
      },
      transitionBuilder:
          (buildContext, animation, secondaryAnimation, dialogChild) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.02),
                  end: Offset.zero,
                ).animate(curved),
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
                  child: dialogChild,
                ),
              ),
            );
          },
    );
  }

  Future<_SourceUpdateDialogAction?> _showSourceUpdateDialogIfNeeded() async {
    if (_isShowingSourceUpdateDialog) {
      return null;
    }

    final check = await HazukiSourceService.instance
        .checkJmSourceVersionFromCloud();
    if (!mounted || check == null || !check.hasUpdate) {
      return null;
    }

    final prefs = await SharedPreferences.getInstance();
    final skipDate = prefs.getString(_sourceUpdateSkipDateKey);
    if (skipDate == _formatTodayKey()) {
      return null;
    }

    _isShowingSourceUpdateDialog = true;

    final dismissible = ValueNotifier<bool>(false);
    var phase = _SourceUpdateDialogPhase.available;
    var progress = 0.0;
    var indeterminate = true;
    var downloadCompleted = false;
    String? errorText;

    final result = await _showAnimatedDialog<_SourceUpdateDialogAction>(
      barrierDismissible: false,
      dismissibleListenable: dismissible,
      child: StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final strings = l10n(dialogContext);
          final theme = Theme.of(dialogContext);
          final colorScheme = theme.colorScheme;
          final textTheme = theme.textTheme;
          final restartTitle = strings.sourceUpdateRestartTitle;
          final restartMessage = strings.sourceUpdateRestartMessage;
          final localVersionLabel = strings.sourceUpdateLocalLabel;
          final remoteVersionLabel = strings.sourceUpdateCloudLabel;

          const dialogMaxWidth = 360.0;
          final availableMessage = strings.sourceUpdateAvailableMessage;
          final downloadingMessage = strings.sourceUpdateDownloadingMessage;
          final restartHint = strings.sourceUpdateRestartHint;

          double resolveDialogRadius() {
            switch (phase) {
              case _SourceUpdateDialogPhase.available:
                return 28;
              case _SourceUpdateDialogPhase.downloading:
                return 24;
              case _SourceUpdateDialogPhase.restartRequired:
                return 26;
            }
          }

          EdgeInsets resolveDialogPadding() {
            switch (phase) {
              case _SourceUpdateDialogPhase.available:
                return const EdgeInsets.fromLTRB(20, 20, 20, 18);
              case _SourceUpdateDialogPhase.downloading:
                return const EdgeInsets.fromLTRB(20, 18, 20, 18);
              case _SourceUpdateDialogPhase.restartRequired:
                return const EdgeInsets.fromLTRB(20, 20, 20, 20);
            }
          }

          Color resolveAccentColor() {
            switch (phase) {
              case _SourceUpdateDialogPhase.available:
                return colorScheme.primary;
              case _SourceUpdateDialogPhase.downloading:
                return colorScheme.primary;
              case _SourceUpdateDialogPhase.restartRequired:
                return colorScheme.tertiary;
            }
          }

          Widget buildLeadingIcon({
            required IconData icon,
            required Color accent,
          }) {
            return Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: accent, size: 22),
            );
          }

          Widget buildPanel({required Widget child}) {
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.36),
                ),
              ),
              child: child,
            );
          }

          Widget buildHeader({
            required IconData icon,
            required String title,
            required String subtitle,
            required Color accent,
            String? badgeText,
          }) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildLeadingIcon(icon: icon, accent: accent),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (badgeText != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badgeText,
                      style: textTheme.labelMedium?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            );
          }

          Widget buildVersionRow({
            required IconData icon,
            required Color accent,
            required String label,
            required String value,
          }) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accent, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          Widget buildErrorCard(String message) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.error.withValues(alpha: 0.10),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: colorScheme.onErrorContainer,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      message,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          Widget buildDialogScene() {
            switch (phase) {
              case _SourceUpdateDialogPhase.available:
                return Column(
                  key: const ValueKey<String>('source-update-phase-available'),
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    buildHeader(
                      icon: Icons.system_update_alt_rounded,
                      title: strings.sourceUpdateAvailableTitle,
                      subtitle: availableMessage,
                      accent: colorScheme.primary,
                      badgeText: strings.sourceUpdateRemoteVersion(
                        check.remoteVersion,
                      ),
                    ),
                    const SizedBox(height: 18),
                    buildPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          buildVersionRow(
                            icon: Icons.history_rounded,
                            accent: colorScheme.onSurfaceVariant,
                            label: localVersionLabel,
                            value: check.localVersion,
                          ),
                          const SizedBox(height: 12),
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.32,
                            ),
                          ),
                          const SizedBox(height: 12),
                          buildVersionRow(
                            icon: Icons.cloud_download_outlined,
                            accent: colorScheme.primary,
                            label: remoteVersionLabel,
                            value: check.remoteVersion,
                          ),
                        ],
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 12),
                      buildErrorCard(errorText!),
                    ],
                    const SizedBox(height: 18),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () async {
                        dismissible.value = false;
                        setDialogState(() {
                          phase = _SourceUpdateDialogPhase.downloading;
                          errorText = null;
                          progress = 0;
                          indeterminate = true;
                        });

                        final ok = await HazukiSourceService.instance
                            .downloadJmSourceAndReload(
                              onProgress: (received, total) {
                                if (!dialogContext.mounted) {
                                  return;
                                }
                                setDialogState(() {
                                  if (total > 0) {
                                    indeterminate = false;
                                    progress = (received / total).clamp(0.0, 1.0);
                                  } else {
                                    indeterminate = true;
                                  }
                                });
                              },
                            );

                        if (!dialogContext.mounted) {
                          return;
                        }

                        if (ok) {
                          downloadCompleted = true;
                          dismissible.value = true;
                          setDialogState(() {
                            phase = _SourceUpdateDialogPhase.restartRequired;
                            indeterminate = false;
                            progress = 1;
                          });
                        } else {
                          dismissible.value = false;
                          setDialogState(() {
                            phase = _SourceUpdateDialogPhase.available;
                            errorText = strings.sourceUpdateDownloadFailed;
                          });
                        }
                      },
                      child: Text(strings.sourceUpdateDownload),
                    ),
                    const SizedBox(height: 8),
                    OverflowBar(
                      alignment: MainAxisAlignment.end,
                      spacing: 4,
                      overflowSpacing: 4,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(
                            dialogContext,
                          ).pop(_SourceUpdateDialogAction.skipToday),
                          child: Text(strings.comicDetailRemindLaterToday),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(
                            dialogContext,
                          ).pop(_SourceUpdateDialogAction.cancel),
                          child: Text(strings.commonCancel),
                        ),
                      ],
                    ),
                  ],
                );
              case _SourceUpdateDialogPhase.downloading:
                final progressLabel = indeterminate
                    ? strings.sourceUpdateDownloading
                    : strings.sourceUpdateDownloadingProgress(
                        (progress * 100).toStringAsFixed(0),
                      );
                final percentLabel = '${(progress * 100).toStringAsFixed(0)}%';
                return Column(
                  key: const ValueKey<String>('source-update-phase-downloading'),
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    buildHeader(
                      icon: Icons.downloading_rounded,
                      title: strings.sourceUpdateDownloading,
                      subtitle: downloadingMessage,
                      accent: colorScheme.primary,
                      badgeText: strings.sourceUpdateRemoteVersion(
                        check.remoteVersion,
                      ),
                    ),
                    const SizedBox(height: 18),
                    buildPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  progressLabel,
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                              if (!indeterminate)
                                Text(
                                  percentLabel,
                                  style: textTheme.labelLarge?.copyWith(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              minHeight: 8,
                              value: indeterminate ? null : progress,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            indeterminate
                                ? downloadingMessage
                                : restartHint,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              case _SourceUpdateDialogPhase.restartRequired:
                return Column(
                  key: const ValueKey<String>('source-update-phase-restart'),
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    buildHeader(
                      icon: Icons.restart_alt_rounded,
                      title: restartTitle,
                      subtitle: restartMessage,
                      accent: colorScheme.tertiary,
                      badgeText: strings.sourceUpdateRemoteVersion(
                        check.remoteVersion,
                      ),
                    ),
                    const SizedBox(height: 18),
                    buildPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          buildVersionRow(
                            icon: Icons.cloud_done_rounded,
                            accent: colorScheme.tertiary,
                            label: remoteVersionLabel,
                            value: check.remoteVersion,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            restartHint,
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () => Navigator.of(dialogContext).pop(
                        _SourceUpdateDialogAction.downloaded,
                      ),
                      child: Text(strings.commonConfirm),
                    ),
                  ],
                );
            }
          }

          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeInOutCubic,
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: dialogMaxWidth),
              padding: resolveDialogPadding(),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(resolveDialogRadius()),
                border: Border.all(
                  color: resolveAccentColor().withValues(alpha: 0.14),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeInOutCubic,
                alignment: Alignment.center,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  layoutBuilder: (currentChild, previousChildren) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        ...previousChildren,
                        ?currentChild,
                      ],
                    );
                  },
                  transitionBuilder: (child, animation) {
                    final curved = CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                      reverseCurve: Curves.easeInCubic,
                    );
                    return ClipRect(
                      child: FadeTransition(
                        opacity: curved,
                        child: SizeTransition(
                          sizeFactor: curved,
                          axis: Axis.vertical,
                          axisAlignment: 0,
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: buildDialogScene(),
                ),
              ),
            ),
          );
        },
      ),
    );

    dismissible.dispose();

    final effectiveResult = downloadCompleted && result == null
        ? _SourceUpdateDialogAction.downloaded
        : result;

    if (effectiveResult == _SourceUpdateDialogAction.skipToday) {
      await prefs.setString(_sourceUpdateSkipDateKey, _formatTodayKey());
    }

    if (!mounted) {
      _isShowingSourceUpdateDialog = false;
      return effectiveResult;
    }

    _isShowingSourceUpdateDialog = false;
    return effectiveResult;
  }

  ThemeData _buildLightTheme([ColorScheme? dynamicColorScheme]) {
    final preset = kHazukiColorPresets[_appearance.presetIndex];
    final colorScheme = _appearance.dynamicColor && dynamicColorScheme != null
        ? dynamicColorScheme.harmonized()
        : ColorScheme.fromSeed(
            seedColor: preset.seedColor,
            brightness: Brightness.light,
            dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
          );

    return ThemeData(colorScheme: colorScheme, useMaterial3: true);
  }

  ThemeData _buildDarkTheme([ColorScheme? dynamicColorScheme]) {
    final preset = kHazukiColorPresets[_appearance.presetIndex];
    final baseColorScheme =
        _appearance.dynamicColor && dynamicColorScheme != null
        ? dynamicColorScheme.harmonized()
        : ColorScheme.fromSeed(
            seedColor: preset.seedColor,
            brightness: Brightness.dark,
            dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
          );

    final base = ThemeData(colorScheme: baseColorScheme, useMaterial3: true);

    if (!_appearance.oledPureBlack) {
      return base;
    }

    final pureBlackScheme = base.colorScheme.copyWith(
      surface: Colors.black,
      surfaceContainer: Colors.black,
      surfaceContainerLow: Colors.black,
      surfaceContainerLowest: Colors.black,
      surfaceContainerHigh: Colors.black,
      surfaceContainerHighest: Colors.black,
    );

    return base.copyWith(
      scaffoldBackgroundColor: Colors.black,
      canvasColor: Colors.black,
      colorScheme: pureBlackScheme,
      cardColor: Colors.black,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        return MaterialApp(
          navigatorKey: _navigatorKey,
          debugShowCheckedModeBanner: false,
          onGenerateTitle: (context) => l10n(context).appTitle,
          locale: _locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          themeMode: _appearance.themeMode,
          theme: _buildLightTheme(lightDynamic),
          darkTheme: _buildDarkTheme(darkDynamic),
          builder: (context, child) {
            final scheme = Theme.of(context).colorScheme;
            return Stack(
              children: [
                // ignore: use_null_aware_elements
                if (child != null) child,
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring:
                        !_showInitialSourceBootstrapOverlay &&
                        !_showInitialSourceBootstrapIntro,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (widget, animation) {
                        final curved = CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                          reverseCurve: Curves.easeInCubic,
                        );
                        return FadeTransition(
                          opacity: curved,
                          child: ScaleTransition(
                            scale: Tween<double>(
                              begin: 0.94,
                              end: 1,
                            ).animate(curved),
                            child: widget,
                          ),
                        );
                      },
                      child:
                          _showInitialSourceBootstrapOverlay ||
                                  _showInitialSourceBootstrapIntro
                              ? ColoredBox(
                                  key: ValueKey(
                                    _showInitialSourceBootstrapOverlay
                                        ? 'initial-source-bootstrap-overlay'
                                        : 'initial-source-bootstrap-intro',
                                  ),
                                  color: Colors.transparent,
                                  child: Center(
                                    child: Container(
                                      width: 332,
                                      padding: const EdgeInsets.fromLTRB(
                                        20,
                                        18,
                                        20,
                                        18,
                                      ),
                                      decoration: BoxDecoration(
                                        color: scheme.surface,
                                        borderRadius: BorderRadius.circular(28),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.14,
                                            ),
                                            blurRadius: 24,
                                            offset: const Offset(0, 10),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            l10n(context)
                                                .sourceBootstrapDownloading,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
                                          ),
                                          const SizedBox(height: 14),
                                          if (_showInitialSourceBootstrapOverlay)
                                            ...[
                                              LinearProgressIndicator(
                                                value:
                                                    _sourceBootstrapIndeterminate
                                                        ? null
                                                        : _sourceBootstrapProgress,
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                                minHeight: 8,
                                              ),
                                              const SizedBox(height: 10),
                                            ],
                                          Text(
                                            _sourceBootstrapErrorText ??
                                                (_showInitialSourceBootstrapIntro
                                                    ? l10n(context)
                                                          .sourceBootstrapPreparing
                                                    : _sourceBootstrapIndeterminate
                                                    ? l10n(context)
                                                          .sourceBootstrapPreparing
                                                    : l10n(context)
                                                          .sourceBootstrapProgress(
                                                            (_sourceBootstrapProgress *
                                                                    100)
                                                                .toStringAsFixed(
                                                                  0,
                                                                ),
                                                          )),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color:
                                                      scheme.onSurfaceVariant,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(
                                  key: ValueKey(
                                    'initial-source-bootstrap-overlay-empty',
                                  ),
                                ),
                    ),
                  ),
                ),
              ],
            );
          },
          home: HazukiHomePage(
            appearanceSettings: _appearance,
            onAppearanceChanged: _updateAppearance,
            locale: _locale,
            onLocaleChanged: _updateLocalePreference,
            allowDiscoverInitialLoad: _allowDiscoverInitialLoad,
            hideDiscoverLoadingUntilAllowed:
                _showInitialSourceBootstrapOverlay ||
                _showInitialSourceBootstrapIntro,
            refreshTick: _homeRefreshTick,
          ),
        );
      },
    );
  }
}

enum _SourceUpdateDialogPhase { available, downloading, restartRequired }

enum _SourceUpdateDialogAction { skipToday, cancel, downloaded }
