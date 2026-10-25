import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter/scheduler.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/features/home/support/home_feature_contracts.dart';
import 'package:hazuki/shared/favorites/favorite_app_bar_actions_state.dart';
import 'package:hazuki/shared/favorites/favorite_folders_button_morph.dart';
import 'package:hazuki/shared/source_account/source_account_actions.dart';
import 'package:hazuki/shared/search_box_outline.dart';
import 'package:hazuki/shared/appearance/appearance_settings_scope.dart';
import 'package:hazuki/shared/discover_back_to_top_notification.dart';
import 'package:hazuki/shared/liquid_glass_support.dart';
import 'package:hazuki/widgets/widgets.dart';
import 'package:hazuki/widgets/windows_comic_detail_host.dart';

import 'home_app_bar_actions.dart';
import 'home_bottom_navigation.dart';
import 'home_content_stack.dart';
import 'home_drawer_snapshot.dart';
import 'package:hazuki/features/home/view/home_drawer.dart';

part 'home_scaffold_app_bar.dart';
part 'home_scaffold_drawer.dart';

class HomeScaffoldShell extends StatefulWidget {
  const HomeScaffoldShell({
    super.key,
    required this.scaffoldKey,
    required this.currentIndex,
    required this.discoverSearchMorphProgress,
    required this.usePinnedDiscoverSearch,
    required this.downloadStatus,
    required this.activeSourceKey,
    required this.supportsSourceAccount,
    required this.discoverChild,
    required this.favoriteChild,
    required this.favoriteAppBarActions,
    this.sourcePlugins,
    required this.showFavoriteBackToTop,
    required this.isLogged,
    required this.profileLoading,
    required this.avatarUrl,
    required this.username,
    required this.autoCheckInEnabled,
    required this.showCheckInActions,
    required this.checkInBusy,
    required this.checkedInToday,
    required this.onWillPop,
    required this.onExitRequested,
    required this.onOpenSearch,
    required this.onFavoriteSortSelected,
    required this.onFavoriteCreateFolderPressed,
    required this.onFavoriteModeTogglePressed,
    required this.onFavoriteBackToTopPressed,
    required this.onProfileTap,
    required this.onCheckInPressed,
    required this.onSwitchSourcePressed,
    this.sourceSwitchService,
    this.onSourceSwitched,
    required this.onOpenHistory,
    required this.onOpenCategories,
    required this.onOpenRanking,
    required this.onOpenDownloads,
    required this.onOpenDownloadTasks,
    required this.onOpenSettings,
    this.onOpenAnnouncements,
    required this.onOpenLines,
    this.selectedDrawerDestination,
    this.unreadAnnouncementCount = 0,
    required this.onDestinationSelected,
  });

  final GlobalKey<ScaffoldState> scaffoldKey;
  final int currentIndex;
  final double discoverSearchMorphProgress;
  final bool usePinnedDiscoverSearch;
  final HomeDownloadStatusListenable downloadStatus;
  final String activeSourceKey;
  final bool supportsSourceAccount;
  final Widget discoverChild;
  final Widget favoriteChild;
  final FavoriteAppBarActionsState favoriteAppBarActions;
  final SourcePluginGateway? sourcePlugins;
  final bool showFavoriteBackToTop;
  final bool isLogged;
  final bool profileLoading;
  final String? avatarUrl;
  final String username;
  final bool autoCheckInEnabled;
  final bool showCheckInActions;
  final bool checkInBusy;
  final bool checkedInToday;
  final Future<bool> Function() onWillPop;
  final Future<void> Function() onExitRequested;
  final VoidCallback onOpenSearch;
  final ValueChanged<String> onFavoriteSortSelected;
  final VoidCallback onFavoriteCreateFolderPressed;
  final VoidCallback onFavoriteModeTogglePressed;
  final VoidCallback onFavoriteBackToTopPressed;
  final VoidCallback? onProfileTap;
  final FutureOr<void> Function()? onCheckInPressed;
  final VoidCallback? onSwitchSourcePressed;
  final SourceRuntimeGateway? sourceSwitchService;
  final Future<void> Function()? onSourceSwitched;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenCategories;
  final VoidCallback onOpenRanking;
  final VoidCallback onOpenDownloads;
  final VoidCallback onOpenDownloadTasks;
  final VoidCallback onOpenSettings;
  final VoidCallback? onOpenAnnouncements;
  final VoidCallback onOpenLines;
  final HomeDrawerDestination? selectedDrawerDestination;
  final int unreadAnnouncementCount;
  final ValueChanged<int> onDestinationSelected;

