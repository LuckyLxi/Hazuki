import 'dart:async';

import 'package:flutter/material.dart';

int _hazukiPromptTicket = 0;
_HazukiPromptHandle? _activeHazukiPrompt;
final HazukiPromptPlacementController hazukiPromptPlacementController =
    HazukiPromptPlacementController();
final NavigatorObserver hazukiPromptNavigatorObserver =
    _HazukiPromptNavigatorObserver();

class _HazukiPromptHandle {
  _HazukiPromptHandle({
    required this.entry,
    required this.completer,
    required this.dismiss,
  });

  final OverlayEntry entry;
  final Completer<void> completer;
  final void Function() dismiss;
}

class HazukiPromptPlacementController extends ChangeNotifier {
  static const double _defaultBottomPadding = 18;

  bool _rootRouteVisible = true;
  int _homeTabIndex = 0;
  double _elevatedBottomPadding = _defaultBottomPadding;

  double get bottomPadding {
    if (_rootRouteVisible && _shouldElevateForTab(_homeTabIndex)) {
      return _elevatedBottomPadding;
    }
    return _defaultBottomPadding;
  }

  void updateHomeAnchor({
    required int tabIndex,
    required double elevatedBottomPadding,
  }) {
    final normalizedPadding = elevatedBottomPadding < _defaultBottomPadding
        ? _defaultBottomPadding
        : elevatedBottomPadding;
    if (_homeTabIndex == tabIndex &&
        _elevatedBottomPadding == normalizedPadding) {
      return;
    }
    _homeTabIndex = tabIndex;
    _elevatedBottomPadding = normalizedPadding;
    notifyListeners();
  }

  void setRootRouteVisible(bool value) {
    if (_rootRouteVisible == value) {
      return;
    }
    _rootRouteVisible = value;
    notifyListeners();
  }

  bool _shouldElevateForTab(int tabIndex) => tabIndex == 0 || tabIndex == 1;
}

class _HazukiPromptNavigatorObserver extends NavigatorObserver {
  void _syncVisibility() {
    final isRootRouteVisible = !(navigator?.canPop() ?? false);
    hazukiPromptPlacementController.setRootRouteVisible(isRootRouteVisible);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _syncVisibility();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _syncVisibility();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _syncVisibility();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _syncVisibility();
  }
}

