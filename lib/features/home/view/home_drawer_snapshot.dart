import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'package:hazuki/shared/liquid_glass_support.dart';

/// Caches stationary home content before the drawer transforms it.
/// Scrolling content and tab transitions stay live; the app bar can cache itself.
class HomeDrawerSnapshot extends StatefulWidget {
  const HomeDrawerSnapshot({
    super.key,
    required this.animation,
    required this.child,
    this.enabled = true,
    this.contentAnimating,
  });

  final Animation<double> animation;
  final Widget child;
  final bool enabled;

  /// Keeps changing content live for the current drawer motion.
  final ValueListenable<bool>? contentAnimating;

  @override
  State<HomeDrawerSnapshot> createState() => _HomeDrawerSnapshotState();
}

class _HomeDrawerSnapshotState extends State<HomeDrawerSnapshot> {
  final _snapshot = SnapshotController();
  final _scrolling = <ScrollPosition>{};
  bool _snapshotScheduled = false;
  bool _skipCurrentTransition = false;

  bool get _shouldCache =>
      widget.enabled &&
      HazukiLiquidGlass.isAvailable &&
      widget.animation.status.isAnimating &&
      !_skipCurrentTransition &&
      !(widget.contentAnimating?.value ?? false) &&
      !_hasVisibleScrollingContent;

  bool get _hasVisibleScrollingContent {
    _scrolling.removeWhere(
      (position) =>
          position.context.notificationContext?.mounted != true ||
          !position.isScrollingNotifier.value,
    );
    return _scrolling.any((position) {
      RenderObject? node = position.context.notificationContext
          ?.findRenderObject();
      while (node != null) {
        // Both home tabs stay mounted; a hidden Discover carousel must not
        // disable caching for the visible Favorites page.
        if (node is RenderOffstage && node.offstage ||
            node is RenderOpacity && node.opacity == 0 ||
            node is RenderAnimatedOpacity &&
                node.opacity.value == 0 &&
                !node.opacity.status.isAnimating) {
          return false;
        }
        node = node.parent;
      }
      return true;
    });
  }

  bool _handleScroll(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      // A tab can fade into view while its carousel is already scrolling.
      if (_scrolling.isNotEmpty) _updateSnapshotting();
      return false;
    }
    if (notification is! ScrollStartNotification &&
        notification is! ScrollEndNotification) {
      return false;
    }
    final notificationContext = notification.context;
    if (notificationContext == null) return false;
    final position = Scrollable.maybeOf(notificationContext)?.position;
    if (position == null) return false;
    if (notification is ScrollStartNotification) {
      _scrolling.add(position);
    } else {
      _scrolling.remove(position);
    }
    // Release before the first scrolling frame, even when autoplay starts
    // halfway through the drawer transition. Do not pause its controller.
    _updateSnapshotting();
    return false;
  }

  @override
  void initState() {
    super.initState();
    widget.animation.addStatusListener(_handleStatus);
    widget.contentAnimating?.addListener(_handleContentAnimation);
    HazukiLiquidGlass.changes.addListener(_updateSnapshotting);
    _handleContentAnimation();
  }

  @override
  void didUpdateWidget(HomeDrawerSnapshot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      oldWidget.animation.removeStatusListener(_handleStatus);
      widget.animation.addStatusListener(_handleStatus);
      _skipCurrentTransition = false;
    }
    if (oldWidget.contentAnimating != widget.contentAnimating) {
      oldWidget.contentAnimating?.removeListener(_handleContentAnimation);
      widget.contentAnimating?.addListener(_handleContentAnimation);
    }
    _handleContentAnimation();
  }

  void _handleStatus(AnimationStatus status) {
    if (!status.isAnimating) _skipCurrentTransition = false;
    _handleContentAnimation();
  }

  void _handleContentAnimation() {
    if (widget.animation.status.isAnimating &&
        (widget.contentAnimating?.value ?? false)) {
      // Tab transitions last longer than a drawer transition. Capturing the
      // whole page as the tab settles adds a raster pass for only a few frames.
      // Keep this drawer motion live and try caching on the next one instead.
      _skipCurrentTransition = true;
    }
    _updateSnapshotting();
  }

  void _updateSnapshotting() {
    if (!_shouldCache) {
      _snapshot.allowSnapshotting = false;
      return;
    }
    if (_snapshot.allowSnapshotting || _snapshotScheduled) return;
    _snapshotScheduled = true;
    // The drawer route starts the avatar Hero flight after its first frame.
    // Capture after its in-page placeholder rebuild, leaving the flying avatar
    // live in the Navigator overlay instead of baking in a second avatar.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _snapshotScheduled = false;
      if (mounted) _snapshot.allowSnapshotting = _shouldCache;
    });
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_handleStatus);
    widget.contentAnimating?.removeListener(_handleContentAnimation);
    HazukiLiquidGlass.changes.removeListener(_updateSnapshotting);
    _snapshot.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: _handleScroll,
        child: GlassSnapshot(controller: _snapshot, child: widget.child),
      );
}
