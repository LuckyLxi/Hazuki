import 'package:get_it/get_it.dart';

import '../services/cloud_sync_service.dart';
import '../services/cloud_sync/cloud_sync_participant_set.dart';
import '../services/comment_filter_service.dart';
import '../services/discover_daily_recommendation_service.dart';
import '../services/download_groups_service.dart';
import '../services/hazuki_source_service.dart';
import '../services/source/source_capabilities.dart';
import '../services/local_favorites_service.dart';
import '../services/manga_download/manga_download_service.dart';
import '../services/password_lock_service.dart';
import '../services/reading_progress_service.dart';
import '../services/read_history_service.dart';
import '../services/search_history_service.dart';
import '../services/software_update/software_update_download_service.dart';
import '../services/software_update/software_update_service.dart';
import '../services/storage/hazuki_database.dart';

final GetIt sl = GetIt.instance;

/// Registers app-level services in the dependency injection container.
///
/// Called once during startup, before any service `.instance` accessor is used.
void registerServices() {
  if (!sl.isRegistered<HazukiDatabase>()) {
    sl.registerLazySingleton<HazukiDatabase>(
      () => HazukiDatabase(),
      dispose: (database) => database.close(),
    );
  }
  if (!sl.isRegistered<CommentFilterService>()) {
    sl.registerLazySingleton<CommentFilterService>(
      () => CommentFilterService(),
    );
  }
  if (!sl.isRegistered<LocalFavoritesService>()) {
    sl.registerLazySingleton<LocalFavoritesService>(
      () => LocalFavoritesService(database: sl<HazukiDatabase>()),
    );
  }
  if (!sl.isRegistered<DownloadGroupsService>()) {
    sl.registerLazySingleton<DownloadGroupsService>(
      () => DownloadGroupsService(database: sl<HazukiDatabase>()),
      dispose: (service) => service.dispose(),
    );
  }
  if (!sl.isRegistered<ReadHistoryService>()) {
    sl.registerLazySingleton<ReadHistoryService>(
      () => ReadHistoryService(database: sl<HazukiDatabase>()),
    );
  }
  if (!sl.isRegistered<ReadingProgressService>()) {
    sl.registerLazySingleton<ReadingProgressService>(
      () => ReadingProgressService(database: sl<HazukiDatabase>()),
    );
  }
  if (!sl.isRegistered<SearchHistoryService>()) {
    sl.registerLazySingleton<SearchHistoryService>(
      () => SearchHistoryService(database: sl<HazukiDatabase>()),
    );
  }
  if (!sl.isRegistered<PasswordLockService>()) {
    sl.registerLazySingleton<PasswordLockService>(() => PasswordLockService());
  }
  if (!sl.isRegistered<SoftwareUpdateDownloadService>()) {
    sl.registerLazySingleton<SoftwareUpdateDownloadService>(
      () => SoftwareUpdateDownloadService(),
    );
  }
  if (!sl.isRegistered<SoftwareUpdateService>()) {
    sl.registerLazySingleton<SoftwareUpdateService>(
      () => SoftwareUpdateService(),
    );
  }
  if (!sl.isRegistered<MangaDownloadService>()) {
    sl.registerLazySingleton<MangaDownloadService>(
      () => MangaDownloadService(),
    );
  }
  if (!sl.isRegistered<DiscoverDailyRecommendationService>()) {
    sl.registerLazySingleton<DiscoverDailyRecommendationService>(
      () =>
          DiscoverDailyRecommendationService(source: sl<HazukiSourceService>()),
    );
  }
  if (!sl.isRegistered<SourceRuntimeRegistry>()) {
    sl.registerLazySingleton<SourceRuntimeRegistry>(
      () => sl<HazukiSourceService>().runtimeRegistry,
    );
  }
  if (!sl.isRegistered<CloudSyncParticipantSet>()) {
    sl.registerLazySingleton<CloudSyncParticipantSet>(
      () => createCloudSyncParticipantSet(
        source: sl<HazukiSourceService>(),
        readHistory: sl<ReadHistoryService>(),
        readingProgress: sl<ReadingProgressService>(),
        localFavorites: sl<LocalFavoritesService>(),
        downloadGroups: sl<DownloadGroupsService>(),
        searchHistory: sl<SearchHistoryService>(),
      ),
    );
  }
  if (!sl.isRegistered<CloudSyncService>()) {
    sl.registerLazySingleton<CloudSyncService>(
      () => CloudSyncService(
        localFavorites: sl<LocalFavoritesService>(),
        commentFilter: sl<CommentFilterService>(),
        downloadGroups: sl<DownloadGroupsService>(),
        participants: sl<CloudSyncParticipantSet>(),
      ),
    );
  }
  if (!sl.isRegistered<HazukiSourceService>()) {
    sl.registerLazySingleton<HazukiSourceService>(() => HazukiSourceService());
  }
  if (!sl.isRegistered<HazukiSourceCapabilities>()) {
    sl.registerLazySingleton<HazukiSourceCapabilities>(
      () => HazukiSourceCapabilities(sl<HazukiSourceService>()),
    );
  }
  if (!sl.isRegistered<SourceSearchGateway>()) {
    sl.registerLazySingleton<SourceSearchGateway>(
      () => sl<HazukiSourceCapabilities>(),
    );
  }
  if (!sl.isRegistered<SourceDiscoverGateway>()) {
    sl.registerLazySingleton<SourceDiscoverGateway>(
      () => sl<HazukiSourceCapabilities>(),
    );
  }
  if (!sl.isRegistered<SourceFavoriteGateway>()) {
    sl.registerLazySingleton<SourceFavoriteGateway>(
      () => sl<HazukiSourceCapabilities>(),
    );
  }
  if (!sl.isRegistered<SourceReaderGateway>()) {
    sl.registerLazySingleton<SourceReaderGateway>(
      () => sl<HazukiSourceCapabilities>(),
    );
  }
  if (!sl.isRegistered<SourceSettingsGateway>()) {
    sl.registerLazySingleton<SourceSettingsGateway>(
      () => sl<HazukiSourceCapabilities>(),
    );
  }
  if (!sl.isRegistered<SourceAccountGateway>()) {
    sl.registerLazySingleton<SourceAccountGateway>(
      () => sl<HazukiSourceCapabilities>(),
    );
  }
  if (!sl.isRegistered<SourceDebugGateway>()) {
    sl.registerLazySingleton<SourceDebugGateway>(
      () => sl<HazukiSourceCapabilities>(),
    );
  }
}
