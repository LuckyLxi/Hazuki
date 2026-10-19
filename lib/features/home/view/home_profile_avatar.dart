import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hazuki/shared/navigation_tags.dart';
import 'package:hazuki/widgets/widgets.dart';

class HomeProfileAvatar extends StatefulWidget {
  const HomeProfileAvatar({
    super.key,
    required this.avatarUrl,
    required this.loading,
    required this.size,
    this.borderWidth = 0,
    this.borderColor,
    this.backgroundColor,
    this.heroEnabled = false,
    this.borderRadius,
    this.animateOnLoad = false,
  });

  final String? avatarUrl;
  final bool loading;
  final double size;
  final double borderWidth;
  final Color? borderColor;
  final Color? backgroundColor;
  final bool heroEnabled;
  final BorderRadius? borderRadius;
  final bool animateOnLoad;

  @override
  State<HomeProfileAvatar> createState() => _HomeProfileAvatarState();
}

class _HomeProfileAvatarState extends State<HomeProfileAvatar> {
  final _heroContentKey = GlobalKey();
  Timer? _retryTimer;
  int _retryCount = 0;

  @override
  void didUpdateWidget(covariant HomeProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.avatarUrl != widget.avatarUrl ||
        oldWidget.loading != widget.loading) {
      _retryTimer?.cancel();
      _retryTimer = null;
      _retryCount = 0;
    }
  }

  void _scheduleRetry() {
    if (_retryTimer != null || _retryCount >= 2) return;
    _retryTimer = Timer(Duration(seconds: 1 + _retryCount * 2), () {
      _retryTimer = null;
      if (!mounted) return;
      setState(() => _retryCount++);
    });
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HeroMode(
    enabled: widget.heroEnabled,
    child: Hero(
      tag: homeProfileAvatarHeroTag,
      // The default destination placeholder unmounts the image, restarting its
      // reveal after landing. Keep it alive while the shuttle shows the image
      // without another load animation.
      placeholderBuilder: (context, size, child) => Visibility(
        visible: false,
        maintainSize: true,
        maintainAnimation: true,
        maintainState: true,
        child: child,
      ),
      flightShuttleBuilder:
          (context, animation, direction, fromContext, toContext) =>
              _buildAvatar(toContext, inFlight: true),
      child: KeyedSubtree(key: _heroContentKey, child: _buildAvatar(context)),
    ),
  );

  Widget _buildAvatar(BuildContext context, {bool inFlight = false}) {
    final animateOnLoad = widget.animateOnLoad && !inFlight;
    // A warm avatar is already visible in the source Hero. Its route motion is
    // the entrance animation; fading the destination again dims the handoff.
    final route = widget.heroEnabled ? ModalRoute.of(context) : null;
    final arrivingWithHero =
        route != null &&
        (route.offstage || route.animation?.isCompleted == false);
    final resolvedAvatarUrl = (widget.avatarUrl ?? '').trim();
    final size = widget.size;
    final borderWidth = widget.borderWidth;
    final radius = size / 2;
    final contentSize = (size - borderWidth * 2).clamp(0.0, size).toDouble();
    final borderRadius = widget.borderRadius;
    final fallbackIcon = Icon(
      Icons.person_outline,
      size: contentSize * 0.58,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    final avatar = Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(borderWidth),
      decoration: BoxDecoration(
        shape: borderRadius == null ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: borderRadius,
        color:
            widget.backgroundColor ??
            Theme.of(context).colorScheme.surfaceContainerHighest,
        border: borderWidth > 0
            ? Border.all(
                color:
                    widget.borderColor ??
                    Theme.of(context).colorScheme.outlineVariant,
                width: borderWidth,
              )
            : null,
      ),
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(radius),
        child: widget.loading
            ? HazukiShimmerLoading(width: contentSize, height: contentSize)
            : resolvedAvatarUrl.isEmpty
            ? Center(child: fallbackIcon)
            : borderRadius != null || widget.animateOnLoad || inFlight
            ? HazukiCachedImage(
                key: ValueKey((resolvedAvatarUrl, _retryCount)),
                url: resolvedAvatarUrl,
                width: contentSize,
                height: contentSize,
                fit: BoxFit.cover,
                error: HazukiShimmerLoading(
                  width: contentSize,
                  height: contentSize,
                ),
                loading: HazukiShimmerLoading(
                  width: contentSize,
                  height: contentSize,
                ),
                ignoreNoImageMode: true,
                animateOnLoad: animateOnLoad,
                animateOnCacheHit: animateOnLoad && !arrivingWithHero,
                waitForFirstFrame: widget.animateOnLoad || inFlight,
                loadAnimationDuration: const Duration(milliseconds: 300),
                onStateChanged: (_, state) {
                  if (state == HazukiCachedImageLoadState.error) {
                    _scheduleRetry();
                  }
                },
              )
            : HazukiCachedCircleAvatar(
                key: ValueKey(_retryCount),
                radius: contentSize / 2,
                url: resolvedAvatarUrl,
                useShimmerFallback: true,
                ignoreNoImageMode: true,
                onLoadError: _scheduleRetry,
              ),
      ),
    );

    return Material(
      type: MaterialType.transparency,
      shape: borderRadius == null
          ? CircleBorder(side: _heroBorderSide(context))
          : RoundedRectangleBorder(
              borderRadius: borderRadius,
              side: _heroBorderSide(context),
            ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(width: radius * 2, height: radius * 2, child: avatar),
    );
  }

  BorderSide _heroBorderSide(BuildContext context) {
    if (widget.borderWidth <= 0) {
      return BorderSide.none;
    }
    return BorderSide(
      color: widget.borderColor ?? Theme.of(context).colorScheme.outlineVariant,
      width: widget.borderWidth,
    );
  }
}
