import '../../models/hazuki_models.dart';
import 'manga_download_models.dart';

export 'manga_download_models.dart';

/// Download operations available to comic details and reader actions.
abstract interface class MangaDownloadCommands {
  Future<MangaDownloadConflict> checkDownloadTaskConflict({
    required ComicDetailsData details,
    required List<MangaChapterDownloadTarget> chapters,
  });

  Future<MangaDownloadConflict> checkDownloadConflict({
    required ComicDetailsData details,
    required List<MangaChapterDownloadTarget> chapters,
  });

  Future<MangaDownloadEnqueueResult> enqueueDownload({
    required ComicDetailsData details,
    required String coverUrl,
    required String description,
    required List<MangaChapterDownloadTarget> chapters,
    bool redownloadExisting = false,
  });
}
