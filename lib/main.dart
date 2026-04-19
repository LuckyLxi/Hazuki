import 'dart:async';
import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app_settings_store.dart';
import 'app/app_startup_coordinator.dart';
import 'app/appearance_settings.dart';
import 'app/hazuki_app_controller.dart';
import 'app/hazuki_theme_controller.dart';
import 'app/hazuki_theme_factory.dart';
import 'app/software_update_dialog_support.dart';
import 'app/source_runtime_coordinator.dart';
import 'app/source_runtime_widgets.dart';
import 'app/source_update_dialog_support.dart';
import 'app/theme_reveal_support.dart';
import 'app/ui_flags.dart';
import 'app/windows_title_bar_controller.dart';
import 'l10n/app_localizations.dart';
import 'l10n/l10n.dart';
import 'package:hazuki/features/home/view/home_page.dart';
import 'services/cloud_sync_service.dart';
import 'services/hazuki_source_service.dart';
import 'services/manga_download_service.dart';
import 'services/manga_download_storage_support.dart';
import 'services/password_lock_service.dart';
import 'widgets/hazuki_prompt.dart';
import 'widgets/password_lock_widgets.dart';

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
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final SourceRuntimeCoordinator _sourceRuntimeCoordinator =
      SourceRuntimeCoordinator();
  final SourceUpdateDialogSupport _sourceUpdateDialogSupport =
      const SourceUpdateDialogSupport();
  final SoftwareUpdateDialogSupport _softwareUpdateDialogSupport =
      const SoftwareUpdateDialogSupport();

  late final HazukiThemeController _themeController;
  late final HazukiAppController _appController;
  late final HazukiWindowsTitleBarController _windowsTitleBarController;
  late final HazukiThemeRevealSupport _themeRevealSupport;
  late final HazukiAppStartupCoordinator _startupCoordinator;
  late final Listenable _appListenable;
  late Locale? _locale;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _themeController = HazukiThemeController(
      settingsStore: widget.settingsStore,
      initialSettings: widget.initialAppearance,
    );
    _windowsTitleBarController = HazukiWindowsTitleBarController(
      settingsStore: widget.settingsStore,
      initialUseSystemTitleBar: widget.initialUseSystemTitleBar,
    );
    _themeRevealSupport = HazukiThemeRevealSupport(
      vsync: this,
      isMounted: () => mounted,
      requestRebuild: () {
        if (mounted) {
          setState(() {});
        }
      },
      logEvent: _logThemeEvent,
    );
    _startupCoordinator = HazukiAppStartupCoordinator(
      navigatorKey: _navigatorKey,
      sourceRuntimeCoordinator: _sourceRuntimeCoordinator,
      sourceUpdateDialogSupport: _sourceUpdateDialogSupport,
      softwareUpdateDialogSupport: _softwareUpdateDialogSupport,
      isMounted: () => mounted,
    );
    _appController = HazukiAppController(
      settingsStore: widget.settingsStore,
      themeController: _themeController,
      windowsTitleBarController: _windowsTitleBarController,
      reloadLocale: _reloadLocalePreference,
      refreshHome: _startupCoordinator.refreshHome,
    );
    _appListenable = Listenable.merge([_themeController, _startupCoordinator]);
    _locale = widget.initialLocale;
    _startupCoordinator.initialize();
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
    _themeRevealSupport.dispose();
    _themeController.dispose();
    _startupCoordinator.dispose();
    _windowsTitleBarController.dispose();
    unawaited(_startupCoordinator.close());
    super.dispose();
  }

  Future<void> _updateAppearance(
    AppearanceSettingsData next, {
    Offset? revealOrigin,
  }) async {
    await _themeRevealSupport.updateAppearance(
      current: _themeController.settings,
      next: next,
      applyTheme: _themeController.update,
      resolveThemeBrightness: _resolveThemeBrightness,
      revealOrigin: revealOrigin,
    );
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _appListenable,
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
                        key: _themeRevealSupport.repaintBoundaryKey,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            HazukiWindowFrame(child: child),
                            if (_themeRevealSupport.revealImage != null &&
                                _themeRevealSupport.revealCenter != null)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: AnimatedBuilder(
                                    animation: _themeRevealSupport.controller,
                                    builder: (context, _) {
                                      return ThemeRevealOverlay(
                                        image: _themeRevealSupport.revealImage!,
                                        center:
                                            _themeRevealSupport.revealCenter!,
                                        progress: _themeRevealSupport
                                            .controller
                                            .value,
                                      );
                                    },
                                  ),
                                ),
                              ),
                            Positioned.fill(
                              child: IgnorePointer(
                                ignoring:
                                    !_startupCoordinator
                                        .bootstrapState
                                        .showOverlay &&
                                    !_startupCoordinator
                                        .bootstrapState
                                        .showIntro,
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
                                    showOverlay: _startupCoordinator
                                        .bootstrapState
                                        .showOverlay,
                                    showIntro: _startupCoordinator
                                        .bootstrapState
                                        .showIntro,
                                    indeterminate: _startupCoordinator
                                        .bootstrapState
                                        .indeterminate,
                                    progress: _startupCoordinator
                                        .bootstrapState
                                        .progress,
                                    errorText: _startupCoordinator
                                        .bootstrapState
                                        .errorText,
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
                allowDiscoverInitialLoad:
                    _startupCoordinator.allowDiscoverInitialLoad,
                hideDiscoverLoadingUntilAllowed:
                    _startupCoordinator.bootstrapState.showOverlay ||
                    _startupCoordinator.bootstrapState.showIntro,
                refreshTick: _startupCoordinator.homeRefreshTick,
              ),
            );
          },
        );
      },
    );
  }
}
