import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app/app_settings_store.dart';
import 'app/app_startup_coordinator.dart';
import 'app/appearance_settings.dart';
import 'app/hazuki_app_controller.dart';
import 'app/service_locator.dart';
import 'app/startup/app_bootstrap.dart';
import 'app/theme/hazuki_theme_controller.dart';
import 'app/theme/hazuki_theme_factory.dart';
import 'app/launch_shortcut_bridge.dart';
import 'app/launch_shortcut_coordinator.dart';
import 'app/source_runtime/source_runtime_coordinator.dart';
import 'app/source_runtime/source_runtime_bootstrap_overlay.dart';
import 'app/source_runtime/source_update_dialog_support.dart';
import 'app/theme/theme_reveal_support.dart';
import 'app/windows/windows_title_bar_controller.dart';
import 'app/software_update/software_update_dialog_support.dart';
import 'features/comic_detail/view/comic_detail_page.dart';
import 'features/comments/comments.dart';
import 'features/discover/view/discover_section_page.dart';
import 'features/reader/view/reader_page.dart';
import 'features/search/search.dart';
import 'l10n/app_localizations.dart';
import 'l10n/l10n.dart';
import 'package:hazuki/features/home/view/home_page.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'services/cloud_sync_service.dart';
import 'services/hazuki_source_service.dart';
import 'services/manga_download/manga_download_service.dart';
import 'services/password_lock_service.dart';
import 'services/source/source_capabilities.dart';
import 'shared/comments/comments_widget_builder.dart';
import 'widgets/hazuki_prompt.dart';
import 'widgets/source_image_gateway_scope.dart';
import 'features/password_lock/view/password_lock_widgets.dart';

Future<void> main() async {
  final bootstrap = await bootstrapApp();
  runApp(
    HazukiApp(
      settingsStore: bootstrap.settingsStore,
      initialAppearance: bootstrap.initialAppearance,
      initialLocale: bootstrap.initialLocale,
      initialUseSystemTitleBar: bootstrap.initialUseSystemTitleBar,
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
  late final HazukiLaunchShortcutCoordinator _launchShortcutCoordinator;
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
    _launchShortcutCoordinator = HazukiLaunchShortcutCoordinator(
      navigatorKey: _navigatorKey,
      actionSource: HazukiLaunchShortcutBridge(),
      isMounted: () => mounted,
      handleAction: _handleLaunchShortcutAction,
    );
    _appController = HazukiAppController(
      settingsStore: widget.settingsStore,
      themeController: _themeController,
      windowsTitleBarController: _windowsTitleBarController,
      sourceRuntime: sl<SourceRuntimeGateway>(),
      reloadLocale: _reloadLocalePreference,
      refreshHome: _startupCoordinator.refreshHome,
    );
    _appListenable = Listenable.merge([_themeController, _startupCoordinator]);
    _locale = widget.initialLocale;
    _startupCoordinator.initialize();
    _launchShortcutCoordinator.initialize();
    unawaited(sl<CloudSyncService>().autoSyncOnce());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    sl<MangaDownloadService>().handleAppLifecycleState(state);
    unawaited(sl<PasswordLockService>().handleAppLifecycleState(state));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _launchShortcutCoordinator.dispose();
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
    sl<HazukiSourceService>().clearLocalizedSourceTextCaches();
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
    sl<HazukiSourceService>().clearLocalizedSourceTextCaches();
  }

  Brightness _resolveThemeBrightness(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system =>
        WidgetsBinding.instance.platformDispatcher.platformBrightness,
    };
  }

  static Widget _buildCommentsPage({
    required String comicId,
    String? subId,
    required String sourceKey,
    ScrollController? scrollController,
    Future<void> Function()? onRequestTabFullscreen,
    bool showAppBar = false,
    bool isTabView = false,
    bool isActiveInTabView = true,
    Map<String, Object?> Function()? debugOuterScrollStateBuilder,
  }) => CommentsPage(
    comicId: comicId,
    subId: subId,
    sourceKey: sourceKey,
    showAppBar: showAppBar,
    isTabView: isTabView,
    isActiveInTabView: isActiveInTabView,
    scrollController: scrollController,
    onRequestTabFullscreen: onRequestTabFullscreen,
    debugOuterScrollStateBuilder: debugOuterScrollStateBuilder,
  );

  static final ReaderCommentsWidgetBuilder _buildReaderCommentsPage =
      readerCommentsWidgetBuilderFrom(_buildCommentsPage);

  Widget _buildRootComicDetailPage(ExploreComic comic, String heroTag) {
    return ComicDetailPage(
      comic: comic,
      heroTag: heroTag,
      readerWidgetBuilder:
          ({
            required title,
            required chapterTitle,
            required comicId,
            required epId,
            required chapterIndex,
            required images,
            required sourceKey,
            comicTheme,
            onFavoriteRequested,
          }) => ReaderPage(
            title: title,
            chapterTitle: chapterTitle,
            comicId: comicId,
            epId: epId,
            chapterIndex: chapterIndex,
            images: images,
            sourceKey: sourceKey,
            comicTheme: comicTheme,
            onFavoriteRequested: onFavoriteRequested,
            commentsWidgetBuilder: _buildReaderCommentsPage,
          ),
      searchPageBuilder: (initialKeyword) => SearchPage(
        initialKeyword: initialKeyword,
        comicDetailPageBuilder: _buildRootComicDetailPage,
      ),
      commentsWidgetBuilder: _buildCommentsPage,
      categoryPageBuilder:
          ({
            required title,
            required viewMoreUrl,
            required comicDetailPageBuilder,
          }) => DiscoverSectionPage(
            section: ExploreSection(
              title: title,
              comics: const <ExploreComic>[],
              viewMoreUrl: viewMoreUrl,
            ),
            comicDetailPageBuilder: comicDetailPageBuilder,
          ),
    );
  }

  Future<void> _handleLaunchShortcutAction(
    HazukiLaunchShortcutAction action,
  ) async {
    switch (action) {
      case HazukiLaunchShortcutAction.search:
        await _navigatorKey.currentState?.push<void>(
          MaterialPageRoute<void>(
            builder: (_) =>
                SearchPage(comicDetailPageBuilder: _buildRootComicDetailPage),
          ),
        );
    }
  }

  void _logThemeEvent(
    String title, {
    String level = 'info',
    Map<String, Object?>? content,
  }) {
    sl<HazukiSourceService>().addApplicationLog(
      level: level,
      title: title,
      source: 'theme_switch',
      content: {
        'activeThemeMode': _themeController.themeMode.name,
        'platformBrightness':
            WidgetsBinding.instance.platformDispatcher.platformBrightness.name,
        'mounted': mounted,
        ...?content,
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
                final app = HazukiAppControllerScope(
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
                              listenable: sl<PasswordLockService>(),
                              builder: (context, _) {
                                if (!sl<PasswordLockService>().shouldBlockApp) {
                                  return const SizedBox.shrink();
                                }
                                return PasswordLockGateOverlay(
                                  controller: sl<PasswordLockService>(),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
                return SourceImageGatewayScope(
                  gateway: sl<SourceImageGateway>(),
                  sourceListenable: sl<SourceRuntimeGateway>(),
                  child: app,
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
