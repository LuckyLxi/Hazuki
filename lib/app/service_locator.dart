import 'package:get_it/get_it.dart';

import '../services/cloud_sync_service.dart';
import '../services/cloud_sync/cloud_sync_participant_set.dart';
import '../services/comment_filter_service.dart';
import '../services/discover_daily_recommendation_service.dart';
import '../services/download_groups_service.dart';
import '../services/source/runtime/source_runtime_assembly.dart';
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
      () => sl<SourceRuntimeAssembly>().runtimeRegistry,
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
  if (!sl.isRegistered<SourceRuntimeAssembly>()) {
    sl.registerLazySingleton<SourceRuntimeAssembly>(
      () => SourceRuntimeAssembly(),
    );
  }
  if (!sl.isRegistered<SourceSearchGateway>()) {
    sl.registerLazySingleton<SourceSearchGateway>(
      () => sl<SourceRuntimeAssembly>().gateways.search,
    );
  }
  if (!sl.isRegistered<SourceDiscoverGateway>()) {
    sl.registerLazySingleton<SourceDiscoverGateway>(
      () => sl<SourceRuntimeAssembly>().gateways.discover,
    );
  }
  if (!sl.isRegistered<SourceFavoriteGateway>()) {
    sl.registerLazySingleton<SourceFavoriteGateway>(
      () => sl<SourceRuntimeAssembly>().gateways.favorite,
    );
  }
  if (!sl.isRegistered<SourceReaderGateway>()) {
    sl.registerLazySingleton<SourceReaderGateway>(
      () => sl<SourceRuntimeAssembly>().gateways.reader,
    );
  }
  if (!sl.isRegistered<SourceSettingsGateway>()) {
    sl.registerLazySingleton<SourceSettingsGateway>(
      () => sl<SourceRuntimeAssembly>().gateways.settingsGateway,
    );
  }
  if (!sl.isRegistered<SourceAccountGateway>()) {
    sl.registerLazySingleton<SourceAccountGateway>(
      () => sl<SourceRuntimeAssembly>().gateways.accountGateway,
    );
  }
  if (!sl.isRegistered<SourceDebugGateway>()) {
    sl.registerLazySingleton<SourceDebugGateway>(
      () => sl<SourceRuntimeAssembly>().gateways.debugGateway,
    );
  }
  if (!sl.isRegistered<SourceImageGateway>()) {
    sl.registerLazySingleton<SourceImageGateway>(
      () => sl<SourceRuntimeAssembly>().gateways.imageGateway,
    );
  }
  if (!sl.isRegistered<SourceRecommendationGateway>()) {
    sl.registerLazySingleton<SourceRecommendationGateway>(
      () => sl<SourceRuntimeAssembly>().gateways.recommendation,
    );
  }
  if (!sl.isRegistered<SourceDailyRecommendationGateway>()) {
    sl.registerLazySingleton<SourceDailyRecommendationGateway>(
      () => sl<SourceRuntimeAssembly>().gateways.dailyRecommendation,
    );
  }
  if (!sl.isRegistered<SourceSyncGateway>()) {
    sl.registerLazySingleton<SourceSyncGateway>(
      () => sl<SourceRuntimeAssembly>().gateways.sync,
    );
  }
  if (!sl.isRegistered<SourceRuntimeGateway>()) {
    sl.registerLazySingleton<SourceRuntimeGateway>(
      () => sl<SourceRuntimeAssembly>().gateways.runtimeGateway,
    );
  }
  if (!sl.isRegistered<SourceSelectionGateway>()) {
    sl.registerLazySingleton<SourceSelectionGateway>(
      () => sl<SourceRuntimeAssembly>().gateways.selection,
    );
  }
  if (!sl.isRegistered<SourceHomeGateway>()) {
    sl.registerLazySingleton<SourceHomeGateway>(
      () => sl<SourceRuntimeAssembly>().gateways.home,
    );
  }
  if (!sl.isRegistered<SourceSwitchGateway>()) {
    sl.registerLazySingleton<SourceSwitchGateway>(
      () => sl<SourceRuntimeAssembly>().gateways.switchGateway,
    );
  }
  if (!sl.isRegistered<SourceAdvancedGateway>()) {
    sl.registerLazySingleton<SourceAdvancedGateway>(
      () => sl<SourceRuntimeAssembly>().gateways.advanced,
    );
  }
  if (!sl.isRegistered<SourceCategoryGateway>()) {
    sl.registerLazySingleton<SourceCategoryGateway>(
      () => sl<SourceRuntimeAssembly>().gateways.category,
    );
  }
  if (!sl.isRegistered<SourceCommentsGateway>()) {
    sl.registerLazySingleton<SourceCommentsGateway>(
      () => sl<SourceRuntimeAssembly>().gateways.commentsGateway,
    );
  }
  if (!sl.isRegistered<SourceComicDetailGateway>()) {
    sl.registerLazySingleton<SourceComicDetailGateway>(
      () => sl<SourceRuntimeAssembly>().gateways.comicDetail,
    );
  }
  if (!sl.isRegistered<SourceBootstrapGateway>()) {
    sl.registerLazySingleton<SourceBootstrapGateway>(
      () => sl<SourceRuntimeAssembly>().gateways.bootstrap,
    );
  }
  if (!sl.isRegistered<SourceUpdateGateway>()) {
    sl.registerLazySingleton<SourceUpdateGateway>(
      () => sl<SourceRuntimeAssembly>().gateways.update,
    );
  }
  if (!sl.isRegistered<SourceScriptGateway>()) {
    sl.registerLazySingleton<SourceScriptGateway>(
      () => sl<SourceRuntimeAssembly>().gateways.script,
    );
  }
  if (!sl.isRegistered<SourceLocalizationGateway>()) {
    sl.registerLazySingleton<SourceLocalizationGateway>(
      () => sl<SourceRuntimeAssembly>().gateways.localizationGateway,
    );
  }
}
