import 'package:get_it/get_it.dart';

import '../services/cloud_sync_service.dart';
import '../services/cloud_sync/cloud_sync_participant_set.dart';
import '../services/comment_filter_service.dart';
import '../services/discover_daily_recommendation_service.dart';
import '../services/download_groups_service.dart';
import '../services/hazuki_source_service.dart';
import '../services/source/source_capabilities.dart';
import '../services/local_favorites_service.dart';
import '../services/local_favorites/local_favorites_contracts.dart';
import '../services/local_favorites/local_favorites_migration.dart';
import '../services/local_favorites/local_favorites_persistence.dart';
import '../services/local_favorites/local_favorites_preferences_store.dart';
import '../services/local_favorites/local_favorites_sync_codec.dart';
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
  if (!sl.isRegistered<LocalFavoritesPreferencesStore>()) {
    sl.registerLazySingleton<LocalFavoritesPreferencesStore>(
      SharedPreferencesLocalFavoritesPreferencesStore.new,
    );
  }
  if (!sl.isRegistered<LocalFavoritesPersistence>()) {
    sl.registerLazySingleton<LocalFavoritesPersistence>(
      () => DriftLocalFavoritesPersistence(sl<HazukiDatabase>()),
    );
  }
  if (!sl.isRegistered<LocalFavoritesSyncCodec>()) {
    sl.registerLazySingleton<LocalFavoritesSyncCodec>(
      () => LocalFavoritesSyncCodec(sl<LocalFavoritesPersistence>()),
    );
  }
  if (!sl.isRegistered<LocalFavoritesMigration>()) {
    sl.registerLazySingleton<LocalFavoritesMigration>(
      () => LocalFavoritesMigration(syncCodec: sl<LocalFavoritesSyncCodec>()),
    );
  }
  if (!sl.isRegistered<LocalFavoritesService>()) {
    sl.registerLazySingleton<LocalFavoritesService>(
      () => LocalFavoritesService(
        preferences: sl<LocalFavoritesPreferencesStore>(),
        persistence: sl<LocalFavoritesPersistence>(),
        syncCodec: sl<LocalFavoritesSyncCodec>(),
        migration: sl<LocalFavoritesMigration>(),
      ),
    );
  }
  if (!sl.isRegistered<LocalFavoritesRepository>()) {
    sl.registerLazySingleton<LocalFavoritesRepository>(
      () => sl<LocalFavoritesService>(),
    );
  }
  if (!sl.isRegistered<LocalFavoritesSyncStore>()) {
    sl.registerLazySingleton<LocalFavoritesSyncStore>(
      () => sl<LocalFavoritesService>(),
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
      () => MangaDownloadService(sourceReader: sl<SourceReaderGateway>()),
    );
  }
  if (!sl.isRegistered<DiscoverDailyRecommendationService>()) {
    sl.registerLazySingleton<DiscoverDailyRecommendationService>(
      () => DiscoverDailyRecommendationService(
        source: sl<SourceDailyRecommendationGateway>(),
      ),
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
        source: sl<SourceSyncGateway>(),
        readHistory: sl<ReadHistoryService>(),
        readingProgress: sl<ReadingProgressService>(),
        localFavorites: sl<LocalFavoritesSyncStore>(),
        downloadGroups: sl<DownloadGroupsService>(),
        searchHistory: sl<SearchHistoryService>(),
      ),
    );
  }
  if (!sl.isRegistered<CloudSyncService>()) {
    sl.registerLazySingleton<CloudSyncService>(
      () => CloudSyncService(
        localFavorites: sl<LocalFavoritesRepository>(),
        commentFilter: sl<CommentFilterService>(),
        downloadGroups: sl<DownloadGroupsService>(),
        participants: sl<CloudSyncParticipantSet>(),
      ),
    );
  }
  if (!sl.isRegistered<HazukiSourceService>()) {
    sl.registerLazySingleton<HazukiSourceService>(() => HazukiSourceService());
  }
  if (!sl.isRegistered<SourceSearchGateway>()) {
    sl.registerLazySingleton<SourceSearchGateway>(
      () => HazukiSourceSearchAdapter(sl<HazukiSourceService>()),
    );
  }
  if (!sl.isRegistered<SourceDiscoverGateway>()) {
    sl.registerLazySingleton<SourceDiscoverGateway>(
      () => HazukiSourceDiscoverAdapter(sl<HazukiSourceService>()),
    );
  }
  if (!sl.isRegistered<SourceFavoriteGateway>()) {
    sl.registerLazySingleton<SourceFavoriteGateway>(
      () => HazukiSourceFavoriteAdapter(sl<HazukiSourceService>()),
    );
  }
  if (!sl.isRegistered<SourceReaderGateway>()) {
    sl.registerLazySingleton<SourceReaderGateway>(
      () => HazukiSourceReaderAdapter(sl<HazukiSourceService>()),
    );
  }
  if (!sl.isRegistered<SourceSettingsGateway>()) {
    sl.registerLazySingleton<SourceSettingsGateway>(
      () => HazukiSourceSettingsAdapter(sl<HazukiSourceService>()),
    );
  }
  if (!sl.isRegistered<SourceAccountGateway>()) {
    sl.registerLazySingleton<SourceAccountGateway>(
      () => HazukiSourceAccountAdapter(sl<HazukiSourceService>()),
    );
  }
  if (!sl.isRegistered<SourceDebugGateway>()) {
    sl.registerLazySingleton<SourceDebugGateway>(
      () => HazukiSourceDebugAdapter(sl<HazukiSourceService>()),
    );
  }
  if (!sl.isRegistered<SourceImageGateway>()) {
    sl.registerLazySingleton<SourceImageGateway>(
      () => HazukiSourceImageAdapter(sl<HazukiSourceService>()),
    );
  }
  if (!sl.isRegistered<SourceRecommendationGateway>()) {
    sl.registerLazySingleton<SourceRecommendationGateway>(
      () => HazukiSourceRecommendationAdapter(sl<HazukiSourceService>()),
    );
  }
  if (!sl.isRegistered<SourceDailyRecommendationGateway>()) {
    sl.registerLazySingleton<SourceDailyRecommendationGateway>(
      () => HazukiSourceDailyRecommendationAdapter(sl<HazukiSourceService>()),
    );
  }
  if (!sl.isRegistered<SourceSyncGateway>()) {
    sl.registerLazySingleton<SourceSyncGateway>(
      () => HazukiSourceSyncAdapter(sl<HazukiSourceService>()),
    );
  }
  if (!sl.isRegistered<SourceRuntimeGateway>()) {
    sl.registerLazySingleton<SourceRuntimeGateway>(
      () => HazukiSourceRuntimeAdapter(sl<HazukiSourceService>()),
    );
  }
  if (!sl.isRegistered<SourceCategoryGateway>()) {
    sl.registerLazySingleton<SourceCategoryGateway>(
      () => HazukiSourceCategoryAdapter(sl<HazukiSourceService>()),
    );
  }
  if (!sl.isRegistered<SourceCommentsGateway>()) {
    sl.registerLazySingleton<SourceCommentsGateway>(
      () => HazukiSourceCommentsAdapter(sl<HazukiSourceService>()),
    );
  }
  if (!sl.isRegistered<SourceComicDetailGateway>()) {
    sl.registerLazySingleton<SourceComicDetailGateway>(
      () => HazukiSourceComicDetailAdapter(sl<HazukiSourceService>()),
    );
  }
}