Future<void> showHazukiPrompt(
  BuildContext context,
  String message, {
  bool isError = false,
  Duration holdDuration = const Duration(seconds: 2),
}) async {
  final ticket = ++_hazukiPromptTicket;
  _activeHazukiPrompt?.dismiss();

  final overlay = Overlay.of(context, rootOverlay: true);

  var expanded = false;
  var textVisible = false;
  var removed = false;
  final completer = Completer<void>();

  late OverlayEntry entry;

  void markNeedsBuild() {
    if (!removed) {
      entry.markNeedsBuild();
    }
  }

  void removeEntry() {
    if (removed) {
      return;
    }
    removed = true;
    entry.remove();
    if (!completer.isCompleted) {
      completer.complete();
    }
    if (identical(_activeHazukiPrompt?.entry, entry)) {
      _activeHazukiPrompt = null;
    }
  }

  entry = OverlayEntry(
    builder: (overlayContext) {
      final colorScheme = Theme.of(overlayContext).colorScheme;
      final backgroundColor = isError
          ? colorScheme.errorContainer
          : colorScheme.inverseSurface;
      final foregroundColor = isError
          ? colorScheme.onErrorContainer
          : colorScheme.onInverseSurface;
      final textStyle =
          Theme.of(overlayContext).textTheme.labelMedium?.copyWith(
            color: foregroundColor,
            fontWeight: FontWeight.w600,
          ) ??
          TextStyle(
            color: foregroundColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          );
      final mediaQuery = MediaQuery.of(overlayContext);
      final safeHorizontalInsets =
          mediaQuery.padding.left + mediaQuery.padding.right;
      final maxPromptWidth = mediaQuery.size.width - safeHorizontalInsets - 24;
      final textPainter = TextPainter(
        text: TextSpan(text: message, style: textStyle),
        maxLines: 1,
        textDirection: Directionality.of(overlayContext),
        textScaler: mediaQuery.textScaler,
      )..layout();
      final desiredExpandedWidth = 24.0 + 18.0 + 8.0 + textPainter.width + 2.0;
      final expandedWidth = desiredExpandedWidth > maxPromptWidth
          ? maxPromptWidth
          : desiredExpandedWidth;

      return ListenableBuilder(
        listenable: hazukiPromptPlacementController,
        builder: (context, _) {
          return IgnorePointer(
            ignoring: true,
            child: Material(
              type: MaterialType.transparency,
              child: SafeArea(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: AnimatedPadding(
                    duration: const Duration(milliseconds: 300),
                    curve: const Cubic(0.2, 0.72, 0.18, 1.0),
                    padding: EdgeInsets.only(
                      bottom: hazukiPromptPlacementController.bottomPadding,
                    ),
                    child: AnimatedScale(
                      duration: Duration(milliseconds: expanded ? 340 : 220),
                      curve: expanded
                          ? Curves.easeOutBack
                          : Curves.easeOutCubic,
                      scale: expanded ? 1 : 0.96,
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: expanded ? 340 : 220),
                        curve: expanded
                            ? Curves.easeOutBack
                            : const Cubic(0.22, 0.0, 0.2, 1.0),
                        width: expanded
                            ? (expandedWidth < 44 ? 44 : expandedWidth)
                            : 44,
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: backgroundColor,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: expanded ? 18 : 14,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedScale(
                              duration: Duration(
                                milliseconds: expanded ? 260 : 180,
                              ),
                              curve: expanded
                                  ? Curves.easeOutBack
                                  : Curves.easeOutCubic,
                              scale: expanded ? 1 : 0.94,
                              child: Icon(
                                Icons.tips_and_updates_rounded,
                                size: 18,
                                color: foregroundColor,
                              ),
                            ),
                            ClipRect(
                              child: AnimatedAlign(
                                alignment: Alignment.centerLeft,
                                duration: const Duration(milliseconds: 220),
                                curve: textVisible
                                    ? const Cubic(0.18, 0.84, 0.22, 1.0)
                                    : const Cubic(0.4, 0.0, 0.2, 1.0),
                                widthFactor: textVisible ? 1 : 0,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 160),
                                    curve: textVisible
                                        ? Curves.easeOutCubic
                                        : Curves.easeInCubic,
                                    opacity: textVisible ? 1 : 0,
                                    child: Text(
                                      message,
                                      maxLines: 1,
                                      overflow: TextOverflow.fade,
                                      softWrap: false,
                                      style: textStyle,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );

  _activeHazukiPrompt = _HazukiPromptHandle(
    entry: entry,
    completer: completer,
    dismiss: removeEntry,
  );
  overlay.insert(entry);

  unawaited(() async {
    await Future<void>.delayed(const Duration(milliseconds: 70));
    if (removed || ticket != _hazukiPromptTicket) {
      removeEntry();
      return;
    }
    expanded = true;
    markNeedsBuild();

    await Future<void>.delayed(const Duration(milliseconds: 90));
    if (removed || ticket != _hazukiPromptTicket) {
      removeEntry();
      return;
    }
    textVisible = true;
    markNeedsBuild();

    await Future<void>.delayed(holdDuration);
    if (removed || ticket != _hazukiPromptTicket) {
      removeEntry();
      return;
    }
    textVisible = false;
    markNeedsBuild();

    await Future<void>.delayed(const Duration(milliseconds: 90));
    if (removed || ticket != _hazukiPromptTicket) {
      removeEntry();
      return;
    }
    expanded = false;
    markNeedsBuild();

    await Future<void>.delayed(const Duration(milliseconds: 240));
    removeEntry();
  }());

  await completer.future;
}
