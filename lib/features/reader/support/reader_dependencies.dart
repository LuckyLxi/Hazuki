import 'package:hazuki/services/manga_download/manga_download_service.dart';
import 'package:hazuki/services/reading_progress_service.dart';
import 'package:hazuki/services/source/source_capabilities.dart';

class ReaderDependencies {
  const ReaderDependencies({
    required this.sourceReader,
    required this.sourceSettings,
    required this.readingProgressService,
    required this.downloader,
  });

  final SourceReaderGateway sourceReader;
  final SourceSettingsGateway sourceSettings;
  final ReadingProgressService readingProgressService;
  final MangaDownloadService downloader;
}
