import 'package:get_it/get_it.dart';

import '../../services/cloud_sync/cloud_sync_participant_set.dart';
import '../../services/cloud_sync_service.dart';
import '../../services/comment_filter_service.dart';
import '../../services/discover_daily_recommendation_service.dart';
import '../../services/download_groups_service.dart';
import '../../services/local_favorites/local_favorites_contracts.dart';
import '../../services/local_favorites/local_favorites_migration.dart';
import '../../services/local_favorites/local_favorites_persistence.dart';
import '../../services/local_favorites/local_favorites_preferences_store.dart';
import '../../services/local_favorites/local_favorites_sync_codec.dart';
import '../../services/local_favorites_service.dart';
import '../../services/manga_download/manga_download_service.dart';
import '../../services/password_lock_service.dart';
import '../../services/read_history_service.dart';
import '../../services/reading_progress_service.dart';
import '../../services/search_history_service.dart';
import '../../services/software_update/software_update_download_service.dart';
import '../../services/software_update/software_update_service.dart';
import '../../services/source/source_capabilities.dart';
import '../../services/storage/hazuki_database.dart';

/// Registers application services against their contract-level dependencies.
void registerApplicationServices(GetIt services) {
  if (!services.isRegistered<HazukiDatabase>()) {
    services.registerLazySingleton<HazukiDatabase>(
      HazukiDatabase.new,
      dispose: (database) => database.close(),
    );
  }
  if (!services.isRegistered<CommentFilterService>()) {
    services.registerLazySingleton<CommentFilterService>(
      CommentFilterService.new,
    );
  }
  if (!services.isRegistered<LocalFavoritesPreferencesStore>()) {
    services.registerLazySingleton<LocalFavoritesPreferencesStore>(
      SharedPreferencesLocalFavoritesPreferencesStore.new,
    );
  }
  if (!services.isRegistered<LocalFavoritesPersistence>()) {
    services.registerLazySingleton<LocalFavoritesPersistence>(
      () => DriftLocalFavoritesPersistence(services<HazukiDatabase>()),
    );
  }
  if (!services.isRegistered<LocalFavoritesSyncCodec>()) {
    services.registerLazySingleton<LocalFavoritesSyncCodec>(
      () => LocalFavoritesSyncCodec(services<LocalFavoritesPersistence>()),
    );
  }
  if (!services.isRegistered<LocalFavoritesMigration>()) {
    services.registerLazySingleton<LocalFavoritesMigration>(
      () => LocalFavoritesMigration(
        syncCodec: services<LocalFavoritesSyncCodec>(),
      ),
    );
  }
  if (!services.isRegistered<LocalFavoritesService>()) {
    services.registerLazySingleton<LocalFavoritesService>(
      () => LocalFavoritesService(
        preferences: services<LocalFavoritesPreferencesStore>(),
        persistence: services<LocalFavoritesPersistence>(),
        syncCodec: services<LocalFavoritesSyncCodec>(),
        migration: services<LocalFavoritesMigration>(),
      ),
    );
  }
  if (!services.isRegistered<LocalFavoritesRepository>()) {
    services.registerLazySingleton<LocalFavoritesRepository>(
      () => services<LocalFavoritesService>(),
    );
  }
  if (!services.isRegistered<LocalFavoritesSyncStore>()) {
    services.registerLazySingleton<LocalFavoritesSyncStore>(
      () => services<LocalFavoritesService>(),
    );
  }
  if (!services.isRegistered<DownloadGroupsService>()) {
    services.registerLazySingleton<DownloadGroupsService>(
      () => DownloadGroupsService(database: services<HazukiDatabase>()),
      dispose: (service) => service.dispose(),
    );
  }
  if (!services.isRegistered<ReadHistoryService>()) {
    services.registerLazySingleton<ReadHistoryService>(
      () => ReadHistoryService(database: services<HazukiDatabase>()),
    );
  }
  if (!services.isRegistered<ReadingProgressService>()) {
    services.registerLazySingleton<ReadingProgressService>(
      () => ReadingProgressService(database: services<HazukiDatabase>()),
    );
  }
  if (!services.isRegistered<SearchHistoryService>()) {
    services.registerLazySingleton<SearchHistoryService>(
      () => SearchHistoryService(database: services<HazukiDatabase>()),
    );
  }
  if (!services.isRegistered<PasswordLockService>()) {
    services.registerLazySingleton<PasswordLockService>(
      PasswordLockService.new,
    );
  }
  if (!services.isRegistered<SoftwareUpdateDownloadService>()) {
    services.registerLazySingleton<SoftwareUpdateDownloadService>(
      SoftwareUpdateDownloadService.new,
    );
  }
  if (!services.isRegistered<SoftwareUpdateService>()) {
    services.registerLazySingleton<SoftwareUpdateService>(
      SoftwareUpdateService.new,
    );
  }
  if (!services.isRegistered<MangaDownloadService>()) {
    services.registerLazySingleton<MangaDownloadService>(
      () => MangaDownloadService(sourceReader: services<SourceReaderGateway>()),
    );
  }
  if (!services.isRegistered<DiscoverDailyRecommendationService>()) {
    services.registerLazySingleton<DiscoverDailyRecommendationService>(
      () => DiscoverDailyRecommendationService(
        source: services<SourceDailyRecommendationGateway>(),
      ),
    );
  }
  if (!services.isRegistered<CloudSyncParticipantSet>()) {
    services.registerLazySingleton<CloudSyncParticipantSet>(
      () => createCloudSyncParticipantSet(
        source: services<SourceSyncGateway>(),
        readHistory: services<ReadHistoryService>(),
        readingProgress: services<ReadingProgressService>(),
        localFavorites: services<LocalFavoritesSyncStore>(),
        downloadGroups: services<DownloadGroupsService>(),
        searchHistory: services<SearchHistoryService>(),
      ),
    );
  }
  if (!services.isRegistered<CloudSyncService>()) {
    services.registerLazySingleton<CloudSyncService>(
      () => CloudSyncService(
        localFavorites: services<LocalFavoritesRepository>(),
        commentFilter: services<CommentFilterService>(),
        downloadGroups: services<DownloadGroupsService>(),
        participants: services<CloudSyncParticipantSet>(),
      ),
    );
  }
}
