import 'package:flutter/material.dart';

import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/shared/navigation_tags.dart';
import 'package:hazuki/shared/windows/windows_comic_detail.dart';

import 'discover_comic_tile.dart';
import 'discover_section_page.dart';

class DiscoverSectionBlock extends StatelessWidget {
  const DiscoverSectionBlock({
    super.key,
    required this.section,
    required this.sectionIndex,
    required this.comicDetailPageBuilder,
    required this.comicCoverHeroTagBuilder,
  });

  final ExploreSection section;
  final int sectionIndex;
  final ComicDetailPageBuilder comicDetailPageBuilder;
  final ComicHeroTagBuilder comicCoverHeroTagBuilder;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final placeholderColor = theme.colorScheme.surfaceContainerHighest;
    final coverCacheWidth = (130 * MediaQuery.devicePixelRatioOf(context))
        .round();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(section.title, style: theme.textTheme.titleMedium),
              ),
              if (section.comics.isNotEmpty)
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => DiscoverSectionPage(
                          section: section,
                          comicDetailPageBuilder: comicDetailPageBuilder,
                          comicCoverHeroTagBuilder: comicCoverHeroTagBuilder,
                        ),
                      ),
                    );
                  },
                  child: Text(strings.discoverMore),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 228,
            child: ListView.separated(
              key: PageStorageKey<String>(
                'discover-section-$sectionIndex-${section.title}',
              ),
              scrollDirection: Axis.horizontal,
              itemCount: section.comics.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final comic = section.comics[index];
                final heroTag = comicCoverHeroTagBuilder(
                  comic,
                  salt: 'discover-$sectionIndex-${section.title}-$index',
                );
                return SizedBox(
                  width: 130,
                  child: DiscoverComicCoverTile(
                    comic: comic,
                    heroTag: heroTag,
                    coverCacheWidth: coverCacheWidth,
                    placeholderColor: placeholderColor,
                    onTap: () => openComicDetail(
                      context,
                      comic: comic,
                      heroTag: heroTag,
                      pageBuilder: comicDetailPageBuilder,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
