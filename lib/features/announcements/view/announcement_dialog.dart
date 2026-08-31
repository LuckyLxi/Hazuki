import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/services/announcement_service.dart';

import 'announcement_content.dart';

Future<void> showAnnouncementDialog(
  BuildContext context,
  Announcement announcement, {
  bool morphFromSource = false,
  VoidCallback? onMorphLanding,
}) {
  if (morphFromSource) {
    return _showMorphingAnnouncementDialog(
      context,
      announcement,
      onMorphLanding: onMorphLanding,
    );
  }
  if (announcement.level == AnnouncementLevel.important) {
    return _showImportantAnnouncementDialog(context, announcement);
  }
  return showDialog<void>(
    context: context,
    builder: (context) => _AnnouncementDialog(announcement: announcement),
  );
}

Future<void> _showImportantAnnouncementDialog(
  BuildContext context,
  Announcement announcement,
) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (context, animation, secondaryAnimation) =>
        _AnnouncementDialog(announcement: announcement),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final fadeAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final movementAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final scaleAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        key: const ValueKey<String>('important_announcement_fade_transition'),
        opacity: fadeAnimation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(movementAnimation),
          child: ScaleTransition(
            key: const ValueKey<String>(
              'important_announcement_scale_transition',
            ),
            scale: Tween<double>(begin: 0.9, end: 1).animate(scaleAnimation),
            child: child,
          ),
        ),
      );
    },
  );
}

Future<void> _showMorphingAnnouncementDialog(
  BuildContext context,
  Announcement announcement, {
  VoidCallback? onMorphLanding,
}) async {
  final sourceRect = _resolveSourceRect(context);
  final disposed = Completer<void>();
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.34),
    transitionDuration: const Duration(milliseconds: 420),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return _AnnouncementMorphLifecycle(
        animation: animation,
        onLanding: onMorphLanding,
        onDisposed: () {
          if (!disposed.isCompleted) {
            disposed.complete();
          }
        },
        child: _AnnouncementMorphDialog(
          animation: animation,
          announcement: announcement,
          sourceRect: sourceRect,
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) => child,
  );
  if (!disposed.isCompleted) {
    await disposed.future;
  }
}

class _AnnouncementMorphLifecycle extends StatefulWidget {
  const _AnnouncementMorphLifecycle({
    required this.animation,
    this.onLanding,
    required this.onDisposed,
    required this.child,
  });

  final Animation<double> animation;
  final VoidCallback? onLanding;
  final VoidCallback onDisposed;
  final Widget child;

  @override
  State<_AnnouncementMorphLifecycle> createState() =>
      _AnnouncementMorphLifecycleState();
}