  @override
  State<HomeScaffoldShell> createState() => _HomeScaffoldShellState();
}

class _HomeScaffoldShellState extends State<HomeScaffoldShell>
    with TickerProviderStateMixin {
  final _sourceSwitchDialogOpen = ValueNotifier(false);
  final _sourceSwitchButtonKey = GlobalKey();
  final _homeContentAnimating = ValueNotifier(false);
  // 内容区与应用栏共享同一道切口过渡。
  late final _tabTransition = HomeTabCutTransition(
    vsync: this,
    initialIndex: widget.currentIndex,
    onTransitionChanged: _setHomeContentAnimating,
  );

  // 由显示设置控制，关闭时使用淡入滑动过渡。
  bool _cutTransitionEnabled = false;

  void _setHomeContentAnimating(bool animating) =>
      _homeContentAnimating.value = animating;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final enabled =
        HazukiThemeControllerScope.maybeOf(
          context,
        )?.settings.homeTabCutTransition ??
        false;
    if (enabled == _cutTransitionEnabled) return;
    _cutTransitionEnabled = enabled;
    // 换用另一种过渡后，原过渡的结束回调不再触发，这里直接复位。
    _tabTransition.jumpTo(widget.currentIndex);
    _homeContentAnimating.value = false;
  }

  @override
  void didUpdateWidget(HomeScaffoldShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_cutTransitionEnabled) {
      _tabTransition.jumpTo(widget.currentIndex);
      return;
    }
    // 在子树重建前切换，使应用栏与内容区在同一帧收到进度变化。
    _tabTransition.select(widget.currentIndex);
  }

  Future<void> _showSourceSwitchWithMorph(
    FavoriteFoldersMorphOrigin origin,
  ) async {
    if (_sourceSwitchDialogOpen.value) return;
    _sourceSwitchDialogOpen.value = true;
    var buttonRestored = false;
    void restoreButton() {
      if (buttonRestored) return;
      buttonRestored = true;
      if (mounted) _sourceSwitchDialogOpen.value = false;
    }

    try {
      await showHomeSourceSwitchDialog(
        context,
        sourceService: widget.sourceSwitchService!,
        onSourceSwitched: widget.onSourceSwitched,
        morphOrigin: origin,
        onDialogClosed: restoreButton,
      );
    } finally {
      restoreButton();
    }
  }

  bool _showDiscoverBackToTop = false;
  VoidCallback? _onDiscoverBackToTopPressed;
  static const _profileDrawerDuration = Duration(milliseconds: 210);
  static const _profileDrawerReverseDuration = Duration(milliseconds: 160);
  late final AnimationController _profileDrawerController = AnimationController(
    vsync: this,
    duration: _profileDrawerDuration,
    reverseDuration: _profileDrawerReverseDuration,
  );

  GlobalKey<ScaffoldState> get scaffoldKey => widget.scaffoldKey;
  int get currentIndex => widget.currentIndex;
  double get discoverSearchMorphProgress => widget.discoverSearchMorphProgress;
  bool get usePinnedDiscoverSearch => widget.usePinnedDiscoverSearch;
  HomeDownloadStatusListenable get downloadStatus => widget.downloadStatus;
  String get activeSourceKey => widget.activeSourceKey;
  bool get supportsSourceAccount => widget.supportsSourceAccount;
  String? get avatarUrl => widget.avatarUrl;
  bool get profileLoading => widget.profileLoading;
  String get username => widget.username;
  FavoriteAppBarActionsState get favoriteAppBarActions =>
      widget.favoriteAppBarActions;
  Future<bool> Function() get onWillPop => widget.onWillPop;
  Future<void> Function() get onExitRequested => widget.onExitRequested;
  VoidCallback get onOpenSearch => widget.onOpenSearch;
  ValueChanged<String> get onFavoriteSortSelected =>
      widget.onFavoriteSortSelected;
  VoidCallback get onFavoriteCreateFolderPressed =>
      widget.onFavoriteCreateFolderPressed;
  VoidCallback get onFavoriteModeTogglePressed =>
      widget.onFavoriteModeTogglePressed;
  VoidCallback? get onProfileTap => widget.onProfileTap;
  FutureOr<void> Function()? get onCheckInPressed => widget.onCheckInPressed;
  VoidCallback? get onSwitchSourcePressed => widget.onSwitchSourcePressed;
  VoidCallback get onOpenHistory => widget.onOpenHistory;
  VoidCallback get onOpenCategories => widget.onOpenCategories;
  VoidCallback get onOpenRanking => widget.onOpenRanking;
  VoidCallback get onOpenDownloads => widget.onOpenDownloads;
  VoidCallback get onOpenDownloadTasks => widget.onOpenDownloadTasks;
  VoidCallback get onOpenSettings => widget.onOpenSettings;
  VoidCallback? get onOpenAnnouncements => widget.onOpenAnnouncements;
  VoidCallback get onOpenLines => widget.onOpenLines;
  HomeDrawerDestination? get selectedDrawerDestination =>
      widget.selectedDrawerDestination;
  ValueChanged<int> get onDestinationSelected => widget.onDestinationSelected;

  @override
  void dispose() {
    _sourceSwitchDialogOpen.dispose();
    _tabTransition.dispose();
    _homeContentAnimating.dispose();
    _profileDrawerController.dispose();
    super.dispose();
  }

  void _setProfileDrawerOpen(bool isOpen) {
    if (!mounted) {
      return;
    }
    if (isOpen) {
      _profileDrawerController.forward();
    } else {
      _profileDrawerController.reverse();
    }
  }

  void _resetProfileDrawer() {
    if (!mounted) {
      return;
    }
    resetHomeDrawerScale(_profileDrawerController);
  }

  @override
  Widget build(BuildContext context) {
    final drawerVisualKey =
        '$activeSourceKey|${avatarUrl ?? ''}|$profileLoading|${widget.isLogged}|$username';
    final homeContent = HomeContentStack(
      currentIndex: currentIndex,
      transition: _tabTransition,
      cutTransition: _cutTransitionEnabled,
      onTransitionChanged: _setHomeContentAnimating,
      discoverChild: NotificationListener<DiscoverBackToTopNotification>(
        onNotification: (notification) {
          setState(() {
            _showDiscoverBackToTop = notification.visible;
            _onDiscoverBackToTopPressed = notification.onPressed;
          });
          return true;
        },
        child: widget.discoverChild,
      ),
      favoriteChild: widget.favoriteChild,
    );
    final sidebarProfile = HomeSidebarProfileState(
      isLogged: widget.isLogged,
      profileLoading: profileLoading,
      avatarUrl: avatarUrl,
      username: username,
      autoCheckInEnabled: widget.autoCheckInEnabled,
      showCheckInActions: widget.showCheckInActions,
      checkInBusy: widget.checkInBusy,
      checkedInToday: widget.checkedInToday,
    );
    final sidebarActions = HomeSidebarActions(
      onProfileTap: supportsSourceAccount ? onProfileTap : null,
      onCheckInPressed: onCheckInPressed,
      onSwitchSourcePressed: onSwitchSourcePressed,
      onSwitchSourceWithMorph:
          (Platform.isAndroid || Platform.isIOS) &&
              widget.sourceSwitchService != null &&
              onSwitchSourcePressed != null
          ? _showSourceSwitchWithMorph
          : null,
      sourceSwitchDialogOpen: _sourceSwitchDialogOpen.value,
      sourceSwitchDialogOpenListenable: _sourceSwitchDialogOpen,
      sourceSwitchButtonKey: _sourceSwitchButtonKey,
      onSelectDiscover: () => onDestinationSelected(0),
      onSelectFavorite: () => onDestinationSelected(1),
      onOpenHistory: onOpenHistory,
      onOpenCategories: onOpenCategories,
      onOpenRanking: onOpenRanking,
      onOpenDownloads: onOpenDownloads,
      onOpenSettings: onOpenSettings,
      onOpenAnnouncements: onOpenAnnouncements,
      onOpenLines: onOpenLines,
    );
    final mobileDrawerContent = HomeDrawerContent(
      key: const ValueKey('home-mobile-drawer'),
      profile: sidebarProfile,
      actions: sidebarActions,
      activeSourceKey: activeSourceKey,
      selectedDestination: selectedDrawerDestination,
      unreadAnnouncementCount: widget.unreadAnnouncementCount,
    );
    final body = Platform.isWindows
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: resolveHomeWindowsSidebarWidth(context),
                child: HomeWindowsSidebar(
                  key: ValueKey('home-windows-sidebar-$drawerVisualKey'),
                  profile: sidebarProfile,
                  sourceSwitchService: widget.sourceSwitchService,
                  onSourceSwitched: widget.onSourceSwitched,
                  actions: sidebarActions,
                  currentIndex: currentIndex,
                  selectedDestination: selectedDrawerDestination,
                  unreadAnnouncementCount: widget.unreadAnnouncementCount,
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(22),
                  ),
                  child: ColoredBox(
                    color: Theme.of(context).colorScheme.surface,
                    child: HazukiDesktopPageContainer(child: homeContent),
                  ),
                ),
              ),
            ],
          )
        : HazukiDesktopPageContainer(child: homeContent);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        unawaited(
          handleHomePopRequest(
            onWillPop: onWillPop,
            onExitRequested: () {
              if (!context.mounted) {
                return Future<void>.value();
              }
              return onExitRequested();
            },
          ),
        );
      },
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: HomeDrawerTransition(
          animation: _profileDrawerController,
          showNavigation: !Platform.isWindows,
          child: WindowsComicDetailHost(
            child: ListenableBuilder(
              listenable: downloadStatus,
              builder: (context, _) {
                final hasDownloadTasks = downloadStatus.hasTasks;
                return TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: hasDownloadTasks ? 118 : 56),
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  builder: (context, leadingWidth, _) {
                    // 属于某一页的应用栏组件仅在切口过渡开启时跟随裁剪。
                    Widget cutClip(int index, Widget child) =>
                        _cutTransitionEnabled
                        ? HomeTabCutClip(
                            transition: _tabTransition,
                            index: index,
                            child: child,
                          )
                        : child;
                    // overlay 为切页期间叠在上方的进入页应用栏：背景透明，
                    // 头像位只占位，确保组件位置与切换完成后的真实布局一致。
                    PreferredSizeWidget buildAppBar(
                      int index, {
                      bool overlay = false,
                    }) => hazukiFrostedAppBar(
                      context: context,
                      leading: Platform.isWindows
                          ? null
                          : overlay
                          ? const SizedBox.shrink()
                          : _HomeAppBarProfileButton(
                              downloadStatus: downloadStatus,
                              activeSourceKey: activeSourceKey,
                              avatarUrl: avatarUrl,
                              profileLoading: profileLoading,
                              username: username,
                              drawerContent: mobileDrawerContent,
                              onOpenDownloads: onOpenDownloadTasks,
                              onDrawerVisibilityChanged: _setProfileDrawerOpen,
                              onDrawerCovered: _resetProfileDrawer,
                            ),
                      leadingWidth: Platform.isWindows ? null : leadingWidth,
                      automaticallyImplyLeading: false,
                      backgroundAlpha: overlay ? 0 : 0.72,
                      title: index == 1
                          ? null
                          : cutClip(
                              0,
                              _HomeAppBarSearchBox(
                                onOpenSearch: onOpenSearch,
                                maxWidth: Platform.isWindows ? 320 : null,
                              ),
                            ),
                      titleSpacing: Platform.isWindows ? null : 4,
                      centerTitle: Platform.isWindows,
                      actions: [
                        cutClip(
                          1,
                          HomeAppBarActions(
                            currentIndex: index,
                            discoverSearchMorphProgress:
                                discoverSearchMorphProgress,
                            forceDiscoverSearchInAppBar:
                                usePinnedDiscoverSearch,
                            favoriteAppBarActions: favoriteAppBarActions,
                            sourcePlugins: widget.sourcePlugins,
                            onOpenSearch: onOpenSearch,
                            onFavoriteSortSelected: onFavoriteSortSelected,
                            onFavoriteCreateFolderPressed:
                                onFavoriteCreateFolderPressed,
                            onFavoriteModeTogglePressed:
                                onFavoriteModeTogglePressed,
                          ),
                        ),
                      ],
                    );
                    final appBar = buildAppBar(currentIndex);
                    return HazukiLiquidGlass.backdropScope(
                      child: Scaffold(
                        key: scaffoldKey,
                        extendBody: true,
                        appBar: PreferredSize(
                          preferredSize: appBar.preferredSize,
                          child: RepaintBoundary(
                            key: const ValueKey(
                              'home-app-bar-repaint-boundary',
                            ),
                            child: HomeDrawerSnapshot(
                              animation: _profileDrawerController,
                              enabled: !Platform.isWindows,
                              contentAnimating: _homeContentAnimating,
                              // The app bar normally composites over Scaffold's
                              // background. Include it in the isolated raster
                              // so its translucent glass keeps the same tint.
                              child: ColoredBox(
                                color: Theme.of(
                                  context,
                                ).scaffoldBackgroundColor,
                                // 切页期间真实应用栏保持退出页布局，进入页组件
                                // 由上层透明应用栏承载，两者按同一切口互补裁剪。
                                child: !_cutTransitionEnabled
                                    ? Stack(children: [appBar])
                                    : AnimatedBuilder(
                                        animation: _tabTransition.animation,
                                        builder: (context, _) {
                                          if (!_tabTransition.isAnimating) {
                                            return Stack(children: [appBar]);
                                          }
                                          return Stack(
                                            children: [
                                              buildAppBar(
                                                _tabTransition.outgoing,
                                              ),
                                              Positioned.fill(
                                                child: IgnorePointer(
                                                  child: HeroMode(
                                                    enabled: false,
                                                    child: buildAppBar(
                                                      _tabTransition.incoming,
                                                      overlay: true,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                              ),
                            ),
                          ),
                        ),
                        drawerEnableOpenDragGesture: false,
                        drawer: null,
                        // Cache the body and header separately. A full-page
                        // snapshot would rasterize the cached header again and
                        // allocate a second texture containing the same pixels.
                        body: HazukiLiquidGlass.backdropSource(
                          child: HomeDrawerSnapshot(
                            animation: _profileDrawerController,
                            enabled: !Platform.isWindows,
                            contentAnimating: _homeContentAnimating,
                            child: ColoredBox(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              child: body,
                            ),
                          ),
                        ),
                        bottomNavigationBar: null,
                      ),
                    );
                  },
                );
              },
            ),
          ),
          navigationBuilder: (context, drawerProgress, viewportSize) {
            final navigationScale = 1 - 0.035 * drawerProgress;
            final navigationOffset = resolveHomeNavigationDrawerOffset(
              viewportSize: viewportSize,
              progress: drawerProgress,
            );
            final navigationContent = RepaintBoundary(
              key: const ValueKey('home-bottom-navigation-repaint-boundary'),
              child: HomeBottomNavigation(
                currentIndex: currentIndex,
                onDestinationSelected: onDestinationSelected,
                discoverLabel: l10n(context).homeTabDiscover,
                favoriteLabel: l10n(context).homeTabFavorite,
                backToTopLabel: l10n(context).favoriteBackToTop,
                layoutScale: navigationScale,
                showBackToTop: currentIndex == 0
                    ? _showDiscoverBackToTop
                    : currentIndex == 1 && widget.showFavoriteBackToTop,
                onBackToTopPressed: currentIndex == 0
                    ? _onDiscoverBackToTopPressed
                    : widget.onFavoriteBackToTopPressed,
              ),
            );
            return HazukiLiquidGlass.isAvailable
                ? HomeNavigationDrawerLayout(
                    viewportWidth: viewportSize.width,
                    progress: drawerProgress,
                    child: navigationContent,
                  )
                : Padding(
                    padding: EdgeInsets.only(left: navigationOffset.dx * 2),
                    child: navigationContent,
                  );
          },
        ),
      ),
    );
  }
}
