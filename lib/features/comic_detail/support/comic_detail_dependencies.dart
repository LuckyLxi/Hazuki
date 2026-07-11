import 'package:hazuki/services/local_favorites/local_favorites_contracts.dart';
import 'package:hazuki/services/manga_download/manga_download_service.dart';
import 'package:hazuki/services/read_history_service.dart';
import 'package:hazuki/services/reading_progress_service.dart';
import 'package:hazuki/services/source/source_capabilities.dart';

import '../repository/comic_detail_repository.dart';

class ComicDetailDependencies {
  const ComicDetailDependencies({
    required this.source,
    required this.localFavorites,
    required this.downloader,
    required this.readingProgress,
    required this.readHistory,
    required this.imageGateway,
  });

  final SourceComicDetailGateway source;
  final LocalFavoritesRepository localFavorites;
  final MangaDownloadService downloader;
  final ReadingProgressService readingProgress;
  final ReadHistoryService readHistory;
  final SourceImageGateway imageGateway;

  ComicDetailFeatureFacade createFacade({String sourceKey = ''}) {
    return ComicDetailFeatureFacade(
      source: source,
      local: localFavorites,
      downloader: downloader,
      readingProgress: readingProgress,
      readHistory: readHistory,
      sourceKey: sourceKey,
    );
  }
}
