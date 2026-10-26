import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/l10n.dart';
import '../../../../services/translation/translation_usage_store.dart';
import '../../../../shared/translation/translation_confirmation_dialog.dart';
import '../settings_group.dart';

int translationHeatmapLevel(int pages, int maximum) =>
    pages <= 0 ? 0 : (pages * 4 / math.max(1, maximum)).ceil().clamp(1, 4);

class TranslationUsageGroup extends StatefulWidget {
  const TranslationUsageGroup({super.key, required this.store});
  final TranslationUsageStore store;
  @override
  State<TranslationUsageGroup> createState() => _TranslationUsageGroupState();
}

class _TranslationUsageGroupState extends State<TranslationUsageGroup>
    with SingleTickerProviderStateMixin {
  late Future<Map<String, DailyTranslationUsage>> _data = widget.store.load();
  final _heatmapKey = GlobalKey();
  final _detail = OverlayPortalController();
  late final _detailAnimation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
  )..addStatusListener(_detailStatusChanged);
  ScrollPosition? _scroll;
  _UsageDetail? _selected;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_reload);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 详情卡按点击时的格子位置定位，页面滚动后位置失效，直接收起。
    final scroll = Scrollable.maybeOf(context)?.position;
    if (scroll != _scroll) {
      _scroll?.removeListener(_hideDetail);
      _scroll = scroll?..addListener(_hideDetail);
    }
  }

  void _reload() {
    if (mounted) {
      _detailAnimation.value = 0;
      setState(() {
        _data = widget.store.load();
      });
    }
  }

  bool get _detailOpen =>
      _detail.isShowing &&
      _detailAnimation.status != AnimationStatus.reverse &&
      _detailAnimation.status != AnimationStatus.dismissed;

  void _detailStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && _detail.isShowing && mounted) {
      _detail.hide();
      setState(() => _selected = null);
    }
  }

  /// 直接替换当前详情，不必等上一张收起。
  void _showDetail(_UsageDetail detail) {
    setState(() => _selected = detail);
    _detail.show();
    _detailAnimation.forward();
  }

  void _hideDetail() {
    if (!_detailOpen) return;
    _detailAnimation.reverse();
    setState(() {});
  }

  @override
  void dispose() {
    widget.store.removeListener(_reload);
    _scroll?.removeListener(_hideDetail);
    _detailAnimation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    // 详情卡打开时，返回键先收起详情而不是退出页面。
    canPop: !_detailOpen,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _hideDetail();
    },
    child: _buildGroup(context),
  );

  Widget _buildGroup(BuildContext context) => SettingsGroup(
    children: [
      ListTile(
        title: Text(l10n(context).translationUsage),
        trailing: SizedBox(
          width: 128,
          child: TextButton(
            onPressed: () async {
              if (!await confirmTranslationClear(context)) return;
              try {
                await widget.store.clear();
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n(context).translationUnknown)),
                  );
                }
              }
            },
            child: Text(l10n(context).translationClearUsage),
          ),
        ),
      ),
      FutureBuilder<Map<String, DailyTranslationUsage>>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n(context).translationUnknown),
            );
          }
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final data = snapshot.data!;
          final now = DateTime.now(), colors = Theme.of(context).colorScheme;
          final cutoff = TranslationUsageStore.dateKey(
            DateTime(now.year, now.month, now.day - 29),
          );
          var pages = 0, tokens = 0;
          for (final entry in data.entries) {
            if (entry.key.compareTo(cutoff) >= 0) {
              pages += entry.value.pages;
              tokens += entry.value.inputTokens + entry.value.outputTokens;
            }
          }
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n(context).translationUsageSummary(pages, tokens)),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final weeks = (constraints.maxWidth / 15).floor().clamp(
                      1,
                      52,
                    );
                    final start = DateTime(
                      now.year,
                      now.month,
                      now.day - (now.weekday - 1) - (weeks - 1) * 7,
                    );
                    final counts = <int>[];
                    for (var column = 0; column < weeks; column++) {
                      for (var row = 0; row < 7; row++) {
                        counts.add(
                          data[TranslationUsageStore.dateKey(
                                    DateTime(
                                      start.year,
                                      start.month,
                                      start.day + column * 7 + row,
                                    ),
                                  )]
                                  ?.pages ??
                              0,
                        );
                      }
                    }
                    final maximum = counts.fold<int>(0, math.max);
                    final levelColors = [
                      // 纯黑模式下各层 surface 均为黑色，空格会与卡片同色而消失，改用前景色叠加。
                      colors.surfaceContainerHighest ==
                              colors.surfaceContainerLow
                          ? colors.onSurface.withValues(alpha: 0.1)
                          : colors.surfaceContainerHighest,
                      for (final alpha in [0.2, 0.4, 0.65, 1.0])
                        colors.primary.withValues(alpha: alpha),
                    ];
                    final selected = _selected;
                    final selectedIndex = selected == null || !_detailOpen
                        ? null
                        : DateTime(
                                selected.date.year,
                                selected.date.month,
                                selected.date.day,
                                12,
                              )
                              .difference(
                                DateTime(
                                  start.year,
                                  start.month,
                                  start.day,
                                  12,
                                ),
                              )
                              .inDays;
                    return OverlayPortal(
                      controller: _detail,
                      overlayChildBuilder: (context) => Positioned.fill(
                        child: CustomSingleChildLayout(
                          delegate: _UsageDetailLayout(
                            anchor: _selected!.anchor,
                            bounds: _selected!.bounds,
                            padding: MediaQuery.paddingOf(context),
                          ),
                          child: TapRegion(
                            groupId: _detail,
                            child: FadeTransition(
                              opacity: CurvedAnimation(
                                parent: _detailAnimation,
                                curve: Curves.easeOut,
                              ),
                              child: ScaleTransition(
                                scale: Tween(begin: 0.94, end: 1.0).animate(
                                  CurvedAnimation(
                                    parent: _detailAnimation,
                                    curve: Curves.easeOutCubic,
                                  ),
                                ),
                                child: _UsageDetailCard(detail: _selected!),
                              ),
                            ),
                          ),
                        ),
                      ),
                      child: TapRegion(
                        groupId: _detail,
                        onTapOutside: (_) => _hideDetail(),
                        child: GestureDetector(
                          onTapDown: (details) {
                            final column = details.localPosition.dx ~/ 15,
                                row = details.localPosition.dy ~/ 15;
                            if (column >= weeks ||
                                row >= 7 ||
                                details.localPosition.dx % 15 > 12 ||
                                details.localPosition.dy % 15 > 12) {
                              _hideDetail();
                              return;
                            }
                            final date = DateTime(
                              start.year,
                              start.month,
                              start.day + column * 7 + row,
                            );
                            if (date.isAfter(now)) {
                              _hideDetail();
                              return;
                            }
                            // 再次点击同一格视为收起。
                            if (_detailOpen && _selected!.date == date) {
                              _hideDetail();
                              return;
                            }
                            final heatmap =
                                _heatmapKey.currentContext!.findRenderObject()
                                    as RenderBox;
                            final overlay =
                                Overlay.of(context).context.findRenderObject()
                                    as RenderBox;
                            _showDetail(
                              _UsageDetail(
                                date: date,
                                usage:
                                    data[TranslationUsageStore.dateKey(date)] ??
                                    const DailyTranslationUsage(),
                                anchor:
                                    heatmap.localToGlobal(
                                      Offset(column * 15.0, row * 15.0),
                                      ancestor: overlay,
                                    ) &
                                    const Size(12, 12),
                                bounds:
                                    heatmap.localToGlobal(
                                      Offset.zero,
                                      ancestor: overlay,
                                    ) &
                                    heatmap.size,
                              ),
                            );
                          },
                          child: CustomPaint(
                            key: _heatmapKey,
                            size: Size(weeks * 15, 105),
                            painter: _HeatmapPainter(
                              counts: counts,
                              maximum: maximum,
                              colors: levelColors,
                              selected: selectedIndex,
                              highlight: colors.onSurface,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    ],
  );
}

class _HeatmapPainter extends CustomPainter {
  const _HeatmapPainter({
    required this.counts,
    required this.maximum,
    required this.colors,
    required this.highlight,
    this.selected,
  });
  final List<int> counts;
  final int maximum;
  final List<Color> colors;
  final Color highlight;

  /// 正在查看详情的格子，绘制描边标出。
  final int? selected;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var index = 0; index < counts.length; index++) {
      paint.color = colors[translationHeatmapLevel(counts[index], maximum)];
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH((index ~/ 7) * 15, (index % 7) * 15, 12, 12),
          const Radius.circular(2),
        ),
        paint,
      );
    }
    final selected = this.selected;
    if (selected != null && selected >= 0 && selected < counts.length) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            (selected ~/ 7) * 15,
            (selected % 7) * 15,
            12,
            12,
          ).inflate(1),
          const Radius.circular(3),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = highlight,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HeatmapPainter oldDelegate) =>
      oldDelegate.counts != counts ||
      oldDelegate.colors != colors ||
      oldDelegate.selected != selected ||
      oldDelegate.highlight != highlight;
}

