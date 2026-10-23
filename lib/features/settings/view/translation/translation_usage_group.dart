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

class _TranslationUsageGroupState extends State<TranslationUsageGroup> {
  late Future<Map<String, DailyTranslationUsage>> _data = widget.store.load();
  @override
  void initState() {
    super.initState();
    widget.store.addListener(_reload);
  }

  void _reload() {
    if (mounted) {
      setState(() {
        _data = widget.store.load();
      });
    }
  }

  @override
  void dispose() {
    widget.store.removeListener(_reload);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SettingsGroup(
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
                      colors.surfaceContainerHighest,
                      for (final alpha in [0.2, 0.4, 0.65, 1.0])
                        colors.primary.withValues(alpha: alpha),
                    ];
                    return GestureDetector(
                      onTapDown: (details) {
                        final column = details.localPosition.dx ~/ 15,
                            row = details.localPosition.dy ~/ 15;
                        if (column >= weeks ||
                            row >= 7 ||
                            details.localPosition.dx % 15 > 12 ||
                            details.localPosition.dy % 15 > 12) {
                          return;
                        }
                        final date = DateTime(
                          start.year,
                          start.month,
                          start.day + column * 7 + row,
                        );
                        if (date.isAfter(now)) return;
                        final usage =
                            data[TranslationUsageStore.dateKey(date)] ??
                            const DailyTranslationUsage();
                        final dateText = DateFormat.yMd(
                          Localizations.localeOf(context).toLanguageTag(),
                        ).format(date);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              l10n(context).translationUsageDetail(
                                dateText,
                                usage.pages,
                                usage.requests,
                                usage.inputTokens,
                                usage.outputTokens,
                              ),
                            ),
                          ),
                        );
                      },
                      child: CustomPaint(
                        size: Size(weeks * 15, 105),
                        painter: _HeatmapPainter(
                          counts: counts,
                          maximum: maximum,
                          colors: levelColors,
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
  });
  final List<int> counts;
  final int maximum;
  final List<Color> colors;
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
  }

  @override
  bool shouldRepaint(covariant _HeatmapPainter oldDelegate) =>
      oldDelegate.counts != counts || oldDelegate.colors != colors;
}
