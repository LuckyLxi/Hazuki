import 'package:hazuki/services/manga_download/manga_download_commands.dart';
import 'package:hazuki/services/reading_progress_service.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/services/source/interaction/source_ui_service.dart';
import '../../../shared/translation/manga_translation_dependencies.dart';

class ReaderDependencies {
  const ReaderDependencies({
    required this.sourceUiService,
    required this.sourceReader,
    required this.sourceSettings,
    required this.readingProgressService,
    required this.downloader,
    this.taskControl,
    this.readerSessions,
    this.readingProgressUploads,
    this.cloudReading,
    this.translation,
  });

  final SourceUiService sourceUiService;
  final SourceReaderGateway sourceReader;
  final SourceReaderSessionGateway? readerSessions;
  final SourceReadingProgressGateway? readingProgressUploads;
  final SourceCloudReadingGateway? cloudReading;
  final SourceSettingsGateway sourceSettings;
  final ReadingProgressService readingProgressService;
  final MangaDownloadCommands downloader;
  final SourceTaskControlGateway? taskControl;
  final MangaTranslationDependencies? translation;
}
