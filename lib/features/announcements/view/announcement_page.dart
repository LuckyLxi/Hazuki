import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/services/announcement_service.dart';

import 'announcement_content.dart';

class AnnouncementPage extends StatefulWidget {
  const AnnouncementPage({super.key, required this.service});

  final AnnouncementService service;

  @override
  State<AnnouncementPage> createState() => _AnnouncementPageState();
}

class _AnnouncementPageState extends State<AnnouncementPage> {
  @override
  void initState() {
    super.initState();
    widget.service.addListener(_handleAnnouncementsChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markVisibleAnnouncementsRead();
    });
  }

  @override
  void didUpdateWidget(covariant AnnouncementPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service == widget.service) {
      return;
    }
    oldWidget.service.removeListener(_handleAnnouncementsChanged);
    widget.service.addListener(_handleAnnouncementsChanged);
    _markVisibleAnnouncementsRead();
  }

  void _handleAnnouncementsChanged() {
    _markVisibleAnnouncementsRead();
  }

  void _markVisibleAnnouncementsRead() {
    unawaited(widget.service.markAllRead());
  }

  @override
  void dispose() {
    widget.service.removeListener(_handleAnnouncementsChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(l10n(context).announcementTitle)),
      body: ListenableBuilder(
        listenable: widget.service,
        builder: (context, _) {
          final announcements = widget.service.notificationHistory;
          if (announcements.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_none_rounded,
                    size: 48,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 12),
                  Text(l10n(context).announcementEmpty),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: announcements.length,
            itemBuilder: (context, index) => _AnnouncementTimelineItem(
              announcement: announcements[index],
              expired: widget.service.isExpired(announcements[index]),
              isFirst: index == 0,
              isLast: index == announcements.length - 1,
            ),
          );
        },
      ),
    );
  }
}

class _AnnouncementTimelineItem extends StatelessWidget {
  const _AnnouncementTimelineItem({
    required this.announcement,
    required this.expired,
    required this.isFirst,
    required this.isLast,
  });

  final Announcement announcement;
  final bool expired;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final important = announcement.level == AnnouncementLevel.important;
    final accent = important ? Colors.red : Colors.blue;
    final lineColor = colorScheme.outlineVariant;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    key: ValueKey<String>(
                      'announcement_timeline_line_${announcement.id}',
                    ),
                    painter: _AnnouncementTimelinePainter(
                      color: lineColor,
                      isFirst: isFirst,
                      isLast: isLast,
                    ),
                  ),
                ),
                Positioned(
                  left: 4,
                  top: 22,
                  child: DecoratedBox(
                    key: ValueKey<String>(
                      'announcement_timeline_node_${announcement.id}',
                    ),
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: colorScheme.surface, width: 2),
                    ),
                    child: const SizedBox.square(dimension: 12),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: _AnnouncementArticle(
                announcement: announcement,
                expired: expired,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnnouncementTimelinePainter extends CustomPainter {
  const _AnnouncementTimelinePainter({
    required this.color,
    required this.isFirst,
    required this.isLast,
  });

  final Color color;
  final bool isFirst;
  final bool isLast;

  @override
  void paint(Canvas canvas, Size size) {
    const nodeCenter = Offset(10, 28);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (!isFirst) {
      canvas.drawLine(const Offset(10, 0), nodeCenter, paint);
    }
    if (!isLast) {
      canvas.drawLine(nodeCenter, Offset(10, size.height), paint);
    }

    final branch = Path()
      ..moveTo(nodeCenter.dx, nodeCenter.dy)
      ..cubicTo(18, 28, 19, 16, size.width - 4, 16);
    canvas.drawPath(branch, paint);
  }

  @override
  bool shouldRepaint(covariant _AnnouncementTimelinePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.isFirst != isFirst ||
        oldDelegate.isLast != isLast;
  }
}

class _AnnouncementArticle extends StatelessWidget {
  const _AnnouncementArticle({
    required this.announcement,
    required this.expired,
  });

  final Announcement announcement;
  final bool expired;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final important = announcement.level == AnnouncementLevel.important;
    final accent = important ? Colors.red : Colors.blue;
    final backgroundColor = Color.alphaBlend(
      accent.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.24 : 0.12,
      ),
      colorScheme.surface,
    );
    final date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(announcement.publishedAt.toLocal());
    return Card(
      key: ValueKey<String>('announcement_card_${announcement.id}'),
      margin: EdgeInsets.zero,
      elevation: 0,
      color: backgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  important
                      ? Icons.priority_high_rounded
                      : Icons.notifications_none_rounded,
                  color: accent,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    announcement.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (expired) ...[
                  const SizedBox(width: 10),
                  DecoratedBox(
                    key: ValueKey<String>(
                      'announcement_expired_badge_${announcement.id}',
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(
                        alpha: theme.brightness == Brightness.dark ? 0.3 : 0.18,
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      child: Text(
                        l10n(context).announcementExpired,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.brightness == Brightness.dark
                              ? Colors.grey.shade300
                              : Colors.grey.shade700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              date,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            AnnouncementContent(announcement: announcement),
          ],
        ),
      ),
    );
  }
}
