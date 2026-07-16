import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/features/home/support/home_feature_contracts.dart';
import 'package:hazuki/shared/favorites/favorite_app_bar_actions_state.dart';
import 'package:hazuki/shared/search_box_outline.dart';
import 'package:hazuki/widgets/widgets.dart';
import 'package:hazuki/widgets/windows_comic_detail_host.dart';

import 'home_app_bar_actions.dart';
import 'home_bottom_navigation.dart';
import 'home_content_stack.dart';
import 'package:hazuki/features/home/view/home_drawer.dart';

@visibleForTesting
Future<void> handleHomePopRequest({
  required Future<bool> Function() onWillPop,
  required Future<void> Function() onExitRequested,
}) async {
  if (await onWillPop()) {
    await onExitRequested();
  }
}

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
    required this.onProfileTap,
    required this.onCheckInPressed,
    required this.onSwitchSourcePressed,
    required this.onOpenHistory,
    required this.onOpenCategories,
    required this.onOpenRanking,
    required this.onOpenDownloads,
    required this.onOpenDownloadTasks,
    required this.onOpenSettings,
    required this.onOpenLines,
    this.selectedDrawerDestination,
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
  final VoidCallback? onProfileTap;
  final VoidCallback? onCheckInPressed;
  final VoidCallback? onSwitchSourcePressed;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenCategories;
  final VoidCallback onOpenRanking;
  final VoidCallback onOpenDownloads;
  final VoidCallback onOpenDownloadTasks;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenLines;
  final HomeDrawerDestination? selectedDrawerDestination;
  final ValueChanged<int> onDestinationSelected;

  @override
  State<HomeScaffoldShell> createState() => _HomeScaffoldShellState();
}

