import 'package:hazuki/services/cloud_sync_service.dart';
import 'package:hazuki/services/comment_filter_service.dart';
import 'package:hazuki/services/discover_daily_recommendation_service.dart';
import 'package:hazuki/services/manga_download/manga_download_service.dart';
import 'package:hazuki/services/password_lock_service.dart';
import 'package:hazuki/services/software_update/software_update_service.dart';
import 'package:hazuki/services/source/source_capabilities.dart';

class SettingsCoreDependencies {
  const SettingsCoreDependencies({
    required this.sourceSettings,
    required this.sourceDebug,
    required this.passwordLock,
    required this.softwareUpdate,
    required this.cloudSync,
    required this.commentFilter,
    required this.dailyRecommendation,
    required this.downloader,
    required this.sourceRuntime,
  });

  final SourceSettingsGateway sourceSettings;
  final SourceDebugGateway sourceDebug;
  final PasswordLockService passwordLock;
  final SoftwareUpdateService softwareUpdate;
  final CloudSyncService cloudSync;
  final CommentFilterService commentFilter;
  final DiscoverDailyRecommendationService dailyRecommendation;
  final MangaDownloadService downloader;
  final SourceRuntimeGateway sourceRuntime;
}
