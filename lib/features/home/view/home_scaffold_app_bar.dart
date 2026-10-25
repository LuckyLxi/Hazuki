part of 'home_scaffold_shell.dart';

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
    required this.onDrawerCovered,
  });

  final HomeDownloadStatusListenable downloadStatus;
  final String activeSourceKey;
  final String? avatarUrl;
  final bool profileLoading;
  final String username;
  final Widget drawerContent;
  final VoidCallback onOpenDownloads;
  final ValueChanged<bool> onDrawerVisibilityChanged;
  final VoidCallback onDrawerCovered;

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
    Navigator.of(context).push(
      _HomeProfileDrawerRoute(
        drawerWidth: resolveHomeDrawerWidth(context),
        drawerColor:
            DrawerTheme.of(context).backgroundColor ??
            Theme.of(context).drawerTheme.backgroundColor ??
            Theme.of(context).colorScheme.surface,
        drawerContentListenable: _drawerContentNotifier,
        onClosing: () => widget.onDrawerVisibilityChanged(false),
        onDestinationReturning: widget.onDrawerCovered,
      ),
    );
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
      key: const ValueKey('home-app-bar-search-box'),
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

/// 抽屉滑入/滑出期间把抽屉缓存为静态图。
///
/// 抽屉不透明，其中换源按钮的液态玻璃只折射抽屉自身的头部背景，缓存后画面一致；
/// 否则玻璃会随抽屉位移每帧重新采样整屏背景，开启液态玻璃时转场明显掉帧。
class _HomeProfileDrawerSnapshot extends StatefulWidget {
  const _HomeProfileDrawerSnapshot({
    required this.animation,
    required this.child,
  });

  final Animation<double> animation;
  final Widget child;

  @override
  State<_HomeProfileDrawerSnapshot> createState() =>
      _HomeProfileDrawerSnapshotState();
}

class _HomeProfileDrawerSnapshotState
    extends State<_HomeProfileDrawerSnapshot> {
  final _snapshot = SnapshotController();
  bool _snapshotScheduled = false;

  bool get _shouldCache =>
      HazukiLiquidGlass.isAvailable && widget.animation.status.isAnimating;

  @override
  void initState() {
    super.initState();
    widget.animation.addStatusListener(_handleStatus);
    HazukiLiquidGlass.changes.addListener(_updateSnapshotting);
    _updateSnapshotting();
  }

  @override
  void didUpdateWidget(_HomeProfileDrawerSnapshot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      oldWidget.animation.removeStatusListener(_handleStatus);
      widget.animation.addStatusListener(_handleStatus);
      _updateSnapshotting();
    }
  }

  void _handleStatus(AnimationStatus status) => _updateSnapshotting();

  void _updateSnapshotting() {
    if (!_shouldCache) {
      _snapshot.allowSnapshotting = false;
      return;
    }
    if (_snapshot.allowSnapshotting || _snapshotScheduled) return;
    _snapshotScheduled = true;
    // 头像 Hero 在转场首帧之后才起飞并把抽屉内头像替换为占位，
    // 等这次重建完成再截取，避免把第二个头像烘进缓存。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _snapshotScheduled = false;
      if (mounted) _snapshot.allowSnapshotting = _shouldCache;
    });
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_handleStatus);
    HazukiLiquidGlass.changes.removeListener(_updateSnapshotting);
    _snapshot.dispose();
    super.dispose();
  }

  bool _handleRepaint(HomeDrawerRepaintNotification notification) {
    // 已截取的缓存不会随内容更新，重新截取一次以免动画结束时画面突变。
    if (_snapshot.allowSnapshotting) _snapshot.clear();
    return true;
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<HomeDrawerRepaintNotification>(
        onNotification: _handleRepaint,
        child: GlassSnapshot(controller: _snapshot, child: widget.child),
      );
}

class _HomeProfileDrawerRoute extends PageRoute<void> {
  _HomeProfileDrawerRoute({
    required this.drawerWidth,
    required this.drawerColor,
    required this.drawerContentListenable,
    required this.onClosing,
    required this.onDestinationReturning,
  });

  final double drawerWidth;
  final Color drawerColor;
  final ValueListenable<Widget> drawerContentListenable;
  final VoidCallback onClosing;
  final VoidCallback onDestinationReturning;
  bool _closingNotified = false;
  bool _scaleResetHandedOff = false;

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

  void _notifyClosing() {
    if (_closingNotified) {
      return;
    }
    _closingNotified = true;
    onClosing();
  }

  @override
  bool didPop(void result) {
    _notifyClosing();
    return super.didPop(result);
  }

  @override
  void didChangeNext(Route<dynamic>? nextRoute) {
    super.didChangeNext(nextRoute);
    if (_scaleResetHandedOff || nextRoute is! PageRoute<dynamic>) {
      return;
    }
    final destinationAnimation = nextRoute.animation;
    if (destinationAnimation == null) {
      return;
    }
    _scaleResetHandedOff = true;
    _closingNotified = true;
    holdHomeDrawerScaleUntilRouteReturns(
      routeAnimation: destinationAnimation,
      onRouteReturning: onDestinationReturning,
    );
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
      child: RepaintBoundary(
        child: _HomeProfileDrawerSnapshot(
          animation: animation,
          child: Drawer(
            width: drawerWidth,
            backgroundColor: drawerColor,
            child: ValueListenableBuilder<Widget>(
              valueListenable: drawerContentListenable,
              builder: (context, drawerContent, _) => drawerContent,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _notifyClosing();
    super.dispose();
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
        FadeTransition(opacity: animation, child: const SizedBox.expand()),
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
