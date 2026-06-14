import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hazuki/shared/chapter_title_resolver.dart';
import 'package:hazuki/app/windows/windows_title_bar_controller.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/services/manga_download/manga_download_service.dart';
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

  String get _coverHeroTag => 'downloaded_cover_${comic.storageKey}';

  @override
  Widget build(BuildContext context) {
    final imageCount = comic.chapters.fold<int>(
      0,
      (sum, chapter) => sum + chapter.imagePaths.length,
    );
    return Scaffold(
      appBar: hazukiFrostedAppBar(
        context: context,
        title: Text(comic.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          DownloadedComicOverviewCard(
            comic: comic,
            imageCount: imageCount,
            coverHeroTag: _coverHeroTag,
            onCoverTap: () {
              Navigator.of(context).push(
                PageRouteBuilder<void>(
                  opaque: false,
                  barrierColor: Colors.black54,
                  pageBuilder: (previewContext, animation, secondaryAnimation) {
                    return DownloadedComicCoverPreviewPage(
                      comic: comic,
                      heroTag: _coverHeroTag,
                    );
                  },
                ),
              );
            },
            onCopyId: () async {
              await Clipboard.setData(ClipboardData(text: comic.comicId));
              if (!context.mounted) return;
              await showHazukiPrompt(
                context,
                l10n(context).comicDetailCopiedId,
              );
            },
          ),
          if (comic.description.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            DownloadedComicSectionCard(
              title: l10n(context).comicDetailSummary,
              child: DownloadedComicExpandableDescription(
                text: comic.description.trim(),
              ),
            ),
          ],
          if (comic.tags.isNotEmpty || comic.uploader.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            DownloadedComicSectionCard(
              title: l10n(context).comicDetailTabInfo,
              child: DownloadedComicMetadata(
                tags: comic.tags,
                uploader: comic.uploader,
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Text(
                l10n(context).comicDetailChapters,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                '${comic.chapters.length}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...comic.chapters.map((chapter) {
            final displayTitle = resolveHazukiChapterTitle(
              context,
              chapter.title,
            );
            return Card(
              margin: const EdgeInsets.only(bottom: 4),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                leading: SizedBox(
                  width: 26,
                  child: Text(
                    '${chapter.index + 1}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                title: Text(
                  displayTitle,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                subtitle: Text(
                  l10n(context).downloadsCurrentProgress(
                    '${chapter.imagePaths.length}',
                    '${chapter.imagePaths.length}',
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
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
