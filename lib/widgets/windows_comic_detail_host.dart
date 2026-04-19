import 'dart:async';

import 'package:flutter/material.dart';

import '../app/windows_comic_detail.dart';
import 'package:hazuki/features/comic_detail/view/comic_detail_page.dart';

class WindowsComicDetailHost extends StatefulWidget {
  const WindowsComicDetailHost({super.key, required this.child});

  final Widget child;

  @override
  State<WindowsComicDetailHost> createState() => _WindowsComicDetailHostState();
}

class _WindowsComicDetailHostState extends State<WindowsComicDetailHost> {
  WindowsComicDetailEntry? _displayEntry;
  bool _displayEntryShouldAnimatePanelReveal = false;
  Animation<double>? _routeAnimation;
  Animation<double>? _secondaryRouteAnimation;
  bool _deferPanelUntilRouteSettles = false;
  Timer? _closeTimer;

  @override
  void initState() {
    super.initState();
    final controller = WindowsComicDetailController.instance;
    _displayEntry = controller.entry;
    _displayEntryShouldAnimatePanelReveal = _consumePendingPanelReveal(
      _displayEntry,
    );
    controller.addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    _detachRouteAnimation();
    WindowsComicDetailController.instance.removeListener(
      _handleControllerChanged,
    );
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _attachRouteAnimationIfNeeded();
  }

  void _handleControllerChanged() {
    final controller = WindowsComicDetailController.instance;
    final entry = controller.entry;
    _closeTimer?.cancel();

    if (controller.isPanelVisible && entry != null) {
      final shouldAnimatePanelReveal = _consumePendingPanelReveal(entry);
      setState(() {
        _displayEntry = entry;
        _displayEntryShouldAnimatePanelReveal = shouldAnimatePanelReveal;
      });
      return;
    }

    if (entry != null) {
      setState(() {});
      return;
    }

    if (_displayEntry == null) {
      return;
    }

    setState(() {});
    _closeTimer = Timer(windowsComicDetailPanelAnimationDuration, () {
      if (!mounted || WindowsComicDetailController.instance.entry != null) {
        return;
      }
      setState(() {
        _displayEntry = null;
        _displayEntryShouldAnimatePanelReveal = false;
      });
    });
  }

  bool _consumePendingPanelReveal(WindowsComicDetailEntry? entry) {
    if (entry == null) {
      return false;
    }
    final controller = WindowsComicDetailController.instance;
    final shouldAnimatePanelReveal = controller.shouldAnimatePanelReveal(entry);
    controller.markPanelRevealHandled(entry);
    return shouldAnimatePanelReveal;
  }

  void _attachRouteAnimationIfNeeded() {
    final route = ModalRoute.of(context);
    final nextAnimation = route?.animation;
    final nextSecondaryAnimation = route?.secondaryAnimation;
    if (identical(nextAnimation, _routeAnimation) &&
        identical(nextSecondaryAnimation, _secondaryRouteAnimation)) {
      _syncDeferredPanelVisibility();
      return;
    }
    _detachRouteAnimation();
    _routeAnimation = nextAnimation;
    _secondaryRouteAnimation = nextSecondaryAnimation;
    _routeAnimation?.addStatusListener(_handleRouteAnimationStatusChanged);
    _secondaryRouteAnimation?.addStatusListener(
      _handleRouteAnimationStatusChanged,
    );
    _syncDeferredPanelVisibility();
  }

  void _detachRouteAnimation() {
    _routeAnimation?.removeStatusListener(_handleRouteAnimationStatusChanged);
    _secondaryRouteAnimation?.removeStatusListener(
      _handleRouteAnimationStatusChanged,
    );
    _routeAnimation = null;
    _secondaryRouteAnimation = null;
  }

  void _handleRouteAnimationStatusChanged(AnimationStatus _) {
    if (!mounted) {
      return;
    }
    _syncDeferredPanelVisibility();
  }

  bool get _isCoveredByAnotherRoute {
    final secondaryAnimation = _secondaryRouteAnimation;
    if (secondaryAnimation == null) {
      return false;
    }
    return secondaryAnimation.status != AnimationStatus.dismissed &&
        secondaryAnimation.value > 0;
  }

