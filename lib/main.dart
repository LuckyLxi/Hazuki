import 'dart:async';
import 'dart:math' as math;
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app_settings_store.dart';
import 'app/app_preferences.dart';
import 'app/hazuki_app_controller.dart';
import 'app/appearance_settings.dart';
import 'app/hazuki_theme_controller.dart';
import 'app/hazuki_theme_factory.dart';
import 'app/source_runtime_coordinator.dart';
import 'app/source_runtime_widgets.dart';
import 'app/software_update_dialog_support.dart';
import 'app/source_update_dialog_support.dart';
import 'app/ui_flags.dart';
import 'app/windows_title_bar_controller.dart';
import 'l10n/app_localizations.dart';
import 'l10n/l10n.dart';
import 'pages/home_page.dart';
import 'services/cloud_sync_service.dart';
import 'services/hazuki_source_service.dart';
import 'services/manga_download_service.dart';
import 'services/manga_download_storage_support.dart';
import 'services/password_lock_service.dart';
import 'widgets/password_lock_widgets.dart';
import 'widgets/hazuki_prompt.dart';
import 'widgets/windows_custom_title_bar.dart';

Future<void> _ensureAndroidNoMediaMarker() async {
  if (!Platform.isAndroid) {
    return;
  }

  final rootPath = await MangaDownloadAccess.loadDownloadsRootPath();
  await _ensureNoMediaFile(rootPath);
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(PasswordLockAnimationCache.ensureLoaded());
  await loadHazukiUiFlags();
  await HazukiSourceService.instance.loadSoftwareLogCaptureEnabled();
  await _ensureAndroidNoMediaMarker();
  await MangaDownloadService.instance.ensureInitialized();
  await PasswordLockService.instance.ensureInitialized();
  const settingsStore = HazukiAppSettingsStore();
  final initialAppearance = await settingsStore.loadAppearance();
  final initialLocale = await settingsStore.loadLocalePreference();
  final initialUseSystemTitleBar = await settingsStore.loadUseSystemTitleBar();
  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    windowManager.waitUntilReadyToShow(
      WindowOptions(
        minimumSize: const Size(960, 640),
        title: 'Hazuki',
        titleBarStyle: initialUseSystemTitleBar
            ? TitleBarStyle.normal
            : TitleBarStyle.hidden,
        windowButtonVisibility: initialUseSystemTitleBar,
      ),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }
  runApp(
    HazukiApp(
      settingsStore: settingsStore,
      initialAppearance: initialAppearance,
      initialLocale: initialLocale,
      initialUseSystemTitleBar: initialUseSystemTitleBar,
    ),
  );
}

class HazukiApp extends StatefulWidget {
  const HazukiApp({
    super.key,
    required this.settingsStore,
    required this.initialAppearance,
    required this.initialLocale,
    required this.initialUseSystemTitleBar,
  });

  final HazukiAppSettingsStore settingsStore;
  final AppearanceSettingsData initialAppearance;
  final Locale? initialLocale;
  final bool initialUseSystemTitleBar;

  @override
  State<HazukiApp> createState() => _HazukiAppState();
}