class _HomeScaffoldShellState extends State<HomeScaffoldShell>
    with SingleTickerProviderStateMixin {
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
  VoidCallback? get onCheckInPressed => widget.onCheckInPressed;
  VoidCallback? get onSwitchSourcePressed => widget.onSwitchSourcePressed;
  VoidCallback get onOpenHistory => widget.onOpenHistory;
  VoidCallback get onOpenCategories => widget.onOpenCategories;
  VoidCallback get onOpenRanking => widget.onOpenRanking;
  VoidCallback get onOpenDownloads => widget.onOpenDownloads;
  VoidCallback get onOpenDownloadTasks => widget.onOpenDownloadTasks;
  VoidCallback get onOpenSettings => widget.onOpenSettings;
  VoidCallback get onOpenLines => widget.onOpenLines;
  HomeDrawerDestination? get selectedDrawerDestination =>
      widget.selectedDrawerDestination;
  ValueChanged<int> get onDestinationSelected => widget.onDestinationSelected;

  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) {
    final drawerVisualKey =
        '$activeSourceKey|${avatarUrl ?? ''}|$profileLoading|${widget.isLogged}|$username';
    final homeContent = HomeContentStack(
      currentIndex: currentIndex,
      discoverChild: widget.discoverChild,
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
      onSelectDiscover: () => onDestinationSelected(0),
      onSelectFavorite: () => onDestinationSelected(1),
      onOpenHistory: onOpenHistory,
      onOpenCategories: onOpenCategories,
      onOpenRanking: onOpenRanking,
      onOpenDownloads: onOpenDownloads,
      onOpenSettings: onOpenSettings,
      onOpenLines: onOpenLines,
    );
    final mobileDrawerContent = HomeDrawerContent(
      key: ValueKey('home-mobile-drawer-$drawerVisualKey'),
      profile: sidebarProfile,
      actions: sidebarActions,
      activeSourceKey: activeSourceKey,
      selectedDestination: selectedDrawerDestination,
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
                  actions: sidebarActions,
                  currentIndex: currentIndex,
                  selectedDestination: selectedDrawerDestination,
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
        child: AnimatedBuilder(
          animation: _profileDrawerController,
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
                    return Scaffold(
                      key: scaffoldKey,
                      extendBody: true,
                      appBar: hazukiFrostedAppBar(
                        context: context,
                        leading: Platform.isWindows
                            ? null
                            : _HomeAppBarProfileButton(
                                downloadStatus: downloadStatus,
                                activeSourceKey: activeSourceKey,
                                avatarUrl: avatarUrl,
                                profileLoading: profileLoading,
                                username: username,
                                drawerContent: mobileDrawerContent,
                                onOpenDownloads: onOpenDownloadTasks,
                                onDrawerVisibilityChanged:
                                    _setProfileDrawerOpen,
                              ),
                        leadingWidth: Platform.isWindows ? null : leadingWidth,
                        automaticallyImplyLeading: false,
                        title: currentIndex == 1
                            ? null
                            : _HomeAppBarSearchBox(
                                onOpenSearch: onOpenSearch,
                                maxWidth: Platform.isWindows ? 320 : null,
                              ),
                        titleSpacing: Platform.isWindows ? null : 4,
                        centerTitle: Platform.isWindows,
                        enableBlur: currentIndex != 0 && currentIndex != 1,
                        actions: [
                          HomeAppBarActions(
                            currentIndex: currentIndex,
                            discoverSearchMorphProgress:
                                discoverSearchMorphProgress,
                            forceDiscoverSearchInAppBar:
                                usePinnedDiscoverSearch,
                            favoriteAppBarActions: favoriteAppBarActions,
                            onOpenSearch: onOpenSearch,
                            onFavoriteSortSelected: onFavoriteSortSelected,
                            onFavoriteCreateFolderPressed:
                                onFavoriteCreateFolderPressed,
                            onFavoriteModeTogglePressed:
                                onFavoriteModeTogglePressed,
                          ),
                        ],
                      ),
                      drawerEnableOpenDragGesture: false,
                      drawer: null,
                      body: body,
                      bottomNavigationBar: Platform.isWindows
                          ? null
                          : HomeBottomNavigation(
                              currentIndex: currentIndex,
                              onDestinationSelected: onDestinationSelected,
                              discoverLabel: l10n(context).homeTabDiscover,
                              favoriteLabel: l10n(context).homeTabFavorite,
                            ),
                    );
                  },
                );
              },
            ),
          ),
          builder: (context, child) => Transform.translate(
            offset: Offset(18 * _profileDrawerController.value, 0),
            child: Transform.scale(
              scale: 1 - 0.035 * _profileDrawerController.value,
              alignment: Alignment.centerRight,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeAppBarProfileButton extends StatefulWidget {
  const _HomeAppBarProfileButton({
    required this.downloadStatus,
    required this.activeSourceKey,
    required this.avatarUrl,
    required this.profileLoading,
    required this.username,
    required this.drawerContent,
    required this.onOpenDownloads,
    required this.onDrawerVisibilityChanged,
  });

  final HomeDownloadStatusListenable downloadStatus;
  final String activeSourceKey;
  final String? avatarUrl;
  final bool profileLoading;
  final String username;
  final Widget drawerContent;
  final VoidCallback onOpenDownloads;
  final ValueChanged<bool> onDrawerVisibilityChanged;

  @override
  State<_HomeAppBarProfileButton> createState() =>
      _HomeAppBarProfileButtonState();
}

class _HomeAppBarProfileButtonState extends State<_HomeAppBarProfileButton> {
  late final ValueNotifier<Widget> _drawerContentNotifier =
      ValueNotifier<Widget>(widget.drawerContent);
  int _lastVisibleTaskCount = 0;
  Widget? _pendingDrawerContent;
  bool _drawerContentUpdateScheduled = false;

  @override
  void initState() {
    super.initState();
    _syncLastVisibleTaskCount();
  }

  @override
  void didUpdateWidget(covariant _HomeAppBarProfileButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncLastVisibleTaskCount();
    _syncDrawerContent();
  }

  @override
  void dispose() {
    _drawerContentNotifier.dispose();
    super.dispose();
  }

  void _syncLastVisibleTaskCount() {
    final taskCount = widget.downloadStatus.taskCount;
    if (taskCount > 0) {
      _lastVisibleTaskCount = taskCount;
    }
  }

  void _syncDrawerContent() {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      _pendingDrawerContent = widget.drawerContent;
      if (_drawerContentUpdateScheduled) {
        return;
      }
      _drawerContentUpdateScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _drawerContentUpdateScheduled = false;
        final drawerContent = _pendingDrawerContent;
        _pendingDrawerContent = null;
        if (!mounted || drawerContent == null) {
          return;
        }
        _drawerContentNotifier.value = drawerContent;
      });
      return;
    }
    _drawerContentNotifier.value = widget.drawerContent;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: widget.profileLoading
          ? l10n(context).commonLoading
          : widget.username,
      child: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: IconButton(
          onPressed: _openProfileDrawer,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: widget.downloadStatus.hasTasks ? 1 : 0),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            builder: (context, progress, _) {
              final liveTaskCount = widget.downloadStatus.taskCount;
              final taskCount = liveTaskCount > 0
                  ? liveTaskCount
                  : _lastVisibleTaskCount;
              final pillWidth = 38 + 58 * progress;
              return SizedBox(
                width: pillWidth,
                height: 38,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(
                      alpha: 0.92 * progress,
                    ),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: colorScheme.primary.withValues(
                        alpha: 0.26 * progress,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withValues(
                          alpha: 0.08 * progress,
                        ),
                        blurRadius: 10 * progress,
                        offset: Offset(0, 3 * progress),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      HomeProfileAvatar(
                        key: ValueKey(
                          'home-appbar-avatar-${widget.activeSourceKey}|'
                          '${widget.avatarUrl ?? ''}|'
                          '${widget.profileLoading}|'
                          '${widget.username}',
                        ),
                        avatarUrl: widget.avatarUrl,
                        loading: widget.profileLoading,
                        size: 38,
                        borderWidth: 2,
                        borderColor: colorScheme.primary.withValues(
                          alpha: 0.72,
                        ),
                        backgroundColor: colorScheme.surfaceContainerHigh,
                        heroEnabled: true,
                      ),
                      ClipRect(
                        child: SizedBox(
                          width: 58 * progress,
                          child: Opacity(
                            opacity: progress.clamp(0.0, 1.0),
                            child: GestureDetector(
                              key: const ValueKey<String>(
                                'home-appbar-download-status',
                              ),
                              behavior: HitTestBehavior.opaque,
                              onTap: widget.onOpenDownloads,
                              child: _HomeDownloadStatusContent(
                                taskCount: taskCount,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _openProfileDrawer() {
    final context = this.context;
    widget.onDrawerVisibilityChanged(true);
    Navigator.of(context)
        .push(
          _HomeProfileDrawerRoute(
            drawerWidth: resolveHomeDrawerWidth(context),
            drawerColor:
                DrawerTheme.of(context).backgroundColor ??
                Theme.of(context).drawerTheme.backgroundColor ??
                Theme.of(context).colorScheme.surface,
            drawerContentListenable: _drawerContentNotifier,
          ),
        )
        .whenComplete(() => widget.onDrawerVisibilityChanged(false));
  }
}

class _HomeDownloadStatusContent extends StatelessWidget {
  const _HomeDownloadStatusContent({required this.taskCount});

  final int taskCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 7, right: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.download_rounded,
            size: 18,
            color: colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 3),
          Text(
            'x$taskCount',
            maxLines: 1,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeAppBarSearchBox extends StatelessWidget {
  const _HomeAppBarSearchBox({required this.onOpenSearch, this.maxWidth});

  final VoidCallback onOpenSearch;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final searchBox = Material(
      color: hazukiSearchBoxBackgroundColor(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(50),
        side: hazukiSearchBoxOutlineSide(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(50),
        onTap: onOpenSearch,
        child: SizedBox(
          height: 40,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(
                  Icons.search,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n(context).homeSearchHint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (maxWidth == null) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: searchBox,
      );
    }
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth!),
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: searchBox,
      ),
    );
  }
}

class _HomeProfileDrawerRoute extends PageRoute<void> {
  _HomeProfileDrawerRoute({
    required this.drawerWidth,
    required this.drawerColor,
    required this.drawerContentListenable,
  });

  final double drawerWidth;
  final Color drawerColor;
  final ValueListenable<Widget> drawerContentListenable;

  @override
  bool get opaque => false;

  @override
  bool get barrierDismissible => true;

  @override
  Color get barrierColor => Colors.black.withValues(alpha: 0.28);

  @override
  String? get barrierLabel => 'Dismiss';

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 210);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 160);

  @override
  void didChangeNext(Route<dynamic>? nextRoute) {
    super.didChangeNext(nextRoute);
    if (nextRoute is! PageRoute<dynamic>) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigator?.removeRoute(this);
    });
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Drawer(
        width: drawerWidth,
        backgroundColor: drawerColor,
        child: ValueListenableBuilder<Widget>(
          valueListenable: drawerContentListenable,
          builder: (context, drawerContent, _) => drawerContent,
        ),
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return Stack(
      children: [
        FadeTransition(
          opacity: animation,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: const SizedBox.expand(),
          ),
        ),
        SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-1, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      ],
    );
  }
}
