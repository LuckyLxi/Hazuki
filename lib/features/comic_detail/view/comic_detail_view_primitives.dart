import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/widgets/widgets.dart';

class ComicDetailLoadingView extends StatelessWidget {
  const ComicDetailLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const HazukiSandyLoadingIndicator(size: 136),
          const SizedBox(height: 10),
          Text(l10n(context).comicDetailLoading),
        ],
      ),
    );
  }
}

class ComicDetailLoadErrorView extends StatelessWidget {
  const ComicDetailLoadErrorView({
    super.key,
    required this.isTimeout,
    this.isRetrying = false,
    this.onRetry,
  });

  final bool isTimeout;
  final bool isRetrying;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isRetrying
                  ? strings.sourceRuntimeRetryingMessage
                  : isTimeout
                  ? strings.comicDetailRecoveryTimedOut
                  : strings.sourceRuntimeErrorGeneric,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: isRetrying ? null : onRetry,
              icon: isRetrying
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: Text(
                isRetrying ? strings.comicDetailLoading : strings.commonRetry,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ComicDetailAppBarTitle extends StatelessWidget {
  const ComicDetailAppBarTitle({
    super.key,
    required this.showCollapsedComicTitle,
    required this.appBarComicTitle,
    required this.appBarUpdateTime,
    required this.theme,
  });

  final bool showCollapsedComicTitle;
  final String appBarComicTitle;
  final String appBarUpdateTime;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.centerLeft,
          children: <Widget>[...previousChildren, ?currentChild],
        );
      },
      transitionBuilder: (child, animation) {
        final offset = Tween<Offset>(
          begin: const Offset(0, 0.18),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: showCollapsedComicTitle
          ? Text(
              appBarComicTitle,
              key: const ValueKey('collapsed-appbar-title'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : Text(
              appBarUpdateTime.isNotEmpty
                  ? l10n(context).comicDetailUpdatedAt(appBarUpdateTime)
                  : l10n(context).comicDetailTitle,
              key: const ValueKey('default-appbar-update-time'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
    );
  }
}

class ComicDetailTabTickerScope extends StatefulWidget {
  const ComicDetailTabTickerScope({
    super.key,
    required this.tabController,
    required this.tabIndex,
    required this.builder,
  });

  final TabController tabController;
  final int tabIndex;
  final Widget Function(BuildContext context, bool shouldRender) builder;

  @override
  State<ComicDetailTabTickerScope> createState() =>
      _ComicDetailTabTickerScopeState();
}

class _ComicDetailTabTickerScopeState extends State<ComicDetailTabTickerScope> {
  bool _tickerEnabled = false;

  @override
  void initState() {
    super.initState();
    _attach();
    _compute();
  }

  @override
  void didUpdateWidget(covariant ComicDetailTabTickerScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabController != widget.tabController) {
      _detach(oldWidget.tabController);
      _attach();
    }
    _compute();
  }

  @override
  void dispose() {
    _detach(widget.tabController);
    super.dispose();
  }

  void _attach() {
    widget.tabController.animation?.addListener(_compute);
    widget.tabController.addListener(_compute);
  }

  void _detach(TabController controller) {
    controller.animation?.removeListener(_compute);
    controller.removeListener(_compute);
  }

  void _compute() {
    final tc = widget.tabController;
    final animValue = tc.animation?.value ?? tc.index.toDouble();
    final distance = (animValue - widget.tabIndex).abs();
    final isTransitioning =
        tc.indexIsChanging ||
        (tc.animation != null &&
            (tc.animation!.value - tc.index).abs() >= 0.01);
    final newTickerEnabled =
        tc.index == widget.tabIndex || (isTransitioning && distance <= 1.0);
    if (newTickerEnabled != _tickerEnabled) {
      setState(() {
        _tickerEnabled = newTickerEnabled;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Hidden tabs must remove their scrollables from NestedScrollView's shared
    // controller. TickerMode alone only pauses their animations.
    return TickerMode(
      enabled: _tickerEnabled,
      child: widget.builder(context, _tickerEnabled),
    );
  }
}

class ComicDetailEntranceReveal extends StatefulWidget {
  const ComicDetailEntranceReveal({
    super.key,
    required this.child,
    this.beginOffset = const Offset(0, 16),
    this.enabled = true,
  });

  final Widget child;
  final Offset beginOffset;
  final bool enabled;

  @override
  State<ComicDetailEntranceReveal> createState() =>
      _ComicDetailEntranceRevealState();
}

class _ComicDetailEntranceRevealState extends State<ComicDetailEntranceReveal> {
  late final bool _playsEntrance = widget.enabled;

  @override
  Widget build(BuildContext context) {
    if (!_playsEntrance) {
      return widget.child;
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      child: widget.child,
      builder: (context, value, child) {
        final dx = lerpDouble(widget.beginOffset.dx, 0, value) ?? 0;
        final dy = lerpDouble(widget.beginOffset.dy, 0, value) ?? 0;
        return Opacity(
          opacity: value,
          child: Transform.translate(offset: Offset(dx, dy), child: child),
        );
      },
    );
  }
}

class ComicDetailSkeletonBlock extends StatelessWidget {
  const ComicDetailSkeletonBlock({
    super.key,
    required this.color,
    this.width,
    this.height = 14,
    this.radius = 10,
  });

  final Color color;
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