class _AnnouncementMorphLifecycleState
    extends State<_AnnouncementMorphLifecycle> {
  bool _landingReported = false;

  @override
  void initState() {
    super.initState();
    widget.animation.addListener(_handleAnimation);
  }

  void _handleAnimation() {
    if (!_landingReported &&
        widget.animation.status == AnimationStatus.reverse &&
        widget.animation.value <= 0.08) {
      _reportLanding();
    }
  }

  void _reportLanding() {
    if (_landingReported) {
      return;
    }
    _landingReported = true;
    widget.onLanding?.call();
  }

  @override
  void dispose() {
    widget.animation.removeListener(_handleAnimation);
    _reportLanding();
    widget.onDisposed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

Rect? _resolveSourceRect(BuildContext context) {
  final sourceBox = context.findRenderObject();
  final overlayBox = Navigator.of(
    context,
    rootNavigator: true,
  ).overlay?.context.findRenderObject();
  if (sourceBox is! RenderBox ||
      overlayBox is! RenderBox ||
      !sourceBox.attached ||
      !overlayBox.attached) {
    return null;
  }
  final origin = sourceBox.localToGlobal(Offset.zero, ancestor: overlayBox);
  return origin & sourceBox.size;
}

class _AnnouncementMorphDialog extends StatefulWidget {
  const _AnnouncementMorphDialog({
    required this.animation,
    required this.announcement,
    required this.sourceRect,
  });

  final Animation<double> animation;
  final Announcement announcement;
  final Rect? sourceRect;

  @override
  State<_AnnouncementMorphDialog> createState() =>
      _AnnouncementMorphDialogState();
}

class _AnnouncementMorphDialogState extends State<_AnnouncementMorphDialog> {
  double? _measuredContentHeight;

  void _updateContentHeight(double height) {
    if ((_measuredContentHeight ?? -1) == height || !mounted) {
      return;
    }
    setState(() {
      _measuredContentHeight = height;
    });
  }

  @override
  Widget build(BuildContext context) {
    final animation = widget.animation;
    final announcement = widget.announcement;
    final sourceRect = widget.sourceRect;
    final mediaQuery = MediaQuery.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final dialogWidth = (constraints.maxWidth - 32).clamp(0.0, 608.0);
        final availableHeight =
            constraints.maxHeight -
            mediaQuery.padding.top -
            mediaQuery.padding.bottom -
            32;
        final maxDialogHeight = availableHeight.clamp(0.0, 570.0);
        final dialogLayout = _resolveMorphDialogLayout(
          context: context,
          announcement: announcement,
          dialogWidth: dialogWidth,
          maxHeight: maxDialogHeight,
          measuredContentHeight: _measuredContentHeight,
        );
        final endRect = Rect.fromCenter(
          center: Offset(
            constraints.maxWidth / 2,
            (mediaQuery.padding.top +
                    constraints.maxHeight -
                    mediaQuery.padding.bottom) /
                2,
          ),
          width: dialogWidth,
          height: dialogLayout.height,
        );
        final startRect =
            sourceRect ??
            Rect.fromCenter(
              center: endRect.center,
              width: dialogWidth,
              height: 48,
            );
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final progress = animation.value;
            final moveProgress = const Interval(
              0,
              0.78,
              curve: Curves.easeOutCubic,
            ).transform(progress);
            final expandProgress = const Interval(
              0.08,
              1,
              curve: Curves.easeOutCubic,
            ).transform(progress);
            final movingRect = Rect.lerp(
              startRect,
              Rect.fromCenter(
                center: endRect.center,
                width: startRect.width,
                height: startRect.height,
              ),
              moveProgress,
            )!;
            final rect = Rect.fromCenter(
              center: movingRect.center,
              width:
                  startRect.width +
                  ((endRect.width - startRect.width) * expandProgress),
              height:
                  startRect.height +
                  ((endRect.height - startRect.height) * expandProgress),
            );
            final contentOpacity = const Interval(
              0.42,
              0.78,
              curve: Curves.easeOutCubic,
            ).transform(progress);
            final launcherOpacity =
                1 - const Interval(0.12, 0.42).transform(progress);
            final shellColor = Color.lerp(
              colorScheme.primaryContainer,
              colorScheme.surfaceContainerHigh,
              expandProgress,
            )!;
            return Stack(
              key: const ValueKey<String>('announcement_morph_animation'),
              children: [
                Positioned.fromRect(
                  rect: rect,
                  child: Material(
                    key: const ValueKey<String>('announcement_morph_dialog'),
                    color: shellColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        16 + (12 * expandProgress),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    elevation: 2 + (6 * expandProgress),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Opacity(
                          opacity: launcherOpacity,
                          child: _AnnouncementMorphLauncherContents(
                            announcement: announcement,
                          ),
                        ),
                        Positioned.fill(
                          child: ClipRect(
                            child: OverflowBox(
                              alignment: Alignment.center,
                              minWidth: endRect.width,
                              maxWidth: endRect.width,
                              minHeight: endRect.height,
                              maxHeight: endRect.height,
                              child: Opacity(
                                opacity: contentOpacity,
                                child: _AnnouncementDialogPanel(
                                  announcement: announcement,
                                  contentScrollable:
                                      dialogLayout.contentScrollable,
                                  onContentSizeChanged: _updateContentHeight,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

({double height, bool contentScrollable}) _resolveMorphDialogLayout({
  required BuildContext context,
  required Announcement announcement,
  required double dialogWidth,
  required double maxHeight,
  double? measuredContentHeight,
}) {
  if (maxHeight <= 0) {
    return (height: 0, contentScrollable: false);
  }
  final theme = Theme.of(context);
  final textScaler = MediaQuery.textScalerOf(context);
  final direction = Directionality.of(context);
  final contentWidth = (dialogWidth - 48).clamp(0.0, double.infinity);
  final titleWidth =
      (contentWidth -
              (announcement.level == AnnouncementLevel.important ? 28 : 0))
          .clamp(0.0, double.infinity);

  double textHeight(String text, TextStyle? style, double width) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
      textScaler: textScaler,
    )..layout(maxWidth: width);
    return painter.height;
  }

  var estimatedContentHeight = 0.0;
  for (var index = 0; index < announcement.content.length; index++) {
    if (index > 0) {
      estimatedContentHeight += 16;
    }
    final block = announcement.content[index];
    estimatedContentHeight += switch (block) {
      AnnouncementTextBlock(:final text) => textHeight(
        text,
        theme.textTheme.bodyMedium?.copyWith(height: 1.55),
        contentWidth,
      ),
      AnnouncementLinkBlock() => 48,
      AnnouncementImageBlock image =>
        (image.aspectRatio == null
                ? 220.0
                : (contentWidth / image.aspectRatio!).clamp(0.0, 420.0)) +
            (image.caption == null
                ? 0
                : 8 +
                      textHeight(
                        image.caption!,
                        theme.textTheme.bodySmall,
                        contentWidth,
                      )),
    };
  }

  final titleHeight = textHeight(
    announcement.title,
    theme.textTheme.headlineSmall,
    titleWidth,
  );
  final dateHeight = textHeight(
    MaterialLocalizations.of(
      context,
    ).formatMediumDate(announcement.publishedAt.toLocal()),
    theme.textTheme.bodySmall,
    contentWidth,
  );
  const fixedSpacingAndActions = 24 + 6 + 16 + 12 + 48 + 16;
  final contentHeight = measuredContentHeight ?? estimatedContentHeight;
  final desiredHeight =
      fixedSpacingAndActions + titleHeight + dateHeight + contentHeight;
  return (
    height: desiredHeight.clamp(200.0.clamp(0.0, maxHeight), maxHeight),
    contentScrollable: desiredHeight > maxHeight,
  );
}

class _AnnouncementMorphLauncherContents extends StatelessWidget {
  const _AnnouncementMorphLauncherContents({required this.announcement});

  final Announcement announcement;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final date = MaterialLocalizations.of(
      context,
    ).formatShortDate(announcement.publishedAt.toLocal());
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(
            announcement.level == AnnouncementLevel.important
                ? Icons.priority_high_rounded
                : Icons.notifications_none_rounded,
            size: 22,
            color: announcement.level == AnnouncementLevel.important
                ? colorScheme.error
                : colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              announcement.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            date,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnnouncementDialogPanel extends StatelessWidget {
  const _AnnouncementDialogPanel({
    required this.announcement,
    required this.contentScrollable,
    required this.onContentSizeChanged,
  });

  final Announcement announcement;
  final bool contentScrollable;
  final ValueChanged<double> onContentSizeChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(announcement.publishedAt.toLocal());
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (announcement.level == AnnouncementLevel.important) ...[
                Icon(
                  Icons.priority_high_rounded,
                  size: 20,
                  color: colorScheme.error,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  key: const ValueKey<String>('announcement_dialog_title'),
                  announcement.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            key: const ValueKey<String>('announcement_dialog_date'),
            date,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              key: const ValueKey<String>('announcement_dialog_content_scroll'),
              physics: contentScrollable
                  ? const ClampingScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              child: _MeasuredAnnouncementContent(
                announcement: announcement,
                onSizeChanged: onContentSizeChanged,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton.tonal(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n(context).announcementAcknowledge),
            ),
          ),
        ],
      ),
    );
  }
}

class _MeasuredAnnouncementContent extends StatefulWidget {
  const _MeasuredAnnouncementContent({
    required this.announcement,
    required this.onSizeChanged,
  });

  final Announcement announcement;
  final ValueChanged<double> onSizeChanged;

  @override
  State<_MeasuredAnnouncementContent> createState() =>
      _MeasuredAnnouncementContentState();
}

class _MeasuredAnnouncementContentState
    extends State<_MeasuredAnnouncementContent> {
  final _contentKey = GlobalKey();
  double? _lastReportedHeight;

  void _scheduleMeasurement() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final renderObject = _contentKey.currentContext?.findRenderObject();
      if (renderObject is! RenderBox) {
        return;
      }
      final height = renderObject.size.height;
      if (_lastReportedHeight == height) {
        return;
      }
      _lastReportedHeight = height;
      widget.onSizeChanged(height);
    });
  }

  @override
  Widget build(BuildContext context) {
    _scheduleMeasurement();
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (notification) {
        _scheduleMeasurement();
        return false;
      },
      child: SizeChangedLayoutNotifier(
        child: AnnouncementContent(
          key: _contentKey,
          announcement: widget.announcement,
        ),
      ),
    );
  }
}

class _AnnouncementDialog extends StatelessWidget {
  const _AnnouncementDialog({required this.announcement});

  final Announcement announcement;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(announcement.publishedAt.toLocal());
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 14, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (announcement.level == AnnouncementLevel.important) ...[
                Icon(
                  Icons.priority_high_rounded,
                  size: 20,
                  color: colorScheme.error,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(child: Text(announcement.title)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            date,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.62,
          ),
          child: SingleChildScrollView(
            child: AnnouncementContent(announcement: announcement),
          ),
        ),
      ),
      actions: [
        FilledButton.tonal(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n(context).announcementAcknowledge),
        ),
      ],
    );
  }
}
