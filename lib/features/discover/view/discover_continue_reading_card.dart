import 'package:flutter/material.dart';

import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/shared/chapter_title_resolver.dart';
import 'package:hazuki/shared/navigation_tags.dart';
import 'package:hazuki/shared/text/chinese_conversion_scope.dart';
import 'package:hazuki/shared/windows/windows_comic_detail.dart';
import 'package:hazuki/widgets/widgets.dart';

import '../state/discover_continue_reading_controller.dart';

/// Windows 发现页首屏右侧的“继续阅读”卡，列出当前源最近阅读的漫画。
class DiscoverContinueReadingCard extends StatelessWidget {
  const DiscoverContinueReadingCard({
    super.key,
    required this.entries,
    required this.height,
    required this.comicDetailPageBuilder,
    required this.comicCoverHeroTagBuilder,
  });

  final List<DiscoverContinueReadingEntry> entries;
  final double height;
  final ComicDetailPageBuilder comicDetailPageBuilder;
  final ComicHeroTagBuilder comicCoverHeroTagBuilder;

  static const _coverWidth = 40.0;
  static const _coverHeight = 54.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      key: const ValueKey('discover-continue-reading-card'),
      height: height,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              l10n(context).discoverContinueReadingTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: entries.length,
              itemBuilder: (context, index) =>
                  _buildItem(context, entries[index], index),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(
    BuildContext context,
    DiscoverContinueReadingEntry entry,
    int index,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final comic = entry.comic;
    final heroTag = comicCoverHeroTagBuilder(
      comic,
      salt: 'discover-continue-$index',
    );
    final progress = entry.progress;
    final subtitle = progress == null
        ? comic.subTitle
        : l10n(context).discoverContinueReadingProgress(
            resolveHazukiChapterTitle(context, progress.chapterTitle),
            progress.pageIndex + 1,
          );
    final placeholder = ColoredBox(color: colorScheme.surfaceContainerHighest);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => openComicDetail(
        context,
        comic: comic,
        heroTag: heroTag,
        pageBuilder: comicDetailPageBuilder,
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Row(
          children: [
            Hero(
              tag: heroTag,
              flightShuttleBuilder: buildComicCoverHeroFlightShuttle,
              placeholderBuilder: buildComicCoverHeroPlaceholder,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: _coverWidth,
                  height: _coverHeight,
                  child: comic.cover.isEmpty
                      ? placeholder
                      : HazukiCachedImage(
                          url: comic.cover,
                          sourceKey: comic.sourceKey,
                          width: _coverWidth,
                          height: _coverHeight,
                          fit: BoxFit.cover,
                          cacheWidth:
                              (_coverWidth *
                                      MediaQuery.devicePixelRatioOf(context))
                                  .round(),
                          filterQuality: FilterQuality.low,
                          loading: placeholder,
                          error: placeholder,
                        ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    convertChineseText(context, comic.title),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