  void _syncDeferredPanelVisibility() {
    final animation = _routeAnimation;
    final routeInTransition =
        animation != null &&
        animation.status != AnimationStatus.dismissed &&
        animation.status != AnimationStatus.completed &&
        animation.value < 1;
    final shouldDefer =
        _displayEntry != null &&
        (routeInTransition || _isCoveredByAnotherRoute);
    if (shouldDefer == _deferPanelUntilRouteSettles) {
      return;
    }
    setState(() {
      _deferPanelUntilRouteSettles = shouldDefer;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!useWindowsComicDetailPanel) {
      return widget.child;
    }

    return ListenableBuilder(
      listenable: WindowsComicDetailController.instance,
      builder: (context, _) {
        final controller = WindowsComicDetailController.instance;
        final entry = controller.isPanelVisible ? controller.entry : null;
        final activeEntry = entry ?? _displayEntry;
        final shouldReservePanelSpace =
            activeEntry != null &&
            (controller.isPanelVisible || _isCoveredByAnotherRoute);
        final shouldAnimatePanelReveal =
            activeEntry != null &&
            _displayEntry != null &&
            activeEntry.revision == _displayEntry!.revision &&
            _displayEntryShouldAnimatePanelReveal;
        final showPanel = activeEntry != null && !_deferPanelUntilRouteSettles;
        final totalWidth = MediaQuery.sizeOf(context).width;
        final panelWidth = totalWidth * 0.6;
        final contentWidth = shouldReservePanelSpace
            ? totalWidth - panelWidth
            : totalWidth;

        return Row(
          children: [
            AnimatedContainer(
              duration: windowsComicDetailPanelAnimationDuration,
              curve: Curves.easeOutCubic,
              width: contentWidth,
              child: HeroMode(
                enabled: !shouldReservePanelSpace,
                child: widget.child,
              ),
            ),
            AnimatedContainer(
              duration: windowsComicDetailPanelAnimationDuration,
              curve: Curves.easeOutCubic,
              width: shouldReservePanelSpace ? panelWidth : 0,
              child: IgnorePointer(
                ignoring: !shouldReservePanelSpace || !showPanel,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: panelWidth,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(24),
                      ),
                      child: Opacity(
                        opacity: showPanel ? 1 : 0,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x22000000),
                                blurRadius: 28,
                                offset: Offset(-8, 0),
                              ),
                            ],
                          ),
                          child: activeEntry == null
                              ? const SizedBox.shrink()
                              : HeroMode(
                                  enabled: showPanel,
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 280),
                                    reverseDuration: const Duration(
                                      milliseconds: 220,
                                    ),
                                    switchInCurve: Curves.easeOutCubic,
                                    switchOutCurve: Curves.easeInCubic,
                                    layoutBuilder:
                                        (currentChild, previousChildren) {
                                          final overlayChildren =
                                              currentChild == null
                                              ? const <Widget>[]
                                              : <Widget>[currentChild];
                                          return Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              ...previousChildren,
                                              ...overlayChildren,
                                            ],
                                          );
                                        },
                                    transitionBuilder: (child, animation) {
                                      final slide =
                                          Tween<Offset>(
                                            begin: const Offset(0.08, 0),
                                            end: Offset.zero,
                                          ).animate(
                                            CurvedAnimation(
                                              parent: animation,
                                              curve: Curves.easeOutCubic,
                                              reverseCurve: Curves.easeInCubic,
                                            ),
                                          );
                                      return FadeTransition(
                                        opacity: animation,
                                        child: SlideTransition(
                                          position: slide,
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: KeyedSubtree(
                                      key: ValueKey<int>(activeEntry.revision),
                                      child: ComicDetailPage(
                                        comic: activeEntry.comic,
                                        heroTag: activeEntry.heroTag,
                                        isDesktopPanel: true,
                                        shouldAnimateInitialRevealOverride:
                                            shouldAnimatePanelReveal,
                                        onCloseRequested:
                                            WindowsComicDetailController
                                                .instance
                                                .close,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
