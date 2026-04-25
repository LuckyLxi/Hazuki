import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hazuki/app/chapter_title_resolver.dart';
import 'package:hazuki/app/windows_title_bar_controller.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/services/manga_download_service.dart';
import 'package:hazuki/widgets/widgets.dart';
import 'downloaded_comic_detail_widgets.dart';
import 'downloads_cover_widgets.dart';
import '../support/downloads_shared.dart';

class DownloadedComicDetailPage extends StatelessWidget {
  const DownloadedComicDetailPage({
    super.key,
    required this.comic,
    required this.readerPageBuilder,
  });

  final DownloadedMangaComic comic;
  final DownloadedComicReaderPageBuilder readerPageBuilder;

  String get _coverHeroTag => 'downloaded_cover_${comic.comicId}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: hazukiFrostedAppBar(
        context: context,
        title: Text(comic.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DownloadedComicCover(
                comic: comic,
                heroTag: _coverHeroTag,
                width: 116,
                height: 162,
                borderRadius: 16,
                onTap: () {
                  Navigator.of(context).push(
                    PageRouteBuilder<void>(
                      opaque: false,
                      barrierColor: Colors.black54,
                      pageBuilder:
                          (previewContext, animation, secondaryAnimation) {
                            return DownloadedComicCoverPreviewPage(
                              comic: comic,
                              heroTag: _coverHeroTag,
                            );
                          },
                    ),
                  );
                },
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comic.title,
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ) ??
                          const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ),
                    ),
                    if (comic.subTitle.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(comic.subTitle),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      l10n(
                        context,
                      ).downloadsChapterCount('${comic.chapters.length}'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (comic.description.trim().isNotEmpty) ...[
            const SizedBox(height: 18),
            DownloadedComicExpandableDescription(
              text: comic.description.trim(),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            l10n(context).comicDetailChapters,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          ...comic.chapters.map((chapter) {
            final displayTitle = resolveHazukiChapterTitle(
              context,
              chapter.title,
            );
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                title: Text(displayTitle),
                subtitle: Text(
                  l10n(context).downloadsCurrentProgress(
                    '${chapter.imagePaths.length}',
                    '${chapter.imagePaths.length}',
                  ),
                ),
                trailing: const Icon(Icons.menu_book_outlined),
                onTap: () async {
                  final titleBarController = Platform.isWindows
                      ? HazukiWindowsTitleBarScope.of(context)
                      : null;
                  final titleBarSuppressionOwner = Object();
                  titleBarController?.suppressCustomTitleBar(
                    titleBarSuppressionOwner,
                  );
                  try {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => readerPageBuilder(comic, chapter),
                      ),
                    );
                  } finally {
                    titleBarController?.releaseCustomTitleBarSuppression(
                      titleBarSuppressionOwner,
                    );
                  }
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}
