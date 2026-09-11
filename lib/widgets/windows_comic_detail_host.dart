import 'windows_comic_detail_transition.dart';
import 'windows_comic_detail_presentation_scope.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../shared/windows/windows_comic_detail.dart';

class WindowsComicDetailHost extends StatefulWidget {
  const WindowsComicDetailHost({
    super.key,
    required this.child,
    this.suppressExistingPanel = false,
    this.controller,
  });

  final Widget child;
  final WindowsComicDetailController? controller;
  final bool suppressExistingPanel;

  @override
  State<WindowsComicDetailHost> createState() => _WindowsComicDetailHostState();
}

class _WindowsComicDetailHostState extends State<WindowsComicDetailHost> {
  WindowsComicDetailEntry? _displayEntry;
  bool _displayEntryShouldAnimatePanelReveal = false;
  Animation<double>? _routeAnimation;
  bool _deferPanelUntilRouteSettles = false;
  Timer? _closeTimer;
  int? _suppressedEntryRevision;
  WindowsComicDetailSnapshot? _suppressedEntry;
  int? _suppressedEntryRestorationEpoch;
  int? _handledRevealRevision;

  WindowsComicDetailController get _controller =>
      widget.controller ?? WindowsComicDetailController.instance;

  @override
  void initState() {
    super.initState();
    final controller = _controller;
    _initializePresentation();
    controller.addListener(_handleControllerChanged);
  }

  void _initializePresentation() {
    final entry = _controller.entry;
    _suppressedEntryRevision = widget.suppressExistingPanel
        ? entry?.revision
        : null;
    _suppressedEntry = widget.suppressExistingPanel
        ? _controller.captureSnapshot()
        : null;
    _suppressedEntryRestorationEpoch = widget.suppressExistingPanel
        ? _controller.restorationEpoch
        : null;
    _displayEntry = _isEntrySuppressed(entry) ? null : entry;
    _displayEntryShouldAnimatePanelReveal = _consumePendingPanelReveal(
      _displayEntry,
    );
  }

  @override
  void didUpdateWidget(WindowsComicDetailHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previous =
        oldWidget.controller ?? WindowsComicDetailController.instance;
    if (identical(previous, _controller)) return;
    previous.removeListener(_handleControllerChanged);
    _closeTimer?.cancel();
    _handledRevealRevision = null;
    _initializePresentation();
    _controller.addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    final controller = _controller;
    _closeTimer?.cancel();
    _detachRouteAnimation();
    controller.removeListener(_handleControllerChanged);
    if (_suppressedEntry != null) {
      scheduleMicrotask(_restoreSuppressedEntry);
    }
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _attachRouteAnimationIfNeeded();
  }

  void _handleControllerChanged() {
    final controller = _controller;
    final controllerEntry = controller.entry;
    final entry = _isEntrySuppressed(controllerEntry) ? null : controllerEntry;
    _closeTimer?.cancel();

    if (controller.isPanelVisible && entry != null) {
      final shouldAnimatePanelReveal = _consumePendingPanelReveal(entry);
      setState(() {
        _displayEntry = entry;
        _displayEntryShouldAnimatePanelReveal = shouldAnimatePanelReveal;
      });
      return;
    }

    if (controllerEntry != null) {
      setState(() {});
      return;
    }

    if (_displayEntry == null) {
      return;
    }

    setState(() {});
    _closeTimer = Timer(windowsComicDetailPanelAnimationDuration, () {
      if (!mounted || _controller.entry != null) {
        return;
      }
      setState(() {
        _displayEntry = null;
        _displayEntryShouldAnimatePanelReveal = false;
      });
    });
  }

  bool _isEntrySuppressed(WindowsComicDetailEntry? entry) {
    return entry != null && entry.revision == _suppressedEntryRevision;
  }

  void _handleHomeRequested() {
    final navigator = Navigator.of(context, rootNavigator: true);
    _controller.close(discardSuspendedDetails: true);
    navigator.popUntil((route) => route.isFirst);
  }

  bool _consumePendingPanelReveal(WindowsComicDetailEntry? entry) {
    if (entry == null) {
      return false;
    }
    if (_handledRevealRevision == entry.revision) return false;
    _handledRevealRevision = entry.revision;
    return entry.navigation != WindowsComicDetailNavigation.replace &&
        entry.navigation != WindowsComicDetailNavigation.resume;
  }