class _UsageDetail {
  const _UsageDetail({
    required this.date,
    required this.usage,
    required this.anchor,
    required this.bounds,
  });
  final DateTime date;
  final DailyTranslationUsage usage;

  /// 被点击格子与整张热力图在 Overlay 坐标系中的位置。
  final Rect anchor, bounds;
}

/// 详情卡水平对准格子、竖直贴在整张热力图的上方（不足时放下方），
/// 始终不遮挡任何格子，才能直接点下一格切换。
class _UsageDetailLayout extends SingleChildLayoutDelegate {
  const _UsageDetailLayout({
    required this.anchor,
    required this.bounds,
    required this.padding,
  });
  final Rect anchor, bounds;
  final EdgeInsets padding;
  static const _margin = 12.0, _gap = 8.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final width = math.min(240.0, constraints.maxWidth - _margin * 2);
    return BoxConstraints(
      minWidth: width,
      maxWidth: width,
      maxHeight: constraints.maxHeight,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final left = math.max(
      _margin,
      math.min(
        anchor.center.dx - childSize.width / 2,
        size.width - _margin - childSize.width,
      ),
    );
    final above = bounds.top - _gap - childSize.height;
    final top = above >= padding.top + kToolbarHeight
        ? above
        : bounds.bottom + _gap;
    return Offset(left, top);
  }

  @override
  bool shouldRelayout(covariant _UsageDetailLayout oldDelegate) =>
      oldDelegate.anchor != anchor ||
      oldDelegate.bounds != bounds ||
      oldDelegate.padding != padding;
}

class _UsageDetailCard extends StatelessWidget {
  const _UsageDetailCard({required this.detail});
  final _UsageDetail detail;

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final number = NumberFormat.decimalPattern(locale);
    final usage = detail.usage;
    Widget row(IconData icon, String label, int value) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: colors.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            number.format(value),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
    return Material(
      color: colors.surfaceContainerHigh,
      elevation: 6,
      shadowColor: colors.shadow.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat.yMMMEd(locale).format(detail.date),
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            row(
              Icons.auto_stories_outlined,
              strings.translationUsagePagesLabel,
              usage.pages,
            ),
            row(
              Icons.sync_alt_rounded,
              strings.translationUsageRequestsLabel,
              usage.requests,
            ),
            row(
              Icons.arrow_upward_rounded,
              strings.translationUsageInputTokensLabel,
              usage.inputTokens,
            ),
            row(
              Icons.arrow_downward_rounded,
              strings.translationUsageOutputTokensLabel,
              usage.outputTokens,
            ),
          ],
        ),
      ),
    );
  }
}
