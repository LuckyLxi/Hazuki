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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models/hazuki_models.dart';
import 'services/cloud_sync_service.dart';
import 'services/hazuki_source_service.dart';

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
part 'pages/about_page.dart';
part 'widgets/cached_image_widgets.dart';
part 'widgets/sticker_loading_indicator.dart';

const MethodChannel _displayModeChannel = MethodChannel(
  'hazuki.comics/display_mode',
);
const MethodChannel _readerDisplayChannel = MethodChannel(
  'hazuki.comics/reader_display',
);
const _discoverSearchHeroTag = 'discover_search_to_search_page';
const _noImageModeKey = 'advanced_no_image_mode';
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _loadGlobalUiFlags();
  unawaited(HazukiSourceService.instance.init());
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
  const HazukiColorPreset({required this.name, required this.seedColor});

  final String name;
  final Color seedColor;
}

const List<HazukiColorPreset> kHazukiColorPresets = [
  HazukiColorPreset(name: '薄荷绿', seedColor: Color(0xFF009688)),
  HazukiColorPreset(name: '海盐蓝', seedColor: Color(0xFF0288D1)),
  HazukiColorPreset(name: '暮光紫', seedColor: Color(0xFF7E57C2)),
  HazukiColorPreset(name: '樱花粉', seedColor: Color(0xFFEC407A)),
  HazukiColorPreset(name: '珊瑚橙', seedColor: Color(0xFFFF7043)),
  HazukiColorPreset(name: '琥珀黄', seedColor: Color(0xFFFFB300)),
  HazukiColorPreset(name: '青柠绿', seedColor: Color(0xFF7CB342)),
  HazukiColorPreset(name: '石墨灰', seedColor: Color(0xFF546E7A)),
  HazukiColorPreset(name: '莓果红', seedColor: Color(0xFFC62828)),
];

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

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _hasConnectivity = true;
  bool _isShowingSourceUpdateDialog = false;
  int _homeRefreshTick = 0;

  AppearanceSettingsData _appearance = const AppearanceSettingsData(
    themeMode: ThemeMode.system,
    oledPureBlack: false,
    dynamicColor: true,
    presetIndex: 0,
    displayModeRaw: 'native:auto',
    comicDetailDynamicColor: false,
  );

  @override
  void initState() {
    super.initState();
    unawaited(_loadAppearance());
    unawaited(_initConnectivityWatcher());
    unawaited(_checkSourceUpdateInBackground());
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
    var presetIndex = prefs.getInt(_presetIndexKey) ?? 0;
    if (presetIndex < 0 || presetIndex >= kHazukiColorPresets.length) {
      presetIndex = 0;
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
        dynamicColor: prefs.getBool(_dynamicColorKey) ?? true,
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

  Future<void> _runSourceRecovery() async {
    await HazukiSourceService.instance.refreshSourceOnNetworkRecovery();
  }

  Future<void> _checkSourceUpdateInBackground() async {
    await HazukiSourceService.instance.ensureInitialized();
    if (!mounted) {
      return;
    }
    await _showSourceUpdateDialogIfNeeded();
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

  Future<void> _showSourceUpdateDialogIfNeeded() async {
    if (_isShowingSourceUpdateDialog) {
      return;
    }

    final check = await HazukiSourceService.instance
        .checkJmSourceVersionFromCloud();
    if (!mounted || check == null || !check.hasUpdate) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final skipDate = prefs.getString(_sourceUpdateSkipDateKey);
    if (skipDate == _formatTodayKey()) {
      return;
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
            title: const Text('漫画源有更新'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('本地漫画源版本号：${check.localVersion}'),
                const SizedBox(height: 6),
                Text('云端漫画源版本号：${check.remoteVersion}'),
                if (downloading) ...[
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: indeterminate ? null : progress,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    indeterminate
                        ? '下载中...'
                        : '下载中 ${(progress * 100).toStringAsFixed(0)}%',
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
                child: const Text('今日不再提醒'),
              ),
              TextButton(
                onPressed: downloading
                    ? null
                    : () => Navigator.of(
                        dialogContext,
                      ).pop(_SourceUpdateDialogAction.cancel),
                child: const Text('取消'),
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

                        final ok = await HazukiSourceService.instance
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
                            errorText = '下载失败，请稍后重试';
                          });
                        }
                      },
                child: const Text('下载'),
              ),
            ],
          );
        },
      ),
    );

    if (result == _SourceUpdateDialogAction.skipToday) {
      await prefs.setString(_sourceUpdateSkipDateKey, _formatTodayKey());
    }

    if (!mounted) {
      _isShowingSourceUpdateDialog = false;
      return;
    }

    if (result == _SourceUpdateDialogAction.downloaded) {
      setState(() {
        _homeRefreshTick++;
      });
    }

    _isShowingSourceUpdateDialog = false;
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
          title: 'Hazuki',
          themeMode: _appearance.themeMode,
          theme: _buildLightTheme(lightDynamic),
          darkTheme: _buildDarkTheme(darkDynamic),
          home: HazukiHomePage(
            key: ValueKey(_homeRefreshTick),
            appearanceSettings: _appearance,
            onAppearanceChanged: _updateAppearance,
          ),
        );
      },
    );
  }
}

enum _SourceUpdateDialogAction { skipToday, cancel, downloaded }
