import 'dart:async';
import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app/app_settings_store.dart';
import 'app/appearance_settings.dart';
import 'app/hazuki_theme_controller.dart';
import 'app/hazuki_theme_factory.dart';
import 'app/source_runtime_coordinator.dart';
import 'app/source_runtime_widgets.dart';
import 'app/source_update_dialog_support.dart';
import 'app/ui_flags.dart';
import 'l10n/app_localizations.dart';
import 'l10n/l10n.dart';
import 'pages/home_page.dart';
import 'services/cloud_sync_service.dart';
import 'services/hazuki_source_service.dart';
import 'services/manga_download_service.dart';

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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadHazukiUiFlags();
  await HazukiSourceService.instance.loadSoftwareLogCaptureEnabled();
  await _ensureAndroidNoMediaMarker();
  await MangaDownloadService.instance.ensureInitialized();
  const settingsStore = HazukiAppSettingsStore();
  final initialAppearance = await settingsStore.loadAppearance();
  final initialLocale = await settingsStore.loadLocalePreference();
  runApp(
    HazukiApp(
      settingsStore: settingsStore,
      initialAppearance: initialAppearance,
      initialLocale: initialLocale,
    ),
  );
}

class HazukiApp extends StatefulWidget {
  const HazukiApp({
    super.key,
    required this.settingsStore,
    required this.initialAppearance,
    required this.initialLocale,
  });

  final HazukiAppSettingsStore settingsStore;
  final AppearanceSettingsData initialAppearance;
  final Locale? initialLocale;

  @override
  State<HazukiApp> createState() => _HazukiAppState();
}

class _HazukiAppState extends State<HazukiApp> with WidgetsBindingObserver {
  static const _sourceUpdateSkipDateKey = 'source_update_skip_date';

  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final SourceRuntimeCoordinator _sourceRuntimeCoordinator =
      SourceRuntimeCoordinator();
  final SourceUpdateDialogSupport _sourceUpdateDialogSupport =
      const SourceUpdateDialogSupport();

  late final HazukiThemeController _themeController;
  int _homeRefreshTick = 0;
  bool _allowDiscoverInitialLoad = false;
  SourceBootstrapState _bootstrapState = const SourceBootstrapState.idle();
  late Locale? _locale;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _themeController = HazukiThemeController(
      settingsStore: widget.settingsStore,
      initialSettings: widget.initialAppearance,
    );
    _locale = widget.initialLocale;
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
          scheduleSourceUpdateDialogCheck: _scheduleSourceUpdateDialogCheck,
        ),
      );
    });
    unawaited(CloudSyncService.instance.autoSyncOnce());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    MangaDownloadService.instance.handleAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _scheduleSourceUpdateDialogCheck();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _themeController.dispose();
    unawaited(_sourceRuntimeCoordinator.dispose());
    super.dispose();
  }

  Future<void> _updateAppearance(AppearanceSettingsData next) async {
    await _themeController.update(next);
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

  void _scheduleSourceRecovery() {
    _sourceRuntimeCoordinator.scheduleSourceRecovery(
      isMounted: () => mounted,
      scheduleSourceUpdateDialogCheck: _scheduleSourceUpdateDialogCheck,
    );
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
              themeMode: _themeController.themeMode,
              theme: HazukiThemeFactory.buildLight(appearance, lightDynamic),
              darkTheme: HazukiThemeFactory.buildDark(appearance, darkDynamic),
              builder: (context, child) {
                return Stack(
                  children: [
                    // ignore: use_null_aware_elements
                    if (child != null) child,
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
                            indeterminate: _bootstrapState.indeterminate,
                            progress: _bootstrapState.progress,
                            errorText: _bootstrapState.errorText,
                          ),
                        ),
                      ),
                    ),
                  ],
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
  }

  void _handleSourceUpdateDownloaded() {
    if (!mounted) {
      return;
    }
    setState(() {
      _homeRefreshTick++;
    });
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
}