  void _attachRouteAnimationIfNeeded() {
    final route = ModalRoute.of(context);
    final nextAnimation = route?.animation;
    if (identical(nextAnimation, _routeAnimation)) {
      _syncDeferredPanelVisibility();
      return;
    }
    _detachRouteAnimation();
    _routeAnimation = nextAnimation;
    _routeAnimation?.addStatusListener(_handleRouteAnimationStatusChanged);
    _syncDeferredPanelVisibility();
  }

  void _detachRouteAnimation() {
    _routeAnimation?.removeStatusListener(_handleRouteAnimationStatusChanged);
    _routeAnimation = null;
  }

  void _handleRouteAnimationStatusChanged(AnimationStatus status) {
    if (!mounted) {
      return;
    }
    if (status == AnimationStatus.reverse ||
        status == AnimationStatus.dismissed) {
      _restoreSuppressedEntry();
    }
    _syncDeferredPanelVisibility();
  }

  void _restoreSuppressedEntry() {
    final suppressedEntry = _suppressedEntry;
    final restorationEpoch = _suppressedEntryRestorationEpoch;
    _suppressedEntry = null;
    _suppressedEntryRestorationEpoch = null;
    if (suppressedEntry == null || restorationEpoch == null) {
      return;
    }
    final controller = _controller;
    final wasMounted = mounted;
    if (wasMounted) {
      controller.removeListener(_handleControllerChanged);
    }
    controller.restoreSuspended(
      suppressedEntry,
      restorationEpoch: restorationEpoch,
    );
    if (wasMounted) {
      _suppressedEntryRevision = controller.entry?.revision;
      _displayEntry = null;
      _displayEntryShouldAnimatePanelReveal = false;
      controller.addListener(_handleControllerChanged);
      setState(() {});
    }
  }

  void _syncDeferredPanelVisibility() {
    final animation = _routeAnimation;
    final routeInTransition =
        animation != null &&
        animation.status != AnimationStatus.dismissed &&
        animation.status != AnimationStatus.completed &&
        animation.value < 1;
    final shouldDefer = _displayEntry != null && routeInTransition;
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

    return WindowsComicDetailControllerScope(
      controller: _controller,
      child: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final controller = _controller;
          final controllerEntry = controller.isPanelVisible
              ? controller.entry
              : null;
          final entry = _isEntrySuppressed(controllerEntry)
              ? null
              : controllerEntry;
          final activeEntry = entry ?? _displayEntry;
          final shouldAnimatePanelReveal =
              activeEntry != null &&
              _displayEntry != null &&
              activeEntry.revision == _displayEntry!.revision &&
              _displayEntryShouldAnimatePanelReveal;
          final showPanel =
              activeEntry != null &&
              controller.isPanelVisible &&
              !_deferPanelUntilRouteSettles;

          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(
                child: HeroMode(enabled: !showPanel, child: widget.child),
              ),
              Positioned.fill(
                child: AnimatedSlide(
                  duration:
                      activeEntry?.navigation ==
                              WindowsComicDetailNavigation.resume &&
                          showPanel
                      ? Duration.zero
                      : windowsComicDetailPanelAnimationDuration,
                  curve: Curves.easeOutCubic,
                  offset: showPanel ? Offset.zero : const Offset(0, 1),
                  child: IgnorePointer(
                    ignoring: !showPanel,
                    child: ColoredBox(
                      color: Theme.of(context).colorScheme.surface,
                      child: activeEntry == null
                          ? const SizedBox.shrink()
                          : HeroMode(
                              enabled: showPanel,
                              child: WindowsComicDetailTransition(
                                entry: activeEntry,
                                shouldAnimatePanelReveal:
                                    shouldAnimatePanelReveal,
                                child: KeyedSubtree(
                                  key: ValueKey<int>(activeEntry.revision),
                                  child:
                                      WindowsComicDetailPresentationScope.maybeOf(
                                        context,
                                      )?.call(
                                        activeEntry.comic,
                                        activeEntry.heroTag,
                                        shouldAnimatePanelReveal:
                                            shouldAnimatePanelReveal,
                                        isRestoringPreviousDetail:
                                            activeEntry.navigation ==
                                                WindowsComicDetailNavigation
                                                    .pop ||
                                            activeEntry.navigation ==
                                                WindowsComicDetailNavigation
                                                    .resume,
                                        initialTabIndex:
                                            activeEntry.initialTabIndex,
                                        showHomeAction: controller.canGoBack,
                                        onBackRequested: controller.goBack,
                                        onHomeRequested: _handleHomeRequested,
                                      ) ??
                                      const SizedBox.shrink(),
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
      ),
    );
  }
}
