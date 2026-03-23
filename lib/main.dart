import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:io';
import 'dart:ui';

import 'package:crypto/crypto.dart';
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

Future<void> setHazukiNoImageMode(bool enabled) async {
  hazukiNoImageModeNotifier.value = enabled;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_noImageModeKey, enabled);
}

AppLocalizations l10n(BuildContext context) => AppLocalizations.of(context)!;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _loadGlobalUiFlags();
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

class _HazukiAppState extends State<HazukiApp> {
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
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _hasConnectivity = true;
  bool _isShowingSourceUpdateDialog = false;
  Future<void>? _sourceUpdateDialogCheckFuture;
  bool _showInitialSourceBootstrapOverlay = false;
  bool _sourceBootstrapIndeterminate = true;
  double _sourceBootstrapProgress = 0;
  String? _sourceBootstrapErrorText;
  int _homeRefreshTick = 0;

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
    unawaited(_loadAppearance());
    unawaited(_loadLocalePreference());
    unawaited(_initConnectivityWatcher());
    unawaited(MangaDownloadService.instance.ensureInitialized());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_bootstrapSourceRuntime());
    });
    unawaited(CloudSyncService.instance.autoSyncOnce());
  }

  @override
  void dispose() {
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
      setState(() {
        _showInitialSourceBootstrapOverlay = true;
        _sourceBootstrapIndeterminate = true;
        _sourceBootstrapProgress = 0;
        _sourceBootstrapErrorText = null;
      });
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
      if (!mounted) {
        return;
      }
      setState(() {
        _showInitialSourceBootstrapOverlay = false;
      });
      await Future<void>.delayed(const Duration(milliseconds: 280));
      if (!mounted) {
        return;
      }
      setState(() {
        _homeRefreshTick++;
      });
      return;
    }

    await HazukiSourceService.instance.init();
    if (!mounted) {
      return;
    }
    setState(() {
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _sourceUpdateDialogCheckFuture != null) {
        return;
      }
      final future = _runSourceUpdateDialogCheck();
      _sourceUpdateDialogCheckFuture = future;
      unawaited(
        future.whenComplete(() {
          _sourceUpdateDialogCheckFuture = null;
        }),
      );
    });
  }

  Future<void> _runSourceUpdateDialogCheck() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final result = await _showSourceUpdateDialogIfNeeded();
    if (!mounted) {
      return;
    }
    if (result == _SourceUpdateDialogAction.downloaded) {
      setState(() {
        _homeRefreshTick++;
      });
    }
  }

  Future<void> _runSourceRecovery() async {
    final refreshed =
        await HazukiSourceService.instance.refreshSourceOnNetworkRecovery();
    if (!mounted) {
      return;
    }
    if (refreshed) {
      setState(() {
        _homeRefreshTick++;
      });
    }
    _scheduleSourceUpdateDialogCheck();
  }

  Future<void> _showSourceUpdatedPrompt({
    required String fromVersion,
    required String toVersion,
  }) async {
    if (!mounted) {
      return;
    }
    final normalizedFrom = fromVersion.trim();
    final normalizedTo = toVersion.trim();
    var message = normalizedTo;
    if (normalizedFrom.isNotEmpty &&
        normalizedTo.isNotEmpty &&
        normalizedFrom != normalizedTo) {
      message = '$normalizedFrom → $normalizedTo';
    } else if (normalizedFrom.isNotEmpty && normalizedTo.isEmpty) {
      message = normalizedFrom;
    }
    final localeCode = Localizations.localeOf(context).languageCode;
    final title = localeCode == 'zh' ? '漫画源已更新' : 'Source updated';
    final promptMessage = message.isEmpty ? title : '$title $message';
    await showHazukiPrompt(context, promptMessage);
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
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: 'source-update-dialog',
      barrierColor: Colors.black45,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (buildContext, animation, secondaryAnimation) {
        return SafeArea(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Center(
              child: Material(type: MaterialType.transparency, child: child),
            ),
          ),
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
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
                child: dialogChild,
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

    var downloading = false;
    var progress = 0.0;
    var indeterminate = true;
    String? errorText;

    final result = await _showAnimatedDialog<_SourceUpdateDialogAction>(
      barrierDismissible: false,
      child: StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: Text(l10n(dialogContext).sourceUpdateAvailableTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n(
                    dialogContext,
                  ).sourceUpdateLocalVersion(check.localVersion),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n(
                    dialogContext,
                  ).sourceUpdateRemoteVersion(check.remoteVersion),
                ),
                if (downloading) ...[
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: indeterminate ? null : progress,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    indeterminate
                        ? l10n(dialogContext).sourceUpdateDownloading
                        : l10n(dialogContext).sourceUpdateDownloadingProgress(
                            (progress * 100).toStringAsFixed(0),
                          ),
                  ),
                ],
                if (errorText != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    errorText!,
                    style: TextStyle(
                      color: Theme.of(dialogContext).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: downloading
                    ? null
                    : () => Navigator.of(
                        dialogContext,
                      ).pop(_SourceUpdateDialogAction.skipToday),
                child: Text(l10n(dialogContext).comicDetailRemindLaterToday),
              ),
              TextButton(
                onPressed: downloading
                    ? null
                    : () => Navigator.of(
                        dialogContext,
                      ).pop(_SourceUpdateDialogAction.cancel),
                child: Text(l10n(dialogContext).commonCancel),
              ),
              FilledButton(
                onPressed: downloading
                    ? null
                    : () async {
                        setDialogState(() {
                          downloading = true;
                          errorText = null;
                          progress = 0;
                          indeterminate = true;
                        });

                        var ok = false;
                        try {
                          ok = await HazukiSourceService.instance
                              .downloadJmSourceAndReload(
                                onProgress: (received, total) {
                                  if (!dialogContext.mounted) {
                                    return;
                                  }
                                  setDialogState(() {
                                    if (total > 0) {
                                      indeterminate = false;
                                      progress = (received / total).clamp(
                                        0.0,
                                        1.0,
                                      );
                                    } else {
                                      indeterminate = true;
                                    }
                                  });
                                },
                              );
                        } catch (_) {
                          ok = false;
                        }

                        if (!dialogContext.mounted) {
                          return;
                        }
                        if (ok) {
                          Navigator.of(
                            dialogContext,
                          ).pop(_SourceUpdateDialogAction.downloaded);
                        } else {
                          setDialogState(() {
                            downloading = false;
                            errorText = l10n(
                              dialogContext,
                            ).sourceUpdateDownloadFailed;
                          });
                        }
                      },
                child: Text(l10n(dialogContext).sourceUpdateDownload),
              ),
            ],
          );
        },
      ),
    );

    if (result == _SourceUpdateDialogAction.skipToday) {
      await prefs.setString(_sourceUpdateSkipDateKey, _formatTodayKey());
    } else if (result == _SourceUpdateDialogAction.downloaded) {
      await prefs.remove(_sourceUpdateSkipDateKey);
    }

    if (!mounted) {
      _isShowingSourceUpdateDialog = false;
      return result;
    }

    _isShowingSourceUpdateDialog = false;
    if (result == _SourceUpdateDialogAction.downloaded) {
      final appliedVersionSource =
          HazukiSourceService.instance.sourceMeta?.version;
      final appliedVersion =
          appliedVersionSource != null &&
                  appliedVersionSource.trim().isNotEmpty
              ? appliedVersionSource.trim()
              : check.remoteVersion;
      unawaited(
        _showSourceUpdatedPrompt(
          fromVersion: check.localVersion,
          toVersion: appliedVersion,
        ),
      );
    }
    return result;
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
                if (child != null) child,
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: !_showInitialSourceBootstrapOverlay,
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
                      child: _showInitialSourceBootstrapOverlay
                          ? Center(
                              key: const ValueKey(
                                'initial-source-bootstrap-overlay',
                              ),
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
                                      l10n(context).sourceBootstrapDownloading,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 14),
                                    LinearProgressIndicator(
                                      value: _sourceBootstrapIndeterminate
                                          ? null
                                          : _sourceBootstrapProgress,
                                      borderRadius: BorderRadius.circular(999),
                                      minHeight: 8,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      _sourceBootstrapErrorText ??
                                          (_sourceBootstrapIndeterminate
                                              ? l10n(context)
                                                    .sourceBootstrapPreparing
                                              : l10n(context)
                                                    .sourceBootstrapProgress(
                                                      (_sourceBootstrapProgress *
                                                              100)
                                                          .toStringAsFixed(0),
                                                    )),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
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
            sourceRefreshTick: _homeRefreshTick,
          ),
        );
      },
    );
  }
}

enum _SourceUpdateDialogAction { skipToday, cancel, downloaded }