class _HazukiAppState extends State<HazukiApp>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  static const _sourceUpdateSkipDateKey = 'source_update_skip_date';
  static const _softwareUpdateSkipDateKey = 'software_update_skip_date';
  static const _themeRevealSnapshotTimeout = Duration(milliseconds: 180);
  static const _themeRevealDuration = Duration(milliseconds: 920);

  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey _themeRepaintBoundaryKey = GlobalKey();
  final SourceRuntimeCoordinator _sourceRuntimeCoordinator =
      SourceRuntimeCoordinator();
  final SourceUpdateDialogSupport _sourceUpdateDialogSupport =
      const SourceUpdateDialogSupport();
  final SoftwareUpdateDialogSupport _softwareUpdateDialogSupport =
      const SoftwareUpdateDialogSupport();

  late final HazukiThemeController _themeController;
  late final HazukiAppController _appController;
  late final HazukiWindowsTitleBarController _windowsTitleBarController;
  late final AnimationController _themeRevealController;
  int _homeRefreshTick = 0;
  bool _allowDiscoverInitialLoad = false;
  SourceBootstrapState _bootstrapState = const SourceBootstrapState.idle();
  late Locale? _locale;
  bool _autoSourceUpdateCheckEnabled = true;
  bool _autoSoftwareUpdateCheckEnabled = true;
  bool _didAttemptAutoSourceUpdateCheck = false;
  bool _didAttemptAutoSoftwareUpdateCheck = false;
  ui.Image? _themeRevealImage;
  Offset? _themeRevealCenter;
  // 防止 _clearThemeRevealOverlay 在 reset() 触发 dismissed 回调时递归调用
  bool _clearingRevealOverlay = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _themeRevealController =
        AnimationController(vsync: this, duration: _themeRevealDuration)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed ||
                status == AnimationStatus.dismissed) {
              _clearThemeRevealOverlay();
            }
          });
    _themeController = HazukiThemeController(
      settingsStore: widget.settingsStore,
      initialSettings: widget.initialAppearance,
    );
    _windowsTitleBarController = HazukiWindowsTitleBarController(
      settingsStore: widget.settingsStore,
      initialUseSystemTitleBar: widget.initialUseSystemTitleBar,
    );
    _appController = HazukiAppController(
      settingsStore: widget.settingsStore,
      themeController: _themeController,
      windowsTitleBarController: _windowsTitleBarController,
      reloadLocale: _reloadLocalePreference,
      refreshHome: _refreshHome,
    );
    _locale = widget.initialLocale;
    unawaited(_loadAutoUpdateCheckSettings());
    unawaited(
      _sourceRuntimeCoordinator.initConnectivityWatcher(
        scheduleSourceRecovery: _scheduleSourceRecovery,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(
        _sourceRuntimeCoordinator.bootstrapSourceRuntime(
          isMounted: () => mounted,
          onBootstrapStateChanged: _updateBootstrapState,
          onSourceReady: _handleSourceRuntimeReady,
          scheduleSourceUpdateDialogCheck: _scheduleAutomaticSourceUpdateCheck,
        ),
      );
    });
    unawaited(CloudSyncService.instance.autoSyncOnce());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    MangaDownloadService.instance.handleAppLifecycleState(state);
    unawaited(PasswordLockService.instance.handleAppLifecycleState(state));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _themeRevealController.dispose();
    _themeRevealImage?.dispose();
    _themeController.dispose();
    _windowsTitleBarController.dispose();
    unawaited(_sourceRuntimeCoordinator.dispose());
    super.dispose();
  }

  Future<void> _updateAppearance(
    AppearanceSettingsData next, {
    Offset? revealOrigin,
  }) async {
    final current = _themeController.settings;
    final shouldAnimate =
        revealOrigin != null &&
        _resolveThemeBrightness(current.themeMode) !=
            _resolveThemeBrightness(next.themeMode);

    _logThemeEvent(
      'Theme update requested',
      content: {
        'fromThemeMode': current.themeMode.name,
        'toThemeMode': next.themeMode.name,
        'fromBrightness': _resolveThemeBrightness(current.themeMode).name,
        'toBrightness': _resolveThemeBrightness(next.themeMode).name,
        'hasRevealOrigin': revealOrigin != null,
        'shouldAnimateReveal': shouldAnimate,
        if (revealOrigin != null) ...{
          'originX': revealOrigin.dx.round(),
          'originY': revealOrigin.dy.round(),
        },
      },
    );

    if (!shouldAnimate) {
      _logThemeEvent(
        'Theme update applying without reveal animation',
        content: {'targetThemeMode': next.themeMode.name},
      );
      await _themeController.update(next);
      _logThemeEvent(
        'Theme update finished without reveal animation',
        content: {'activeThemeMode': _themeController.themeMode.name},
      );
      return;
    }

    _clearThemeRevealOverlay();
    final snapshot = await _captureThemeRevealSnapshot(revealOrigin);
    if (snapshot != null && mounted) {
      setState(() {
        _themeRevealImage = snapshot.image;
        _themeRevealCenter = snapshot.center;
      });
      _logThemeEvent(
        'Theme reveal snapshot captured',
        content: {
          'centerX': snapshot.center.dx.round(),
          'centerY': snapshot.center.dy.round(),
          'imageWidth': snapshot.image.width,
          'imageHeight': snapshot.image.height,
        },
      );
    } else {
      _logThemeEvent(
        'Theme reveal snapshot unavailable',
        level: 'warning',
        content: {'reason': 'snapshot_null_or_unmounted'},
      );
    }

    await _themeController.update(next);
    _logThemeEvent(
      'Theme controller update completed',
      content: {'activeThemeMode': _themeController.themeMode.name},
    );

    if (snapshot == null || !mounted) {
      _logThemeEvent(
        'Theme reveal animation skipped after update',
        level: 'warning',
        content: {'snapshotAvailable': snapshot != null, 'mounted': mounted},
      );
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _themeRevealImage == null) {
        _logThemeEvent(
          'Theme reveal animation start skipped',
          level: 'warning',
          content: {
            'mounted': mounted,
            'hasRevealImage': _themeRevealImage != null,
          },
        );
        return;
      }
      _logThemeEvent(
        'Theme reveal animation started',
        content: {
          'centerX': _themeRevealCenter?.dx.round(),
          'centerY': _themeRevealCenter?.dy.round(),
        },
      );
      // reset() 已在 _clearThemeRevealOverlay 中将 controller 归零，
      // 直接 forward() 即可，无需再传 from:0（避免重复触发 dismissed 回调）。
      _themeRevealController.forward();
    });
  }

  Future<void> _updateLocalePreference(Locale? locale) async {
    final effectiveLocale = await widget.settingsStore.saveLocalePreference(
      locale,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _locale = effectiveLocale;
    });
  }

  Future<void> _reloadLocalePreference() async {
    final locale = await widget.settingsStore.loadLocalePreference();
    if (!mounted) {
      _locale = locale;
      return;
    }
    setState(() {
      _locale = locale;
    });
  }

  Brightness _resolveThemeBrightness(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system =>
        WidgetsBinding.instance.platformDispatcher.platformBrightness,
    };
  }

  Future<_ThemeRevealSnapshot?> _captureThemeRevealSnapshot(
    Offset revealOrigin,
  ) async {
    final boundary = await _findThemeRepaintBoundary();
    if (boundary == null) {
      _logThemeEvent(
        'Theme reveal boundary not found',
        level: 'warning',
        content: {
          'originX': revealOrigin.dx.round(),
          'originY': revealOrigin.dy.round(),
        },
      );
      return null;
    }

    try {
      final pixelRatio =
          View.maybeOf(
            _themeRepaintBoundaryKey.currentContext!,
          )?.devicePixelRatio ??
          WidgetsBinding
              .instance
              .platformDispatcher
              .views
              .first
              .devicePixelRatio;
      _logThemeEvent(
        'Theme reveal snapshot capture started',
        content: {
          'pixelRatio': pixelRatio,
          'originX': revealOrigin.dx.round(),
          'originY': revealOrigin.dy.round(),
        },
      );
      final image = await boundary
          .toImage(pixelRatio: pixelRatio)
          .timeout(_themeRevealSnapshotTimeout);
      final localCenter = boundary.globalToLocal(revealOrigin);
      return _ThemeRevealSnapshot(image: image, center: localCenter);
    } on TimeoutException {
      _logThemeEvent(
        'Theme reveal snapshot capture timed out',
        level: 'warning',
        content: {
          'timeoutMs': _themeRevealSnapshotTimeout.inMilliseconds,
          'originX': revealOrigin.dx.round(),
          'originY': revealOrigin.dy.round(),
        },
      );
      return null;
    } catch (error, stackTrace) {
      _logThemeEvent(
        'Theme reveal snapshot capture failed',
        level: 'error',
        content: {
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
      return null;
    }
  }

  Future<RenderRepaintBoundary?> _findThemeRepaintBoundary() async {
    RenderRepaintBoundary? boundary() =>
        _themeRepaintBoundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;

    var candidate = boundary();
    if (candidate == null) {
      _logThemeEvent(
        'Theme reveal boundary lookup returned null',
        level: 'warning',
      );
      return null;
    }
    // 等待当前帧绘制完成再截图，确保 RepaintBoundary 内容是最新状态。
    // 注意：不使用 debugNeedsPaint，该属性仅在 debug 模式下有效，
    // release 模式下 assert 被裁剪会导致 LateInitializationError。
    await WidgetsBinding.instance.endOfFrame;
    candidate = boundary();
    _logThemeEvent(
      'Theme reveal boundary resolved',
      content: {
        'width': candidate?.size.width.round(),
        'height': candidate?.size.height.round(),
      },
    );
    return candidate;
  }

  void _clearThemeRevealOverlay() {
    // 防重入：reset() 会触发 dismissed 状态回调，导致此函数被递归调用
    if (_clearingRevealOverlay) return;
    _clearingRevealOverlay = true;

    try {
      final hadOverlay =
          _themeRevealImage != null || _themeRevealCenter != null;
      // 使用 reset() 而非 stop()：将 controller 归零并触发状态变化，
      // 确保下次 forward() 时 controller 已处于 dismissed(0)，
      // 避免 forward(from:0) 因状态从 completed→dismissed 再次触发此回调。
      _themeRevealController.reset();
      final image = _themeRevealImage;
      if (mounted && (image != null || _themeRevealCenter != null)) {
        setState(() {
          _themeRevealImage = null;
          _themeRevealCenter = null;
        });
        if (image != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            image.dispose();
          });
        }
      } else {
        _themeRevealImage = null;
        _themeRevealCenter = null;
        image?.dispose();
      }
      if (hadOverlay) {
        _logThemeEvent('Theme reveal overlay cleared');
      }
    } finally {
      _clearingRevealOverlay = false;
    }
  }

  void _logThemeEvent(
    String title, {
    String level = 'info',
    Map<String, Object?>? content,
  }) {
    HazukiSourceService.instance.addApplicationLog(
      level: level,
      title: title,
      source: 'theme_switch',
      content: {
        'activeThemeMode': _themeController.themeMode.name,
        'platformBrightness':
            WidgetsBinding.instance.platformDispatcher.platformBrightness.name,
        'mounted': mounted,
        if (content != null) ...content,
      },
    );
  }

  void _scheduleSourceRecovery() {
    _sourceRuntimeCoordinator.scheduleSourceRecovery(
      isMounted: () => mounted,
      scheduleSourceUpdateDialogCheck: _scheduleAutomaticSourceUpdateCheck,
    );
  }

  Future<void> _loadAutoUpdateCheckSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final sourceEnabled =
        prefs.getBool(hazukiAutoSourceUpdateCheckEnabledPreferenceKey) ?? true;
    final softwareEnabled =
        prefs.getBool(hazukiAutoSoftwareUpdateCheckEnabledPreferenceKey) ??
        true;
    if (!mounted) {
      _autoSourceUpdateCheckEnabled = sourceEnabled;
      _autoSoftwareUpdateCheckEnabled = softwareEnabled;
      return;
    }
    setState(() {
      _autoSourceUpdateCheckEnabled = sourceEnabled;
      _autoSoftwareUpdateCheckEnabled = softwareEnabled;
    });
  }

  void _scheduleAutomaticSourceUpdateCheck() {
    if (_didAttemptAutoSourceUpdateCheck || !_autoSourceUpdateCheckEnabled) {
      return;
    }
    _didAttemptAutoSourceUpdateCheck = true;
    _scheduleSourceUpdateDialogCheck();
  }

  void _scheduleAutomaticSoftwareUpdateCheck() {
    if (_didAttemptAutoSoftwareUpdateCheck ||
        !_autoSoftwareUpdateCheckEnabled) {
      return;
    }
    _didAttemptAutoSoftwareUpdateCheck = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_runSoftwareUpdateDialogCheckWhenIdle());
    });
  }

  Future<void> _runSoftwareUpdateDialogCheckWhenIdle() async {
    for (var attempt = 0; attempt < 10; attempt++) {
      if (!mounted) {
        return;
      }
      final navigator = _navigatorKey.currentState;
      if (!(navigator?.canPop() ?? false)) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 800));
    }

    if (!mounted) {
      return;
    }

    final result = await _softwareUpdateDialogSupport.showIfNeeded(
      navigatorKey: _navigatorKey,
      isMounted: () => mounted,
      skipPrefsKey: _softwareUpdateSkipDateKey,
    );
    if (!mounted) {
      return;
    }
    if (result == null) {
      return;
    }
  }

  void _scheduleSourceUpdateDialogCheck() {
    _sourceRuntimeCoordinator.scheduleSourceUpdateDialogCheck(
      isMounted: () => mounted,
      showDialogIfNeeded: _showSourceUpdateDialogIfNeeded,
      onSourceDownloaded: _handleSourceUpdateDownloaded,
    );
  }

  Future<SourceUpdateDialogAction?> _showSourceUpdateDialogIfNeeded() async {
    return _sourceUpdateDialogSupport.showIfNeeded(
      navigatorKey: _navigatorKey,
      isMounted: () => mounted,
      skipPrefsKey: _sourceUpdateSkipDateKey,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _themeController,
      builder: (context, _) {
        final appearance = _themeController.settings;
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
              navigatorObservers: [hazukiPromptNavigatorObserver],
              themeMode: _themeController.themeMode,
              theme: HazukiThemeFactory.buildLight(appearance, lightDynamic),
              darkTheme: HazukiThemeFactory.buildDark(appearance, darkDynamic),
              builder: (context, child) {
                return HazukiAppControllerScope(
                  controller: _appController,
                  child: HazukiWindowsTitleBarScope(
                    controller: _windowsTitleBarController,
                    child: HazukiThemeControllerScope(
                      controller: _themeController,
                      child: RepaintBoundary(
                        key: _themeRepaintBoundaryKey,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _HazukiWindowFrame(child: child),
                            if (_themeRevealImage != null &&
                                _themeRevealCenter != null)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: AnimatedBuilder(
                                    animation: _themeRevealController,
                                    builder: (context, _) {
                                      return _ThemeRevealOverlay(
                                        image: _themeRevealImage!,
                                        center: _themeRevealCenter!,
                                        progress: _themeRevealController.value,
                                      );
                                    },
                                  ),
                                ),
                              ),
                            Positioned.fill(
                              child: IgnorePointer(
                                ignoring:
                                    !_bootstrapState.showOverlay &&
                                    !_bootstrapState.showIntro,
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
                                  child: InitialSourceBootstrapOverlay(
                                    showOverlay: _bootstrapState.showOverlay,
                                    showIntro: _bootstrapState.showIntro,
                                    indeterminate:
                                        _bootstrapState.indeterminate,
                                    progress: _bootstrapState.progress,
                                    errorText: _bootstrapState.errorText,
                                  ),
                                ),
                              ),
                            ),
                            ListenableBuilder(
                              listenable: PasswordLockService.instance,
                              builder: (context, _) {
                                if (!PasswordLockService
                                    .instance
                                    .shouldBlockApp) {
                                  return const SizedBox.shrink();
                                }
                                return PasswordLockGateOverlay(
                                  controller: PasswordLockService.instance,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
              home: HazukiHomePage(
                appearanceSettings: appearance,
                onAppearanceChanged: _updateAppearance,
                locale: _locale,
                onLocaleChanged: _updateLocalePreference,
                allowDiscoverInitialLoad: _allowDiscoverInitialLoad,
                hideDiscoverLoadingUntilAllowed:
                    _bootstrapState.showOverlay || _bootstrapState.showIntro,
                refreshTick: _homeRefreshTick,
              ),
            );
          },
        );
      },
    );
  }

  void _handleSourceRuntimeReady() {
    if (!mounted) {
      return;
    }
    setState(() {
      _allowDiscoverInitialLoad = true;
      _homeRefreshTick++;
    });
    _scheduleAutomaticSoftwareUpdateCheck();
  }

  void _handleSourceUpdateDownloaded() {
    _refreshHome();
  }

  void _updateBootstrapState(SourceBootstrapState state) {
    if (!mounted) {
      return;
    }
    setState(() {
      if (state.showOverlay || state.showIntro) {
        _allowDiscoverInitialLoad = false;
      }
      _bootstrapState = state;
    });
  }

  void _refreshHome() {
    if (!mounted) {
      return;
    }
    setState(() {
      _homeRefreshTick++;
    });
  }
}

class _HazukiWindowFrame extends StatelessWidget {
  const _HazukiWindowFrame({required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final effectiveChild = child ?? const SizedBox.shrink();
    final titleBarController = HazukiWindowsTitleBarScope.of(context);
    return ListenableBuilder(
      listenable: titleBarController,
      builder: (context, _) {
        if (!titleBarController.shouldShowCustomTitleBar) {
          return effectiveChild;
        }
        return Column(
          children: [
            TextSelectionTheme(
              data: const TextSelectionThemeData(
                selectionColor: Colors.transparent,
                selectionHandleColor: Colors.transparent,
              ),
              child: const HazukiWindowsCustomTitleBar(),
            ),
            Expanded(child: effectiveChild),
          ],
        );
      },
    );
  }
}

class _ThemeRevealSnapshot {
  const _ThemeRevealSnapshot({required this.image, required this.center});

  final ui.Image image;
  final Offset center;
}

class _ThemeRevealOverlay extends StatelessWidget {
  const _ThemeRevealOverlay({
    required this.image,
    required this.center,
    required this.progress,
  });

  static const Curve _radiusCurve = Cubic(0.22, 0.0, 0.12, 1.0);
  static const Curve _overlayFadeCurve = Cubic(0.3, 0.0, 0.18, 1.0);
  static const double _radiusStartDelay = 0.025;

  final ui.Image image;
  final Offset center;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final delayedProgress =
            ((progress - _radiusStartDelay) / (1 - _radiusStartDelay)).clamp(
              0.0,
              1.0,
            );
        final radiusProgress = _radiusCurve.transform(delayedProgress);
        final overlayOpacity =
            1 -
            _overlayFadeCurve.transform(
              const Interval(0.68, 1.0).transform(progress),
            );
        final radius = _resolveRevealRadius(size, center, radiusProgress);
        return Opacity(
          opacity: overlayOpacity.clamp(0.0, 1.0),
          child: CustomPaint(
            size: size,
            painter: _ThemeRevealPainter(
              image: image,
              center: center,
              radius: radius,
            ),
          ),
        );
      },
    );
  }

  double _resolveRevealRadius(Size size, Offset center, double progress) {
    final distances = <double>[
      (center - Offset.zero).distance,
      (center - Offset(size.width, 0)).distance,
      (center - Offset(0, size.height)).distance,
      (center - Offset(size.width, size.height)).distance,
    ];
    final maxDistance = distances.reduce(math.max);
    final overscan = math.max(size.longestSide * 0.08, 18.0);
    return (maxDistance + overscan) * progress;
  }
}

class _ThemeRevealPainter extends CustomPainter {
  const _ThemeRevealPainter({
    required this.image,
    required this.center,
    required this.radius,
  });

  final ui.Image image;
  final Offset center;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final destination = Offset.zero & size;
    final source = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );

    canvas.saveLayer(destination, Paint());
    canvas.drawImageRect(image, source, destination, Paint());
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..blendMode = BlendMode.clear
        ..isAntiAlias = true,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ThemeRevealPainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.center != center ||
        oldDelegate.radius != radius;
  }
}

// ignore: unused_element
class _ThemeRevealClipper extends CustomClipper<Path> {
  const _ThemeRevealClipper({required this.center, required this.radius});

  final Offset center;
  final double radius;

  @override
  Path getClip(Size size) {
    // 使用 evenOdd 填充规则：矩形 + 圆形叠加后，圆内区域被剪去，
    // 只保留圆形以外的旧主题截图，随动画进度圆半径扩大，覆盖区域收缩直至消失
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(Rect.fromCircle(center: center, radius: radius));
  }

  @override
  bool shouldReclip(covariant _ThemeRevealClipper oldClipper) {
    return oldClipper.center != center || oldClipper.radius != radius;
  }
}
