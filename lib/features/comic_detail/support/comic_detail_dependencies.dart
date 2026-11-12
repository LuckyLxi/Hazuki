import 'package:hazuki/services/local_favorites/local_favorites_contracts.dart';
import 'package:hazuki/services/manga_download/manga_download_commands.dart';
import 'package:hazuki/services/read_history_service.dart';
import 'package:hazuki/services/reading_progress_service.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/services/source/interaction/source_ui_service.dart';

import '../repository/comic_detail_repository.dart';

class ComicDetailDependencies {
  final SourceUiService sourceUiService;
  final SourceTaskControlGateway taskControl;
  const ComicDetailDependencies({
    required this.sourceUiService,
    required this.taskControl,
    required this.source,
    this.cloudReading,
    required this.localFavorites,
    required this.downloader,
    required this.readingProgress,
    required this.readHistory,
    required this.imageGateway,
  });

  final SourceComicDetailGateway source;
  final SourceCloudReadingGateway? cloudReading;
  final LocalFavoritesRepository localFavorites;
  final MangaDownloadCommands downloader;
  final ReadingProgressService readingProgress;
  final ReadHistoryService readHistory;
  final SourceImageGateway imageGateway;

  ComicDetailFeatureFacade createFacade({String sourceKey = ''}) {
    return ComicDetailFeatureFacade(
      source: source,
      cloudReading: cloudReading,
      local: localFavorites,
      readingProgress: readingProgress,
      readHistory: readHistory,
      sourceKey: sourceKey,
    );
  }
}
